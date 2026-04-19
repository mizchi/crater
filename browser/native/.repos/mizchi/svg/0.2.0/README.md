# mizchi/svg

SVG パーサー/レンダラーの [MoonBit](https://www.moonbitlang.com/) 実装。外部依存なし。

## Features

- SVG マークアップのパース (`parse_svg()`)
- CPU ソフトウェアラスタライズ
- シーングラフ操作 (ノードの追加/削除/更新、z-ordering)
- 基本図形: Rect, Circle, Ellipse, Line, Polyline, Polygon, Path, Text
- スタイリング: グラデーション、フィルタ、マスク、クリッピング、ブレンドモード
- 2D アフィン変換 (translate, scale, rotate, skew)
- SVG パスコマンド (`PathCommand` enum, SVG 1.1 仕様準拠)
- テキストレンダリング (ビットマップフォント + `text_to_paths` コールバック)
- 画像処理フィルタ (blur, brightness, contrast, grayscale, etc.)
- ヒットテスト・衝突判定
- スプライトアニメーション、パーティクルシステム

## Usage

```moonbit
// SVG 文字列からピクセル画像を生成
let image = @svg.render_svg_to_image(svg_string, 800, 600)

// パスコマンドの直接操作
let cmds = @svg.parse_path("M10 10 L90 90 Z")
```

## License

Apache-2.0
