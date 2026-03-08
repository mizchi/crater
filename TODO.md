# TODO

## WebDriver BiDi の MoonBit 全面移行（2026-03-08）

- 目的:
  - `.py` / `.ts` に残っている WebDriver BiDi の実行責務を MoonBit に寄せる
  - adapter は最終的に `pytest` fixture / WPT glue のみに縮小する
  - runner 系 `.ts` は「実装本体」ではなく tooling として扱い、残置可否を段階的に判断する

### 現状整理

- MoonBit 化済みの中核:
  - `browser/src/bidi_main/main.mbt`
  - `browser/src/webdriver/bidi_protocol.mbt`
  - `browser/src/webdriver/bidi_server.mbt`
  - `browser/src/webdriver/bidi_storage.mbt`
- まだ Python に大きく残っている本実装:
  - `scripts/crater_bidi_adapter.py`
  - `browsingContext` / `session` / `script` / `network` / `storage` / `input` / `browser`
- まだ TypeScript に残っているもの:
  - `scripts/wpt-webdriver-runner.ts`
  - `scripts/wpt-runner.ts`
  - `scripts/wpt-dom-runner.ts`
  - これらは現時点では test tooling 扱い

### フェーズ

- [x] P0: cookie / storage の実行責務を Python adapter から MoonBit に移す
  - [x] `storage.getCookies / setCookie / deleteCookies`
  - [x] request cookies 解決を MoonBit 化
  - [x] `document.cookie` snapshot 取り込みを MoonBit 化
  - [x] adapter 内の synthetic cookie jar を削除
- [x] P1: synthetic network event の request/response 組み立てを MoonBit に寄せる
  - [x] `beforeRequestSent / responseStarted / responseCompleted / fetchError`
  - [x] blocked request state (`remember/get/forget/hasBlockedNavigation`) を MoonBit 化
  - [x] synthetic response override / cache 判定を MoonBit 化
  - [x] `authRequired` の override 合成を MoonBit 化
- [ ] P2: `browsingContext` / `script` / `session` の adapter 固有ロジックを MoonBit へ移す
  - [x] synthetic `window.location.href` override
  - [x] WPT 向け URL 正規化
  - [x] context tree / userContext の仲介 state 削減
  - [x] preload / realm fixture cleanup (`session.resetForTest`, `script.removeAllPreloadScripts`)
  - [x] preload / realm / evaluate 補助の移行
  - [x] `browsingContext.navigate` の beforeRequest blocking を MoonBit 化
  - [x] `browsingContext.captureScreenshot` の synthetic output を MoonBit 化
  - [x] `browsingContext.print` の synthetic output を MoonBit 化
  - [x] `script.evaluate` の file dialog synthetic glue を MoonBit 化
  - [x] `script.evaluate` の `registerServiceWorker()` no-op を MoonBit 化
  - [x] `script.evaluate` の document dimensions 補正を MoonBit 化
  - [x] `input.set_files` 用の context-scoped `window.allEvents.events` 補助を MoonBit 化
  - [x] `input.set_files` の validation / DOM 操作 / synthetic event 記録を MoonBit 化
  - [x] `script.callFunction` の focus / scroll fallback を MoonBit 化
  - [x] `browsingContext.getRequestedNavigationUrl` で requested URL state を MoonBit query 化
  - [x] `browsingContext.navigate / reload / close` の wrapper glue を MoonBit command に移行
- [x] `session.prepareBaselineContextForTest` と `browsingContext.getContextInfo` で fixture glue を MoonBit query/command 化
- [x] `script.evaluate / callFunction / locateNodes` の `serializationOptions` snake_case 正規化を MoonBit 化
- [x] `script.callFunction` の arguments local normalize を削除して protocol validation に委譲
- [x] `browsingContext.create` の `type_hint / user_context / reference_context` alias を MoonBit で受理
- [x] `script.addPreloadScript / getRealms` の Python wrapper を raw forwarding に縮小
- [x] `session.subscribe / unsubscribe` の `user_contexts` alias を MoonBit で受理
- [x] `script.evaluate / callFunction` の `await_promise / result_ownership / user_activation / function_declaration / serialization_options` alias を MoonBit で受理
- [x] `browsingContext.setViewport` / `network.setExtraHeaders` / `browser.setDownloadBehavior` の `user_contexts` alias を MoonBit で受理
- [ ] P3: adapter を pytest plugin / fixture glue のみに縮小する
  - [x] `network.continueRequest / continueResponse / continueWithAuth / provideResponse / failRequest` を MoonBit 実装へ置換
  - [x] `network.failRequest` の blocked state consume / `fetchError` payload を MoonBit command 化
  - [ ] `browsingContext` / `script` / `session` の protocol command 実装を Python から除去
  - [ ] synthetic state を最小化
    - [x] `_synthetic_scrolled_contexts` を削除して MoonBit state に統合
    - [x] `_last_navigated_url` を削除して requested URL query に置換
    - [x] `_known_user_contexts` を削除して `browser.hasUserContext` query に置換
