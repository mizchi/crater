# WPT Investigation Log (2026-02)

このドキュメントは、`tmp/` に置いていた調査ログのうち再利用価値がある内容だけを抜粋したメモです。  
生ログは削除し、ここに要点だけ残します。

## 1. モジュール別スナップショット（2026-02-28）

出典: `tmp/wpt-modules/*.current.log` の `Summary` 行。

| module | passed | failed | total | pass rate |
| --- | ---: | ---: | ---: | ---: |
| compositing | 2 | 0 | 2 | 100.0% |
| css-align | 16 | 28 | 44 | 36.4% |
| css-box | 30 | 0 | 30 | 100.0% |
| css-contain | 183 | 120 | 303 | 60.4% |
| css-display | 41 | 38 | 79 | 51.9% |
| css-flexbox | 277 | 12 | 289 | 95.8% |
| css-grid | 32 | 1 | 33 | 97.0% |
| css-overflow | 129 | 114 | 243 | 53.1% |
| css-position | 52 | 32 | 84 | 61.9% |
| css-sizing | 92 | 2 | 94 | 97.9% |
| css-tables | 12 | 20 | 32 | 37.5% |
| css-variables | 97 | 10 | 107 | 90.7% |
| filter-effects | 101 | 5 | 106 | 95.3% |

## 2. css-contain の履歴メモ

- 2026-02-25 時点の集計（`tmp/wpt-css-contain-summary.json`）:
  - passed: `177`
  - failed: `126`
  - total: `303`
  - pass rate: `58.4%`
- 2026-02-28 の `current.log` では `183/303` まで改善（+6 pass）。

### 2.1 失敗クラスタ（2026-02-28 の `css-contain.current.fails.full.txt`）

大分類（先頭プレフィックス）:

- `contain-size-*`: 31
- `contain-paint-*`: 29
- `contain-layout-*`: 26
- `contain-style-*`: 15
- `contain-inline-size-*`: 7

目立つ細分類:

- `contain-style-ol-*`: 7
- `contain-size-select-*`: 7
- `contain-inline-size-*`: 7
- `contain-style-counters-*`: 5
- `contain-size-fieldset-*`: 4
- `contain-layout-ink-overflow-*`: 4
- `contain-layout-baseline-*`: 4

## 3. contain-size-replaced-003a/b/c 調査で残す知見

対象: `wpt/css/css-contain/contain-size-replaced-003a.html`（b/c も同系）。

有効だった修正観点:

1. `svg` を replaced element として扱う（`contain:size` で intrinsic を抑制）。
2. inline replaced 間の空白は保持するが、`<br>` 隣接空白は保持しない。
3. `picture/source` の inline 行箱寄与（高さ・baseline）を潰さない。

結果:

- `contain-size-replaced-003a/b/c` の対象再実行で `3 passed, 0 failed` を確認済み。

## 4. 再調査用コマンド

```bash
# モジュール別の最新比較
npx tsx scripts/wpt-runner.ts css-contain
npx tsx scripts/wpt-runner.ts css-overflow

# 問題ケースの局所確認
npx tsx scripts/wpt-runner.ts wpt/css/css-contain/contain-size-replaced-003a.html \
  wpt/css/css-contain/contain-size-replaced-003b.html \
  wpt/css/css-contain/contain-size-replaced-003c.html
```
