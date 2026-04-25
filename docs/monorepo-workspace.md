# Moon Workspace Split Plan

This repository is now bootstrapped as a MoonBit workspace via `moon.work`.
The immediate goal is to manage existing modules from one root and then split
the current `mizchi/crater` module into smaller modules with clearer
responsibility boundaries.

## Workspace Members

The current workspace members are:

- `.`
- `./aomx`
- `./benchmarks`
- `./contract`
- `./testing`
- `./webvitals`
- `./http`
- `./http_sqlite`
- `./css`
- `./dom`
- `./layout`
- `./painter`
- `./renderer`
- `./browser`
- `./webdriver`
- `./browser/native`
- `./js`
- `./wasm`

This keeps the current repository layout working while allowing new modules to
be introduced incrementally with `moon work use` and normalized with
`moon work sync`.

The two target-specific modules are now workspace members as well, but root
commands need explicit targets:

- use `moon info --target js` from the workspace root for the default JS graph
- run `browser/native` with `--target native`
- run `wasm` with `--target wasm`

Both directories also keep a local `moon.work` with `members = ["."]` so
module-scoped commands such as `moon -C browser/native check --target native`
and `moon -C wasm check --target wasm` stay isolated from the mixed-target root
workspace graph.

At this point, target-sensitive root commands are expected to stay explicit:
`moon check`, `moon test`, `moon info`, and `moon build` should always go
through a target-aware recipe or per-module command. The remaining target-free
root commands are intentionally target-agnostic ones such as `moon update` and
`moon fmt`.

The same split now applies to `just` test recipes:

- `just test` / `just test-js` runs the default JS-target MoonBit suite
- `just test-native` runs the `mizchi/crater-browser-native` smoke tests
- `just test-native-smoke` is an explicit alias for the same native facade smoke suite
- `just test-native-v8` runs the `mizchi/crater-browser-native/js_v8` runtime parity suite
- `just test-native-full` runs `mizchi/crater-testing/native_e2e`
- `just test-wasm-mbt` runs the MoonBit-side `mizchi/crater-wasm` tests
- `just test-wasm` keeps its old meaning and runs the Node/JCO component test
- `just status`, `just test-baseline`, and `just test-baseline-update` now all
  use the JS-target MoonBit suite as their baseline
- `just test-pkg <pkg>` auto-selects `js`, `native`, or `wasm` from the package
  prefix
- `just test-pkg-js <pkg>`, `just test-pkg-native <pkg>`, and
  `just test-pkg-wasm <pkg>` force a specific target/module

Both modules also expose module root packages:

- `mizchi/crater-browser-native` for V8/mock-DOM helpers
- `mizchi/crater-wasm` for the typed WASM component facade over the
  core/renderer/incremental/accessibility/yoga interfaces

## Module Taxonomy

The workspace should not be read as "every member is an equally reusable
publishable library". The current split works better when viewed in four
layers:

| Layer | Meaning |
| --- | --- |
| Canonical library | Narrow reusable subsystem with a domain-focused API |
| Integration | Product-level composition over multiple canonical libraries |
| Adapter | Target/runtime/protocol packaging over the integration/core graph |
| Internal / dev-only | Test, benchmark, compatibility, or migration support |

This is the main correction to the original split plan. Some workspace members
exist because they are convenient to build and test in-repo, not because they
should be the default external reuse boundary.

## Target Module Layout

The intended direction is:

| Module | Layer | Role |
| --- | --- |
| `mizchi/crater-layout` | Canonical library | Layout kernel, tree, shared layout data types |
| `mizchi/crater-css` | Canonical library | CSS parsing, selector matching, cascade, and computed style engine |
| `mizchi/crater-dom` | Canonical library | DOM, HTML parsing, scheduler, AOM, and HTML/CSS bridge-analysis packages |
| `mizchi/crater-aomx` | Canonical library | AOM-derived content extraction, grounding, and structural diff helpers |
| `mizchi/crater-webvitals` | Canonical library | Web Vitals metrics such as CLS and LCP helpers |
| `mizchi/crater-painter` | Canonical library | Paint model, SVG/image backends, terminal image output |
| `mizchi/crater-renderer` | Canonical library | Renderer and VRT/export-oriented integration |
| `mizchi/crater-browser-contract` | Canonical library | Shared browser-facing render/AOM helper functions for shell and BiDi |
| `mizchi/crater-browser-runtime` | Canonical library | Shared JS runtime contract and DOM serializer |
| `mizchi/crater-browser-http-sqlite` | Adapter | Optional JS-only SQLite cache backend for `mizchi/crater-browser-http` |
| `mizchi/crater-browser` | Integration | Browser shell, interaction, TUI, network/cache integration |
| `mizchi/crater-webdriver-bidi` | Adapter | WebDriver BiDi server / protocol adapter |
| `mizchi/crater-browser-native` | Adapter | Native browser host bindings |
| `mizchi/crater-js` | Adapter | JS exports for layout/renderer consumers |
| `mizchi/crater-wasm` | Adapter | WASM component packaging |
| `mizchi/crater-benchmarks` | Internal / dev-only | Synthetic fixtures and benchmark suites for renderer/browser performance |
| `mizchi/crater-testing` | Internal / dev-only | WPT runtime, browser-shell fixtures, and native/browser integration test packages |
| `mizchi/crater` | Internal / compatibility | Historical all-in-one facade for compatibility |

We do not need to create all of these at once. The current workspace has
already extracted `mizchi/crater-layout`, `mizchi/crater-css`,
`mizchi/crater-dom`, `mizchi/crater-aomx`, `mizchi/crater-benchmarks`,
`mizchi/crater-browser-contract`, `mizchi/crater-testing`,
`mizchi/crater-webvitals`, `mizchi/crater-painter`, `mizchi/crater-renderer`,
`mizchi/crater-browser-runtime`, and `mizchi/crater-browser-http-sqlite`. The
browser-facing split is now underway in `mizchi/crater-browser`.

The old `mizchi/crater-browser/js` package remains only as a `0.17.x`
compatibility facade over the extracted runtime contract.

## Remaining Root Packages

The root module now mostly exists as a compatibility layer:

- `mizchi/crater`
- `mizchi/crater/css`

Implementation-heavy packages have been moved into dedicated modules. The root
packages keep thin public wrappers and a small set of smoke tests so existing
imports continue to work while new code can depend on narrower module paths.

## Release Policy

The workspace now follows a lockstep MoonBit versioning policy.

- repo-managed Moon modules in this repository share the same release line
- the current workspace-split line is `0.17.x`
- path dependencies inside the workspace are kept on the same version so
  publish metadata matches the repo release
- npm package versions remain independent and may move on a different cadence

This means the canonical libraries, integration module, and adapters ship
together from the same repo tag, instead of being versioned independently.
Lockstep versioning does not imply that every workspace member is equally
recommended as a public reuse surface.

For release and support purposes, treat `mizchi/crater-benchmarks` and
`mizchi/crater-testing` as internal workspace modules. They stay on the same
version line so the workspace graph remains coherent, but they are not the
default public support surface and should not be documented as production
dependencies.

### Publish Order

MoonBit release order is derived from `moon.work` and the workspace-local
`moon.mod.json` dependency graph.

- `just release-moon-list`: print the public publish order
- `just release-moon-check`: run target-aware `moon check` in publish order
- `just release-moon-dry-run`: on macOS, run safe `moon package` dry-run packaging;
  elsewhere, run `moon publish --dry-run` in publish order
- `just release-moon`: run the real `moon publish` sequence
- `.github/workflows/release-moon.yml`: manual Linux release workflow for
  `check` / `dry-run` / `publish`

The default release set includes public workspace modules plus the root
compatibility module when it is part of the dependency closure. Internal modules
such as `mizchi/crater-benchmarks` and `mizchi/crater-testing` are intentionally
excluded from the default publish plan.

When you need the adapter-only subset, use
`node scripts/moon-publish-workspace.mjs --list --only-crater-star`. The script
warns if the selected subset still depends on excluded workspace modules such as
`mizchi/crater`.

`moon publish --dry-run` currently panics on this macOS environment in Moon
CLI's reqwest/system-configuration path. The release script absorbs that by
using `moon package` as the default dry-run implementation on macOS. Use
`node scripts/moon-publish-workspace.mjs --dry-run --force-publish-dry-run` only
when you explicitly want to reproduce the upstream `moon publish --dry-run`
behavior.

