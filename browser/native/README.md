# `mizchi/crater-browser-native`

Native host bindings for Crater's V8-backed browser runtime.

## Test Boundary

There are now two explicit native test layers:

- `just test-native` / `just test-native-smoke`
  - package: `mizchi/crater-browser-native`
  - purpose: smoke contract for the published native facade
  - includes: root facade, V8/mock DOM surface, and lightweight runtime assets
  - does not depend on browser shell navigation/e2e helpers

- `just test-native-v8`
  - package: `mizchi/crater-browser-native/js_v8`
  - purpose: V8 runtime and mock DOM parity tests
  - includes: JS runtime compatibility and DOM snapshot tests
  - does not require sqlite-backed browser e2e wiring

- `just test-native-full`
  - package: `mizchi/crater-testing/native_e2e`
  - purpose: full native browser e2e coverage
  - includes: browser shell integration, Preact/React bundle helpers, and shell-driven navigation
  - lives in the internal `testing` module, not the published native adapter
  - transitively reaches `mizchi/crater-browser/shell` and `mizchi/crater-browser-http`
  - no longer requires sqlite headers by default
  - optional sqlite-backed cache persistence now lives in `mizchi/crater-browser-http-sqlite`

## CI Policy

- required CI coverage should stay on smoke/V8 layers
- full native e2e should be treated as an opt-in or separately scoped check

## Goal

Long-term, `browser/native` should stay a thin V8 host module and pull as little
browser-shell/storage infrastructure as possible. The heavy native browser e2e
coverage now starts in `mizchi/crater-testing/native_e2e`.

The current split is:

- `mizchi/crater-browser-native`
  - root facade over `js_v8` and `assets`
- `mizchi/crater-browser-native/assets`
  - bundled Preact/React sources and lightweight helper functions
- `mizchi/crater-browser-runtime`
  - shared JS runtime contract / DOM serializer used by shell and native V8
- `mizchi/crater-browser-http-sqlite`
  - optional JS-only sqlite cache backend for `mizchi/crater-browser-http`
- `mizchi/crater-browser-native/js_v8`
  - native V8 host runtime over the shared `mizchi/crater-browser-runtime` contract
- `mizchi/crater-testing/native_e2e`
  - browser shell integration tests and full native browser e2e coverage
