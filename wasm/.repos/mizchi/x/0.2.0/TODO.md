# TODO: process package — Advanced API migration

## Goal

Port advanced APIs from upstream `moonbitlang/async/process` to `mizchi/x/process` with native/JS dual-target support. Reduce upstream-exclude.conf SKIP count from 18 to 3.

## APIs to port

| Category | API |
|----------|-----|
| Process handle | `spawn()` -> `Process`, `Process::wait()`, `Process::try_wait()`, `Process::cancel()` |
| Cancellation | `CancellationHandler`, `graceful_cancel()`, `hard_cancel()` |
| Pipe I/O | `read_from_process()`, `write_to_process()`, `ReadFromProcess`, `WriteToProcess` |
| File redirect | `redirect_from_file()`, `redirect_to_file()`, `InputHandle`, `OutputHandle` |
| Orphan process | `spawn_orphan()`, `wait_pid()` |
| Existing API ext | `run()`, `collect_*()` with stdin/stdout/stderr/cancel_handler params |

## Implementation phases

### Phase 1: CancellationHandler + graceful_cancel / hard_cancel
- [ ] `process_native.mbt`: wrap upstream `@async_process.CancellationHandler`
- [ ] `process_js.mbt`: `js_kill(pid, signal)` FFI + timeout logic
- [ ] `process_wasm.mbt` / `process_wasmgc.mbt`: stubs

### Phase 2: ReadFromProcess / WriteToProcess / InputHandle / OutputHandle
- [ ] Native: wrap upstream types + delegate `@io.Reader`/`@io.Writer` traits
- [ ] JS: `@io.pipe()` based + enum handles
- [ ] `read_from_process()`, `write_to_process()` implementation
- [ ] `redirect_from_file()`, `redirect_to_file()` implementation

### Phase 3: Process / spawn / spawn_orphan / wait_pid
- [ ] Native: delegate to `@async_process.spawn` (unwrap InputHandle/OutputHandle)
- [ ] JS: `js_spawn_process` FFI + `group.spawn_bg()` pipe transfer + exit wait
- [ ] `Process::wait()`, `Process::try_wait()`, `Process::cancel()`
- [ ] `spawn_orphan()` -> JS: `detached: true` + `unref()`
- [ ] `wait_pid()` -> JS: `globalThis.__xProc.children` exitPromise

### Phase 4: Existing API extension
- [ ] Add stdin/stdout/stderr/cancel_handler params to `run()`
- [ ] Add stdin param to `collect_*()` functions
- [ ] Unify internal implementation on new spawn base
- [ ] Backward compatible: all new params are optional

### Phase 5: Tests + upstream-exclude.conf update
- [ ] `Process::wait` test
- [ ] `Process::try_wait` test
- [ ] `Process:cancel` test
- [ ] `cancel process` test
- [ ] `cancel process hard` test
- [ ] `cancel process timeout` test
- [ ] `basic_cat` test (stdin pipe)
- [ ] `merge stdout and stderr` test
- [ ] `merge multiple` test
- [ ] `orphan process` / `wait_pid` test
- [ ] `redirect to file` test
- [ ] `collect_output blocked` test (with stdin)
- [ ] Update upstream-exclude.conf

### SKIP (not implementable)
- `kill children on hard cancel` — requires custom test program + Windows-specific
- `do not kill orphan children on hard cancel` — same
- `windows command line arg escape` — Windows-specific

## Validation

```bash
moon check --target native
moon check --target js
moon check --target wasm-gc
moon test --target native -p mizchi/x/process
moon test --target js -p mizchi/x/process
bash scripts/sync-upstream-tests.sh process
```
