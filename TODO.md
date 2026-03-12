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
- [x] `browser.createUserContext` と `browsingContext.{print,locateNodes}` の snake_case alias を MoonBit で受理
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
- [x] `browsingContext.createContextId` を追加して `add_and_remove_iframe` fixture の `context` unwrap を MoonBit 側へ移行
- [x] `session.subscribe / unsubscribe` と `script.evaluate / callFunction` の snake_case alias を protocol 側で受理して adapter の camelCase 変換を削除
- [x] `session/{subscribe,unsubscribe} --quick` / `script/{evaluate,call_function} --quick` / `integration --quick` / `strict` で alias 移行の回帰確認
- [x] `browsing_context/set_viewport --quick` / `network/set_extra_headers --quick` / `browser/set_download_behavior --quick` / `integration --quick` / `strict` で `user_contexts` alias 移行の回帰確認
- [x] `browsing_context/{print,capture_screenshot,locate_nodes} --quick` / `browser/create_user_context --quick` / `integration --quick` / `strict` で wrapper 簡略化の回帰確認
- [x] `network.performSyntheticFetch` を追加して `fetch` fixture の synthetic request sequence を MoonBit に移行
- [x] adapter から synthetic fetch 用 helper / event emit を削除
- [x] `network --quick` / `integration --quick` / `strict` で fetch 移行の回帰確認
- [x] `network.continueBlockedResponse` に `provideResponse` body override を実装して document/script/style の runtime 反映を MoonBit に移行
- [x] adapter から `provideResponse` body override の post-processing を削除
- [x] `network/provide_response/body --quick` / `network/provide_response --quick` / `network --quick` / `integration --quick` / `strict` で回帰確認
- [x] `session.getBaselineContextInfoForTest` / `browsingContext.getCurrentUrl` を追加して `top_context / fetch / current_url` fixture の `_baseline_context_id` / single-context info 依存を削減
- [x] `browsing_context/{get_tree,context_created} --quick` / `integration --quick` / `strict` で baseline fixture query 化の回帰確認
- [x] `browsingContext.getTreeContexts` / `script.addPreloadScriptId` / `script.getRealmsList` を追加して module proxy の result unwrap を MoonBit 側へ移行
- [x] `new_tab` / baseline fixture を `BrowsingContextModule` / `SessionModule` ベースへ整理
- [x] `browsing_context/{get_tree,context_destroyed} --quick` / `script/{add_preload_script,get_realms} --quick` / `integration --quick` / `strict` で proxy 簡略化の回帰確認
- [x] `browsingContext.closeWithState` を追加して `close` の waitForDestroyed 判定と deferred close 応答を MoonBit 側へ移行
- [x] `browsing_context/{close,context_destroyed} --quick` / `integration --quick` / `strict` で `closeWithState` 移行の回帰確認
- [x] `browsingContext.reloadWithState` を追加して `reload` の finalize orchestration と beforeunload 再開を MoonBit 側へ移行
- [x] `browsing_context/reload --quick` / `network --quick` / `integration --quick` / `strict` で `reloadWithState` 移行の回帰確認
- [x] `browsingContext.navigateWithState` を追加して `navigate` の prepare/finalize orchestration と beforeunload 再開を MoonBit 側へ移行
- [x] `browsing_context/navigate --quick` / `network/before_request_sent --quick` / `integration --quick` / `strict` で `navigateWithState` 移行の回帰確認
- [x] `browsingContext.getCurrentUrlValue` / `printData` を追加して `BrowsingContextModule.get_current_url` / `print` の result unwrap を MoonBit 側へ移行
- [x] `browsing_context/print --quick` / `integration --quick` / `strict` で `getCurrentUrlValue` / `printData` 移行の回帰確認
- [x] `browsingContext.captureScreenshotData` / `script.evaluateResult` / `script.callFunctionResult` を追加して `BrowsingContextModule.capture_screenshot` / `ScriptModule.evaluate` / `call_function` の result unwrap を MoonBit 側へ移行
- [x] `browsing_context/capture_screenshot --quick` / `script/{evaluate,call_function} --quick` / `integration --quick` / `strict` で result unwrap 移行の回帰確認
- [x] `browsingContext.closeResult` を追加して `BrowsingContextModule.close` の contextDestroyed 待機を MoonBit 側へ移行
- [x] `browsing_context/{close,context_destroyed} --quick` / `integration --quick` / `strict` で `closeResult` 移行の回帰確認
- [x] `max_depth` / `prompt_unload` / `device_pixel_ratio` を protocol alias として受理して `BrowsingContextModule` の camelCase 変換を削減
- [x] `script.removePreloadScript` が nested `{script:{script:id}}` を受理するようにして `ScriptModule.remove_preload_script` の Python 正規化を削除
- [x] `browser.getUserContextsList` / `getClientWindowsList` を追加して `BrowserModule` の list unwrap を MoonBit 側へ移行
- [x] `BrowsingContextModule.get_current_url` の Python 側 type unwrap を削除
- [x] `script.getElementForTest` を追加して `get_element` fixture の querySelector / locateNodes / iframe fallback を MoonBit 側へ移行
- [x] `input/set_files --quick` で `getElementForTest` 移行の回帰確認
- [x] synthetic `localStorage` の `script.callFunctionResult` unwrap を MoonBit 側で扱うようにして `browser/create_user_context::test_storage_isolation` を修正
- [x] `browser/create_user_context --quick` で localStorage unwrap 修正の回帰確認
- [x] `script.prepareLoadedStaticTestPage` を追加して `load_static_test_page` fixture の DOMContentLoaded / allEvents reset / recorder fallback を MoonBit 側へ移行
- [x] `input/{set_files,perform_actions/wheel} --quick` / `integration --quick` / `strict` で static page setup 移行の回帰確認
- [x] `script.prepareLoadedStaticTestPage` の `pageSpecific` phase を追加して `test_actions*` の page-specific setup を MoonBit 側へ移行
- [x] `input/{perform_actions/wheel,release_actions,set_files} --quick` / `network/set_extra_headers/contexts.py --quick` / `integration --quick` / `strict` で `test_actions*` page-specific 移行の回帰確認
- [x] `script.prepareLoadedStaticTestPage` の `inlineScripts` phase を追加して `load_static_test_page` fixture の inline `<script>` eval loop を MoonBit 側へ移行
- [x] `input/{perform_actions/wheel,release_actions,set_files} --quick` / `integration --quick` / `strict` で `inlineScripts` 移行の回帰確認
- [x] `script.prepareLoadedStaticTestPage(html=...)` で `load_static_test_page` fixture の HTML regex / multi-phase loop を 1 command に集約
- [x] `input/{perform_actions/wheel,release_actions,set_files} --quick` / `integration --quick` / `strict` で `load_static_test_page` 1-command 化の回帰確認
- [x] `script.setupBeforeunloadPageForTest` を追加して `setup_beforeunload_page` fixture の input focus/value/input event 設定を MoonBit 側へ移行
- [x] `browsing_context/{close/prompt_unload.py,navigate/navigate_beforeunload.py} --quick` / `integration --quick` / `strict` で `beforeunload` setup 移行の回帰確認
- [x] `script.prepareBeforeunloadPageUrlForTest` を追加して `setup_beforeunload_page` fixture の `url` unwrap を MoonBit 側へ移行
- [x] `script.syncDocumentCookiesForTest` / `script.fetchFromContextForTest` を追加して `fetch` fixture の `document.cookie` snapshot と page-side `fetch()` 実行を MoonBit command に移行
- [x] `network/{fetch_error/fetch_error.py,provide_response/cookies.py} --quick` / `integration --quick` / `strict` で `fetch` fixture 移行の回帰確認
- [x] `script.createIframeContextForTest` を追加して `create_iframe` fixture の JS/fallback glue を MoonBit 側へ移行
- [x] `network/set_extra_headers/contexts.py --quick` / `integration --quick` / `strict` で `create_iframe` fixture 移行の回帰確認
- [x] `input.releaseActions` と synthetic `mousemove` の dispatch を修正して `queue.py::test_parallel_pointer` / `sequence_tentative.py::test_release_mouse_sequence_resets_dblclick_state` を解消
- [x] `input/release_actions --quick` / `input/perform_actions/wheel --quick` / `input/set_files --quick` / `integration --quick` / `strict` で input 回帰確認
- [x] `create_user_context` fixture は `BrowserModule.create_user_context()` の raw string 返却に揃え、local unwrap を削除
- [x] adapter の未使用 backlog helper (`has_event_listener` / `wait_for_backlog_event` / `pop_event_backlog`) を削除
- [ ] `_event_backlog` 自体は WebSocket transport 層のため Python に残す
- [x] `wait_for_event` fixture の backlog special case と listener 登録を `CraterBidiSession.listen_once()` に集約
- [x] `_trim_contexts_for_test` の backlog clear を session helper 経由に整理
- [x] `wait_for_events` fixture の multi-listener collector を `_BiDiEventCollector` / `listen_many()` に移し、fixture 自体は factory のみに縮小

