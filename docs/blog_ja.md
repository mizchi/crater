WIP

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