For Linux `dry-run` and real `publish` from GitHub Actions, set
`MOON_CREDENTIALS_JSON` as a repository or environment secret containing the
full `~/.moon/credentials.json` payload, then run the manual `Release Moon`
workflow.

## Import Guidance

For new code, prefer the narrowest module that matches the subsystem you need:

| Need | Recommended import |
| --- | --- |
| Layout kernel and tree primitives | `mizchi/crater-layout` |
| CSS parser / selector / cascade | `mizchi/crater-css` |
| DOM / HTML / AOM / scheduler | `mizchi/crater-dom` |
| Paint tree / SVG / image output | `mizchi/crater-painter` |
| Renderer / VRT facade | `mizchi/crater-renderer` |
| Browser shell / interaction / CDP | `mizchi/crater-browser` |
| Browser runtime contract / DOM serializer | `mizchi/crater-browser-runtime` |
| BiDi / WebDriver helper surface | `mizchi/crater-webdriver-bidi` |
| Native V8 host bindings | `mizchi/crater-browser-native` |
| JS exports | `mizchi/crater-js` |
| WASM component facade | `mizchi/crater-wasm` |

Keep using `mizchi/crater` or `mizchi/crater/css` only when you need backwards
compatibility with older imports or explicitly want the historical all-in-one
surface.

Prefer the layers in this order:

1. canonical library module
2. integration module
3. adapter module
4. compatibility facade only when migration pressure requires it

In particular, do not treat `mizchi/crater-benchmarks` or
`mizchi/crater-testing` as default public dependencies for production code.

`mizchi/crater-browser-runtime` is now the canonical shared module for the JS
runtime contract and DOM serializer. Keep `mizchi/crater-browser/js` only for
`0.17.x` compatibility with older import paths; new code should not depend on
it.

## Compatibility Policy

The root compatibility facades are intentionally still present:

- `mizchi/crater`
- `mizchi/crater/css`

They remain supported through the `0.17.x` line so existing consumers do not
need an immediate rewrite. New code should move to direct module imports. The
root facade is now a compatibility layer, not the default recommendation for
new integrations.

## Split Quality Notes

The current split is good enough for workspace management, but not every
boundary is equally strong from a reuse perspective.

- `layout`, `css`, `dom`, `painter`, `renderer`, `aomx`, and `webvitals` are
  the strongest reusable boundaries today
- `browser` is still broad and should be treated as a product-level integration
  module rather than a narrow library
- `jsbidi`, `browser-native`, `js`, and `wasm` are target/protocol adapters,
  not primary domain modules
- `benchmarks` and `testing` are internal support modules even though they are
  workspace members

One concrete cleanup from this review is already done: production/integration
code no longer depends on internal benchmark fixtures. In particular,
`mizchi/crater-browser` no longer depends on `mizchi/crater-benchmarks`;
browser-specific benchmark suites and benchmark baseline tooling now live under
the `benchmarks` module.

## Extracted Modules

### `mizchi/crater-layout`

The layout kernel has been moved into `layout/`:

- `types`
- `style`
- `core`
- `core_subset`
- `.`
- `absolute`
- `alignment`
- `baseline`
- `block`
- `dispatch`
- `flex`
- `float`
- `grid`
- `inline`
- `node`
- `table`
- `testing`
- `trace`
- `tree`

### `mizchi/crater-css`

The CSS kernel has been moved into `css/`:

- `token`
- `parser`
- `selector`
- `cascade`
- `media`
- `computed`
- `diagnostics`

### `mizchi/crater-dom`

The DOM-facing packages have been moved into `dom/`:

- `.`
- `html`
- `dom`
- `aom`
- `scheduler`
- `css/responsive`
- `layout/dom_bridge`
- `layout/html_bridge`
- `layout/html_tree`
- `layout/style_bridge`

This keeps the `html` / `dom` / `aom` / `scheduler` cluster together with the
layout bridge code it depends on, without introducing a root-module cycle.

This still matches the broad dependency graph:

- layout kernel packages depend mainly on `types`, `style`, and `core`
- DOM bridge-analysis packages pull in `css`, `html`, or `dom`