### 次の具体タスク

- [x] `scripts/crater_bidi_adapter.py` の現状を 3 分類で棚卸しする
  - 現在は `2415` 行。基準にしている `dd98dd8` 時点の `5379` 行から `-2964` 行、約 `55%` 減
  - `A. Python に残す transport / plugin core`
    - `CraterBidiSession` の WebSocket 接続、receive loop、command future 解決、event backlog/listener 管理
    - `_BiDiEventCollector`、`event_loop` / `bidi_session` / `current_session` / `session` など pytest plugin の基盤
    - ここは MoonBit へ移す対象ではなく、`pytest` plugin を残す限り Python に残る
  - `B. さらに MoonBit へ寄せられる thin wrapper / fixture glue`
    - `BrowsingContextModule` / `SessionModule` / `ScriptModule`
    - `top_context` / `new_tab` / `get_element` / `fetch` / `load_static_test_page` / `create_user_context` / `setup_network_test`
    - この層は command/query を追加すればまだかなり削れる
  - `C. WPT tooling として残置判断が必要な fixture glue`
    - `server_config` / `url` / `inline` / `iframe`
    - PDF/PNG assertion helper や test page builder (`assert_pdf_content`, `assert_pdf_image`, `get_actions_origin_page` など)
    - これは WebDriver 実装ではなく WPT harness 側の補助なので、MoonBit 化の優先度は低い
  - 見積もり
    - `B` を中心に adapter を `1200-1600` 行まで縮める: あと `3-5日`
    - Python を WebDriver 実装から完全に外す: あと `1-2週間`
    - 後者は transport / pytest plugin / runner の置き換えを含み、単なる移植ではなく実行基盤の再設計になる
