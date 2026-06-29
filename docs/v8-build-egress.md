# Building the native V8 runtime under scoped git egress (and how not to misdiagnose it)

This note records what actually blocks the `mizchi/v8` / rusty_v8 native build in
the Claude-Code-on-the-web sandbox, the HTTPS path that builds it anyway, and how
to avoid the recurring **misdiagnosis** that "v8 egress is blocked, so the runtime
can't build here." See also #312.

## What is actually blocked

The sandbox's network policy is **per-channel**, not "GitHub is blocked":

| Channel | Example | Result |
| --- | --- | --- |
| `git` protocol | `git clone https://github.com/denoland/rusty_v8` | **403** — rewritten to the session git proxy (`127.0.0.1:.../git/...`), which is scoped to the session's repos only |
| HTTPS web/API | `curl https://github.com/denoland/rusty_v8/releases/latest` | 200 |
| HTTPS release asset | `curl .../releases/download/<tag>/librusty_v8_release_*.a.gz` | 200/206, full file |
| HTTPS source tarball | `curl .../archive/refs/tags/<tag>.tar.gz` | 200 |
| HTTPS binding | `curl .../releases/download/<tag>/src_binding_release_*.rs` | 200 |
| crates.io | cargo deps | direct (allow-listed in `noProxy`) |

So **only `git` is scoped**. Every artifact the build needs is reachable over
plain HTTPS.

## Why it looks like "all tests are blocked"

`mizchi/v8` runs a `postadd` hook (`src/scripts/build-rusty-v8.sh`) during
**whole-workspace dependency resolution**. That script does
`git clone --depth 1 --branch <rev> https://github.com/denoland/rusty_v8.git`,
which 403s. Because resolution covers the whole workspace, even a v8-unrelated
`moon test -p mizchi/crater-dom --target js` aborts before any test runs. That is
the symptom #312 describes — it is a `git`-scope failure, not a general egress
wall.

Mitigation that exists today: `scripts/moon-test-no-v8.sh` drops `./browser/native`
and `./testing` from `moon.work` and sets `MIZCHI_V8_OPTIONAL=1`, so the non-v8
packages resolve and test. The member-trimming is factored into
`scripts/ci/drop-v8-members.sh` (idempotent, in-place) so the same trim is reused
by CI jobs that don't link V8 — `moon-test-no-v8.sh` wraps it with backup/restore,
while an ephemeral CI runner can call it directly with no restore.

### Which CI jobs need the trim

A job that runs `moon` over the workspace (e.g. via `./.github/actions/moon-prefetch`,
which runs `moon tree` + `moon fetch`) resolves the full graph and triggers the v8
postadd. A job that **links V8** (the native `test`, `wpt-webdriver-tests`,
`playwright-*`) pairs `moon-prefetch` with `./.github/actions/rusty-v8-prefetch` and
*should* build it. A job that is **JS/wasm-only** pays the `git clone` for nothing
and inherits its flake risk. `vrt-bench` (a pure `--target js`
`mizchi/crater-benchmarks` build — verified to build with the members trimmed and
**zero** network) now runs `scripts/ci/drop-v8-members.sh` before its prefetch.
The same step can be added to other JS/wasm-only `moon-prefetch` jobs
(`js-package`, `wasm-component`, `wpt-css-tests`, `wpt-dom-tests`) once it's
confirmed they don't intend to compile-check the trimmed members on their target;
apply it per-job deliberately rather than globally.

## The HTTPS build path (verified to work in-sandbox)

`build-rusty-v8.sh` skips the `git clone` when `deps/rusty_v8/.git` exists, and the
rusty_v8 crate's `build.rs` honors `RUSTY_V8_ARCHIVE` / `RUSTY_V8_SRC_BINDING_PATH`
to skip its own network fetch. So:

```bash
REV=v146.8.0   # = mizchi/v8 deps/rusty_v8.rev
SUFFIX=x86_64-unknown-linux-gnu

# 1. rusty_v8 crate source via HTTPS tarball (NOT git clone)
curl -fsSL "https://github.com/denoland/rusty_v8/archive/refs/tags/${REV}.tar.gz" | tar -xz
mv rusty_v8-* deps/rusty_v8 && ( cd deps/rusty_v8 && git init -q )   # .git presence => clone skipped

# 2. prebuilt static lib via HTTPS, decompressed to a plain .a
curl -fsSL "https://github.com/denoland/rusty_v8/releases/download/${REV}/librusty_v8_release_${SUFFIX}.a.gz" -o lib.a.gz
gunzip lib.a.gz   # -> lib.a  (ar archive, ~170 MB)

# 3. matching source binding via HTTPS
curl -fsSL "https://github.com/denoland/rusty_v8/releases/download/${REV}/src_binding_release_${SUFFIX}.rs" -o src_binding.rs

# 4. build the bridge against the local archive
export RUSTY_V8_ARCHIVE="$PWD/lib.a"
export RUSTY_V8_SRC_BINDING_PATH="$PWD/src_binding.rs"
( cd native/bridge && cargo build --release )   # -> target/.../librusty_v8_bridge.a
```

### Gotcha: rusty_v8's Python downloader is proxy-incompatible

If you let `build.rs` download the static lib itself (no `RUSTY_V8_ARCHIVE`), it
shells out to a Python downloader and the result fails to gunzip
(`Decompression error Err(Buf)`) — the streamed body comes back corrupt through
the proxy, even though the same URL is byte-perfect via `curl`. **Always fetch the
archive with `curl` and hand it to `build.rs` via `RUSTY_V8_ARCHIVE`.** No `gn`,
`depot_tools`, or V8-from-source checkout is needed for the prebuilt path.

