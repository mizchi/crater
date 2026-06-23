---
name: moonbit-mem-profile
description: Profile MoonBit memory/allocations with moon-pprof to find and fix allocation hotspots. Use when the user wants to memory-profile a MoonBit package, reduce allocations / GC pressure, investigate a slow hot path on the wasm backend, or mentions moon-pprof / samply / "memory profile" / "allocation profile" in this repo.
---

# MoonBit memory profiling with moon-pprof

Find allocation hotspots in MoonBit code by building a small wasm entry that
exercises the hot path, profiling it with `moon-pprof memprofile`, and reading
the per-site allocation summary. This is how the HTML parser allocation wins
(#304: −71% parse allocations) were found.

`moon-pprof`: https://github.com/mizchi/moon-pprof

## When to use

- "memory profile / allocation profile this", "reduce allocations", "why is GC
  hot", "profile the parser/cascade/layout".
- After a CPU/time finding, to see whether allocation is the cause.
- The win is usually **wasm-specific**: `String` `op_get` (`s[i]`), per-char
  `StringBuilder.write_char`, `Some(...)` in `peek`/`consume`, and per-element
  `Map`/`Array` allocation dominate. JS-target benches often won't show it
  (JS string indexing doesn't allocate), so profile **wasm**.

## One-time setup

```bash
# moon-pprof needs protoc + rustc 1.80+
apt-get install -y protobuf-compiler          # if `protoc` is missing
cargo install moon-pprof --locked             # ~5 min; binary lands in ~/.cargo/bin
export PATH="$HOME/.cargo/bin:$HOME/.moon/bin:/root/.moon/bin:$PATH"
```

## Workflow

### 1. Add a temporary wasm `main` that drives the hot path

Create a throwaway package **inside the module you're profiling** (so imports
resolve locally), e.g. `dom/profmain/`:

`dom/profmain/moon.pkg`
```
import { "mizchi/crater-dom/html" }
options( "is-main": true )
```

`dom/profmain/main.mbt` — generate representative input and run the hot path
**once** over a **small** workload (instrumented wasm is slow). Reference the
result so it isn't optimised away:
```moonbit
fn main {
  let html = gen_attr_heavy_html(200)        // ~200 elements is plenty
  let doc = @html.parse_document(html)
  println("children=\{doc.root.children.length()}")
}
```
Make the input shaped like the real concern (e.g. inline `style=`/`class=` on
every element for parser work), not bare tags.

### 2. Build to wasm (NOT wasm-gc, NOT release)

```bash
cd <module>            # e.g. cd dom
moon build --target wasm
# artifact: _build/wasm/debug/build/<module-name>/<pkg>/<pkg>.wasm
```
- Use **debug**: release strips the alloc-hook sites → *"no instrumentation
  sites found in this wasm"*.
- Use **`--target wasm`** (linear memory): `memprofile` hooks `moonbit.malloc`.

### 3. Profile and summarise

```bash
WASM=_build/wasm/debug/build/mizchi/crater-dom/profmain/profmain.wasm
timeout 110 moon-pprof memprofile "$WASM" --out /tmp/prof.pb.gz   # keep workload small or it times out
moon-pprof summary /tmp/prof.pb.gz                                # top sites by bytes + alloc count
moon-pprof summary --diff before.pb.gz after.pb.gz               # compare before/after a fix
```

`summary` reports `Total: <bytes> across N sites`, `Total allocations: M`, and
top sites with `bytes`, `%`, `allocs`, and demangled function name.

### 4. Read the profile

- Sort by **alloc count**, not just bytes: a site with many tiny (~12B) allocs
  is GC pressure and usually a per-char/per-iteration bug.
- Names are demangled, e.g. `mizchi::crater_2ddom::html::find__substring`
  (`__` = `_`), `moonbit.unsafe_make_string_raw` (a real `String` allocation),
  `moonbit.ref_array_make_raw`, `Map::set__with__hash`.
- `unsafe_make_string_raw` with few large allocs is usually *necessary* output
  (the parsed strings). Hunt the **many-small-allocs** sites instead.

### 5. Confirm attribution before fixing (important)

moon-pprof's site can mis-attribute (inlining). **Stub the suspect** and
re-profile to confirm the allocs actually move:
```moonbit
// temporarily: let resource_html = html   // was strip_noscript_blocks(html)
```
If the suspect's allocs vanish from `summary`, it's real. Then fix and re-profile
to measure.

### 6. Fix patterns (wasm allocation)

- Full-document `s[i]` char scans → native **`String::contains` / `String::find`
  / `String::rev_find`** (allocation-free), or scan a **`StringView`**.
- Per-char `StringBuilder` value building → scan an index range, then one slice:
  `input[start:end].to_owned()` (StringView → owned String; not `.to_string()`,
  which is deprecated for views).
- `peek`/`consume` returning `Char?` per char → index loop with
  `input[p].to_int()` / `view.unsafe_charcode_at(p)` (no `Option`).
- Skip redundant whole-string passes (lowercasing + rebuilding when nothing
  matches): early-return the input unchanged.

### 7. Clean up

Remove the throwaway `profmain/` package and `_build` artifacts; ship only the
library change. Keep `before/after` numbers from `moon-pprof summary` in the
commit/PR body.

## CPU profiling (samply / pprof)

For time (not allocation): `moon-pprof profile <wasm>` runs wasm under wasmtime +
GuestProfiler and emits pprof; `moon-pprof bench` does baseline/patched
comparison across backends. samply consumes the Firefox-profiler format that
moon-pprof can convert. Prefer the JS bench harness (`moon bench --package
... --target js --file X.mbt`) for quick wall-clock numbers, and reserve
moon-pprof for allocation attribution.

## Gotchas

- JS-target benches may show *no* change for a wasm allocation fix — that's
  expected; report it honestly and note the win is wasm-specific.
- Instrumented wasm is ~2–5× slower; shrink the workload (one pass, a few
  hundred elements) so `memprofile` finishes well under the timeout.
- `gc-alloc-sites=0` in the memprofile log is normal for `--target wasm`
  (it wraps `moonbit.malloc`, not GC sites).
