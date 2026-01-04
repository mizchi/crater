去年は mizchi 

フロントエンドの経験+CLS/LCPと向き合ううちに、ブラウザのレンダリングの実装が大体

claude code の ink の使い方に感銘を受けたので、

- Layout Engine
- Yoga Engineの Grid 対応版が欲しい
- 12/31 まで ClaudeCode のリミットが二倍のボーナス期間だったので、大きめのものを作れないか

## ゴールの設定

- yoga の代替として使えること
- ヘッドレスブラウザに使えること
- モジュラーにしておいて、自分の
- フォントのレンダリングはしない
- Pure Moonbit で書くこと

## tuffy のテストを移植する

tuffy の text_fixtures をそのまま使うことにしました。

https://github.com/DioxusLabs/taffy/tree/main/test_fixtures

| Module | Passed | Total | Rate |
|--------|--------|-------|------|
| Flexbox | 547 | 607 | 90.1% |
| Block | 204 | 224 | 91.1% |
| Grid | 162 | 331 | 48.9% |

Grid は複雑な仕様が多くて、

## WPT

WPT からレイアウト関連のテストをターゲットにします。

- css/contain
- css/flexbox
- css/grid
- css/overflow
- css/position


| Module | Passed | Total | Rate |
|--------|--------|-------|------|
| css-flexbox | 148 | 234 | 63.2% |
| css-grid | 17 | 30 | 56.7% |
| css-sizing | 23 | 50 | 46.0% |
| css-overflow | 8 | 20 | 40.0% |
| css-position | 11 | 30 | 36.7% |

現状、こんな感じです。




## 手順

## 学び/苦労した点

WPT



## よかった点

## 感想

Double Dirty Bit 

----

最初は taffy の移植から始めました。

https://github.com/DioxusLabs/taffy

blitz

taffy 

CSS flexbox

## Layout Engine

## Intrinsic Sizing　がとにかく難しい

知っての通り、CSSは子要素の大きさで親要素の高さが決まったりするわけですが、その計算順がとにかく難しい。

素朴な flex: 1, flex:2 みたいなのは簡単だとして、
要素が溢れて折り返すと、その横幅が再計算されるわけで、

flex の小要素で

## なんでもいいから表示したい

フォントのレンダリングは大変です。
スケーリングしないといけません。

## CSS Style Engine

https://github.com/servo/stylo

