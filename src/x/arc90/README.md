# Arc90 Content Extraction

Readability/Trafilatura にインスパイアされたコンテンツ抽出アルゴリズム。
Article Extraction Benchmark (AEB) でテスト。

## 現在のベンチマーク結果

```
AEB (without layout, 2026-01-22)
F1: 90.09%
Precision: 88.08%
Recall: 95.00%

AEB (with layout, 2026-01-22)
F1: 90.31%
Precision: 88.49%
Recall: 95.00%
```

比較（AEB, 参考値含む）:

| Method | Precision | Recall | F1 | Notes |
|---|---:|---:|---:|---|
| Crater Arc90 (without layout) | 88.08% | 95.00% | 90.09% | 2026-01-22, 181 cases |
| Crater Arc90 (with layout) | 88.49% | 95.00% | 90.31% | 2026-01-22, 181 cases |
| Readability | 91.4% | 98.2% | 94.7% | 参考値 (過去計測) |
| Trafilatura | 97.8% | 92.0% | 93.7% | 参考値 (過去計測) |

## ナビゲーション構造抽出の評価 (AEB, 弱ラベル)

AOM から抽出した nav 候補を、Puppeteer で取得したレイアウト矩形の
弱ラベル (nav/ad パターン + link density) で評価。
strict は記事メタ (share/author/byline 等) を除外した評価。

```
Nav eval (AEB 181 cases, 2026-01-22)
Base:               loose F1=60.31  strict F1=59.80  meta R=19.35  adOverlap=1106
Refined:            loose F1=70.93  strict F1=73.28  meta R= 6.36  adOverlap=2
Refined+meta:       loose F1=73.77  strict F1=73.85  meta R=13.88  adOverlap=2
Refined+hier:       loose F1=73.88  strict F1=76.30  meta R= 6.36  adOverlap=2
Refined+hier+meta:  loose F1=77.58  strict F1=76.43  meta R=19.16  adOverlap=2
```

結論:
- **Refined+hier+meta** が strict F1 で最大 (76.43%)
- adOverlap がほぼ 0 になり、広告誤検出が大幅に減少

## 実装済み機能

### スコアリング要素

1. **Text Density**: テキスト長 / バウンディングボックス面積
2. **Visual Score**: サイズと比率に基づくスコア
3. **Position Penalty**: ヘッダー/フッター/サイドバー位置にペナルティ
4. **Role Bonus**: Article=2.0, Main=1.8, Region=1.2
5. **Tag Multiplier**: article/main=1.5, section=1.1, header/footer/nav/aside=0.1
6. **Selector Score**: class/id のパターンマッチング
   - Positive: article, content, post, text, body, entry, story, main, blog, news
   - Negative: sidebar, widget, ad, sponsor, comment, footer, header, nav, menu
7. **Link Density Score**: リンクテキスト比率が高いとペナルティ
8. **Paragraph Bonus**: p/pre/blockquote 要素が多いほどボーナス
9. **Punctuation Bonus**: 句読点密度が文章らしければボーナス
10. **Navigation Detection**:
    - nav/header/footer/aside などのコンテナ優先
    - list + link ratio / link density で nav を補強
    - nav 配下は content block から除外

### コンテンツ選択ロジック

1. `find_article_or_main()` で article/main 要素を探す
2. content_blocks をスコア順にソート
3. article/main vs top content_block を比較:
   - content_block が 20 倍以上大きい場合は content_block を優先
   - それ以外は article/main を優先

## 既知の問題

### 1. AOM パース問題 (d90bda7ed14df195)
- **症状**: F1=0%、AOM ツリーが空になる
- **原因**: HTML に 75 個の未閉じタグがあり、パーサーが処理できない
- **対策**: HTML パーサーの堅牢性向上が必要

### 2. 過剰抽出 (ac3c035520461017 など)
- **症状**: Precision が低い (8.7%)、Recall=100%
- **原因**: 短い記事に対して大きな親コンテナが選ばれる
- **例**: 419 文字の記事に対して 16643 文字を抽出 (39.72 倍)
- **対策**: より細かい粒度でのスコアリングが必要

### 3. ナビ評価のラベル揺れ
- **症状**: h2 単体などが nav として弱ラベル化されるケースがある
- **原因**: レイアウト側の弱ラベルが粗い
- **対策**: nav と meta を分離した二段評価を導入する

## 次のステップ (F1 > 90% 達成に向けて)

### 高優先度

1. **Readability スタイルの段落レベルスコアリング**
   - 段落 (p, pre, blockquote) に直接スコアを付ける
   - スコアを親要素に伝播（減衰あり）
   - 最高スコアの要素をメインコンテンツとして選択

2. **過剰抽出の改善**
   - 「read more」「next post」「previous post」などのナビゲーションパターン検出
   - 短いコンテンツに対しては小さなコンテナを優先

### 中優先度

3. **AOM パーサーの堅牢性向上**
   - 未閉じタグの自動修復
   - エラー耐性の向上

4. **ナビゲーション/記事メタの分離**
   - share/author/byline を nav と分離して抽出
   - nav + meta の二段評価を標準化

5. **ナビゲーション構造抽出の精度改善**
   - list 階層の優先度調整
   - selector 粒度の揺れ (h2 単体など) に対する補正

## ベンチマークの実行方法

```bash
# AEB ベンチマーク実行
npx tsx scripts/aeb-runner.ts

# WASM ビルド
just wasm

# ナビゲーション評価
npx tsx scripts/aeb-nav-eval.ts
```

## レイアウト矩形のダンプ

```bash
# AEB HTML を Puppeteer でレンダリングし、矩形情報を JSON へ出力
npx tsx scripts/aeb-layout-dump.ts --limit 10
npx tsx scripts/aeb-layout-dump.ts <hash>
npx tsx scripts/aeb-layout-dump.ts <hash> --no-css --timeout 15000
npx tsx scripts/aeb-layout-dump.ts <hash> --allow-assets --timeout 60000
```

出力先: `render-results/aeb-layout/<hash>.json`

## 参考資料

- [Mozilla Readability](https://github.com/mozilla/readability)
- [Trafilatura](https://github.com/adbar/trafilatura)
- [Article Extraction Benchmark](https://github.com/scrapinghub/article-extraction-benchmark)
