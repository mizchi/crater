# TODO

Last organized: 2026-05-15

このファイルは「次に着手できる未完了タスク」だけを置く。完了済みの作業ログ、過去の WPT 数値、実装履歴は git history / docs / issue に寄せる。

優先度は UX 影響軸で付ける:

- **Now (P0)** — 描画品質・互換性に直結し、 次リリースで体感差が出るもの
- **Next (P1)** — UX 改善だが scope 大、 release を跨ぐ可能性があるもの
- **Backlog (P2/P3)** — developer 体験 / 内部品質 / refactor。 一段先回し
- **External / Blocker** — 外部 repo や環境依存

## Now (P0)

- [ ] `filter-effects` の WPT 数値を再計測し、 残 failure を潰す
  - 旧 memo は `99 / 106 passed`、 現在の通過率を `npm run wpt -- wpt-tests/filter-effects/...` 系で再計測する
  - filter / composite は modern CSS で頻出、 SaaS UI で目立つ箇所
- [ ] テキスト折り返し精度を改善する
  - paint の単語単位 wrap と layout engine の精密 wrap の差を縮める
  - layout と同じスペース考慮の行幅累積を paint 側にも寄せる
  - real-world VRT diff% に最も効くと予想
- [ ] WPT 対象 module を順次拡張する (UX 頻出順)
  - `css-text` — 文字レイアウトの根幹
  - `css-backgrounds`
  - `css-color`
  - `css-transforms`
  - `css-pseudo`
  - `css-writing-modes`
  - `css-ruby`
  - 各 module を 1 PR ペースで追加して baseline を引き上げる

## Next (P1)

- [ ] Web Components 残件を埋める
  - selector/style: `:host` 複合 selector, `::slotted`, `:host-context`
  - DOM surface: `closed` shadow root, declarative shadow DOM, customized built-in, form-associated custom elements / `ElementInternals`
  - Playwright / CDP / jsbidi の query / action / inspection surface を shadow-aware に揃え切る
- [ ] Browser shell の control default action 残件を潰す
  - `select` popup UI
  - blur 時 `change` の細かい spec 差分
  - IME / selection / caret
- [ ] built-in real-world snapshot を 3-5 ページに増やし、 CI で比較できるようにする
- [ ] GitHub 実 URL VRT の `--mask-assets` 後も残る差分を最小 fixture 化する
  - sticky nav / card border / list marker
- [ ] CSS background gradient / repeating-gradient の VRT fixture を増やす
- [ ] SVG/logo の intrinsic size と paint path を実 URL fixture から分離する
- [ ] select / button など native form control の appearance 差分を、 mask 対象にするか paint 実装対象にするか決める
- [ ] Browser shell fixture を実ページ寄りに拡張する
  - article / dashboard / GitHub snapshot で DOM mutation + repaint を固定観測する

## Backlog (P2/P3)

### Refactor residuals (module boundary 大物は本リリースサイクルで完了済)

- [ ] `painter/svg` facade の直接 re-export 候補を棚卸しする
  - `interop_*.mbt` の adapter 群から direct alias 可能な primitive を分ける
  - public `.mbti` を維持したまま `mizchi/svg` の公開型へ寄せる
- [ ] `painter/paint/raster/paint_raster.mbt` / glyph 周辺の責務整理を閉じる
  - bitmap font fallback と glyph path render の境界を見直す
  - `mizchi/font` / `mizchi/svg` へ委譲できる処理は crater 側を adapter にする
- [ ] `webdriver/server` を `webdriver/webdriver` から切り出す
  - WebSocket transport / server state / session wiring
- [ ] `scripts/crater_bidi_adapter.py` から transport 以外の実装責務を削る
- [ ] WebDriver tooling の `.ts` runner (`scripts/wpt-webdriver-runner.ts` / `scripts/wpt-runner.ts` / `scripts/wpt-dom-runner.ts`) の責務を整理する