- [ ] P4: tooling の `.ts` を整理する
  - [ ] runner を残すか MoonBit/just に寄せるか判断
  - [ ] CI 集計やレポート生成の責務を分離

### 今回の着手

- [x] `storage.resolveRequestCookies` を MoonBit に追加
- [x] `storage.rememberDocumentCookie` を MoonBit に追加
- [x] adapter の cookie read/write を上記 command 経由に切り替える
- [x] `storage --quick` / `integration --quick` / `strict` で回帰確認
- [x] synthetic `network.*` payload 生成を MoonBit command 経由に移行
- [x] `storage --quick` / `integration --quick` / `strict` で network 移行の回帰確認
- [x] adapter 内に残っていた synthetic cookie jar を削除
- [x] `network.failRequest` の validation / payload 生成 / state forget を MoonBit command に移行
- [x] `network.continueRequest` の validation / payload 生成 / state forget を MoonBit command に移行
- [x] `network.continueResponse / provideResponse / continueWithAuth` の blocked-response state machine を MoonBit command に移行
- [x] synthetic `window.location.href` override と cookie base URL 解決を MoonBit state に移行
- [x] `network --quick` / `integration --quick` / `strict` で synthetic location 移行の回帰確認
- [x] `network.setExtraHeaders` の state / headers echo payload / request header merge を MoonBit に移行
- [x] synthetic iframe fallback を MoonBit の child context 作成に置き換える
- [x] `network/set_extra_headers --quick` / `network --quick` / `integration --quick` / `strict` で extra headers 移行の回帰確認
- [x] `script.evaluate` の file dialog synthetic glue を MoonBit に移行
- [x] `script.evaluate` の `registerServiceWorker()` no-op を MoonBit に移行
- [x] `script.evaluate` の document dimensions 補正を MoonBit に移行
- [x] `input.recordSyntheticEvents` と `JSON.stringify(window.allEvents.events)` の context-scoped 補助を MoonBit に移行
- [x] `session.resetForTest` で test fixture の context/realm/preload cleanup を MoonBit に移行
- [x] `script.removeAllPreloadScripts` で preload fixture cleanup の id 追跡を削除
- [x] `script.evaluate` の `allEvents` normalize / dedupe を MoonBit に移行
- [x] `network.resolveMatchingIntercepts` を MoonBit に追加して adapter の intercept mirror を削除
- [x] `network.rememberCollectedData / getData / disownData` を MoonBit に追加して adapter の collector mirror を削除
- [x] `network.prepareNavigationRequest` を追加して `browsingContext.navigate` の beforeRequest blocking を MoonBit に移行
- [x] `network.emitNavigationRequestSequence` を追加して `navigate/reload` 後の synthetic request sequence 生成を MoonBit に移行
- [x] `network.allocateRequestId` を追加して synthetic request id 発番を MoonBit に統一
- [x] `browsingContext.captureScreenshot` の synthetic output を MoonBit に移行
- [x] `browsingContext.print` の synthetic output を MoonBit に移行
- [x] `script.callFunction` の focus / scroll fallback を MoonBit に移行
- [x] `input/file_dialog_opened --quick` / `browsing_context/capture_screenshot --quick` / `network/{before_request_sent,response_started,response_completed} --quick` / `integration --quick` で回帰確認
- [x] `input/set_files --quick` / `input/file_dialog_opened --quick` / `strict` で input synthetic event 移行の回帰確認
- [x] `input.setFiles` internal command を追加して `input.set_files` の adapter 実装を薄くする
- [x] `input/set_files --quick` / `input/file_dialog_opened --quick` / `network --quick` / `strict` で `input.set_files` 移行の回帰確認
- [x] `script/add_preload_script --quick` / `script/get_realms --quick` / `script/realm_created --quick` / `integration --quick` / `strict` で preload/realm fixture 移行の回帰確認
- [x] `browsing_context/capture_screenshot --quick` / `browsing_context/print --quick` / `integration --quick` / `strict` で回帰確認
- [x] `browsingContext.getRequestedNavigationUrl` / `browser.hasUserContext` / `storage.getContextCookieInfo` を追加して adapter の local mirror を削減
- [x] `storage --quick` / `integration --quick` / `strict` で requested URL / cookie scope query 化の回帰確認
- [x] `network.removeIntercept / setCacheBehavior / getData / disownData / continueWithAuth(credentials)` の adapter local validation を削減し、MoonBit validator に委譲
- [x] network adapter に残っていた dead helper（header/cookie/auth/data-url 補助）を削除
- [x] `network/remove_intercept --quick` / `network/get_data --quick` / `network/disown_data --quick` / `network/set_cache_behavior/invalid --quick` / `network/continue_with_auth --quick` / `network --quick` / `strict` で回帰確認
- [x] `browsingContext.prepareNavigate / finalizeNavigate / finalizeReload / getCloseMetadata` を追加して `navigate/reload/close` wrapper glue を MoonBit 化
- [x] `session.prepareBaselineContextForTest` を追加して `_trim_contexts_for_test` の baseline 準備を MoonBit 化
- [x] `browsingContext.getContextInfo` を追加して `top_context / new_tab / current_url` fixture の `getTree(root, maxDepth=0)` 依存を削減
- [x] `serializationOptions` の snake_case alias (`max_dom_depth` / `max_object_depth` / `include_shadow_tree`) を MoonBit validator / runtime に追加
- [x] adapter 側の `_convert_serialization_options` / `_normalize_call_function_arguments` を削除
- [x] `script/evaluate --quick` / `script/call_function --quick` / `browsing_context/{locate_nodes,close,reload,navigate} --quick` / `integration --quick` / `strict` で回帰確認
- [x] `browsing_context/{get_tree,context_created} --quick` / `script/get_realms --quick` / `integration --quick` / `strict` で fixture glue 移行の回帰確認
- [x] `browsingContext.create` の snake_case alias を protocol 側で受理して adapter の camelCase 変換を削除
- [x] `script.addPreloadScript / getRealms` を raw forwarding に寄せ、`browsing_context/create --quick` / `script/{add_preload_script,get_realms} --quick` / `integration --quick` / `strict` で回帰確認
- [x] `session.subscribe / unsubscribe` と `script.evaluate / callFunction` の snake_case alias を protocol 側で受理して adapter の camelCase 変換を削除
- [x] `session/{subscribe,unsubscribe} --quick` / `script/{evaluate,call_function} --quick` / `integration --quick` / `strict` で alias 移行の回帰確認
- [x] `browsing_context/set_viewport --quick` / `network/set_extra_headers --quick` / `browser/set_download_behavior --quick` / `integration --quick` / `strict` で `user_contexts` alias 移行の回帰確認