- [ ] `browsingContext` / `session` / `script` に残る adapter state を棚卸しして MoonBit 側へ寄せる
- [x] WPT 向け URL 正規化を MoonBit 側へ移して adapter 依存を減らす
- [x] `context_user_context / context_parent` の Python mirror を `browsingContext.getContextScopeInfo` / `session.isSubscribedForContext` ベースに削減する
- [ ] `browsingContext` / `script` / `session` に残る local validation と fixture glue を MoonBit command に置き換える
  - `captureScreenshot` / `print` / `script.callFunction` の主要な synthetic path は移行済み
  - `navigate/reload` 後の synthetic request sequence と request id 発番は MoonBit 側へ移行済み
  - `close` の waitForDestroyed 判定と deferred close 応答は `closeWithState` に移行済み
  - `reload` の finalize orchestration は `reloadWithState` に移行済み
  - `navigate` の prepare/finalize orchestration は `navigateWithState` に移行済み
  - `get_current_url` / `print` の result unwrap は MoonBit 側へ移行済み
  - `capture_screenshot` / `script.evaluate` / `script.call_function` の result unwrap は MoonBit 側へ移行済み
  - `close` の contextDestroyed 待機は `closeResult` に移行済み
  - `serializationOptions` 正規化は MoonBit 側へ移行済み
  - baseline context 準備と baseline/current-url query は MoonBit 側へ移行済み
  - requested navigation URL / context cookie scope / userContext existence は query command 化済み
  - `network` の dead helper と一部 local validation は削除済み
  - `create_iframe` fixture の JS/fallback glue は `script.createIframeContextForTest` に移行済み
  - `create_iframe` fixture の `context` unwrap は `script.createIframeContextIdForTest` に移行済み
  - `load_static_test_page` の `test_actions*` page-specific setup は `script.prepareLoadedStaticTestPage(phase=\"pageSpecific\")` に移行済み
  - `load_static_test_page` の inline `<script>` eval loop は `script.prepareLoadedStaticTestPage(phase=\"inlineScripts\")` に移行済み
  - `load_static_test_page` の HTML regex / multi-phase loop は `script.prepareLoadedStaticTestPage(html=...)` に集約済み
  - `setup_beforeunload_page` の navigate + setup は `script.prepareBeforeunloadPageForTest` に移行済み
  - `setup_beforeunload_page` の `url` unwrap は `script.prepareBeforeunloadPageUrlForTest` に移行済み
  - `fetch` fixture の cookie snapshot / page-side fetch 実行は `script.fetchForTest` に集約済み
  - `setup_network_test` の baseline context navigation は `network.prepareContextForTest` に移行済み
- [ ] adapter を `pytest` fixture と最小限の WPT glue のみに縮小する
  - `network` の local mirror (`_network_intercepts`, `_network_collectors`, `_network_collected_data`, synthetic subscription fallback) は削除済み
  - `browsingContext` の `_last_navigated_url` と session の `_known_user_contexts` は削除済み
  - `_baseline_context_id` と `get_tree(root,maxDepth=0)` ベースの baseline fixture fallback は削除済み
  - `new_tab` / `top_context` / `fetch` / `current_url` は module/query command ベースへ整理済み
  - `top_context` / `new_tab` の result unwrap は `session.getBaselineContextInfoValueForTest` / `browsingContext.createAndGetInfoValue` に移行済み
  - `create_user_context` fixture の cleanup は `session.prepareBaselineContextForTest` 側へ集約済み
  - `NetworkModule` の `continue/provide/fail/auth` event emit と preflight follow-up は MoonBit 側へ移行済み
  - `fetch` fixture の synthetic request sequence / redirect / preflight / blocked state / collected data は MoonBit 側へ移行済み
  - `provideResponse` の body override は MoonBit 側へ移行済み
  - `get_element` / `fetch` / `setup_network_test` は MoonBit command ベースに整理済み
  - `get_element` の Python 側 `sharedId` normalize は削除済み
  - 同期 fixture の `get_test_page` は protocol command ではなく、MoonBit helper package `browser/src/webdriver_fixture_builder` を subprocess + cache で呼ぶ形に移行済み
  - `url` / `inline` / `iframe` / `get_actions_origin_page` も同 helper package 経由に移行済み
  - `compare_png_bidi` / `render_pdf_to_png_bidi` / `assert_pdf_dimensions` も同 helper package 経由に移行済み
  - synthetic print payload に `pages` / `signature` を追加し、`assert_pdf_content` / `assert_pdf_image` も helper package 経由で実動化済み
  - `assert_file_dialog_canceled` / `assert_file_dialog_not_canceled` は placeholder ではなく、`unhandledPromptBehavior[file]` を検証する実実装に差し替え済み
  - `session/capabilities/unhandled_prompt_behavior/file --quick` は `12/12`、`browser/create_user_context/unhandled_prompt_behavior.py --quick` は `24/24`、`input/file_dialog_opened --quick` は `8/8`
  - `prepareBaselineContextForTest` は session capability 由来の default `unhandledPromptBehavior` を保持するよう修正済み
  - `file` prompt の spec default は `ignore` として扱う
  - 未使用の `create_dialog` / `wait_for_class_change` placeholder fixture は削除済み
  - 現在の `scripts/crater_bidi_adapter.py` は `2107` 行
  - 残りは `browsingContext` / `session` / `script` 周辺の fixture glue と module proxy の整理、および transport 層の棚卸し

### 2026-03-09 の詳細計画

- [x] Step 1: `browsing_context/create` クラスターを先に潰す
  - [x] `document.visibilityState` / `document.hasFocus()` の synthetic `script.callFunctionResult` unwrap を MoonBit 側で修正する
  - [x] wbtest を追加して raw remote value 契約を固定する
  - [x] `browsing_context/create --quick` を `34/46 -> 46/46` に戻す
  - [x] `--profile strict` を直列で再実行して回帰がないことを確認する
- [x] Step 2: `browsingContext.create` の残差分を再分類する
  - [x] `visibilityState / hasFocus`
  - [x] `background` 時の active context 切替
  - [x] `reference_context / user_context / opener` の整合
  - [x] `browsing_context/create --quick` は `46/46` で、quick クラスター内の残差分は解消済み
  - [x] 以後は `create` 個別差分ではなく、周辺 fixture/helper の raw command 化を優先する