### VRT / Paint cleanup

- [ ] low diff ページの pseudo / icon / border-radius 残差は、 font 差分除外 VRT の budget tighten 後に個別対応する
- [ ] WPT VRT ベースラインを `just wpt-vrt-baseline-update` で更新する
- [ ] fixture ごとの threshold を artifact を見ながら段階的に tighten する

### Flaker / Test Management

- [ ] `vrt-harness` consumer payload を crater contract に接続する
  - external `vrt-artifact` fixture は `identity.key` なし / 独自 key ありの両方を用意する
  - 実 `vrt-harness` 側は crater の公開 API だけを使い、 baseline 管理と fixture UX は `vrt-harness` に残す
  - stable identity contract は `taskId + spec + filter + variant + optional shard`。 upstream issue: `mizchi/flaker#8`
- [ ] flaker core と crater domain metadata の境界を固定する
  - core: selection / quarantine / summary / diff
  - crater: VRT 固有メトリクス (`diffRatio`, `threshold`, `backend`, `viewport`, `snapshotKind`)
- [ ] VRT 判定は crater に残しつつ、 summary / identity / quarantine 連携だけ共通契約へ寄せる
- [ ] crater に残った汎用 test management code を削る
  - task selection / quarantine / batch summary の local wrapper が facade だけになっていないか棚卸しする
- [ ] flaker issue と crater / `vrt-harness` TODO の相互参照を整え、 drift を防ぐ

### CI / Task Runner

- [ ] `affected pkfire` job の実 CI 結果を見て required check 化するか決める
  - PR merge-base / push `github.event.before` fallback が GitHub Actions 上で期待どおりか確認する
  - `.cache/pkfire` と `~/.pkl/cache` の hit 率を summary / timing artifact で追えるようにする
- [ ] `pkf affected --profile=ci` の対象 gate を CI 実績に合わせて調整する
  - `check`, `test`, `test-taffy`, `test-wasm`, `test-native-smoke` の required / optional 境界を決める
  - schedule では full matrix、 PR / push では affected gate という分担で過不足がないか確認する

### WPT / Compatibility (補足)

- [ ] 実 `mizchi/image` が依存に入った時点で smoke test を追加する
  - JS export と Bytes 入力の shape を固定する
  - WPT image intrinsic provider の fallback と衝突しないことを確認する
- [ ] `taffy_compat` の既存 failure 群を baseline 管理対象にするか、 段階的に潰すか方針を決める
- [ ] `moon coverage analyze` の mixed-target workspace 前提の扱いを決める

### Workspace / Release

- [ ] `benchmarks` / `testing` / adapter module の release note template と changelog 粒度を決める
- [ ] root facade retirement 後の publish / release note を確認する
  - publish script / docs / downstream adapter が retired facade を参照しないことを release 前に再確認する
- [ ] `browser/native` と `wasm` を CI の required check にどこまで含めるか決める
- [ ] adapter module (`jsbidi`, `browser-native`, `js`, `wasm`) をどこまで公開サポート対象にするか決める

## External / Blocker

- [ ] `mizchi/kagura`: テキスト色が薄い SVG rasterizer alpha 問題を追う
- [ ] `mizchi/kagura`: glyph mirror の per-quad UV swap workaround を正しい層で解消する
- [ ] CI: llvmpipe セットアップを決める
  - `LIBGL_ALWAYS_SOFTWARE=1`
  - `mesa-vulkan-drivers`

## Maintenance Rules

- 完了したタスクは必要な要約だけ残し、 長い作業ログは追加しない。
- 古い計測値を書くときは再計測コマンドと日付を必ず添える。
- 実装計画は Red / Green / Refactor の次アクションが分かる粒度に保つ。
- 優先度は UX 影響軸 (Now=P0 → Next=P1 → Backlog) で並べ替え、 release を跨ぐ前にトリアージし直す。
