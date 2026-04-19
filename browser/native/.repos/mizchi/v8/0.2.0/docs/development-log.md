# Development Log

[English](development-log.md) | [日本語](development-log.ja.md)

This document tracks the implementation status, design notes, and known limitations of `mizchi/v8`. For the user-facing entry point, see [README.md](../README.md). For the full public surface, see [src/README.mbt.md](../src/README.mbt.md).

## Goals

- provide a thin native binding so MoonBit can drive V8 directly
- keep as much runtime logic as possible on the MoonBit side
- keep the Rust side focused on isolate/context management and the C ABI bridge
- provide a base for experimenting with Node / Deno-style event loops

## Current Status

### Core Runtime

- [x] `runtime_new`, `runtime_new_with_snapshot`
- [x] `eval_string`, `eval_async_string`, `eval_module_string`
- [x] named script origins and entry module specifiers
- [x] `perform_microtask_checkpoint`
- [x] `V8Error`-based error contract

### Value Bridge

- [x] `eval_json`, `eval_bytes`, `eval_async_json`, `eval_async_bytes`
- [x] `set/get/call_global_json`
- [x] `set/get/call_global_bytes`

### Promise / Module Handle

- [x] `PromiseHandle::state`, `result_*`, `await_*`
- [x] `ModuleHandle::export_names`, `get_export_*`, `call_export_*`
- [x] asynchronous top-level await module evaluation through `ModuleEvalHandle`

### Module Loading

- [x] `Runtime::load_module`, `load_modules`
- [x] static import / dynamic import
- [x] relative specifier resolution
- [x] reusable runtime images with preloaded modules

### Snapshot / Bootstrap

- [x] `snapshot_create`, `snapshot_extend`
- [x] `SnapshotBuilder`
- [x] `RuntimeBuilder`
- [x] `RuntimeImage`

### Host Bridge

- [x] sync JSON op
- [x] sync bytes op
- [x] async JSON op queue
- [x] async bytes op queue
- [x] sync JSON callback
- [x] sync bytes callback
- [x] async host callback
- [x] richer host op surface

## Current Limitations

- native target only
- compatibility is still partial: Deno is limited to an opt-in `Deno.core` op/util shim plus a few top-level `Deno` helpers, and Node to a minimal `global` / `process` / `Buffer` shim
- async host integration can now use queue-based ops, direct callbacks, and result callbacks, and failure reasons can be passed as JSON values as well as plain strings
- the runtime now has an embedder-side resource table, and `Deno.core.resources` / `close` / `tryClose` are backed by that table with per-resource ref state
- the MoonBit async event-loop driver can now drive Deno-style pending ops, but it allows only one active loop per runtime and assumes you do not mix it with manual `take_async_*_op` handling on the same lane
- `Deno.sleep` and the minimal `setTimeout` / `clearTimeout` / `setInterval` / `clearInterval` shim now run as hidden async ops on top of that MoonBit async event loop and also occupy timer resources
- `with_runtime_async` and `eval_promise_*_async` now let MoonBit async code use that same loop without wiring `PromiseHandle` manually
- top-level await modules can now be driven through the same path with `Runtime::eval_module_handle_string_async`
- consumer modules still need one-time setup when importing this package from mooncakes today, although the bundled setup script now automates the common path and can also build the bridge for local path dependencies via `--build-bridge`
- `oden/` now exists as a sibling MoonBit module with its own `moon.mod.json`, so runtime/CLI experiments can be developed separately on top of `mizchi/v8`; its current MoonBit-first router covers `run` / `check` / `test` / `bundle` / `fmt` / `info` / `task` / `plan` plus help/version/manifest

## Design Notes

- keep `Runtime` and handle types on the MoonBit side, and isolate the Rust bridge in a small staticlib
- hide `rusty_v8` initialization and link complexity behind the Rust layer
- stabilize the public API in MoonBit while keeping the Rust implementation replaceable
- focus first on JSON and bytes as the two value lanes needed for runtime-loop experiments
- split compatibility code into shared helpers plus Deno / Node shims, and prioritize expanding the Deno-facing surface first
- the Deno-core-style `run_event_loop` path is modeled on MoonBit async task groups, which poll pending V8 ops and dispatch them into async tasks

## Where To Look Next

- package API index: [src/README.mbt.md](../src/README.mbt.md)
- release history: [CHANGELOG.md](../CHANGELOG.md)
- Rust bridge implementation: [native/bridge/src/lib.rs](../native/bridge/src/lib.rs)
