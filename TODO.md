# TODO

Last organized: 2026-05-14

このファイルは「次に着手できる未完了タスク」だけを置く。完了済みの作業ログ、過去の WPT 数値、実装履歴は git history / docs / issue に寄せる。

## Now

- [ ] module boundary reset を段階的に進める
  - Red: `scripts/moon-module-boundary-*` に公開 facade / contract / implementation の逆流検出を追加する
  - Green: `webdriver/contract` へ純粋な API 型・legacy WebDriver 型・JSON wire helper・HTTP route parser、`webdriver/rpc` へ JSON-RPC helper・method parser、`webdriver/runtime` へ QuickJS runtime FFI/state と navigation encoding helper、`webdriver/protocol` へ pure BiDi JSON param / validation helper、`mizchi/crater-network` へ network runtime state / synthetic network event 型 / synthetic fetch 型 / byte/query JS helper を切り出し、`webdriver/network` は互換 adapter、`webdriver/webdriver` は implementation package にする
  - Refactor: `webdriver/webdriver` から以下を順に切り出す
    - `webdriver/rpc`: JSON-RPC ID / error / response builder / method-name adapter
    - `webdriver/runtime`: DOM JS bridge / input runtime snippets
    - `webdriver/network`: `mizchi/crater-network` の互換 adapter として維持し、実装側は canonical module を直接参照する
    - `webdriver/protocol`: BiDi command validation / dispatch table / event serialization を、pure helper から順に分離する
    - `webdriver/protocol` / `webdriver/browser_domain`: intercept / fetch / cookie / storage / network event payload のうち BiDi 固有処理を分離する
    - `webdriver/browser_domain`: bluetooth / emulation / geolocation / permissions / screen / web extension など synthetic domain
    - `webdriver/rendering`: screenshot / print / actual paint / VRT bridge
    - `webdriver/server`: WebSocket transport / server state / session wiring
  - 外部化方針: `mizchi/font` は glyph provider / cache / rasterize / layout の実装責務、`mizchi/svg` は SVG primitive / scene / raster math の実装責務を持ち、crater 側は compatibility adapter に寄せる
- [ ] `painter/svg` facade の直接 re-export 候補を棚卸しする
  - `interop_*.mbt` に分割済みの adapter 群から、crater-local compatibility wrapper と direct alias 可能な primitive を分ける
  - public `.mbti` を維持したまま `mizchi/svg` の公開型へ寄せられるものを検証する
  - `moon info` で意図しない公開面変更がないことを確認する
- [ ] `painter/paint/raster/paint_raster.mbt` / glyph 周辺の責務整理を閉じる
  - glyph bitmap 配置計算は `painter/paint/glyph` の `layout_glyph_bitmaps` へ移動済み
  - raster 側に残すのは glyph blit / vertical clip / framebuffer compositing に限定する
  - bitmap font fallback と glyph path render の責務境界をさらに見直す
  - `mizchi/font` / `mizchi/svg` へ委譲できる処理は crater 側を adapter にする
- [ ] 最新の split に対応する boundary guard を追加・更新する
  - SVG interop adapter の file-size guard は追加済み。次は painter raster / browser / webdriver の split 状況を確認する
  - `scripts/moon-module-boundary.test.ts` 系の domain guard が、renderer / painter / browser / webdriver の現状を正しく見ているか確認する
  - 巨大 core への逆流を検出する file-size / symbol boundary を維持する
- [ ] `scripts/flaker-*` / `docs/flaker-runbook.md` の ownership と TODO を同期する
  - `@mizchi/flaker` に upstream 済みの pure core と、crater に残す VRT domain extension を再分類する

## Browser / Playwright / WebDriver

- [ ] `scripts/crater_bidi_adapter.py` に残る transport 以外の実装責務を削る
  - `BrowsingContextModule` / `SessionModule` / `ScriptModule` の wrapper をさらに thin にする
  - result unwrap / page-side JS / fixture glue が残っていれば MoonBit command/query へ寄せる
  - `_event_backlog` は WebSocket transport / pytest plugin core として残す前提で、実装 TODO からは分離する
- [ ] WebDriver tooling の `.ts` runner の責務を整理する
  - `scripts/wpt-webdriver-runner.ts`
  - `scripts/wpt-runner.ts`
  - `scripts/wpt-dom-runner.ts`
  - 実装本体ではなく test tooling として残すもの、MoonBit/just へ寄せるものを分ける
- [ ] Browser shell の control default action 残件を潰す
  - `select` popup UI
  - blur 時 `change` の細かい spec 差分
  - IME / selection / caret
- [ ] Browser shell fixture を実ページ寄りに拡張する
  - article / dashboard / GitHub snapshot で DOM mutation + repaint を固定観測する
