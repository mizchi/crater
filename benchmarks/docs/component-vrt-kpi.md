# Component VRT KPI

## Goal

This KPI targets a component-oriented rendering path, not a full E2E browser flow.

Input:

- a bounded DOM fragment
- component CSS
- shared baseline CSS
- a target selector or component root

Output:

- layout information for the target component, or
- an image artifact suitable for VRT, or
- a landmark-only accessibility tree artifact for structural VRT

The priority is speed and regression detection for repeated component snapshots.

## Non-Goals

- full-page navigation latency
- general website compatibility
- network fetch timing
- end-to-end automation overhead

## Measurement Model

Use fixed fixtures and split the pipeline into phases.

### Layout Artifact Path

```text
HTML + CSS
  -> parse / style / node build
  -> layout
  -> target component extraction
  -> layout artifact serialization
```

### Image Artifact Path

```text
HTML + CSS
  -> parse / style / node build
  -> layout
  -> paint tree
  -> raster / encode
  -> image artifact
```

### Landmark Artifact Path

```text
HTML
  -> target component root resolution
  -> AOM build
  -> landmark extraction
  -> landmark tree serialization
```

## Primary Metrics

### 1. End-to-End Component Layout Time

`T_layout_artifact`

Time from fixture load to "layout artifact for the selected component is ready".

This is the primary KPI for layout-driven VRT and layout assertions.

### 2. End-to-End Component Image Time

`T_image_artifact`

Time from fixture load to "PNG/JPEG artifact for the selected component is ready".

This is the primary KPI for image-based VRT.

### 3. Phase Breakdown

Track these separately so regressions are attributable:

- `T_node_layout`: DOM + CSS -> node + layout
- `T_aom_build`: target component DOM -> accessibility tree
- `T_extract`: selector/sharedId resolution + component clipping/extraction
- `T_landmark_extract`: accessibility tree -> landmark-only subtree/forest
- `T_landmark_serialize`: landmark-only subtree/forest -> JSON
- `T_paint`: node/layout -> paint tree
- `T_raster`: paint tree -> framebuffer / RGBA
- `T_encode`: framebuffer -> PNG/JPEG/base64

### 4. Regression Budget

Use both absolute and relative gates:

- absolute latency target
- relative regression budget against the last accepted baseline

Recommended regression guard:

- `p50` must not regress by more than `10%`
- `p95` must not regress by more than `15%`
- image artifact `p95` may use a looser `25%` guard because raster/encode tail latency is noisier than structural artifacts

## Fixture Classes

Define KPI against fixture classes instead of one giant snapshot.

| Class | Typical Shape | Target Use |
| --- | --- | --- |
| `XS` | simple badge/button/card, `< 100` DOM nodes | design-system atoms |
| `S` | card/list item/panel, `< 300` DOM nodes | common component VRT |
| `M` | table section/dialog/form block, `< 800` DOM nodes | realistic feature components |
| `L` | dashboard panel/article section, `< 1500` DOM nodes | upper bound for component snapshots |

For KPI review, `S` and `M` should be the default gating classes.

## Target KPI

These numbers are intended as the first enforced targets for local dev and CI on fixed hardware.
If the baseline proves unrealistic, tune the numbers once, then freeze them.

### Layout Artifact

| Class | p50 | p95 |
| --- | --- | --- |
| `XS` | `< 4 ms` | `< 8 ms` |
| `S` | `< 8 ms` | `< 15 ms` |
| `M` | `< 20 ms` | `< 35 ms` |
| `L` | `< 40 ms` | `< 75 ms` |

### Image Artifact

| Class | p50 | p95 |
| --- | --- | --- |
| `XS` | `< 8 ms` | `< 15 ms` |
| `S` | `< 15 ms` | `< 28 ms` |
| `M` | `< 35 ms` | `< 60 ms` |
| `L` | `< 80 ms` | `< 140 ms` |

### Landmark Artifact

| Class | p50 | p95 |
| --- | --- | --- |
| `XS` | `< 0.08 ms` | `< 0.12 ms` |
| `S` | `< 0.20 ms` | `< 0.30 ms` |
| `M` | `< 0.50 ms` | `< 0.80 ms` |
| `L` | `< 0.80 ms` | `< 1.20 ms` |

## Suggested Acceptance Rule

For component VRT to be considered healthy:

- `S` and `M` fixtures must satisfy the absolute KPI above
- no benchmark may exceed the regression budget versus the stored baseline
- image extraction regressions are allowed only if layout extraction remains within budget and the regression is explained by intentional raster-quality work
- landmark extraction is the preferred gate for structural/smoke VRT where screenshot fidelity is unnecessary

## Recommended Technical Shape

### Input Contract

Use a fixture contract like:

```json
{
  "html": "<div data-component-root>...</div>",
  "baselineCss": "...",
  "componentCss": "...",
  "selector": "[data-component-root]",
  "viewport": { "width": 800, "height": 600 },
  "artifact": "layout|image"
}
```

### Preferred Extraction API

1. Load bounded HTML directly, without navigation.
2. Inline baseline CSS and component CSS into the fixture.
3. Resolve the component root by selector.
4. Produce either:
   - layout JSON for the selected component, or
   - clipped image output for the selected component, or
   - landmark-only AOM JSON for the selected component

This keeps the benchmark focused on renderer cost instead of browser-shell overhead.

## Existing Hooks In This Repository

The current codebase already has useful building blocks:

- `shell/browser_bench_wbtest.mbt`
  - existing bench entry point for render phases
- `shell/browser.mbt`
  - `Browser::set_html_content`
  - `Browser::render_output`
- `mizchi/crater/aom`
  - `build_accessibility_tree_from_element`
  - `find_landmarks`
- `../webdriver/webdriver/bidi_protocol.mbt`
  - `browsingContext.locateNodes`
  - `browsingContext.captureScreenshotData`
  - `clip.element` and `clip.box`
- `../webdriver/webdriver/bidi_browsing_context_actual_paint.mbt`
  - actual paint timing already split into `render`, `paint`, `fb`, `total`

That means the repository can support both:

- pure renderer benchmarks
- protocol-level component snapshot benchmarks

## Recommended Benchmark Names

Use stable names so KPI charts stay readable:

- `component_layout_xs`
- `component_layout_s`
- `component_layout_m`
- `component_layout_l`
- `component_landmarks_xs`
- `component_landmarks_s`
- `component_landmarks_m`
- `component_landmarks_l`
- `component_image_xs`
- `component_image_s`
- `component_image_m`
- `component_image_l`
- `component_phase_aom_build_m`
- `component_phase_node_layout_m`
- `component_phase_paint_m`
- `component_phase_landmark_extract_m`
- `component_phase_landmark_serialize_m`
- `component_phase_raster_m`
- `component_phase_encode_m`

## Recommendation

The main KPI should be:

`bounded component fixture -> selected component artifact`

not:

`page navigation -> browser automation -> screenshot`

For this repository, that means:

- use landmark-tree artifact as the fast path for structural VRT and smoke snapshots
- use renderer-level benches for the hard latency gate
- use BiDi-level component clipping only as an integration check
- keep full E2E flows out of the KPI path

## Baseline Workflow

- run once to inspect current numbers:
  - `pnpm bench:component-vrt`
- update the stored baseline after intentional improvements:
  - `pnpm bench:component-vrt:update-baseline`
- verify against the stored baseline and absolute budget:
  - `pnpm bench:component-vrt:check-baseline`
- baseline update/check uses `1` warmup suite run and `5` measured suite runs by default
- stored data is aggregated as `p50/p95` over repeated suite runs, not a single `mean`
- override the sample count when needed:
  - `node benchmarks/scripts/component-vrt-bench-baseline.mjs check --warmup 2 --runs 7`

Stored baseline:

- `benchmarks/tests/component-vrt-bench-baseline.json`

## Crater CLI KPI

Renderer-only benches stay the hard latency gate, but `crater` itself also needs a shell-level KPI.

The CLI KPI covers:

- Node process startup
- CLI argument parsing and validation
- HTML/CSS file reads
- selector resolution
- artifact emission to stdout or `--output-file`

Initial CLI metrics:

- `crater_cli_landmarks_selector_s`
- `crater_cli_landmarks_selector_m`
- `crater_cli_layout_selector_s`
- `crater_cli_layout_selector_m`
- `crater_cli_image_selector_s_file`
- `crater_cli_image_selector_m_file`

Notes:

- all CLI metrics resolve the target via `--target-selector`
- layout metrics emit JSON to stdout
- image metrics emit a JSON envelope with `encoding: "png-base64"` via `--output-file` to include the artifact write path
- landmarks intentionally skip CSS files to represent the fast structural VRT path
- CLI absolute budgets are looser than renderer-only benches because they include process startup, file IO, selector resolution, and compressed PNG artifact emission
- CLI `p95` uses a looser `25%` regression budget because small-sample tail latency is dominated by fresh-process startup and file-system variance

CLI baseline workflow:

- inspect current numbers:
  - `pnpm bench:crater-cli`
- update the stored CLI baseline after intentional improvements:
  - `pnpm bench:crater-cli:update-baseline`
- verify against the stored baseline and absolute budget:
  - `pnpm bench:crater-cli:check-baseline`

Stored CLI baseline:

- `benchmarks/tests/crater-cli-bench-baseline.json`
