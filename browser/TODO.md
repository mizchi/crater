# crater/browser TODO

## 画像表示 (Issue #16)

- [ ] JPEG/GIF の kitty graphics 表示 (ghostty で f=100 が効かない問題の調査)
  - `f=32` (RGBA) パスで JS 側デコード → 生ピクセル送信を検討
- [ ] sixel フォールバック (kitty 非対応ターミナル)
- [ ] 画像キャッシュのメモリ管理 (大量画像ページ対策)
- [ ] スクロール時の画像再配置最適化

## CSS レンダリング精度

- [ ] `inline-flex` レイアウトで hidden input (`position:absolute` + `clip:rect`) がある場合に後続要素が消える
- [ ] サブピクセルレイアウト (rem/padding の端数処理で Chrome と 1-4px のずれ)
- [ ] `box-shadow` 描画
- [ ] `text-overflow: ellipsis`
- [ ] `::before` / `::after` 疑似要素のコンテンツ幅計算の改善

## フォント

- [ ] font-family CSS プロパティによるフォント切替 (現状は単一フォント)
- [ ] bold フォントのロード (Regular のみ → Bold ウェイト対応)
- [ ] CJK フォントフォールバック (日本語テキスト)
- [ ] font metrics のサブピクセル精度 (Chrome との advance width 差を縮小)

## Luna コンポーネント VRT

- [ ] Luna SSR → HTML fixture 自動生成 (luna.mbt 側で `render_to_string` → fixture 出力)
- [ ] fixture 追加: tabs, accordion, meter, disclosure, radio, toolbar
- [ ] diff 5% 以下をパス基準として CI に組み込み
- [ ] mizchi/pixelmatch (MoonBit) を crater CLI に統合 (`--artifact diff` モード)

## TUI ブラウザ

- [ ] `--headless=full` で複数 viewport をまたいだ全ページ出力
- [ ] CDP bridge の hit testing と runtime fidelity 強化
- [ ] selection mode とマウス操作の UX 改善

## 検証コマンド

```bash
pnpm build                     # moon build + rolldown minify
pnpm test                      # vitest (CDP tests)
pnpm test:luna-vrt             # Luna component VRT (crater vs Chrome)
pnpm test:luna-vrt:update      # Update Chrome baselines
moon test                      # MoonBit unit tests
moon check                     # Type check
```
