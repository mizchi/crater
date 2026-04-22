# Moon Workspace Split Plan

This repository is now bootstrapped as a MoonBit workspace via `moon.work`.
The immediate goal is to manage existing modules from one root and then split
the current `mizchi/crater` module into smaller publishable modules.

## Workspace Members

The current workspace members are:

- `.`
- `./aomx`
- `./benchmarks`
- `./testing`
- `./webvitals`
- `./css`
- `./dom`
- `./layout`
- `./painter`
- `./renderer`
- `./browser`
- `./browser/jsbidi`
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

The same split now applies to `just` test recipes:

- `just test` / `just test-js` runs the default JS-target MoonBit suite
- `just test-native` runs the `mizchi/crater-browser-native` smoke tests
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

## Target Module Layout

The intended direction is:

| Module | Role |
| --- | --- |
| `mizchi/crater-layout` | Layout kernel, tree, shared layout data types |
| `mizchi/crater-css` | CSS parsing, selector matching, cascade, and computed style engine |
| `mizchi/crater-dom` | DOM, HTML parsing, scheduler, AOM, and HTML/CSS bridge-analysis packages |
| `mizchi/crater-aomx` | AOM-derived content extraction, grounding, and structural diff helpers |
| `mizchi/crater-benchmarks` | Synthetic fixtures and benchmark suites for renderer/browser performance |
| `mizchi/crater-testing` | WPT runtime and MoonBit integration test packages |
| `mizchi/crater-webvitals` | Web Vitals metrics such as CLS and LCP helpers |
| `mizchi/crater-painter` | Paint model, SVG/image backends, terminal image output |
| `mizchi/crater-renderer` | Renderer and VRT/export-oriented integration |
| `mizchi/crater-browser` | Browser runtime, interaction, TUI, network/cache integration |
| `mizchi/crater-jsbidi` | BiDi / JS-facing browser bindings |
| `mizchi/crater-browser-native` | Native browser host bindings |
| `mizchi/crater-js` | JS exports for layout/renderer consumers |
| `mizchi/crater-wasm` | WASM component packaging |

We do not need to create all of these at once. The current workspace has
already extracted `mizchi/crater-layout`, `mizchi/crater-css`,
`mizchi/crater-dom`, `mizchi/crater-aomx`, `mizchi/crater-benchmarks`,
`mizchi/crater-testing`, `mizchi/crater-webvitals`, `mizchi/crater-painter`, and
`mizchi/crater-renderer`. The browser-facing split is now underway in
`mizchi/crater-browser`.

## Remaining Root Packages

The root module now mostly exists as a compatibility layer:

- `mizchi/crater`
- `mizchi/crater/css`

Implementation-heavy packages have been moved into dedicated modules. The root
packages keep thin public wrappers and a small set of smoke tests so existing
imports continue to work while new code can depend on narrower module paths.

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

The root package now provides a thin facade over the shell/CDP/JS entry points,
while shell and BiDi consumers stay on browser-local package paths instead of
reaching back into the root integration module for runtime-facing helpers.

### `mizchi/crater-jsbidi`

The JS/BiDi-facing packages are kept in `browser/jsbidi/`:

- `.`
- `webdriver`
- `bidi_main`
- `webdriver_fixture_builder`

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

## Suggested Next Patch

The next implementation patch should continue trimming browser-adjacent helpers
out of the root integration module:

1. move browser-only test and fixture helpers if they no longer serve root users
2. avoid reintroducing dependencies from browser modules back into root renderer
   packages
3. decide whether `benchmarks` and other remaining root-only helpers should stay
   in root or move into dedicated modules
4. run `moon info`, `moon check`, and targeted browser/BiDi tests from the
   workspace root

That keeps the next split mechanical and avoids mixing protocol/runtime changes
into the same change.
