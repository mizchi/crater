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

### 動作するケース

- Row flex + `align-items: baseline` (基本ケース)
- 異なる font-size を持つ flex items の baseline 揃え
- `align-self: baseline` の個別指定

### テスト結果

```
Taffy: 1159/1329 (87%)
WPT:   157/234  (67%)
```

パスするテスト例:
- `align-self-006.html` - 異なる font-size での baseline
- `align-items-009.html` - font shorthand を使った baseline

## 未実装・課題

### 1. `<br>` 要素の処理

**問題**: `line1<br>line2` が2つの独立した text node として処理される

```html
<div>line1<br>line2</div>
```

現状:
- `#text "line1"` と `#text "line2"` が別々に測定される
- 各テキストが独自の高さを持つ
- 全体の高さが正しく計算されない

必要な対応:
- `<br>` を line break として認識
- 連続するテキストを1つのテキストランとして測定
- または block レイアウトで `<br>` を改行として処理

### 2. 論理プロパティ

```css
inline-size: min-content;
block-size: 100px;
```

- `inline-size` → `width` (horizontal) / `height` (vertical)
- `block-size` → `height` (horizontal) / `width` (vertical)
- `writing-mode` に依存

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

### 4. Column Flex Baseline

Row flex と異なる baseline 計算が必要:
- 横書きでの column: 最初の子の baseline を使用
- 縦書きでの column: 異なる軸での計算

## 実装優先度

1. **`<br>` 要素** - 多くのテストで使用、比較的独立した機能
2. **論理プロパティ** - `inline-size`/`block-size` の解析追加
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

css/computed/compute.mbt
  - parse_font_size()
  - parse_line_height()
  - parse_font_shorthand()

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