- [ ] Web Components の残件を埋める
  - selector/style: `:host` 複合 selector, `::slotted`, `:host-context`
  - DOM surface: `closed` shadow root, declarative shadow DOM, customized built-in, form-associated custom elements / `ElementInternals`
  - Playwright / CDP / jsbidi の query / action / inspection surface を shadow-aware に揃え切る

## VRT / Paint

- [ ] GitHub 実 URL VRT の `--mask-assets` 後も残る sticky nav / card border / list marker 差分を最小 fixture 化する
- [ ] CSS background gradient / repeating-gradient の VRT fixture を増やす
- [ ] SVG/logo の intrinsic size と paint path を実 URL fixture から分離する
- [ ] select / button など native form control の appearance 差分を、mask 対象にするか paint 実装対象にするか決める
- [ ] low diff ページの pseudo / icon / border-radius 残差は、font 差分除外 VRT の budget tighten 後に個別対応する
- [ ] テキスト折り返し精度を改善する
  - paint の単語単位 wrap と layout engine の精密 wrap の差を縮める
  - layout と同じスペース考慮の行幅累積を paint 側にも寄せる
- [ ] WPT VRT ベースラインを更新する
  - `just wpt-vrt-baseline-update` で native backend の結果を記録する
- [ ] fixture ごとの threshold を artifact を見ながら段階的に tighten する
- [ ] built-in real-world snapshot を増やし、CI で 3-5 ページ比較できるようにする

## WPT / Compatibility

- [ ] `filter-effects` の残り failure を潰す
  - 現在の古いメモでは `99 / 106 passed`、要再計測
- [ ] WPT 対象 module を広げる
  - `css-ruby`
  - `css-writing-modes`
  - `css-pseudo`
  - `css-text`
  - `css-transforms`
  - `css-backgrounds`
  - `css-color`
- [ ] 実 `mizchi/image` が依存に入った時点で smoke test を追加する
  - JS export と Bytes 入力の shape を固定する
  - WPT image intrinsic provider の fallback と衝突しないことを確認する
- [ ] `taffy_compat` の既存 failure 群を baseline 管理対象にするか、段階的に潰すか方針を決める
- [ ] `moon coverage analyze` の mixed-target workspace 前提の扱いを決める

## Flaker / Test Management

- [ ] stable test identity を `crater` / `flaker` / `vrt-harness` で共有する
  - 候補: `taskId + spec + filter + variant + optional shard`
  - upstream issue: `mizchi/flaker#8`
- [ ] `flaker core` と crater domain metadata の境界を固定する
  - core: selection / quarantine / summary / diff
  - crater: VRT 固有メトリクス (`diffRatio`, `threshold`, `backend`, `viewport`, `snapshotKind`)
- [ ] VRT 判定は crater に残しつつ、summary / identity / quarantine 連携だけ共通契約へ寄せる
- [ ] `vrt-harness` を crater の consumer として接続する
  - crater の公開 API だけを使う
  - markup scenario から stable identity / normalized report を生成する
  - baseline 管理と fixture UX は `vrt-harness` に残す
- [ ] crater に残った汎用 test management code を削る
- [ ] `flaker` issue と crater / `vrt-harness` TODO の相互参照を整え、drift を防ぐ

## CI / Task Runner

- [ ] `affected pkfire` job の実 CI 結果を見て required check 化するか決める
  - PR merge-base / push `github.event.before` fallback が GitHub Actions 上で期待どおりか確認する
  - `.cache/pkfire` と `~/.pkl/cache` の hit 率を summary / timing artifact で追えるようにする
- [ ] `pkf affected --profile=ci` の対象 gate を CI 実績に合わせて調整する
  - `check`, `test`, `test-taffy`, `test-wasm`, `test-native-smoke` の required / optional 境界を決める
  - schedule では full matrix、PR / push では affected gate という分担で過不足がないか確認する

## Workspace / Release

- [ ] `benchmarks` / `testing` / adapter module の release note template と changelog 粒度を決める
- [ ] `mizchi/crater` facade を `0.18` 以降で doc 上 deprecated 扱いに進めるか決める
- [ ] `browser/native` と `wasm` を CI の required check にどこまで含めるか決める
- [ ] adapter module (`jsbidi`, `browser-native`, `js`, `wasm`) をどこまで公開サポート対象にするか決める

## External Follow-up

- [ ] `mizchi/kagura`: テキスト色が薄い SVG rasterizer alpha 問題を追う
- [ ] `mizchi/kagura`: glyph mirror の per-quad UV swap workaround を正しい層で解消する
- [ ] CI: llvmpipe セットアップを決める
  - `LIBGL_ALWAYS_SOFTWARE=1`
  - `mesa-vulkan-drivers`

## Maintenance Rules

- 完了したタスクは必要な要約だけ残し、長い作業ログは追加しない。
- 古い計測値を書くときは再計測コマンドと日付を必ず添える。
- 実装計画は Red / Green / Refactor の次アクションが分かる粒度に保つ。
