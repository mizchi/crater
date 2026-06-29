# V8 startup snapshot: pre-injecting the DOM / global API into the isolate

Status: implemented in `browser/native/js_v8/js_runtime_v8.mbt` (native target)
and **validated in the web sandbox** — the prior "V8 SIGSEGVs at isolate init"
claim was a simdutf symbol collision, now fixed (see `docs/v8-build-egress.md`).
With the HTTPS bridge build + simdutf isolation, the full native `js_v8` suite —
including the parity test below — passes here (`moon -C browser/native test -p
mizchi/crater-browser-native/js_v8 --target native`).

## What changed

Like a real browser (Chrome/Node/Deno), the **page-independent JS API surface**
is now baked into a V8 startup snapshot and the isolate is created *from* that
snapshot, instead of re-evaluating the (large) setup JS on every runtime.

- **Before:** `V8JsRuntime::init()` created an empty runtime; the first
  `execute()` then `eval`'d `mock_dom_source` (the full mock-DOM classes /
  `document` / `window` / helpers), the logs bridge, and the ElementInternals
  polyfill — every runtime paid that cost.
- **After:** the static surface is captured once into a process-cached snapshot
  (`mizchi/v8` `snapshot_builder_new().eval(...).build()`), and each runtime is
  created via `runtime_new_with_snapshot(bytes)`. The API globals are already
  present in the realm; `execute()` only runs **per-page** data
  (`create_dom_init_code(dom)`) and the user script.

The split is exactly page-independent vs page-specific:

| In the snapshot (once)                         | Per page (`execute`)              |
| ---------------------------------------------- | --------------------------------- |
| mock-DOM classes, `document`/`window` globals  | `create_dom_init_code(dom)` data  |
| console, `logs`/`domOps` arrays, `__getLogs`   | `logs.length = 0; domOps.length=0`|
| ElementInternals polyfill, `_SyncPromise`, etc.| the user script + flush/timers    |

## Safety / fallback

- The snapshot is built lazily and **cached per source string**
  (`mock_dom_snapshot_cache`); a changed `mock_dom_source` rebuilds.
- If snapshot **build or restore fails**, `init()` falls back to
  `init_plain_runtime()` — a plain runtime that `eval`s the setup on first
  `execute()` (the prior behavior). So a platform where snapshotting misbehaves
  degrades to correct-but-slower, never broken.
- `set_v8_snapshot_enabled(false)` forces the eval path (to isolate a
  snapshot-specific issue).

## Validation

`js_runtime_v8_dom_wbtest.mbt` → **"V8+Snapshot: snapshot-initialized runtime
matches eval-initialized"** runs the same DOM-manipulating script both ways
(toggled via `set_v8_snapshot_enabled`) and asserts identical results — the
parity sign-off. All existing `js_v8` native tests also now exercise the
snapshot path by default, so `just test-native-v8` is the broad check.

## Notes / follow-ups

- A snapshot must contain only snapshot-serializable state. The mock DOM is pure
  JS, so it captures cleanly; avoid baking host-bound callbacks or wall-clock
  values into the snapshot setup (they'd be frozen at build time). If a future
  addition isn't snapshot-safe, keep it in the per-`execute` path.
- `SnapshotBuilder` also offers `build_image` / `build_runtime`; we use
  `build()` → `Bytes` so one snapshot blob can seed many isolates.
- The blob could be persisted to disk and shipped to skip even the one-time
  build; for now it is rebuilt once per process.
