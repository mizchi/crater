# TODO

Last organized: 2026-05-22

このファイルは pkspec scenario の navigation index と、 scenario に reify していない backlog の置き場。

- **master**: `specs/crater.pkl` (Goal + Scenario)
- **個別バグ・契約**: GitHub issue
- **このファイル**: scenario への pointer + scenario 化対象外の運用メモ・外部依存

```sh
pkspec spec --goals specs/crater.pkl specs/tasks.Test.pkl   # 全 goal coverage
pkspec spec --next  specs/crater.pkl specs/tasks.Test.pkl   # 未実装 scenario を priority 順
pkf run spec-check                                          # contract が壊れていないか
```

## Now (P0) — pkspec scenarios

| scenario id | 概要 | link |
|---|---|---|
| `compat.css-images-baseline` | css-images WPT baseline 有効化 | #65, #68 |
| `compat.css-values-baseline` | css-values WPT baseline 有効化 | #65, #67 |
| `compat.css-inline-baseline` | css-inline WPT baseline 有効化 | #65, #66 |
| `compat.css-filter-effects` | filter-effects 残 failure 潰し | #64 |
| `paint.text-glyph-metrics` | glyph metrics / AA Chromium parity | #47 |

## Next (P1) — pkspec scenarios

| scenario id | 概要 | link |
|---|---|---|
| `compat.web-components-shadow-selectors` | `:host` 複合 / `::slotted` / `:host-context` | #155 |
| `compat.web-components-element-internals` | closed shadow / declarative SD / form-associated | #156 |
| `compat.browser-shell-form-controls` | select popup / blur change / IME / caret | #159 |
| `compat.native-form-control-appearance` | select / button native appearance 方針 | #160 |
| `protocol.playwright-shadow-aware` | Playwright / CDP / jsbidi shadow-aware | #157 |
| `paint.real-world-snapshots` | built-in real-world snapshot 3-5 ページ | #161 |
| `paint.github-residual-diff` | GitHub VRT 残差 (sticky nav / card border / list marker) | #162 |
| `paint.browser-shell-fixture-expansion` | browser shell fixture を実ページ寄りに | #163 |
| `diagnostic.paint-tree-diff` | paint tree diff API | #23 |
| `diagnostic.css-property-mutation` | CSS property mutation API | #24 |
| `protocol.bidi-computed-style` | BiDi `getComputedStyle()` | #26 |
| `diagnostic.vrt-prescanner-tracker` | VRT prescanner benchmark tracker | #29 |
| `ci.parallel-vrt-bottleneck` | VRT shard 並列化 | #44 |
| `ci.flaker-effectiveness` | flaker quarantine / fixture tighten | #79 |

## Backlog (P2/P3) — pkspec scenarios

| scenario id | 概要 | link |
|---|---|---|
| `bug.flexbox-min-width-justify` | flexbox min_width + justify-content | #2 |
| `bug.inline-abspos-width-ahem` | inline abspos width Ahem | #17 |
| `bug.border-radius-paint` | border-radius pixel diff | #19 |
| `bug.flexbox-align-items` | align-items 反映 | #22 |
| `bug.samesite.psl-required` | SameSite eTLD+1 は PSL が必要 (security review I3) | — |
| `bug.dom.html-form-element-submit-missing` | `HTMLFormElement.submit` / `requestSubmit` 未公開 | PR #132 |
| `bug.dom.document-forms-missing` | `document.forms` HTMLCollection 未公開 | PR #132 |
| `bug.bidi.navigate-wait-complete-returns-early` | `browsingContext.navigate` wait=complete が JS target で HTML fetch より先に解決 | PR #132 |
| `bug.runtime.fetch-no-partition-cookies` | runtime `fetch()` が partition cookie を自動付与しない | PR #132 |
| `bug.runtime.fetch-no-cors-gate` | runtime `fetch()` が `script_fetch_with_cors` を通らない | PR #132 |
| `diagnostic.css-rule-usage-tracking` | dead CSS rule tracking | #27 |
| `tui.raster-image-display` | TUI JPEG / PNG / GIF | #16 |
| `ci.affected-required-check` | affected pkfire の required 化判断 | — |
| `ci.flaker-vrt-harness-contract` | vrt-harness consumer payload 接続 | — |

## Not reified — operational / refactor 残務

scenario 化していない (contract として書く粒度ではない) もの。 必要になったタイミングで issue 化するか、 該当 module の TODO コメントで管理する。

### Refactor

- `painter/paint/raster/paint_raster.mbt` の glyph 周辺責務整理 (bitmap font fallback と glyph path render の境界、 `mizchi/font` / `mizchi/svg` 委譲)
- `webdriver/server` の WebSocket transport (`bidi_server.mbt`) 移動 — `reset_runtime_js_state` / `reset_paint_provider` を callback 化してから (#71 続き)
- `scripts/crater_bidi_adapter.py` から transport 以外の実装責務を削る
- `scripts/wpt-webdriver-runner.ts` / `scripts/wpt-runner.ts` / `scripts/wpt-dom-runner.ts` の責務整理

### Workspace / Release

- 実 `mizchi/image` 依存時の JS export + Bytes 入力 shape 固定 (smoke test)
- `taffy_compat` failure を baseline 管理にするか段階潰しか方針決定
- `moon coverage analyze` の mixed-target workspace 扱い決定
- `benchmarks` / `testing` / adapter module の release note template と changelog 粒度
- root facade retirement 後の publish / release note 確認 (publish script / docs / downstream が retired facade を参照しないか)
- `browser/native` / `wasm` を CI required check にどこまで含めるか
- adapter module (`jsbidi`, `browser-native`, `js`, `wasm`) の公開サポート範囲

### VRT 運用

- low diff ページの pseudo / icon / border-radius 残差は font 差分除外 VRT の budget tighten 後に対応
- WPT VRT ベースラインを `just wpt-vrt-baseline-update` で随時更新
- fixture ごとの threshold を artifact を見ながら段階的に tighten
- Static snapshot scaling は `benchmarks/BASELINE.md` に記録済み。 synthetic probes は概ね linear、 `mdn-wasm-text` は 1k→2k の content-shape threshold を必要時に profiler 対象にする

## External / Blocker

- `mizchi/kagura`: SVG rasterizer alpha 問題 (テキスト色が薄い)
- `mizchi/kagura`: glyph mirror per-quad UV swap workaround の正しい層での解消
- CI: llvmpipe セットアップ判断 (`LIBGL_ALWAYS_SOFTWARE=1` / `mesa-vulkan-drivers`)

## Maintenance Rules

- pkspec scenario に reify したら、 該当行をこのファイルから削除する
- scenario の reviewStatus が `approved` になったら、 表の link 列に対応 test を追記する
- 古い計測値は再計測コマンドと日付を必ず添える
- 完了済タスクの実装履歴は git history / docs / issue に寄せる
