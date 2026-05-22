# Crater

A headless browser environment for [MoonBit](https://www.moonbitlang.com/), driven by [Playwright](https://playwright.dev/) over [WebDriver BiDi](https://w3c.github.io/webdriver-bidi/).

> **Use Playwright tests on a small, predictable target instead of spinning up a full Chromium.** Crater speaks the WebDriver BiDi protocol natively, so existing Playwright suites can connect to it for layout-and-DOM-level testing without the weight of a real browser.

## Why

- Playwright + BiDi is becoming the standard surface for web automation. Crater treats that surface as a first-class contract instead of an afterthought.
- The runtime is small enough to embed in tests, CI pipelines, and design tools where Chromium is overkill.
- A predictable layout / paint pipeline (Taffy-derived) makes regressions easier to bisect than against a moving Chromium release train.
- Built in MoonBit, so the codebase compiles to JS / native / wasm targets out of the same source.

## Quick start

```bash
pnpm install
pnpm exec playwright install chromium  # only needed for VRT reference captures
pkf run prepare
```

Run a Playwright test against Crater (Crater starts on demand via the project's `playwright.config.ts` webServer):

```typescript
import { test, expect } from "@playwright/test";

test("Crater serves a static page over BiDi", async ({ page }) => {
  await page.goto("data:text/html,<h1>hello</h1>");
  await expect(page.locator("h1")).toHaveText("hello");
});
```

Or drive it raw from the WebDriver BiDi protocol:

```typescript
import { connectCraterBidi } from "./tests/helpers/crater-bidi";

const session = await connectCraterBidi();
await session.browsingContext.navigate({
  url: "data:text/html,<form id=login>...</form>",
  wait: "complete",
});
const count = await session.script.evaluate({
  expression: "document.forms.length",
});
```

## Supported surface

| Area | Status |
|---|---|
| WebDriver BiDi `session` / `browsingContext` / `script` / `input` / `network` / `storage` | 100% of the WPT subset we gate on |
| HTML + CSS parsing | 100% local parser tests, 94% [WPT CSS](https://github.com/web-platform-tests/wpt) layout pass rate |
| DOM (`wpt/dom/nodes`) | 100% |
| Shadow DOM + custom elements | Core surface; full coverage in flight (`compat.web-components-*` scenarios) |
| Cookie jar (Set-Cookie / SameSite / partitioned storage) | Spec-conformant for the http-only path |
| CORS preflight + Access-Control-* validation | Enforced on `script.evaluate` fetches via Phase 1 of the auth/CORS spec |
| Per-origin Authorization injection (Bearer / JWT) | `crater.setOriginAuthorization` BiDi extension command |
| HTTP Basic 401 challenge + `network.continueWithAuth` | Phase 2, tracked in #147 |
| Form-based login end-to-end (`form.submit` / `navigate wait:"complete"`) | Working via the cookie jar + Set-Cookie ingest path |
| Visual regression vs Chromium reference | `pkf run test-visual` (paint-vrt) and `pkf run test-wpt-vrt` |

## Modules

Crater is split into focused MoonBit modules under one repository. Pick the narrow module you need:

```bash
moon add mizchi/crater-layout            # Taffy-derived layout engine
moon add mizchi/css                      # CSS parser + selector matching
moon add mizchi/crater-dom               # DOM + Shadow DOM
moon add mizchi/crater-renderer          # HTML -> layout tree -> paint tree
moon add mizchi/crater-browser           # Browser shell (cookie jar, fetch, navigation)
moon add mizchi/crater-browser-runtime   # JS runtime + DOM serializer
moon add mizchi/crater-webdriver-bidi    # WebDriver BiDi protocol surface
moon add mizchi/crater-browser-http      # http / cookie / cors / samesite / auth profile
moon add mizchi/crater-wasm              # wasm component target
```

Each module exposes its public contract through a generated `.mbti` file; CI ensures the surface doesn't drift accidentally.

## Architecture highlights

- **Profile-backed HTTP state.** Each BiDi session carries a `Profile { cookie_jar, http_cache, auth_state, preflight_cache }`. Cookies, CORS preflight cache, and per-origin Authorization headers live on the same value, scoped per browsing context; user-agent emulation stays in WebDriver state.
- **Two-stage CORS.** The fetch shim runs spec-faithful `classify_request` -> preflight (`OPTIONS`) -> `validate_actual_response` for cross-origin requests, with a JS-side preflight cache that mirrors the MoonBit `PreflightCache` (same Max-Age clamp, same cache key formula).
- **Caller-wins header attach.** When the runtime auto-attaches cookies or `Authorization`, it skips if the caller (page script) already supplied that header. Same policy for both.
- **Async / sync bridge.** WebDriver BiDi handlers are synchronous MoonBit code, but navigation and fetch are async JavaScript. Bridges (`js_navigate_and_send_async`, `js_eval_and_send_async`) let the JS side send BiDi responses via `socket.send` once the promise resolves, instead of the MoonBit handler trying (and failing) to await.

Full design documents live under `docs/superpowers/specs/`:

- [Browser auth + CORS](docs/superpowers/specs/2026-05-17-browser-auth-cors-design.md)
- [BiDi origin-scoped Authorization](docs/superpowers/specs/2026-05-18-bidi-origin-authorization-design.md)
- [HTTP cache](docs/superpowers/specs/2026-04-04-http-cache-design.md)

## Test compatibility

### Web Platform Tests (CSS)

Pass rates measured by the layout-tree-compare runner (`scripts/wpt-runner.ts`):

| Module | Passed | Total | Rate |
|--------|--------|-------|------|
| css-flexbox | 282 | 289 | 97.6% |
| css-grid | 32 | 33 | 97.0% |
| css-tables | 30 | 32 | 93.8% |
| css-display | 79 | 79 | 100.0% |
| css-box | 30 | 30 | 100.0% |
| css-sizing | 83 | 94 | 88.3% |
| css-align | 37 | 44 | 84.1% |
| css-position | 83 | 84 | 98.8% |
| css-overflow | 214 | 243 | 88.1% |
| css-contain | 283 | 303 | 93.4% |
| css-variables | 107 | 107 | 100.0% |
| filter-effects | 98 | 106 | 92.5% |
| compositing | 2 | 2 | 100.0% |
| css-logical | 5 | 5 | 100.0% |
| css-content | 1 | 2 | 50.0% |
| css-multicol | 4 | 4 | 100.0% |
| css-break | 26 | 27 | 96.3% |
| css-color | 30 | 30 | 100.0% |
| css-backgrounds | 74 | 80 | 92.5% |
| css-transforms | 2 | 2 | 100.0% |
| css-writing-modes | 17 | 27 | 63.0% |
| css-pseudo | 1 | 1 | 100.0% |
| css-borders | 4 | 5 | 80.0% |

Module-level pass / fail counts are pinned in `tests/wpt-baselines/<module>.env`; CI fails if the count regresses. See `pkspec spec --goals specs/crater.pkl specs/tasks.Test.pkl` for per-goal coverage.

### WebDriver BiDi

| Profile | Passed | Total |
|---|---|---|
| `wpt/webdriver` (strict subset) | 277 | 277 |
| `session` | 130 | 130 |
| `browsing_context` | 1008 | 1008 |
| `script` | 1025 | 1025 |
| `input` | 708 | 708 |
| `network` | 1389 | 1389 |

```bash
pkf run wpt           # CSS + DOM + WebDriver BiDi
just wpt-webdriver-profile strict
```

### Layout (Taffy compatibility)

Crater's layout engine is a MoonBit port of [Taffy](https://github.com/DioxusLabs/taffy):

| Module | Passed | Total | Rate |
|---|---|---|---|
| Flexbox | 543 | 609 | 89.2% |
| Block | 204 | 226 | 90.3% |
| Grid | 268 | 331 | 81.0% |
| **Total** | **1015** | **1166** | **87.0%** |

### Visual regression vs Chromium

| Site | Diff | Status |
|---|---|---|
| example.com | 1.16% | PASS |
| info.cern.ch | 3.30% | PASS |
| www.google.com | 3.80% | PASS |
| news.ycombinator.com | 12.4% | WARN |
| en.wikipedia.org | 7.65% | WARN |

```bash
just vrt-url-native https://example.com
just vrt-url https://example.com --mask-text --mask-dynamic
just test-wpt-vrt
CRATER_PAINT_BACKEND=native just test-vrt
```

## WPT runner setup

```bash
npm run wpt:fetch-all  # Fetch all WPT tests
npm run wpt:run-all    # Run all enabled WPT tests
```

WPT target selection is configured in `wpt.json`. Browser WPT commands:

```bash
just wpt-dom-all
just wpt-webdriver-profile strict
just wpt-webdriver session
just wpt-webdriver browsing_context
just wpt-webdriver script
just wpt-webdriver input
just wpt-webdriver network
```

Optional external intrinsic providers for text/image:

```bash
CRATER_TEXT_MODULE=/abs/path/to/text-module.js \
CRATER_TEXT_FONT_PATH=/abs/path/to/font.ttf \
npx tsx scripts/wpt-runner.ts css-overflow

CRATER_IMAGE_MODULE=/abs/path/to/image-module.js \
npx tsx scripts/wpt-runner.ts css-contain
```

See the WPT CI Maintenance section below for shard balancing notes.

## Quality contracts (pkspec)

Crater's behavioural contracts live in `specs/crater.pkl` (pkspec). They link to the tests that exercise them, and CI fails if an approved scenario loses its implementation.

```bash
pkf run spec-check          # contracts are linked
pkf run spec-lint            # cross-references valid
pkf run spec-test            # executable smoke tests
pkspec spec --next  specs/crater.pkl specs/tasks.Test.pkl   # next-priority drafts
```

Open scenario draft work is tracked in GitHub issues; see the `enhancement` and `bug` labels for the active backlog.

## Performance

HTML parser benchmarks (Apple Silicon):

| Benchmark | Time |
|---|---|
| Simple HTML (100 elements) | ~27 µs |
| Large document (100 sections × 20 paragraphs) | ~5.2 ms |
| Attribute-heavy (200 elements, 6 attrs each) | ~390 µs |
| Table (100×20 cells) | ~990 µs |

```bash
moon bench -p html
```

## Layout module usage

For projects that just want the layout engine without the rest of the browser, the `crater-renderer` module exposes a minimal HTML → layout API:

```moonbit
// Parse HTML and render layout

///|
let html = "<div style=\"display: flex; width: 300px;\"><div style=\"flex: 1\">A</div><div style=\"flex: 2\">B</div></div>"

///|
let ctx = @renderer.RenderContext::default()

///|
let layout = @renderer.render(html, ctx)

// layout contains x, y, width, height for each element
```

## WPT CI Maintenance (Parallel Shards)

The CI workflow runs WPT compatibility checks with about 6 workers:

- `wpt-css`: 4 shards (`wpt-css (shard-1..4)`)
- `wpt-dom`: 1 job (`wpt-dom`, runs `--dom` and `--svg`)
- `wpt-webdriver`: 1 job (`wpt-webdriver`, runs 10 strict BiDi targets)

See the shard assignment in `.github/workflows/ci.yml` (`wpt-css-tests`, `wpt-dom-tests`, `wpt-webdriver-tests`).

Each run also publishes two summaries:

- `wpt-compat-summary`: compatibility totals/pass rate (`wpt-summary/wpt-compat-summary.md`)
- `ci-timing-summary`: queue/run bottlenecks by job and group (`ci-timing/summary.md`)

Use this checklist when maintaining shard balance:

1. Open the latest GitHub Actions run and check `ci-timing-summary`.
2. Compare `wpt-css (shard-*)` durations in "Slowest Jobs".
3. If one shard is consistently slower (roughly >10s), move modules between shard definitions in `.github/workflows/ci.yml`.
4. Keep each shard runtime close (current target is roughly 65-75s per CSS shard).
5. Verify compatibility totals from `wpt-compat-summary` are not regressing.

Optional local dry-run for summaries:

```bash
mkdir -p /tmp/wpt-reports
npx tsx scripts/wpt-runner.ts css-overflow css-grid css-tables --workers 4 --json /tmp/wpt-reports/wpt-css-shard-1.json
npx tsx scripts/wpt-dom-runner.ts --dom --json /tmp/wpt-reports/wpt-dom-dom.json
npx tsx scripts/wpt-dom-runner.ts --svg --json /tmp/wpt-reports/wpt-dom-svg.json
npx tsx scripts/wpt-webdriver-runner.ts --subset --json /tmp/wpt-reports/wpt-webdriver-strict.json
npx tsx scripts/wpt-ci-summary.ts --input /tmp/wpt-reports --json /tmp/wpt-summary.json --markdown /tmp/wpt-summary.md
```

When a compatibility improvement/regression should become the new baseline, update `tests/wpt-baseline.env` (used by `scripts/wpt-ci-summary.ts` for CSS baseline delta).

## Limitations

- **Font rendering** is approximate (monospace character sizing). Text-wrap parity with Chromium is an open scenario (#154).
- **Some DOM gaps** under active fix — see `bug.dom.*` scenarios in `specs/crater.pkl`.
- **No GPU-based painting** — the kagura native paint backend handles common output but isn't pixel-perfect against Chromium for complex content.

## Documentation

- [API Reference](docs/api.md)
- [Workspace Guide](docs/monorepo-workspace.md) — module layout, release policy
- [Browser support KPI](docs/browser-support-kpi.md) — detailed compatibility snapshot
- Design docs under `docs/superpowers/specs/`

## License

Apache-2.0. Layout engine derived from [Taffy](https://github.com/DioxusLabs/taffy) (MIT/Apache-2.0).