### 次の具体タスク

- [ ] `browsingContext` / `session` / `script` に残る adapter state を棚卸しして MoonBit 側へ寄せる
- [x] WPT 向け URL 正規化を MoonBit 側へ移して adapter 依存を減らす
- [x] `context_user_context / context_parent` の Python mirror を `browsingContext.getContextScopeInfo` / `session.isSubscribedForContext` ベースに削減する
- [ ] `browsingContext` / `script` / `session` に残る local validation と fixture glue を MoonBit command に置き換える
  - `captureScreenshot` / `print` / `script.callFunction` の主要な synthetic path は移行済み
  - `navigate/reload` 後の synthetic request sequence と request id 発番は MoonBit 側へ移行済み
  - `navigate/reload/close` の wrapper glue と `serializationOptions` 正規化は MoonBit 側へ移行済み
  - baseline context 準備と single-context query は MoonBit 側へ移行済み
  - requested navigation URL / context cookie scope / userContext existence は query command 化済み
  - `network` の dead helper と一部 local validation は削除済み
- [ ] adapter を `pytest` fixture と最小限の WPT glue のみに縮小する
  - `network` の local mirror (`_network_intercepts`, `_network_collectors`, `_network_collected_data`, synthetic subscription fallback) は削除済み
  - `browsingContext` の `_last_navigated_url` と session の `_known_user_contexts` は削除済み

## WPT サポート状況（2026-03-03）

