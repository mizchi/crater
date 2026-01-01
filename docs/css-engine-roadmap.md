# CSS Style Engine Roadmap

## Overview

crater向けのCSSスタイルエンジンをMoonBitでフル実装する。
Servo/FirefoxのStyloを参考に、レイアウト計算に必要な機能に特化。

## Architecture

```
HTML + CSS Text
     │
     ▼
┌─────────────┐
│ css/token   │  CSS Text → Token列
└─────────────┘
     │
     ▼
┌─────────────┐
│ css/parser  │  Token列 → Stylesheet, Selectors, Properties
└─────────────┘
     │
     ▼
┌─────────────┐
│css/selector │  Node × Selector → Match判定 + Specificity
└─────────────┘
     │
     ▼
┌─────────────┐
│ css/cascade │  Declarations → 優先順位解決 → Cascaded Values
└─────────────┘
     │
     ▼
┌─────────────┐
│css/computed │  Cascaded → Specified → Computed Values
└─────────────┘
     │
     ▼
┌─────────────┐
│   style/    │  Computed → @style.Style (Taffy互換)
└─────────────┘
     │
     ▼
┌─────────────┐
│  compute/   │  Style + Node → Layout
└─────────────┘
```

## Module Structure

```
css/
├── token/              # CSS Tokenizer
│   └── token.mbt       # Token定義, tokenize()
│
├── parser/             # CSS Parser
│   ├── selector.mbt    # Selector Parser
│   ├── property.mbt    # Property Value Parser
│   └── stylesheet.mbt  # Stylesheet Parser
│
├── selector/           # Selector Matching
│   ├── matcher.mbt     # マッチングロジック
│   └── specificity.mbt # 詳細度計算
│
├── cascade/            # Cascading
│   ├── cascade.mbt     # カスケードアルゴリズム
│   └── origin.mbt      # Origin (author/user/ua)
│
└── computed/           # Computed Values
    ├── resolve.mbt     # 値の解決
    ├── inherit.mbt     # 継承処理
    └── initial.mbt     # 初期値定義
```

## Implementation Phases

### Phase 1: CSS Tokenizer (css/token/)

**Goal**: CSS Syntax Level 3 準拠のトークナイザー

**Token Types** (CSS Syntax Level 3):
- `<ident-token>` - 識別子
- `<function-token>` - 関数 (ident + `(`)
- `<at-keyword-token>` - @ルール (@ident)
- `<hash-token>` - ハッシュ (#id, #unrestricted)
- `<string-token>` - 文字列
- `<number-token>` - 数値
- `<percentage-token>` - パーセント (num%)
- `<dimension-token>` - 次元 (num + unit)
- `<whitespace-token>` - 空白
- `<delim-token>` - 区切り文字
- `<colon-token>`, `<semicolon-token>`, `<comma-token>`
- `<[-token>`, `<]-token>`, `<(-token>`, `<)-token>`, `<{-token>`, `<}-token>`
- `<EOF-token>`

**Deliverable**: `tokenize(input: String) -> Array[Token]`

**Estimated**: ~500 lines

### Phase 2: Property Parser (css/parser/)

**Goal**: レイアウト関連プロパティの値をパース

**Target Properties**:
- Box Model: `display`, `position`, `box-sizing`
- Sizing: `width`, `height`, `min-width`, `min-height`, `max-width`, `max-height`
- Spacing: `margin`, `padding`, `border-width`
- Flexbox: `flex-direction`, `flex-wrap`, `flex-grow`, `flex-shrink`, `flex-basis`
- Grid: `grid-template-columns`, `grid-template-rows`, `grid-auto-flow`
- Alignment: `align-items`, `align-content`, `align-self`, `justify-items`, `justify-content`, `justify-self`
- Gap: `gap`, `row-gap`, `column-gap`
- Inset: `top`, `right`, `bottom`, `left`, `inset`

**Deliverable**: `parse_value(tokens: Array[Token], property: String) -> PropertyValue`

**Estimated**: ~1000 lines

### Phase 3: Selector Parser & Matcher (css/selector/)

**Goal**: 基本セレクタの解析とマッチング

**Supported Selectors**:
- Type: `div`, `span`
- Class: `.foo`
- ID: `#bar`
- Universal: `*`
- Attribute: `[attr]`, `[attr=value]`, `[attr~=value]`, `[attr|=value]`, `[attr^=value]`, `[attr$=value]`, `[attr*=value]`
- Combinators: ` ` (descendant), `>` (child), `+` (adjacent sibling), `~` (general sibling)
- Pseudo-classes: `:first-child`, `:last-child`, `:nth-child()`, `:not()`

**Deliverables**:
- `parse_selector(tokens: Array[Token]) -> Selector`
- `matches(node: Node, selector: Selector) -> Bool`
- `specificity(selector: Selector) -> (Int, Int, Int)`

**Estimated**: ~800 lines

### Phase 4: Cascade (css/cascade/)

**Goal**: 複数宣言から適用する値を決定

**Cascade Order** (high to low):
1. Transition declarations
2. `!important` user-agent
3. `!important` user
4. `!important` author
5. Animation declarations
6. Normal author
7. Normal user
8. Normal user-agent

**Resolution**:
1. Origin and Importance
2. Specificity
3. Source Order

**Deliverable**: `cascade(declarations: Array[Declaration]) -> CascadedValues`

**Estimated**: ~300 lines

### Phase 5: Computed Values (css/computed/)

**Goal**: Cascaded値を計算値に変換

**Processing**:
1. **Inheritance**: 継承プロパティの親からの値継承
2. **Initial Values**: 未指定プロパティへの初期値適用
3. **Relative Resolution**: `em`, `%`, `rem` → `px` への変換
4. **Keyword Resolution**: `auto`, `inherit`, `initial`, `unset`, `revert` の解決

**Inherited Properties** (layout-related):
- `direction`
- `writing-mode`

**Non-inherited Properties** (layout-related):
- `display`, `position`
- All sizing properties
- All spacing properties
- All flex/grid properties

**Deliverable**: `compute(cascaded: CascadedValues, parent: ComputedStyle?, context: Context) -> ComputedStyle`

**Estimated**: ~1500 lines

### Phase 6: Integration

**Tasks**:
1. `ComputedStyle` → `@style.Style` 変換
2. WPT テスト統合
3. E2E テスト

## Test Strategy

- WPT (Web Platform Tests) の css-cascade テストを変換して使用
- 各フェーズごとにユニットテスト
- E2Eテストでレイアウト結果を検証

## References

- [CSS Cascading and Inheritance Level 4](https://www.w3.org/TR/css-cascade-4/)
- [CSS Syntax Level 3](https://www.w3.org/TR/css-syntax-3/)
- [Selectors Level 4](https://www.w3.org/TR/selectors-4/)
- [Web Platform Tests - css-cascade](https://github.com/web-platform-tests/wpt/tree/master/css/css-cascade)
- [Stylo (Servo)](https://github.com/nicholashibberd/nicholashibberd.github.io/blob/master/servo-style/readme.md)
- [Blitz (DioxusLabs)](https://github.com/DioxusLabs/blitz)
