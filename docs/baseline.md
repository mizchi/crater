# Baseline Alignment Implementation

CSS Flexbox baseline alignment の実装状況をまとめる。

## 現在の実装状況

### 完了

1. **テキストノードの baseline 計算** (`compute/flex/flex.mbt`)
   - `compute_node_baseline` でテキストノードを検出
   - baseline = `font_size * 0.8` (typical ascent ratio)
   - 他の leaf ノード (画像など) は bottom of box

2. **Font プロパティの継承** (`renderer/renderer.mbt`, `css/computed/compute.mbt`)
   - `font_size` と `line_height` を Style 構造体に追加
   - CSS からの font-size, line-height 解析
   - 親要素からの継承 (ratio ベース)
   - `font-size` 変更時に `line_height` も比率を維持して再計算

3. **Font shorthand パース** (`css/computed/compute.mbt`)
   - `font: 100px/1 Ahem` 形式をサポート
   - font-size と line-height を抽出

4. **`<br>` 要素の処理** (`renderer/renderer.mbt`)
   - `collect_inline_content` でテキストと `<br>` を連結
   - `<br>` を改行文字 (`\n`) に変換
   - `create_text_measure` で明示的な改行を考慮した高さ計算

5. **論理プロパティ** (`css/computed/compute.mbt`, `renderer/renderer.mbt`)
   - `inline-size` → `width` (horizontal-tb mode)
   - `block-size` → `height` (horizontal-tb mode)
   - `min-inline-size`, `max-inline-size`, `min-block-size`, `max-block-size` 対応

### 動作するケース

- Row flex + `align-items: baseline` (基本ケース)
- 異なる font-size を持つ flex items の baseline 揃え
- `align-self: baseline` の個別指定
- `<br>` を含む複数行テキストの高さ計算

### テスト結果

```
Taffy: 1162/1332 (87%)
```

パスするテスト例:
- `align-self-006.html` - 異なる font-size での baseline
- `align-items-009.html` - font shorthand を使った baseline

## 未実装・課題

### 1. Column Flex + Wrap + Baseline

**問題**: `align_baseline_multiline_column` テストが失敗

```
actual: children[2].y = 20
expected: children[2].y = 0
```

Column flex + wrap + baseline alignment の組み合わせで、
2番目の line のアイテムの y 座標が正しく計算されていない。

原因調査中:
- baseline 計算が main axis に影響している可能性
- wrap 時の line 処理に問題がある可能性

### 2. `min-content` / `max-content` sizing

```css
inline-size: min-content;
width: max-content;
```

現在 `Dimension` 型は `Auto`、`Length`、`Percent` のみ。
intrinsic sizing keywords のサポートが必要。

### 3. Writing Mode

```css
writing-mode: vertical-rl;
writing-mode: vertical-lr;
```

Column baseline テストの多くが依存:
- `align-items-baseline-column-vert-*.html`
- `align-items-baseline-vert-*-column-*.html`

vertical 時の変更:
- main axis と cross axis が入れ替わる
- baseline の計算方向が変わる
- 論理プロパティの解決も変わる

## 実装優先度

1. **Column flex baseline 修正** - multiline column baseline の問題を修正
2. **intrinsic sizing** - `min-content`/`max-content` のサポート
3. **writing-mode** - 大規模な変更が必要、後回し

## コード構造

現在 baseline 関連コードは分散している:

```
compute/flex/flex.mbt
  - compute_node_baseline()     # baseline 値の計算
  - FlexLineItem.baseline       # アイテムの baseline 保持
  - baseline alignment 処理

renderer/renderer.mbt
  - font_size/line_height 継承
  - create_text_node()          # テキストノード生成
  - collect_inline_content()    # <br> 処理
  - create_text_measure()       # 改行を考慮したテキスト測定

css/computed/compute.mbt
  - parse_font_size()
  - parse_line_height()
  - parse_font_shorthand()
  - apply_property() に inline-size/block-size 追加

style/style.mbt
  - font_size: Double
  - line_height: Double
```

将来的に `compute/baseline/` モジュールに分離を検討:
- baseline 計算ロジック
- フォントメトリクス関連
- vertical alignment 計算

## 参考資料

- [CSS Flexbox Level 1 - Baseline Alignment](https://www.w3.org/TR/css-flexbox-1/#baseline-participation)
- [CSS Inline Layout - Baselines](https://www.w3.org/TR/css-inline-3/#baseline-synthesis)
- [CSS Writing Modes](https://www.w3.org/TR/css-writing-modes-4/)