- 実測コマンド: `npx tsx scripts/wpt-runner.ts <module> --workers 4`
- 全体: `1366 / 1446 passed`（`94.5%`、`80 failed`）

| Module | Passed | Failed | Total | Rate |
|--------|--------|--------|-------|------|
| css-flexbox | 267 | 22 | 289 | 92.4% |
| css-grid | 32 | 1 | 33 | 97.0% |
| css-tables | 26 | 6 | 32 | 81.2% |
| css-display | 71 | 8 | 79 | 89.9% |
| css-box | 30 | 0 | 30 | 100.0% |
| css-sizing | 88 | 6 | 94 | 93.6% |
| css-align | 38 | 6 | 44 | 86.4% |
| css-position | 84 | 0 | 84 | 100.0% |
| css-overflow | 231 | 12 | 243 | 95.1% |
| css-contain | 298 | 5 | 303 | 98.3% |
| css-variables | 100 | 7 | 107 | 93.5% |
| filter-effects | 99 | 7 | 106 | 93.4% |
| compositing | 2 | 0 | 2 | 100.0% |

### 直近の改善

- `css-position`: `74 / 84` -> `84 / 84`

### 直近の優先候補

- `css-flexbox` の残件（`22 failed`）
- `css-overflow` の残件（`12 failed`）
- `css-display` の残件（`8 failed`）
- `css-variables` の残件（`7 failed`）
- `filter-effects` の残件（`7 failed`）

### WPT runner / intrinsic provider メモ

- WPT 用の外部 intrinsic provider フックを追加:
  - text: `set_text_metrics_provider`（`wpt-runner` は `CRATER_TEXT_MODULE` または `mizchi/text` を自動探索）
  - image: `set_image_intrinsic_size_provider`（`CRATER_IMAGE_MODULE` または `mizchi/image`）
  - 画像ローカル寸法解決フォールバックは `CRATER_IMAGE_FILE_RESOLVE=1` のときのみ有効

## css-flexbox WPT 進捗（2026-02-21, 履歴）

- 現在: `278 / 289 passed`（`11 failed`）
- 今回の更新: `270 / 289` → `278 / 289`（+8）
- 実行コマンド: `npx tsx scripts/wpt-runner.ts css-flexbox`

## 今回対応済み（完了）

- [x] `grid-flex-item-001.html`
- [x] `grid-flex-item-002.html`
- [x] `grid-flex-item-004.html`
- [x] `grid-flex-item-005.html`
- [x] `fixed-table-layout-with-percentage-width-in-flex-item.html`

## 残タスク（11）

- [ ] `align-baseline.html`
- [ ] `flex-aspect-ratio-img-column-012.html`
- [ ] `flex-box-wrap.html`
- [ ] `flex-direction-row-vertical.html`
- [ ] `flex-inline.html`
- [ ] `flex-vertical-align-effect.html`
- [ ] `justify-content_space-between-003.tentative.html`
- [ ] `overflow-top-left.html`
- [ ] `position-absolute-scrollbar-freeze.html`
- [ ] `table-with-infinite-max-intrinsic-width.html`
- [ ] `text-overflow-on-flexbox-001.html`

## WPT 伸び代メモ（2026-02-27, 履歴）

- 注: この時点では `css-contain` を次ターゲットとしていたが、2026-02-28 時点で `303 / 303 passed` まで到達済み。

- 全体: `1064 / 1446 passed`（`382 failed`）
- 失敗上位モジュール:
  - `css-contain`: `120 failed`
  - `css-overflow`: `114 failed`
  - `css-display`: `38 failed`

### css-contain（次の着手点）

- 失敗クラスター（概数）
  - `contain-size-*`: 31
  - `contain-paint-*`: 29
  - `contain-layout-*`: 26
  - `contain-style-*`: 15