- [ ] Step 3: `BrowsingContextModule / SessionModule / ScriptModule` の残り wrapper を削る
  - [ ] result unwrap が残っている helper を MoonBit command 化する
  - [ ] fixture ごとの page-side JS を MoonBit command に集約する
  - [x] `browsingContext.createContextId` で `add_and_remove_iframe` の `context` unwrap を削除
  - [x] `script.prepareBeforeunloadPageUrlForTest` で `setup_beforeunload_page` の `url` unwrap を削除
  - [x] `browsingContext.isKnownContext` / `browser.hasUserContextValue` で transport helper の `known` unwrap を raw bool 化
  - [x] 未使用になった `get_context_scope_info` / `get_context_cookie_info` / `resolve_user_context` wrapper を削除
  - [x] 未使用になった `create_and_get_info` / `get_baseline_context_info_for_test` / `create_iframe_context_for_test` / `setup_beforeunload_page_for_test` / `prepare_beforeunload_page_for_test` proxy を削除
  - [x] `network.getBlockedRequestPhaseValue` / `network.getBlockedRequestNavigationValue` で blocked request の object unwrap を raw query 化
  - [x] 未使用になった `get_blocked_network_request` / `forget_blocked_network_request` / `fail_blocked_request` / `continue_auth_request` helper を削除
  - [x] `network.addDataCollectorId` で `add_data_collector` の `collector` unwrap を raw id 化
  - [x] `network.addInterceptId` で `add_intercept` の `intercept` unwrap を raw id 化
  - [x] `provide_response` / `set_cache_behavior` の戻り値 inspection を削除して thin wrapper 化
  - [x] `session.subscribeId` で `subscribe_events` fixture の cleanup を raw subscription id ベースに簡略化
  - [x] `create_iframe` / `current_url` / `setup_beforeunload_page` の `context` unwrap を module helper に寄せた
  - [x] `top_context` / `new_tab` fixture の dict copy unwrap を削除
  - [x] `top_context` / `new_tab` の fallback object を fail-fast helper に置き換えた
  - [x] `get_test_page` の page builder を pure helper に切り出して MoonBit 移植対象を分離した
  - [x] 同期 fixture 制約に合わせて `browser/src/webdriver_fixture_builder` を追加し、`get_test_page` の page builder 自体を MoonBit helper に移した
  - [x] `url` / `inline` / `iframe` / `get_actions_origin_page` も `browser/src/webdriver_fixture_builder` 経由へ移した
  - [x] `compare_png_bidi` / `render_pdf_to_png_bidi` / `assert_pdf_dimensions` も `browser/src/webdriver_fixture_builder` 経由へ移した
  - [x] synthetic print payload に `pages` / `signature` を追加し、`assert_pdf_content` / `assert_pdf_image` を helper package 経由の実動 assertion に置き換えた
  - [x] `print --quick` (`137/137`) と `--profile strict` (`277/277`) で回帰がないことを確認した
  - [x] `scripts/crater_bidi_adapter.py` を `2212` 行から `2002` 行へ縮めた