### `mizchi/crater-painter`

The paint/output packages have been moved into `painter/`:

- `.`
- `paint`
- `paint/*`
- `layout_svg`
- `svg`
- `x/image`
- `x/kitty`

This keeps the paint model, SVG rasterization, and terminal image backends in
one module so the renderer no longer owns image/output helpers directly.

### `mizchi/crater-aomx`

The AOM-derived helper packages have been moved into `aomx/`:

- `.`
- `arc90`
- `diff`
- `grounding`

This keeps content extraction, spatial lookup, and accessibility-tree diffing
next to the DOM/AOM layer they depend on, without keeping browser-oriented
helpers in the root integration module.

### `mizchi/crater-webvitals`

The Web Vitals helpers have been moved into `webvitals/`:

- `.`

This keeps CLS/LCP metric helpers out of the root compatibility layer while
keeping their dependency graph limited to layout data types.

### `mizchi/crater-benchmarks`

The benchmark fixtures and benchmark suites have been moved into
`benchmarks/`:

- `.`
- `fixtures/`

This keeps synthetic HTML fixtures and benchmark-only packages out of the root
integration module while still allowing browser wbtests and scripts to consume
them through a dedicated module.

### `mizchi/crater-testing`

The WPT runtime and MoonBit test packages have been moved into `testing/`:

- `.`
- `browser_shell`
- `wpt_runtime`
- `layout_css_e2e`
- `taffy_compat`
- `tui`

This keeps integration-test-only packages and the lightweight WPT JS runtime
out of the root compatibility layer.

### `mizchi/crater-renderer`

The renderer/export packages have been moved into `renderer/`:

- `.`
- `renderer`
- `vrt`

This keeps render tree construction and VRT helpers in one module while
depending on `mizchi/crater-painter` for paint/image backends. The root module
now consumes these packages as an integration layer.

### `mizchi/crater-browser`

The browser-facing packages have been moved into `browser/`:

- `.`
- `browser_contract`
- `runtime`

The root package now provides a thin facade over the shell/CDP/JS entry points,
while shell/native consumers share `browser/runtime` for the JS runtime
contract and DOM serializer instead of reaching back into the root integration
module for runtime-facing helpers.

### `mizchi/crater-webdriver-bidi`

The WebDriver BiDi adapter packages are kept in `webdriver/`:

- `.`
- `webdriver`
- `bidi_main`

The fixture-only builder now lives in the internal `testing/` module:

- `testing/webdriver_fixture_builder`

The root package provides a small facade over the WebDriver helper surface
without forcing consumers to import the larger `webdriver` package path
directly.

### `mizchi/crater-wasm`

The WASM component module now exposes a root facade in `wasm/`:

- `.`
- `ffi`
- `gen`
- `gen/interface/mizchi/crater/*`
- `world/crater`

The root package provides a typed facade over the generated core/renderer/
incremental/accessibility/yoga interfaces.

## Migration Order

1. Keep `mizchi/crater` as the integration module while workspace support is
   active.
2. Extract `layout/` as `mizchi/crater-layout`.
3. Extract `css/` as `mizchi/crater-css`.
4. Extract `dom/` as `mizchi/crater-dom`.
5. Rewrite internal imports in dependent modules from `mizchi/crater/...` to
   the extracted module paths for moved packages.
6. After the import graph stabilizes further, extract browser-facing runtime
   packages.

## Constraints During the Split

- Do not move bridge packages and kernel packages in the same pass.
- Keep `browser` packages using browser-local paint facades instead of crater
  `paint/*` internals.
- Treat the current root module as a compatibility/integration layer until the
  new modules settle.
- Run `moon work sync` after adding a new member module so member manifests keep
  dependency versions aligned.

## Current Follow-ups

The workspace split itself is done. The next work should focus on operation and
maintenance:

1. keep CI and local recipes target-aware so root commands never rely on an
   implicit target
2. keep `browser/native` smoke and full-test coverage separate, especially
   around sqlite-backed packages
3. document release and migration steps from the repo root so consumers can move
   from compatibility imports to direct module imports
4. avoid reintroducing new runtime packages into the root integration layer

That keeps the next split mechanical and avoids mixing protocol/runtime changes
into the same change.
