# mizchi/v8

[English](README.md) | [日本語](README.ja.md)

`mizchi/v8` is a native-only V8 binding for MoonBit. It is intended as a foundation for prototyping embedded runtimes in the style of Node or Deno.

> Experimental release note: on Moon `0.1.20260309` / MoonBit `v0.8.3`, this package still requires consumer-side prebuild and link setup.

## What You Can Do

- evaluate scripts and modules from MoonBit
- exchange JS values as `String`, JSON, or `Bytes`
- keep pending promises and top-level await modules as host-side handles
- work with preloaded modules, relative imports, and dynamic imports
- build snapshots and runtime images for reusable isolate startup
- experiment with host-side event loops through `MoonBit.opSync(...)` and `MoonBit.opAsync(...)`
- drive Deno-style `opAsync` and top-level await through MoonBit's async event loop
- preload an opt-in Deno shim with `Deno.core.op*`, utility helpers, and minimal `Deno.inspect` / `cwd` / `execPath`
- preload an opt-in Node-style shim with `global`, `process.nextTick`, and a minimal `Buffer`
- keep `oden/` as a sibling module when you want to prototype a separate runtime/CLI on top of `mizchi/v8`

## Status

- version: `0.2.0`
- target: `native`
- usable as an embedder-facing experimental binding
- implementation status and known gaps are tracked in [docs/development-log.md](docs/development-log.md)

## Install From mooncakes

```bash
moon add mizchi/v8
node .mooncakes/mizchi/v8/src/scripts/setup-consumer.mjs --main-pkg cmd/main/moon.pkg
moon check --target native
```

With Moon `0.1.20260309` / MoonBit `v0.8.3`, dependency-side native hooks are not applied to consumers automatically. The bundled setup helper patches the consumer module for the common case:

- copies `scripts/mizchi-v8-consumer-prebuild.mjs`
- adds `--moonbit-unstable-prebuild` to `moon.mod.json`
- adds `${build.MIZCHI_V8_CC_LINK_FLAGS}` and `"supported-targets": "native"` to the specified main package

If your main package lives somewhere else, pass it explicitly:

```bash
node .mooncakes/mizchi/v8/src/scripts/setup-consumer.mjs --main-pkg app/server/moon.pkg
```

If you use a local path dependency and the install hook does not run, the same helper can also build the native bridge in that checkout:

```bash
node ../v8.mbt/src/scripts/setup-consumer.mjs --module-root . --main-pkg cmd/main/moon.pkg --build-bridge
```

### Prerequisites

- `git`
- `bash`
- Rust toolchain with `cargo`
- a native C/C++ toolchain
- `node` for the bundled consumer setup / prebuild scripts
- network access to GitHub, crates.io, and the `rusty_v8` release mirror

The published package also uses a `postadd` hook to eagerly build the native bridge in the installed module cache. The one-time consumer module setup is still required today, but the setup script above automates the common mooncakes workflow.

### Develop From Source

```bash
git clone https://github.com/mizchi/v8.mbt
cd v8.mbt
just bootstrap
just test
```

`just bootstrap` builds `deps/rusty_v8` and the Rust bridge in the current checkout. End users installing from mooncakes do not need to run it manually.

## Minimal Example

For one-shot evaluation, the top-level helpers are enough.

```moonbit
match @v8.eval_string("'Hello' + ', MoonBit!'") {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

For a longer-lived runtime, `RuntimeBuilder` can combine snapshot initialization and module preload.

```moonbit
let builder = @v8.runtime_builder_new()
  .eval_snapshot("globalThis.base = 40;")
  .load_module("dep", "export const answer = globalThis.base + 2;")

match builder.with_runtime(fn(runtime) {
  runtime.eval_async_json(
    "(async () => { let mod = await import('dep'); return { answer: mod.answer } })()",
  )
}) {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

For host-driven event loop experiments, async ops can be handled as a queue.

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.register_async_json_op("add"))
    let promise = runtime.eval_promise_string("MoonBit.opAsync('add', [20, 22])")
    match runtime.take_async_json_op() {
      Ok(Some(op)) => ignore(runtime.resolve_async_json_op(op.id, "{\"answer\":42}"))
      _ => ()
    }
    println(
      promise
      |> Result::map(fn(handle) { handle.await_json() })
      |> Result::flatten,
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

## Main APIs

- evaluation: `Runtime`, `eval_*`, `eval_module_*`, `perform_microtask_checkpoint`
- async handles: `PromiseHandle`, `ModuleEvalHandle`, `ModuleHandle`
- bootstrap: `Runtime::load_module`, `RuntimeBuilder`, `SnapshotBuilder`, `RuntimeImage`
- value bridge: `set/get/call_global_json`, `set/get/call_global_bytes`, `eval_json`, `eval_bytes`
- host bridge: `register_*_callback`, `register_*_result_callback`, `register_*_result_callback_with_json_error`, `register_*_op`, `take_*_op`, `resolve_*_op`, `reject_*_op`, `reject_async_*_op_with_json`
- resource table: `add_resource`, `add_resource_with_close`, `ref_resource`, `unref_resource`, `list_resources`, `close_resource`, `try_close_resource`
- direct async callback: `register_async_json_callback`, `register_async_bytes_callback`, `register_async_*_result_callback`
- async event loop bridge: `with_runtime_async`, `register_async_*_task_*`, `eval_promise_*_async`, `PromiseHandle::await_*_async`, `ModuleEvalHandle::await_ready_async`, `Runtime::eval_module_handle_string_async`
- deno compat: `Runtime::install_deno_core_compat`, `RuntimeBuilder::with_deno_core_compat`, `SnapshotBuilder::with_deno_core_compat`, `Deno.sleep`, minimal `setTimeout` / `clearTimeout` / `setInterval` / `clearInterval`, `Deno.core.refOpPromise` / `unrefOpPromise`
- minimal node shim: `Runtime::install_node_compat`, `RuntimeBuilder::with_node_compat`, `SnapshotBuilder::with_node_compat`
- Failure reasons can be returned as JSON values in addition to plain strings.

For the complete public surface and more examples, see [src/README.mbt.md](src/README.mbt.md).

## Limitations

- native target only
- this project primarily targets low-level embedder bindings; Deno compatibility is currently limited to an opt-in `Deno.core` op/util shim plus a few top-level `Deno` helpers, and Node compatibility to a minimal `global` / `process` / `Buffer` shim
- the MoonBit async event-loop driver allows only one active loop per runtime and assumes you do not mix it with manual `take_async_*_op` handling on the same lane
- `Deno.sleep` and the minimal `setTimeout` / `clearTimeout` / `setInterval` / `clearInterval` shim are built on queue-based async ops and also occupy runtime resource entries; `Deno.core.refOpPromise` / `unrefOpPromise` update that ref state
- `oden/` is now split out as a sibling MoonBit module with its own `moon.mod.json`, so you can keep runtime/CLI experiments separate while still depending on this package by local path; that module currently carries the MoonBit-first `oden` router for `run` / `check` / `test` / `bundle` / `fmt` / `info` / `task` / `plan`
- mooncakes consumers still need a one-time setup step today
- local path dependencies do not run install hooks automatically, but `setup-consumer.mjs --build-bridge` can cover the same bootstrap step

## Documentation

- package API and executable examples: [src/README.mbt.md](src/README.mbt.md)
- implementation status and constraints: [docs/development-log.md](docs/development-log.md)
- Japanese README: [README.ja.md](README.ja.md)
- release history: [CHANGELOG.md](CHANGELOG.md)

## License

Apache-2.0