- [ ] Step 4: Python に残す層を固定する
  - [x] `CraterBidiSession` と event backlog は transport / pytest plugin core として残す方針を固定する
  - [x] `setup_network_test` の listener / buffer 管理を `CraterBidiSession.capture_named_events()` に移して、fixture 側から direct listener 操作を外す
  - [x] `subscribe_events` の subscription cleanup を `CraterBidiSession.track_subscriptions()` に移して、fixture 側の local state を削る
  - [x] `--profile strict` (`277/277`) と `network/add_data_collector/max_encoded_data_size.py --quick` (`2/2`) で transport helper 化の回帰がないことを確認する
  - [x] `network/add_data_collector/user_contexts.py --quick` (`2/2`) / `session/subscribe/user_contexts.py --quick` (`8/8`) / `session/unsubscribe/subscriptions.py --quick` (`17/17`) で subscription tracker 化の回帰がないことを確認する
  - [x] `create_iframe` / `current_url` / `create_user_context` / `setup_beforeunload_page` / `send_blocking_command` / `wait_for_events` の direct binding 化で fixture の local wrapper を削る
  - [x] `browsing_context/user_prompt_opened/beforeunload.py --quick` (`1/1`) / `network/set_extra_headers/contexts.py --quick` (`7/7`) / `browser/create_user_context --quick` (`182/182`) / `session/unsubscribe/subscriptions.py --quick` (`17/17`) / `--profile strict` (`277/277`) で direct binding 化の回帰がないことを確認する
  - [x] helper package 経由の同期 fixture (`url` / `inline` / `iframe` / `get_test_page` / `get_actions_origin_page` / `compare_png_bidi` / `render_pdf_to_png_bidi` / `assert_pdf_content` / `assert_pdf_dimensions`) を top-level helper に共通化した
  - [x] `browsing_context/{print,capture_screenshot,locate_nodes} --quick` / `network/set_extra_headers/contexts.py --quick` / `--profile strict` (`277/277`) で helper package 層の共通化に回帰がないことを確認する
  - [x] `server_config` を helper package の `buildServerConfig` 経由に移し、Python 側の static dict を削除した
  - [x] `assert_pdf_image` / `fetch` / `configuration` は top-level helper + `functools.partial` に寄せて fixture ごとの local closure を削った
  - [x] `browsing_context/print --quick` (`137/137`) / `network/add_intercept/url_patterns.py --quick` (`69/69`) / `browsing_context/navigation_committed/navigation_committed.py --quick` (`20/20`) / `network/add_data_collector/user_contexts.py --quick` (`2/2`) / `--profile strict` (`277/277`) で回帰がないことを確認した
  - [x] `browser/src/webdriver_fixture_builder` の test は `14/14 pass`
  - [x] `get_element` / `load_static_test_page` / `assert_file_dialog_{canceled,not_canceled}` / `setup_network_test` は top-level helper + task/collector group に寄せ、fixture 内の local async closure を削った
  - [x] `input/set_files --quick` (`46/46`) / `input/perform_actions/wheel --quick` (`17/17`) / `input/file_dialog_opened --quick` (`8/8`) / `session/capabilities/unhandled_prompt_behavior/file --quick` (`12/12`) / `network/set_extra_headers/contexts.py --quick` (`7/7`) / `--profile strict` (`277/277`) で helper 抽出の回帰がないことを確認した
  - [x] module proxy の `send_command -> await future` 重複を `_CommandProxy._command()` に寄せ、`current_session` / `capabilities` の inline ロジックも top-level helper 化した
  - [x] `browser/create_user_context --quick` (`182/182`) / `browsing_context/get_tree --quick` (`36/36`) / `script/get_realms --quick` (`24/24`) / `network/add_intercept --quick` (`210/210`) / `storage --quick` (`342/342`) / `input/set_files --quick` (`46/46`) / `--profile strict` (`277/277`) で proxy 共通化の回帰がないことを確認した
  - [x] `input.setFiles` の `files -> sourcePaths/displayNames` 変換を protocol 側へ移し、Python から `_normalize_files` / `_display_file_name` を削除した
  - [x] wbtest で `input.setFiles(files=...)` alias と basename 導出 (`path/to/noop.txt`, `C:\\tmp\\noop.txt`) を固定した
  - [x] `moon -C browser fmt/info/check src/webdriver` / `just build-bidi` / `.venv/bin/python -m py_compile scripts/crater_bidi_adapter.py` / `input/set_files --quick` (`46/46`) / `--profile strict` (`277/277`) で raw forward 化の回帰がないことを確認した
  - [x] `script.fetchForTest` の `requestHeaders/requestData` 生成を protocol 側へ移し、Python から `_synthesize_request_bytes_value` / `_network_header_entries_from_map` を削除した
  - [x] wbtest で `script.fetchForTest(headersJson/postDataJson/postDataMode)` から request body と header が導出されることを固定した
  - [x] `moon -C browser fmt/info/check src/webdriver` / `just build-bidi` / `.venv/bin/python -m py_compile scripts/crater_bidi_adapter.py` / `network/get_data --quick` (`53/53`) / `network/add_data_collector --quick` (`63/63`) / `network --quick` (`1389/1389`) / `--profile strict` (`277/277`) で fetch request shaping 移行の回帰がないことを確認した
  - [x] `load_static_test_page` の `read -> inline -> navigate -> prepare` を `script.loadStaticTestPageForTest` に畳み、public navigate 相当の commit state を protocol 側で適用するようにした
  - [x] wbtest で `script.loadStaticTestPageForTest` が `allEvents` reset と data URL navigation を同時に満たすことを固定した
  - [x] `moon -C browser fmt/info/check src/webdriver` / `just build-bidi` / `.venv/bin/python -m py_compile scripts/crater_bidi_adapter.py` / `input/set_files --quick` (`46/46`) / `input/perform_actions/wheel --quick` (`17/17`) / `input/release_actions --quick` (`12/12`) / `--profile strict` (`277/277`) で load_static_test_page 1-command 化の回帰がないことを確認した
  - [x] adapter に残っていた dead wrapper `ScriptModule.prepare_loaded_static_test_page()` を削除した
  - [x] file dialog helper は `input.isFileDialogCanceledForTest` に寄せて、Python から JS probe / timeout ベースの assertion helper を削除した
  - [x] wbtest で default `ignore` と explicit `dismiss` の file dialog cancel state query を固定した
  - [x] `moon -C browser fmt/info/check src/webdriver` / `just build-bidi` / `.venv/bin/python -m py_compile scripts/crater_bidi_adapter.py` / `session/capabilities/unhandled_prompt_behavior/file --quick` (`12/12`) / `browser/create_user_context/unhandled_prompt_behavior.py --quick` (`24/24`) / `--profile strict` (`277/277`) で file dialog helper command 化の回帰がないことを確認した
  - [x] `test_origin` / `test_alt_origin` / `test_page*` / frame page fixture は `browser/src/webdriver_fixture_builder` の `buildNamedBidiFixture` に寄せて、Python 側の `url` / `inline` 合成を削除した
  - [x] `moon -C browser test src/webdriver_fixture_builder` (`17/17`) / `browsing_context/get_tree --quick` (`36/36`) / `script/get_realms --quick` (`24/24`) / `storage/get_cookies/partition.py --quick` (`9/9`) / `network/combined/network_events.py --quick` (`6/6`) / `--profile strict` (`277/277`) で named page builder 化の回帰がないことを確認した
  - [x] `current_session` / `session` は custom class をやめて `SimpleNamespace(capabilities=...)` の classic harness stub に整理した
  - [x] `session/new/bidi_upgrade.py --quick` (`4/4`) / `input/perform_actions/pointer_mouse_modifier.py --quick` (`10/10`) / `--profile strict` (`277/277`) で classic stub 整理の回帰がないことを確認した
  - [x] `current_session` / `session` / `default_capabilities` / `capabilities` / `modifier_key` / `wait_for_future_safe` / `current_time` は MoonBit 本体ではなく WPT harness compatibility layer として Python に残す方針を固定する
  - [x] `wait_for_future_safe` は foreign loop polling と通常 timeout を `_wait_for_foreign_loop_future` / `_fixture_wait_for_future_safe` に分離し、WPT compatibility helper として責務を明示した
  - [x] `modifier_key` / `current_time` / capabilities merge も `_fixture_*` helper 名に揃えて、fixture 自体は thin binding に整理した
  - [x] `timeout_multiplier` を internal helper/fixture として分離し、adapter 内の `fetch` / `wait_for_events` は `configuration["timeout_multiplier"]` に依存しない形へ整理した
  - [x] `configuration` は WPT harness compatibility fixture としてのみ残し、内部 fixture からは直接参照しない境界にした
  - [x] `browsing_context/load/load.py --quick` (`10/10`) / `network/before_request_sent/before_request_sent.py --quick` (`24/24`) / `--profile strict` (`277/277`) で harness helper 整理の回帰がないことを確認した
  - [x] `session/new/bidi_upgrade.py --quick` (`4/4`) / `input/perform_actions/pointer_mouse.py --quick` (`21/21`) / `network/response_completed/response_completed.py --quick` (`57/57`) / `--profile strict` (`277/277`) で `configuration` 境界整理の回帰がないことを確認した
  - [x] 現在の `scripts/crater_bidi_adapter.py` は `2002` 行
  - [ ] transport 層以外で `.py` に残っている実装責務を TODO から洗い出して消していく