## Native validation (run these in a real environment)

The MoonBit **js** target never executes real JS, so the V8 round-trip — page JS
reading crater's real layout through the bridge (`getBoundingClientRect`,
`offset*`, `getComputedStyle`) and the `run_event_loop` driving timers / rAF — is
covered only by **native-target** tests. Once the bridge is built (the HTTPS path
above, or a normal `git`-capable host where the postadd just works), validate with:

```bash
# Layout/computed-style bridge unit coverage (mock DOM reads injected globals)
moon -C browser/native test -p mizchi/crater-browser-native/js_v8 \
  -f js_runtime_v8_bridge_wbtest.mbt --target native -j 1
# or the whole V8 runtime suite:
just test-native-v8

# Full browser <-> V8 e2e (new_v8_browser/connect_v8, real getBoundingClientRect,
# run_event_loop settle, DOM mutation round-trips, AND the incremental-reflow
# sign-off "E2E: incremental reflow matches a full rebuild on the dynamic JS
# path" — flag-on incremental render == flag-off full rebuild after a JS DOM
# mutation):
just test-native-full     # moon -C testing test -p .../e2e/native_v8 --target native
```

`js_runtime_v8_bridge_wbtest.mbt` asserts the four bridge cases (boxes read,
computed styles read, fallback-to-zero when nothing injected, id-less fallback);
`testing/e2e/native_v8/browser_v8_e2e_test.mbt` drives the whole shell.

### The "SIGSEGV in the web sandbox" was a simdutf symbol collision — fixed

Earlier notes claimed native V8 "segfaults at `v8::Isolate` creation … container
vaddr / sandbox issue." **That diagnosis was wrong.** Verified in the sandbox:

- A minimal standalone `rusty_v8` program (no MoonBit) creates an isolate, a
  context, compiles and runs `40 + 2` → `42`. V8 itself runs fine here. Large
  `PROT_NONE` reservations (4 GB / 1 TB / 8 TB) all succeed, and the prebuilt has
  pointer-compression / sandbox **off** — so the address-space "cage" was never
  the problem.
- crater's native `js_v8` suite *did* SIGSEGV, but the gdb backtrace points at
  **simdutf**, not V8: `simdutf::detect_best_supported_implementation` →
  `autodetect_encoding`, reached from MoonBit's runtime `moonbit_utf8_len_from_utf16`
  when `mizchi/v8 Runtime::eval_string` converts the JS source (UTF-16 → UTF-8).

**Root cause:** MoonBit's runtime statically links its **own** simdutf
(`$HOME/.moon/lib/simdutf.o`) and V8 links a **different** simdutf inside
`librusty_v8_bridge.a`. Both export global `simdutf::*` symbols. The consumer
prebuild used `-Wl,-z,muldefs`, which makes the link *succeed* by keeping the
first definition — but then MoonBit and V8 share one simdutf at runtime, and the
version/ABI mismatch corrupts simdutf's first-use CPU dispatch → SIGSEGV on the
first JS-string conversion. (Why it didn't always crash elsewhere: whether it
faults depends on which copy the linker kept and the host CPU dispatch.)

**Fix (landed):** `browser/scripts/mizchi-v8-consumer-prebuild.mjs`
`isolate_v8_simdutf_symbols()` renames V8's simdutf symbols (definitions and
intra-archive references together) with a `__v8priv` suffix via
`objcopy --redefine-syms`, so V8 stays self-consistent and no longer collides
with MoonBit's copy — each side binds to its own simdutf. Idempotent; a no-op
without binutils (then the `-z,muldefs` fallback applies). With this, the full
native `js_v8` suite (55 tests) **passes in the web sandbox**, so native V8 is no
longer "blocked here" — it just needs the HTTPS bridge build above plus this
symbol isolation (now automatic).

## Recurrence prevention

1. **Probe before claiming "blocked."** Egress is per-channel. Before writing or
   repeating "X egress is blocked," test the specific channel the tool uses
   (`git ls-remote` vs `curl` vs the registry). Cite the failing command and code,
   not a remembered conclusion. The original "rusty_v8 egress is blocked" claim was
   inherited across docs without re-testing; HTTPS was open the whole time.
2. **Prefer HTTPS source fetch over `git clone` in build hooks.** A
   `git clone` in a postadd is fragile under scoped-git policies. Fetching the
   pinned rev as an HTTPS tarball (then `git init`) is equivalent for a `--depth 1`
   checkout and survives the scope. Track this against `mizchi/v8`'s
   `build-rusty-v8.sh`.
3. **Always pass `RUSTY_V8_ARCHIVE` (curl-fetched) in CI/sandboxes.** Never rely on
   the crate's built-in downloader behind a proxy.
4. **Decouple the v8 postadd from non-native resolution** (#312 option C). The
   postadd is upstream in `mizchi/v8` and the `MIZCHI_V8_OPTIONAL` /
   `CRATER_SKIP_V8_BUILD` degrade only covers crater's *prebuild* script, not the
   vendored postadd, so it cannot stop the `git clone` from a `moon` run that
   resolves the v8 members. The crater-side lever is therefore to keep
   `./browser/native` / `./testing` out of `moon.work` for non-native work:
   `scripts/ci/drop-v8-members.sh` for both local (`moon-test-no-v8.sh`) and CI
   (the `vrt-bench` job). The durable upstream fix is to make the postadd honor
   the skip env and prefer the HTTPS source fetch over `git clone`.
5. **Keep `deps/rusty_v8.rev` and the binding/lib suffix in lockstep.** The
   prebuilt lib, the `src_binding_release_*.rs`, and the source tarball must all be
   the same tag, matched to the host triple.
