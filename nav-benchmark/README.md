# Navigation Extraction Benchmark

nav 検出の独自評価データセット。

## 評価対象

| カテゴリ | 説明 | 例 |
|---------|------|-----|
| primary_nav | サイトのメインナビゲーション | ヘッダーメニュー |
| secondary_nav | サブナビゲーション | ドロップダウン、サブメニュー |
| footer_nav | フッターのリンク群 | フッターメニュー |
| sidebar_nav | サイドバーのナビゲーション | カテゴリ一覧、アーカイブ |
| breadcrumb | パンくずリスト | Home > Category > Article |
| pagination | ページネーション | < 1 2 3 ... 10 > |
| skip_link | スキップリンク | Skip to content |
| social_nav | SNS リンク群 | Twitter, Facebook アイコン群 |

## 評価対象外

- 記事内リンク（コンテンツの一部）
- 関連記事（コンテンツ推薦）
- 著者情報（記事メタ）
- 単一シェアボタン（アクション UI）
- 広告

## ラベルフォーマット

```json
{
  "hash": "abc123...",
  "url": "https://example.com/article",
  "viewport": { "width": 1280, "height": 800 },
  "nav_regions": [
    {
      "id": "nav-1",
      "type": "primary_nav",
      "selector": "nav.main-nav",
      "rect": { "x": 0, "y": 0, "width": 1280, "height": 60 },
      "confidence": "certain"
    },
    {
      "id": "nav-2",
      "type": "footer_nav",
      "selector": "footer nav",
      "rect": { "x": 0, "y": 2400, "width": 1280, "height": 120 },
      "confidence": "certain"
    }
  ],
  "notes": "Optional notes about edge cases"
}
```

## 評価指標

### 領域ベース (IoU)

- **IoU (Intersection over Union)**: 予測領域と正解領域の重なり度合い
- **IoU >= 0.5**: マッチとみなす

### 集計指標

- **Precision**: 正しく検出した nav 領域 / 検出した全領域
- **Recall**: 正しく検出した nav 領域 / 正解の全領域
- **F1**: Precision と Recall の調和平均

## 現在のベンチマーク結果

```
Nav Benchmark (30 samples, IoU=0.5, 2026-01-23)

v1 (Original):  P=24.19%  R=60.54%  F1=34.57%  FP=630 FN=131
v2 (Strict):    P=52.45%  R=32.23%  F1=39.93%  FP=97  FN=225
v3 (Balanced):  P=54.36%  R=39.85%  F1=45.99%  FP=89  FN=160  ← Best (after label cleanup)
```

### v3 の改善点

1. 除外パターンの強化 (social, share, related, ad 等)
2. 構造ベース検出の閾値引き上げ (linkCount >= 4, linkRatio >= 0.35)
3. セマンティック nav 要素は除外パターンをスキップ

### ラベルクリーンアップ

ドラフトラベルから以下を除去:
- 関連記事・人気記事 (コンテンツ推薦)
- ソーシャルシェアボタン
- 記事内のセクションヘッダー
- 重複したサブメニュー項目
- 非 nav コンテンツ (著者情報、コメント欄等)

### 既知の制限

- 非セマンティック HTML サイト (`<nav>` や ARIA role 未使用) は検出困難
- 4 サンプルが F1=0% (セマンティックマークアップなし)

## ディレクトリ構造

```
nav-benchmark/
├── README.md
├── labels/
│   ├── {hash}.json      # 各ページのラベル
│   └── ...
├── screenshots/
│   └── {hash}.png       # 参照用スクリーンショット
└── scripts/
    ├── labeler.ts       # ラベル付けツール
    └── evaluate.ts      # 評価スクリプト
```