## WPT サポート状況（2026-03-11）

- 実測コマンド: `npx tsx scripts/wpt-runner.ts <module> --workers 4`
- 全体: `1477 / 1484 passed`（`99.5%`、`7 failed`）

| Module | Passed | Failed | Total | Rate |
|--------|--------|--------|-------|------|
| css-flexbox | 289 | 0 | 289 | 100.0% |
| css-grid | 33 | 0 | 33 | 100.0% |
| css-tables | 32 | 0 | 32 | 100.0% |
| css-display | 79 | 0 | 79 | 100.0% |
| css-box | 30 | 0 | 30 | 100.0% |
| css-sizing | 94 | 0 | 94 | 100.0% |
| css-align | 44 | 0 | 44 | 100.0% |
| css-position | 84 | 0 | 84 | 100.0% |
| css-overflow | 243 | 0 | 243 | 100.0% |
| css-contain | 303 | 0 | 303 | 100.0% |
| css-variables | 107 | 0 | 107 | 100.0% |
| filter-effects | 99 | 7 | 106 | 93.4% |
| compositing | 2 | 0 | 2 | 100.0% |
| css-logical | 5 | 0 | 5 | 100.0% |
| css-content | 2 | 0 | 2 | 100.0% |
| css-multicol | 4 | 0 | 4 | 100.0% |
| css-break | 27 | 0 | 27 | 100.0% |

### 直近の改善

- `css-flexbox`: `285 / 289` -> `289 / 289`
- `css-grid`: `30 / 33` -> `33 / 33`
- `css-tables`: `26 / 32` -> `32 / 32`
- `css-display`: `71 / 79` -> `79 / 79`
- `css-overflow`: `231 / 243` -> `243 / 243`
- `css-multicol`: `2 / 4` -> `4 / 4`
- `css-break`: `4 / 27` -> `27 / 27`
- `css-logical`: `1 / 5` -> `5 / 5`
- `css-content`: 新規導入で `2 / 2`
- `css-position`: `74 / 84` -> `84 / 84`
- `css-sizing`: `88 / 94` -> `94 / 94`
- `css-variables`: `102 / 107` -> `107 / 107`
- `css-align`: `36 / 44` -> `44 / 44`
- `css-contain`: `298 / 303` -> `303 / 303`

### 直近の優先候補

- `filter-effects` の残件（`7 failed`）

### WPT 拡張メモ

- 今回 `wpt.json` に追加:
  - `css-logical`
  - `css-content`
  - `css-multicol`
  - `css-break`
- いまは module ごとの narrow prefix で導入し、広い sub-scope はコメントアウトで保留:
  - `css-content`: `quotes-*`, `element-replacement-*`
  - `css-multicol`: `column-span-*`, `column-balancing-*`, `abspos-*`
  - `css-break`: `orphans-*`, `widows-*`, `page-break-*`, `break-at-end-*`
- 後回しだが今後対応する候補:
  - `css-ruby`
  - `css-writing-modes`
  - `css-pseudo`
  - `css-text`
  - `css-transforms`
  - `css-backgrounds`
  - `css-color`

### WPT runner / intrinsic provider メモ

- WPT 用の外部 intrinsic provider フックを追加:
  - text: `set_text_metrics_provider`（`wpt-runner` は `CRATER_TEXT_MODULE` または `mizchi/text` を自動探索）
  - image: `set_image_intrinsic_size_provider`（`CRATER_IMAGE_MODULE` または `mizchi/image`）
  - 画像ローカル寸法解決フォールバックは `CRATER_IMAGE_FILE_RESOLVE=1` のときのみ有効

## Browser 挙動確認 WPT（2026-03-12）

- 目的:
  - layout engine の互換性ではなく、「ブラウザとして何が動くか」を継続確認する
  - DOM API と WebDriver BiDi を別 KPI で追い、browser shell / automation / app 実行の土台を見える化する

### 実行順

- [x] P0: WebDriver BiDi の bootstrap を直して `strict` を再び gate に戻す
  - コマンド: `just wpt-webdriver-profile strict`
  - 2026-03-12 baseline:
    - 直前までは `globalThis.navigator.userAgent = normalized` が `TypeError`
    - 波及で `ws://127.0.0.1:9222` が落ち、`ConnectionRefusedError` に連鎖していた
  - 2026-03-12 現在:
    - `just wpt-webdriver-profile strict` -> `277 / 277 passed`
    - bootstrap failure は `0`

- [x] P1: DOM core の baseline を取り、selector / tree mutation の穴を先に埋める
  - コマンド: `just wpt-dom-all`
  - 2026-03-12 baseline:
    - `8908 passed, 81 failed, 8 errors`
  - 2026-03-12 現在:
    - `9296 passed, 0 failed, 0 errors`
  - 片付けたクラスター:
    - selector / HTML case semantics
    - tree mutation / `insertAdjacent*`
    - attribute / naming / `NamedNodeMap`
    - `cloneNode` / `isEqualNode` / `adoptNode`
    - `rootNode` / shadow root / `remove-unscopable`
  - KPI:
    - [x] `Element-*` の fail/error file を `0`
    - [x] `ParentNode-*` の fail/error file を `0`
    - [x] `wpt/dom/nodes` の error を `8 -> 0`

- [x] P2: MutationObserver を独立クラスターとして詰める
  - コマンド: `just wpt-dom \"MutationObserver-*\"`
  - 2026-03-12 baseline:
    - `MutationObserver-characterData`
    - `MutationObserver-document`
    - `MutationObserver-sanity`
    - `MutationObserver-takeRecords`
    - `MutationObserver-cross-realm-callback-report-exception`
  - KPI:
    - [x] `MutationObserver-*` の fail/error file を `0`
    - [x] parser insertion / takeRecords / option validation を回帰 test で固定する

