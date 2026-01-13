# TODO

## Bugs


### TUI テーブルレンダリングで文字が1文字切れる

**症状**
- テーブルセル内のテキストが常に最後の1文字切れて表示される
- ASCII文字・CJK文字両方で発生
- 例: "コードブロック" → "コードブロッ", "mbt check" → "mbt chec"

**調査結果**
- ストリーミングパーサー・通常パーサー両方で発生 → パーサーの問題ではない
- `write_text` のループ終了条件は正しそう
- `px_to_col` の四捨五入変更では解決せず

**調査が必要な箇所**
1. レイアウトエンジン (`renderer/renderer.mbt`): テキスト幅計算 `create_text_measure`
2. TUI バッファ (`browser/src/tui/buffer.mbt`): `write_text` の文字列イテレーション
3. ピクセル→カラム変換: `node.width` の値が正しいか確認

**再現方法**
テーブルを含むHTMLをTUIモードでレンダリング

## Completed ✅

- [x] `position: static/relative/absolute/fixed`
- [x] `overflow-x`, `overflow-y` in Layout struct
- [x] Inline layout (display: inline, inline-block)
- [x] Inline Formatting Context (IFC)
- [x] CSS Variables (basic `--var` and `var()` support)
- [x] `visibility: hidden` with child override capability
- [x] CSS diagnostics system
- [x] `aria-owns` support in accessibility tree
- [x] Grid auto-placement dense の詰め戻し
- [x] grid end line の明示指定に合わせた bounds 拡張
- [x] repeat(auto-fit, ...) の collapse 対応
- [x] grid-child-percent-basis-resize-1 の %高さ/スクロールの解決
- [x] grid-flex-spanning-items-001 の min-content 幅解決

## High Priority (Remaining Issues)

### Baseline Alignment (~25 WPT tests)
- [ ] Implement baseline calculation for flex items
- [ ] Handle baseline with padding/margin
- [ ] Multiline baseline in flex and grid

### Writing Modes (~20 WPT tests)
- [ ] vertical-lr, vertical-rl support
- [ ] Direction-aware layout calculations

### Intrinsic Sizing (~20 tests)
- [ ] Fix min-content/max-content for nested containers
- [ ] Implement proper measure functions for leaf nodes

### Margin Collapsing Edge Cases
- [ ] Negative margin collapsing
- [ ] Margin collapse blocked by flex/grid containers

## Medium Priority

### Span Items in Grid (~15 tests)
- [ ] Fix intrinsic sizing for items spanning multiple tracks
- [ ] Correct gap calculation for span items

### Percent in Nested Layouts (~15 tests)
- [ ] Handle percent resolution in nested grids with auto-sized parents
- [ ] Fix cyclic percentage dependencies

### Aspect Ratio (~10 tests)
- [ ] Fix interaction with max-width/max-height constraints
- [ ] Correct fill mode with constraints

## Low Priority (Future Features)

- [ ] Table layout (thead, tbody, caption)
- [ ] z-index stacking context
- [ ] Float layout (intentionally deferred)
- [ ] ShadowRoot support

## Documentation

- [ ] Add more usage examples to README
- [ ] Document API for intrinsic content sizing
