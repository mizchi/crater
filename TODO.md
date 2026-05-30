# TODO

Last organized: 2026-05-30

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

`compat.css-inline-baseline` は完了 (PR #250 / 10-of-11)。残りは外部依存 or 部分完了で blocked。

| scenario id | 概要 | link | 状態 |
|---|---|---|---|
| `compat.css-images-baseline` | css-images WPT baseline 有効化 | #65, #68 | blocked: 上流 `mizchi/css` (border longhand cascade) + `sibling-index()` 未実装 |
| `compat.css-values-baseline` | css-values WPT baseline 有効化 | #65, #67 | blocked: 上流 `mizchi/css` (mixed `calc()` の Dimension 表現). 設計メモ `docs/css-calc-and-border-longhand-design.md` |
| `compat.css-filter-effects` | filter-effects 残 failure 潰し | #64 | 一部済: `has_filter` CB 確立は landed。残りは inline filter CB のジオメトリ + backdrop-filter/SVG subregion (paint側) |
| `paint.text-glyph-metrics` | glyph metrics / AA Chromium parity | #47 | blocked: `mizchi/kagura` ラスタライザ |

## Next (P1) — pkspec scenarios

| scenario id | 概要 | link | 状態 |
|---|---|---|---|
| `compat.web-components-shadow-selectors` | `:host` 複合 / `::slotted` / `:host-context` | #155 | crater 内部・着手可 |
| `compat.web-components-element-internals` | closed shadow / declarative SD / form-associated | #156 | crater 内部 |
| `compat.browser-shell-form-controls` | select popup / blur change / IME / caret | #159 | crater 内部 |
| `compat.native-form-control-appearance` | select / button native appearance 方針 | #160 | 方針判断含む |
| `protocol.playwright-shadow-aware` | Playwright / CDP / jsbidi shadow-aware | #157 | crater 内部 |
| `paint.real-world-snapshots` | built-in real-world snapshot 3-5 ページ | #161 | VRT fixture 整備 |
| `paint.github-residual-diff` | GitHub VRT 残差 (sticky nav / card border / list marker) | #162 | VRT 残差潰し |
| `paint.browser-shell-fixture-expansion` | browser shell fixture を実ページ寄りに | #163 | VRT fixture 整備 |
| `diagnostic.vrt-prescanner-tracker` | VRT prescanner benchmark tracker | #29 | 依存 API/修正は全 landed (#23/#24/#25/#26/#27, #22/#2/#17) → 再ベンチ可能 |
| `ci.parallel-vrt-bottleneck` | VRT shard 並列化 | #44 | 一部済: css-display 3分割 (PR #251), flexbox/box も分割済。残: paint-vrt の timing-driven rebalance |
| `ci.flaker-effectiveness` | flaker quarantine / fixture tighten | #79 | ⏰ `paint-vrt-real-world-ci-latency` quarantine が 2026-05-31 期限。expiry gate / duckdb cache 未対応 |

## Backlog (P2/P3) — pkspec scenarios

| scenario id | 概要 | link |
|---|---|---|
| `bug.border-radius-paint` | border-radius pixel diff | #19 |
| `bug.samesite.psl-required` | SameSite eTLD+1 は PSL が必要 (security review I3) | — |
| `bug.dom.html-form-element-submit-missing` | `HTMLFormElement.submit` / `requestSubmit` 未公開 | PR #132 |
| `bug.dom.document-forms-missing` | `document.forms` HTMLCollection 未公開 | PR #132 |
| `bug.bidi.navigate-wait-complete-returns-early` | `browsingContext.navigate` wait=complete が JS target で HTML fetch より先に解決 | PR #132 |
| `bug.runtime.fetch-no-partition-cookies` | runtime `fetch()` が partition cookie を自動付与しない | PR #132 |
| `bug.runtime.fetch-no-cors-gate` | runtime `fetch()` が `script_fetch_with_cors` を通らない | PR #132 |
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

- `mizchi/css`: mixed `calc()` (percentage + length) の Dimension 表現が無く `Auto` に落ちる → #67 (css-values), 設計メモ `docs/css-calc-and-border-longhand-design.md`
- `mizchi/css`: `border` shorthand が後続の `border-*-width` longhand を上書き (cascade order) → #68 (css-images)
- `mizchi/css`: `sibling-index()` 未実装 → #68
- `mizchi/kagura`: SVG rasterizer alpha 問題 (テキスト色が薄い) → #19 / #47 関連
- `mizchi/kagura`: glyph mirror per-quad UV swap workaround の正しい層での解消
- CI: llvmpipe セットアップ判断 (`LIBGL_ALWAYS_SOFTWARE=1` / `mesa-vulkan-drivers`)
- realm モデル設計判断待ち: live cross-frame DOM → #200, 設計ドキュメント `docs/bidi-cross-frame-realm-model-design.md`

## Recently landed (2026-05-30 セッション)

approved に flip 済の scenario と closed issue。詳細は git history / 各 PR。

- diagnostic-api クラスタ全完了: `diagnostic.paint-tree-diff` (#23), `diagnostic.css-property-mutation` (#24), `diagnostic.selector-scoped-render` (#25), `protocol.bidi-computed-style` (#26), `diagnostic.css-rule-usage-tracking` (#27) — PR #245/#246/#252/#254
- layout バグ verify-and-lock-in: `bug.flexbox-align-items` (#22), `bug.flexbox-min-width-justify` (#2), `bug.inline-abspos-width-ahem` (#17)
- `compat.css-inline-baseline` (#66 fix → baseline 有効化, PR #250)
- BiDi: auth Phase 2 (#147), async cross-evaluate iframe (#198) — 実装済を確認し close
- renderSelector の bbox を paint tree 由来に修正 (#253, PR #254)

## Maintenance Rules

- pkspec scenario に reify したら、 該当行をこのファイルから削除する
- scenario の reviewStatus が `approved` になったら、 表の link 列に対応 test を追記する
- 古い計測値は再計測コマンドと日付を必ず添える
- 完了済タスクの実装履歴は git history / docs / issue に寄せる
