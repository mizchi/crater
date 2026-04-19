# Changelog

All notable changes to this project should be documented in this file.

## [Unreleased]

### Added

- Property-based test example with `moonbitlang/quickcheck`
- Package-level `src/README.mbt.md` with executable examples
- `just ci`, `just ci-all`, `just fmt-check`, and `just info-check`
- Direct async host callbacks via `register_async_json_callback` and `register_async_bytes_callback`
- Result-based host callbacks that can throw/reject via `register_*_result_callback`
- JSON-valued throw/reject reasons via `register_*_result_callback_with_json_error` and `reject_async_*_op_with_json`
- Multiple runtimes can now coexist in the same process
- Bundled `src/scripts/setup-consumer.mjs` to automate the common mooncakes consumer setup path
- `setup-consumer.mjs --build-bridge` to cover local path dependency bootstrapping from the same helper
- Opt-in `Deno.core` op shim helpers via `install_deno_core_compat` and `with_deno_core_compat`
- Opt-in Node-style shim helpers via `install_node_compat` and `with_node_compat`
- Shared compat helpers split out from Deno / Node shims, with Deno utility helpers expanded around `Deno.core` and minimal top-level `Deno` metadata
- Runtime-side resource table helpers via `add_resource`, `ref_resource`, `unref_resource`, `list_resources`, and `close_resource`
- `Deno.core.resources` / `close` / `tryClose` backed by the runtime resource table
- `Deno.sleep` plus minimal `setTimeout` / `clearTimeout` / `setInterval` / `clearInterval` on top of the MoonBit async event loop
- `Deno.core.refOpPromise` / `unrefOpPromise` now toggle real resource ref state, and sleep/op promises are tracked as resources
- `with_deno_core_compat` now installs the runtime hooks needed by those helpers when building runtimes from builders/images
- sibling `oden/` MoonBit module with its own `moon.mod.json`, local-path dependency on `mizchi/v8`, and a separate CLI/runtime experimentation surface
- MoonBit-first `oden` router commands for `run` / `check` / `test` / `bundle` / `fmt` / `info` / `task` / `plan`, plus `version` and help/version aliases
- MoonBit async event-loop bridge for Deno-style pending ops via `register_async_*_task_*`, `PromiseHandle::await_*_async`, and `ModuleEvalHandle::await_ready_async`
- Async convenience helpers via `with_runtime_async`, `with_runtime_with_snapshot_async`, and `eval_promise_*_async`
- Async module-handle convenience helpers via `Runtime::eval_module_handle_string_async` and `Runtime::eval_module_handle_string_async_with_specifier`

### Changed

- GitHub Actions CI now verifies formatting and generated `.mbti` files
- CI now runs `native` checks on both Ubuntu and macOS
- Root README is now user-facing and split into English and Japanese entry points
- `moon.mod.json` now points `readme` to `README.md`
- Published package now includes a consumer-side prebuild helper for mooncakes installs
- README now documents the current Moon `0.1.20260309` / MoonBit `v0.8.3` requirement for consumer-side prebuild and link setup

### Fixed

- Removed the broken `hello()` example from the published README path
- Aligned local `just` workflows with the CI entrypoints
- Packaged docs now explain the native build prerequisites and current mooncakes consumer limitation

## [0.1.2] - 2026-02-12

### Changed

- Baseline template state before release-workflow hardening.