- 先頭ターゲット: `contain-inline-size-intrinsic.html`
  - 症状: `root.width browser=100 / crater=0`
  - 仮説: `contain-intrinsic-inline-size` 未実装
  - 進捗（2026-02-27）:
  - `183 / 303 passed`（`120 failed`）→ `233 / 303 passed`（`70 failed`）
  - `233 / 303 passed`（`70 failed`）→ `236 / 303 passed`（`67 failed`）
  - `236 / 303 passed`（`67 failed`）→ `243 / 303 passed`（`60 failed`）
  - `243 / 303 passed`（`60 failed`）→ `247 / 303 passed`（`56 failed`）
  - `247 / 303 passed`（`56 failed`）→ `249 / 303 passed`（`54 failed`）
  - `249 / 303 passed`（`54 failed`）→ `250 / 303 passed`（`53 failed`）
  - `250 / 303 passed`（`53 failed`）→ `252 / 303 passed`（`51 failed`）
  - `252 / 303 passed`（`51 failed`）→ `253 / 303 passed`（`50 failed`）
  - `253 / 303 passed`（`50 failed`）→ `254 / 303 passed`（`49 failed`）
  - `254 / 303 passed`（`49 failed`）→ `255 / 303 passed`（`48 failed`）
  - `255 / 303 passed`（`48 failed`）→ `256 / 303 passed`（`47 failed`）
  - `256 / 303 passed`（`47 failed`）→ `264 / 303 passed`（`39 failed`）
  - `264 / 303 passed`（`39 failed`）→ `269 / 303 passed`（`34 failed`）
  - 改善済み:
    - `contain-inline-size-intrinsic.html`
    - `contain-inline-size-vertical-rl-.html`
    - `contain-inline-size-fieldset.html`
    - `contain-inline-size-legend.html`
    - `contain-inline-size-bfc-floats-001.html`
    - `contain-inline-size-bfc-floats-002.html`
    - `contain-content-002.html`
    - `contain-layout-001.html`
    - `contain-layout-003.html`
    - `contain-layout-005.html`
    - `contain-layout-009.html`
    - `contain-layout-010.html`
    - `contain-layout-011.html`
    - `contain-layout-012.html`
    - `contain-layout-017.html`
    - `contain-layout-baseline-002.html`
    - `contain-layout-baseline-003.html`
    - `contain-layout-baseline-005.html`
    - `contain-layout-dynamic-004.html`
    - `contain-layout-dynamic-005.html`
    - `contain-layout-ink-overflow-014.html`
    - `contain-layout-ink-overflow-016.html`
    - `contain-layout-ink-overflow-017.html`
    - `contain-layout-ink-overflow-018.html`
    - `contain-layout-button-002.tentative.html`
    - `contain-layout-independent-formatting-context-002.html`
    - `contain-layout-independent-formatting-context-003.html`
    - `contain-layout-suppress-baseline-002.html`
    - `contain-layout-cell-001.html`
    - `contain-layout-cell-002.html`
    - `contain-paint-independent-formatting-context-003.html`
    - `contain-content-004.html`
    - `contain-paint-011.html`
    - `contain-paint-012.html`
    - `contain-paint-024.html`
    - `contain-paint-014.html`
    - `contain-paint-015.html`
    - `contain-paint-016.html`
    - `contain-paint-017.html`
    - `contain-paint-018.html`
    - `contain-paint-022.html`
    - `contain-paint-023.html`
    - `contain-paint-clip-001.html`
    - `contain-paint-047.html`
    - `contain-paint-cell-001.html`
    - `contain-paint-cell-002.html`
    - `contain-paint-ignored-cases-internal-table-001a.html`
    - `contain-paint-ignored-cases-internal-table-001b.html`
    - `contain-size-007.html`
    - `contain-size-008.html`
    - `contain-size-009.html`
    - `contain-size-021.html`
    - `contain-size-025.html`
    - `contain-size-042.html`
    - `contain-size-063.html`
    - `contain-size-fieldset-002.html`
    - `contain-size-fieldset-004.html`
    - `contain-size-table-caption-001.html`
    - `contain-inline-size-removed.html`
    - `contain-size-removed.html`
    - `contain-body-t-o-001.html`
    - `contain-body-t-o-002.html`
    - `contain-body-t-o-003.html`
    - `contain-body-t-o-004.html`
    - `contain-html-t-o-001.html`
    - `contain-html-t-o-002.html`
    - `contain-html-t-o-003.html`
    - `contain-html-t-o-004.html`
  - 次の有力クラスター:
    - `contain-layout-breaks-{001,002}.html`（multicol + forced break 未実装）
    - `contain-size-{breaks-001,multicol-001,multicol-002,multicol-003}`（multicol 未実装）
    - `contain-style-counters-*` / `contain-style-ol-ordinal*`（counter 系）

### css-overflow（次点）

- `scroll-marker/target` 系の失敗が大半（約 52）
- `column-scroll-marker` / `scroll-buttons` / `overflow-alignment` もまとまって残っている
