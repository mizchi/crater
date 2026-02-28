# TODO

## css-flexbox WPT 進捗（2026-02-21）

- 現在: `278 / 289 passed`（`11 failed`）
- 今回の更新: `270 / 289` → `278 / 289`（+8）
- 実行コマンド: `npx tsx scripts/wpt-runner.ts css-flexbox`

## 今回対応済み（完了）

- [x] `grid-flex-item-001.html`
- [x] `grid-flex-item-002.html`
- [x] `grid-flex-item-004.html`
- [x] `grid-flex-item-005.html`
- [x] `fixed-table-layout-with-percentage-width-in-flex-item.html`

## 残タスク（11）

- [ ] `align-baseline.html`
- [ ] `flex-aspect-ratio-img-column-012.html`
- [ ] `flex-box-wrap.html`
- [ ] `flex-direction-row-vertical.html`
- [ ] `flex-inline.html`
- [ ] `flex-vertical-align-effect.html`
- [ ] `justify-content_space-between-003.tentative.html`
- [ ] `overflow-top-left.html`
- [ ] `position-absolute-scrollbar-freeze.html`
- [ ] `table-with-infinite-max-intrinsic-width.html`
- [ ] `text-overflow-on-flexbox-001.html`

## WPT 伸び代メモ（2026-02-27）

- 全体: `1064 / 1446 passed`（`382 failed`）
- 失敗上位モジュール:
  - `css-contain`: `120 failed`
  - `css-overflow`: `114 failed`
  - `css-display`: `38 failed`

### css-contain（次の着手点）

- 失敗クラスター（概数）
  - `contain-size-*`: 31
  - `contain-paint-*`: 29
  - `contain-layout-*`: 26
  - `contain-style-*`: 15
- 先頭ターゲット: `contain-inline-size-intrinsic.html`
  - 症状: `root.width browser=100 / crater=0`
  - 仮説: `contain-intrinsic-inline-size` 未実装
  - 進捗（2026-02-27）:
  - `183 / 303 passed`（`120 failed`）→ `233 / 303 passed`（`70 failed`）
  - `233 / 303 passed`（`70 failed`）→ `236 / 303 passed`（`67 failed`）
  - `236 / 303 passed`（`67 failed`）→ `243 / 303 passed`（`60 failed`）
  - `243 / 303 passed`（`60 failed`）→ `247 / 303 passed`（`56 failed`）
  - 改善済み:
    - `contain-inline-size-intrinsic.html`
    - `contain-inline-size-vertical-rl-.html`
    - `contain-inline-size-fieldset.html`
    - `contain-inline-size-legend.html`
    - `contain-inline-size-bfc-floats-001.html`
    - `contain-inline-size-bfc-floats-002.html`
    - `contain-content-002.html`
    - `contain-layout-001.html`
    - `contain-layout-003.html`
    - `contain-layout-005.html`
    - `contain-layout-009.html`
    - `contain-layout-010.html`
    - `contain-layout-011.html`
    - `contain-layout-012.html`
    - `contain-layout-017.html`
    - `contain-layout-baseline-002.html`
    - `contain-layout-baseline-003.html`
    - `contain-layout-baseline-005.html`
    - `contain-layout-dynamic-004.html`
    - `contain-layout-dynamic-005.html`
    - `contain-layout-ink-overflow-014.html`
    - `contain-layout-ink-overflow-016.html`
    - `contain-layout-ink-overflow-017.html`
    - `contain-layout-ink-overflow-018.html`
    - `contain-layout-button-002.tentative.html`
    - `contain-layout-independent-formatting-context-002.html`
    - `contain-layout-independent-formatting-context-003.html`
    - `contain-layout-suppress-baseline-002.html`
    - `contain-layout-cell-001.html`
    - `contain-layout-cell-002.html`
    - `contain-paint-independent-formatting-context-003.html`
    - `contain-content-004.html`
    - `contain-paint-011.html`
    - `contain-paint-012.html`
    - `contain-paint-024.html`
    - `contain-paint-014.html`
    - `contain-paint-015.html`
    - `contain-paint-016.html`
    - `contain-paint-017.html`
    - `contain-paint-018.html`
    - `contain-paint-047.html`
    - `contain-paint-cell-001.html`
    - `contain-paint-cell-002.html`
    - `contain-size-007.html`
    - `contain-size-008.html`
    - `contain-size-009.html`
    - `contain-inline-size-removed.html`
    - `contain-size-removed.html`
    - `contain-body-t-o-001.html`
    - `contain-body-t-o-002.html`
    - `contain-body-t-o-003.html`
    - `contain-body-t-o-004.html`
    - `contain-html-t-o-001.html`
    - `contain-html-t-o-002.html`
    - `contain-html-t-o-003.html`
    - `contain-html-t-o-004.html`
  - 次の有力クラスター:
    - `contain-layout-baseline-004.html`（font/Ahem 計測差）
    - `contain-layout-breaks-{001,002}.html`（multicol + forced break 未実装）

### css-overflow（次点）

- `scroll-marker/target` 系の失敗が大半（約 52）
- `column-scroll-marker` / `scroll-buttons` / `overflow-alignment` もまとまって残っている
