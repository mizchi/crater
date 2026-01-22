# Arc90 Content Extraction

Readability/Trafilatura にインスパイアされたコンテンツ抽出アルゴリズム。
Article Extraction Benchmark (AEB) でテスト。

## 現在のベンチマーク結果

```
F1: 81.82%
Precision: 73.33%
Recall: 98.13%
```

比較対象:
- Trafilatura: F1=93.7%, Precision=97.8%, Recall=92.0%
- Readability: F1=94.7%, Precision=91.4%, Recall=98.2%

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

4. **コメントセクション抽出**
   - コメント領域の検出と分離
   - ExtractionResult に comment_section フィールド追加

5. **ナビゲーション構造抽出**
   - ナビゲーション要素の構造化抽出
   - サイトマップ的な情報の生成

## ベンチマークの実行方法

```bash
# AEB ベンチマーク実行
npx tsx scripts/aeb-runner.ts

# WASM ビルド
just wasm
```

## 参考資料

- [Mozilla Readability](https://github.com/mozilla/readability)
- [Trafilatura](https://github.com/adbar/trafilatura)
- [Article Extraction Benchmark](https://github.com/scrapinghub/article-extraction-benchmark)