- [x] P3: BiDi の browser surface を module 単位で広げる
  - 優先順:
    - `session`
    - `browsing_context`
    - `script`
    - `input`
    - `network`
  - コマンド:
    - `just wpt-webdriver session`
    - `just wpt-webdriver browsing_context`
    - `just wpt-webdriver script`
    - `just wpt-webdriver input`
    - `just wpt-webdriver network`
  - 2026-03-12 現在:
    - `session` -> `130 / 130 passed`
    - `browsing_context` -> `1008 / 1008 passed`
    - `script` -> `1025 / 1025 passed`
    - `input` -> `708 / 708 passed`
    - `network` -> `1389 / 1389 passed`
  - KPI:
    - [x] `session` module を green にする
    - [x] `browsing_context/get_tree` と `script/get_realms` を strict 以外でも安定 green に保つ
    - [x] `input` を通して click / key / wheel の browser 操作面を固定する

- [x] P4: SVG / namespace を browser DOM として確認する
  - コマンド:
    - `npx tsx scripts/wpt-dom-runner.ts --svg`
  - 2026-03-12 現在:
    - `20 passed, 0 failed, 0 errors`
  - KPI:
    - [x] `svg` category を green に保つ

### 補足

- `css-*` WPT は引き続き layout regression の主指標として使う
- browser の挙動確認では `wpt-dom` と `wpt-webdriver` を優先し、paint / visual fidelity は別 benchmark と fixture snapshot で追う
- 統合確認:
  - `just test-playwright` -> `13 / 13 passed`
  - `just test-playwright-adapter` -> `30 / 30 passed`
  - `just test-preact` -> `49 / 49 passed`

## パフォーマンス改善メモ（2026-03-11）

- 現在の目安:
  - `node_build_large_2k5`: `997.07 µs`
  - `node_only_large_2k5`: `1.73 ms`
  - `render_large_2k5`: `4.04 ms`
  - `layout_only_large`: `2.15 ms`
  - `layout_only_large_card_body`: `1.56 ms`
  - `layout_only_large_simple_cards`: `228.10 µs`
  - `paint_viewport_culling_3280`: `677.83 µs`
  - `paint_stacking_sort`: `92.61 µs`
  - `paint_scroll_sim_50`: `8.02 ms`
  - `browser_text_dashboard`: `8.49 ms`
  - `browser_text_article`: `9.79 ms`
  - `browser_sixel_scroll_500`: `295.36 ms`
- 優先タスク:
  - [ ] `node_build_large_2k5` を `style compute` と `node assembly` に分解する benchmark を追加
  - [ ] browser shell の fixed benchmark に screenshot diff か AOM snapshot を併設して、速度だけでなく見た目回帰も追えるようにする
  - [ ] inline-only style cache を inherited default 以外にも安全に効かせる key 設計を詰める
  - [ ] `layout_only_large_card_body` をさらに `wrapper/text/footer` 単位で分解して、支配コストを固定観測する
  - [ ] `card_body` の block wrapper / empty leaf path をもう一段削る
  - [ ] benchmark の variance が大きい `render_large_2k5` は isolated repeat 測定手順を追加する
- 失敗した案のメモ:
  - [ ] `collect_inline_content()` の no-stylesheet pre-scan fast path は悪化したので、再設計するまで再投入しない

## Paint 実サイト baseline（2026-03-12）

- 追加した tooling:
  - `pnpm capture:realworld -- <url> --name <slug>`
  - `pnpm bench:realworld -- <snapshot...> --iterations 1 --warmup 0 --save-images`
  - `just capture-realworld ...`
  - `just bench-realworld ...`
- 取得した snapshot:
  - built-in: `github-mizchi`
  - local: `real-world/mdn-wasm-text`
  - local: `real-world/playwright-intro`
- baseline:
  - `playwright-intro`
    - Chromium: `load 119.07 ms`, `shot 56.39 ms`, `load+shot 58.90 ms`
    - Crater: `load 75.43 ms`, `shot 4.37 ms`, `load+shot 47.30 ms`
    - ただし `output/playwright/real-world-paint/playwright-intro/crater.png` は `105B` しかなく、blank/欠落描画の疑いが強い
  - `github-mizchi`
    - Chromium: `load 205.02 ms`, `shot 39.67 ms`, `load+shot 85.68 ms`
    - Crater: `browsingContext.captureScreenshotData` が `60s` 超で timeout
  - `mdn-wasm-text`
    - Chromium: `load 335.24 ms`, `shot 58.80 ms`, `load+shot 77.06 ms`
    - Crater: 単体実行でも `browsingContext.captureScreenshotData` が `60s` 超で timeout
- 注意:
  - `browsingContext.captureScreenshotData` は現状 synthetic screenshot で、actual paint benchmark ではない
  - paint の主指標は `/Users/mz/ghq/github.com/mizchi/crater/browser/src/shell/browser_bench_wbtest.mbt` 側へ寄せる
- actual paint baseline:
  - 初回 baseline:
    - `browser_sixel_github_mizchi`: `64.01 ms ± 11.94 ms`
  - 共有 render pass 導入後:
    - `browser_sixel_github_mizchi`: `22.60 ms ± 1.79 ms`
    - `browser_sixel_github_mizchi_node`: `6.97 ms ± 239.38 µs`
    - `browser_sixel_github_mizchi_layout`: `7.22 ms ± 224.60 µs`
    - `browser_sixel_github_mizchi_shared_node_layout`: `7.13 ms ± 661.42 µs`
    - `browser_sixel_github_mizchi_paint_tree`: `0.06 µs ± 0.01 µs`
    - `browser_sixel_github_mizchi_sixel_encode`: `12.82 ms ± 1.37 ms`
  - 見立て:
    - `render_to_node + render_with_external_css` の二重計算が主要な無駄だった
    - shared 化後の主 bottleneck は `sixel_encode`
