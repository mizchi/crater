# Baseline Alignment Implementation

CSS Flexbox baseline alignment の実装状況をまとめる。

## 現在の実装状況

### 完了

1. **テキストノードの baseline 計算** (`compute/baseline/baseline.mbt`)
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

6. **Column Flex Baseline** (`compute/flex/flex.mbt`)
   - Column flex + align-items: baseline を flex-start として処理
   - CSS 仕様に準拠（column flex では baseline alignment は意味がない）

### テスト結果

```
Taffy: 1164/1332 (87%)
```

パスするテスト例:
- `align-self-006.html` - 異なる font-size での baseline
- `align-items-009.html` - font shorthand を使った baseline

## 未実装・課題

### 1. `min-content` / `max-content` sizing

```css
inline-size: min-content;
width: max-content;
```

現在 `Dimension` 型は `Auto`、`Length`、`Percent` のみ。
intrinsic sizing keywords のサポートが必要。

### 2. Writing Mode

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

1. **intrinsic sizing** - `min-content`/`max-content` のサポート
2. **writing-mode** - 大規模な変更が必要、後回し

## コード構造

```
compute/baseline/baseline.mbt
  - compute_node_baseline()     # baseline 値の計算（テキスト・コンテナ再帰処理）

compute/flex/flex.mbt
  - FlexLineItem.baseline       # アイテムの baseline 保持
  - baseline alignment 処理
  - @baseline.compute_node_baseline() を呼び出し

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

将来的な拡張:
- フォントメトリクス関連を `compute/baseline/` に集約
- vertical alignment 計算の追加

## 参考資料

- [CSS Flexbox Level 1 - Baseline Alignment](https://www.w3.org/TR/css-flexbox-1/#baseline-participation)
- [CSS Inline Layout - Baselines](https://www.w3.org/TR/css-inline-3/#baseline-synthesis)
- [CSS Writing Modes](https://www.w3.org/TR/css-writing-modes-4/)
