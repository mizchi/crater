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
packages resolve and test.

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
4. **Decouple the v8 postadd from non-native resolution** (#312 option C): make the
   prebuild a no-op unless the target is native, or keep `./browser/native` /
   `./testing` out of the default `moon.work` for `--target js` runs. Until then,
   route v8-free testing through `scripts/moon-test-no-v8.sh`.
5. **Keep `deps/rusty_v8.rev` and the binding/lib suffix in lockstep.** The
   prebuilt lib, the `src_binding_release_*.rs`, and the source tarball must all be
   the same tag, matched to the host triple.