- 次の優先タスク:
  - [x] `browser_sixel_github_mizchi` を `render_to_node/layout/paint_tree/sixel_encode` に分解する
  - [x] `render_to_sixel_with_css` の node/layout 二重構築を shared pass に統合する
  - [ ] `@sixel.render_paint_node_to_sixel_scrolled` を profile して encode hot path を詰める
  - [ ] `captureScreenshotData` を `paint tree build` / `raster` / `PNG encode` に分解して timer を仕込む
  - [ ] PNG ではなく raw RGBA か PPM を返す debug path を追加して、encode cost を分離する
  - [ ] screenshot benchmark に visual sanity check を追加して、blank だが速い出力を除外する
  - [ ] viewport 単位の clip / occlusion pruning を paint tree 生成前に入れる
  - [ ] repeated screenshot で再利用できる display list / clipped paint subtree cache を検討する

## css-flexbox WPT 進捗（2026-03-10）

- 現在: `289 / 289 passed`（`0 failed`）
- 今回の更新:
  - `align-baseline.html`
  - `align-content-wrap-004.html`
  - `flex-aspect-ratio-img-column-012.html`
  - `flex-aspect-ratio-img-column-018.html`
  - `flex-aspect-ratio-img-row-015.html`
  - `aspect-ratio-transferred-max-size.html`
  - `flex-direction-column-reverse-001-visual.html`
  - `flex-direction-row-reverse-001-visual.html`
  - `flex-direction-row-reverse.html`
  - `flex-direction-row-vertical.html`
  - `gap-001-lr.html`
  - `gap-001-rl.html`
  - `gap-002-lr.html`
  - `gap-002-rl.html`
  - `gap-003-lr.html`
  - `gap-003-rl.html`
  - `gap-006-rl.html`
  - `flex-inline.html`
  - `text-overflow-on-flexbox-001.html`
  - `flex-container-min-content-001.html`
  - `flex-vertical-align-effect.html`
  - `overflow-top-left.html`
  - `table-with-infinite-max-intrinsic-width.html`
- 実行コマンド: `npx tsx scripts/wpt-runner.ts css-flexbox`
- 追加した回帰テスト:
  - `src/renderer/render_test.mbt`: `wpt_column_flex_align_items_baseline_falls_back_to_cross_side`
  - `src/renderer/render_test.mbt`: `wpt_align_content_wrap_004_column_flex_items_use_fit_content_cross_size`
  - `src/renderer/render_test.mbt`: `wpt_flex_aspect_ratio_img_column_012_like_min_height_does_not_set_base_size`
  - `src/renderer/render_test.mbt`: `wpt_flex_aspect_ratio_svg_column_018_like_transferred_max_width_caps_height`
  - `src/renderer/render_test.mbt`: `wpt_flex_aspect_ratio_svg_row_015_like_transferred_max_height_caps_width`
  - `src/renderer/render_test.mbt`: `wpt_row_reverse_default_justify_content_uses_main_start`
  - `src/renderer/render_test.mbt`: `wpt_column_reverse_default_justify_content_uses_main_start`
  - `src/renderer/render_test.mbt`: `wpt_row_direction_matches_inline_axis_in_vertical_writing_mode`
  - `src/renderer/render_test.mbt`: `wpt_gap_vertical_rl_wrap_progression_is_mirrored`
  - `src/layout/inline/inline_test.mbt`: `ifc_negative_top_margin_atomic_inline_keeps_line_box_band`
  - `src/layout/flex/flex_test.mbt`: `row_flex_direct_text_leaf_keeps_single_line_cross_size_at_intrinsic_width`
  - `src/renderer/render_test.mbt`: `wpt_flex_container_min_content_uses_item_min_content_contribution`
  - `src/renderer/render_test.mbt`: `wpt_flex_vertical_align_effect_uses_small_text_input_metrics`
  - `src/renderer/render_test.mbt`: `wpt_overflow_top_left_keeps_stretched_item_inside_column_cross_size`
  - `src/layout/table/table_test.mbt`: `table_percent_column_consumes_remaining_width_after_fixed_sibling`
  - `src/css/cascade/cascade_wbtest.mbt`: `later author stylesheet wins at same specificity`
  - `src/css/cascade/cascade_wbtest.mbt`: `later indexed stylesheet wins at same specificity`
  - `src/renderer/renderer_test.mbt`: `later body font style overrides earlier reset style`
  - `src/renderer/renderer_test.mbt`: `later font shorthand overrides earlier reset longhands in computed style`
- 参考:
  - `css-grid`: `30 / 33 passed`（既知の 3 failure）

## 今回対応済み（2026-03-10）

- [x] `align-baseline.html`
- [x] `align-content-wrap-004.html`
- [x] `flex-aspect-ratio-img-column-012.html`
- [x] `flex-aspect-ratio-img-column-018.html`
- [x] `flex-aspect-ratio-img-row-015.html`
- [x] `aspect-ratio-transferred-max-size.html`
- [x] `flex-direction-column-reverse-001-visual.html`
- [x] `flex-direction-row-reverse-001-visual.html`
- [x] `flex-direction-row-reverse.html`
- [x] `flex-direction-row-vertical.html`
- [x] `gap-001-lr.html`
- [x] `gap-001-rl.html`
- [x] `gap-002-lr.html`
- [x] `gap-002-rl.html`
- [x] `gap-003-lr.html`
- [x] `gap-003-rl.html`
- [x] `gap-006-rl.html`
- [x] `flex-inline.html`
- [x] `text-overflow-on-flexbox-001.html`
- [x] `flex-container-min-content-001.html`
- [x] `flex-vertical-align-effect.html`
- [x] `overflow-top-left.html`
- [x] `table-with-infinite-max-intrinsic-width.html`

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

- 注: この節は 2026-02-27 時点の履歴メモ。現状は上のサマリを参照（2026-03-11 時点で `303 / 303 passed`）。

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
