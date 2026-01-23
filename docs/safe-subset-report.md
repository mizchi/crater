# CSS Safe Subset Report

Craterで安全に使用できるCSSプロパティのリスト。WPT（Web Platform Tests）の結果に基づいて分類。

## 分析概要

- テスト数: 1,378件
- 分析日: 2026-01-23
- 閾値: 70%以上の通過率を「安全」と判定

## Tier 1: Safe (>= 80% 通過率)

これらのプロパティは高い信頼性でブラウザと同じ結果を返します。

### align-content (96.2%)

Flexコンテナの複数行の配置。

```css
/* 安全な値 */
align-content: flex-start;
align-content: flex-end;
align-content: center;
align-content: space-between;
align-content: space-around;
align-content: space-evenly;
align-content: stretch;
```

### flex-shrink (93.8%)

Flexアイテムの縮小係数。

```css
flex-shrink: 0;
flex-shrink: 1;
flex-shrink: 2;
```

### z-index (85.7%)

スタッキングコンテキストでの順序。

```css
z-index: auto;
z-index: 1;
z-index: 100;
```

### justify-content (82.6%)

Flexコンテナの主軸配置。

```css
/* 安全な値 */
justify-content: flex-start;
justify-content: flex-end;
justify-content: center;
justify-content: space-between;
justify-content: space-around;
```

### margin-top (82.5%)

上マージン。

```css
margin-top: 10px;
margin-top: 1em;
margin-top: 5%;
margin-top: auto;
```

### overflow-y (80.0%)

縦方向のオーバーフロー制御。

```css
overflow-y: visible;
overflow-y: hidden;
overflow-y: scroll;
overflow-y: auto;
overflow-y: clip;
```

### order, row-gap, column-gap (100%)

Flexアイテムの順序とギャップ。

```css
order: -1;
order: 0;
order: 1;
row-gap: 10px;
column-gap: 20px;
gap: 10px 20px;
```

## Tier 2: Caution (60-80% 通過率)

基本的な使用は安全だが、エッジケースでブラウザと異なる可能性あり。

| プロパティ | 通過率 | 注意点 |
|-----------|--------|--------|
| overflow-x | 77.8% | clip値に注意 |
| opacity | 75.0% | 基本的に安全 |
| align-self | 72.4% | baseline以外は安全 |
| flex-basis | 71.9% | content値に注意 |
| flex-wrap | 67.3% | wrap-reverseに注意 |
| background-color | 66.3% | 基本的に安全 |
| flex (shorthand) | 60.8% | 個別プロパティ推奨 |
| position | 60.3% | absolute/fixedに注意 |

## Grid Layout (条件付き安全)

**Taffy互換: 100%** | **WPT: 61.5%**

Grid は**単独使用では安全**ですが、特定の組み合わせで問題があります。

### ✅ 安全な Grid パターン

```css
/* 基本グリッド */
display: grid;
grid-template-columns: 100px 200px 100px;
grid-template-rows: auto;
gap: 10px;

/* fr 単位 */
grid-template-columns: 1fr 2fr 1fr;

/* repeat */
grid-template-columns: repeat(3, 1fr);

/* アイテム配置 */
grid-column: 1 / 3;
grid-row: 2;
```

### ❌ 避けるべき Grid パターン

| パターン | 問題 |
|---------|------|
| `flexbox` 内の `grid` | サイズ計算が不正確 |
| `table` が grid item | table幅計算の問題 |
| `%` 高さ（親が auto） | 解決できない |
| `auto-fill` / `auto-fit` | トラック数計算に問題 |
| `minmax(auto, ...)` | intrinsic sizing問題 |

## Tier 3: Experimental (< 60% 通過率)

ブラウザと異なる結果が出やすい。プロトタイプ段階での使用は非推奨。

| プロパティ | 通過率 | 理由 |
|-----------|--------|------|
| height | 57.6% | intrinsic sizingの問題 |
| width | 56.9% | intrinsic sizingの問題 |
| min-height | 57.3% | intrinsic sizingの問題 |
| min-width | 57.1% | intrinsic sizingの問題 |
| display | 46.8% | inline/table系の問題 |
| flex-direction | 49.7% | column系に問題あり |
| align-items | 45.0% | baseline配置の問題 |

## プロトタイピング推奨構成

### 安全なFlexboxレイアウト

```html
<div style="display: flex; flex-wrap: wrap; gap: 10px; justify-content: center;">
  <div style="flex-shrink: 0; order: 1;">Item 1</div>
  <div style="flex-shrink: 1; order: 2;">Item 2</div>
</div>
```

### 安全なサイズ指定

```css
/* 推奨: 明示的なサイズ */
.container {
  width: 300px;      /* 固定値は安全 */
  height: 200px;
}

/* 注意: autoやintrinsic */
.item {
  width: auto;       /* 計算結果が異なる場合あり */
  height: min-content; /* 非推奨 */
}
```

### 避けるべきパターン

```css
/* 非推奨: baseline配置 */
align-items: baseline;

/* 非推奨: 複雑なGrid */
grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));

/* 非推奨: Table display */
display: table;
display: table-cell;
```

## まとめ

| Tier | 件数 | 使用推奨度 |
|------|------|-----------|
| Safe (>= 80%) | 9 | ✅ 積極的に使用可 |
| Caution (60-80%) | 9 | ⚠️ 基本機能は安全 |
| Experimental (< 60%) | 15+ | ❌ 避けるか慎重に |

**プロトタイピングのコツ:**

1. `display: flex` を基本とする
2. サイズは固定値 (`px`) で指定
3. `align-items: baseline` は避ける
4. Grid の複雑な機能は後回しに
5. Table layout は使用しない
