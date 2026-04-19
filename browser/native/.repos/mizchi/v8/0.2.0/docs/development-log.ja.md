# Development Log

[English](development-log.md) | [日本語](development-log.ja.md)

この文書は `mizchi/v8` の実装状況、設計メモ、既知の制約を追うためのものです。利用者向けの導線は [README.ja.md](../README.ja.md)、完全な public surface は [src/README.mbt.md](../src/README.mbt.md) に置いています。

## ゴール

- MoonBit から V8 を扱うための薄い native binding を作る
- runtime のロジックはなるべく MoonBit 側に寄せる
- Rust 側は isolate/context 管理と C ABI の橋渡しに留める
- Node / Deno 風イベントループの実験土台を作る

## 現在の実装状況

### Core Runtime

- [x] `runtime_new`, `runtime_new_with_snapshot`
- [x] `eval_string`, `eval_async_string`, `eval_module_string`
- [x] named script origin / entry module specifier
- [x] `perform_microtask_checkpoint`
- [x] `V8Error` ベースの error contract

### Value Bridge

- [x] `eval_json`, `eval_bytes`, `eval_async_json`, `eval_async_bytes`
- [x] `set/get/call_global_json`
- [x] `set/get/call_global_bytes`

### Promise / Module Handle

- [x] `PromiseHandle::state`, `result_*`, `await_*`
- [x] `ModuleHandle::export_names`, `get_export_*`, `call_export_*`
- [x] `ModuleEvalHandle` による top-level await module の非同期評価

### Module Loading

- [x] `Runtime::load_module`, `load_modules`
- [x] static import / dynamic import
- [x] relative specifier resolution
- [x] preload module を含む reusable runtime image

### Snapshot / Bootstrap

- [x] `snapshot_create`, `snapshot_extend`
- [x] `SnapshotBuilder`
- [x] `RuntimeBuilder`
- [x] `RuntimeImage`

### Host Bridge

- [x] sync JSON op
- [x] sync bytes op
- [x] async JSON op queue
- [x] async bytes op queue
- [x] sync JSON callback
- [x] sync bytes callback
- [x] async host callback
- [x] richer host op surface

## 現在の制約

- native target のみを対象にしている
- 互換層はまだ部分実装で、Deno 側は opt-in の `Deno.core` op/util shim と最小の top-level `Deno` helper、Node 側は `global` / `process` / `Buffer` の最小 shim に限る
- 非同期 host 連携は queue ベースの op に加えて direct callback / result callback でも扱え、失敗 reason には String だけでなく JSON value も使える
- embedder 側 resource table を持てるようになり、`Deno.core.resources` / `close` / `tryClose` はその table を参照し、resource ごとに ref state も持てる
- MoonBit async event loop で Deno 風 pending op を駆動できるが、同時に回せる loop は 1 runtime あたり 1 本で、同じ lane の手動 `take_async_*_op` loop とは混在させない前提
- `Deno.sleep` と最小 `setTimeout` / `clearTimeout` / `setInterval` / `clearInterval` は hidden async op として MoonBit async event loop に載せつつ、sleep/timer resource としても見える
- `with_runtime_async` と `eval_promise_*_async` で、PromiseHandle を手でつながなくても MoonBit async 側から同じ loop を使える
- top-level await module も `Runtime::eval_module_handle_string_async` で同じ loop に直接載せられる
- 現状は mooncakes から import する consumer module 側にも 1 回限りの設定が必要だが、同梱 setup script で一般的な導線を自動化でき、local path dependency でも `--build-bridge` を付ければ bridge build まで寄せられる
- `oden/` 配下には root とは別の `moon.mod.json` を持つ sibling module を切ってあり、`mizchi/v8` を local path dependency として使いながら CLI 層を別管理できる。現状の MoonBit-first router は `run` / `check` / `test` / `bundle` / `fmt` / `info` / `task` / `plan` と help/version/manifest を持つ

## 設計メモ

- MoonBit 側は `Runtime` と handle 群、Rust 側は小さい staticlib bridge に分離する
- `rusty_v8` の複雑な初期化やリンクは Rust 側に閉じ込める
- public API は MoonBit で安定化し、Rust 実装は再生成・差し替えしやすい構造を保つ
- 値 bridge はまず JSON / bytes の 2 lane に絞り、イベントループ実験で必要な経路を先に揃える
- 互換層は shared helper と Deno / Node の shim に分離し、当面は Deno 側の surface 拡張を優先する
- Deno core の `run_event_loop` 相当は Rust future executor の代わりに MoonBit async task group で回し、pending op を queue から task へ dispatch する

## 次に見る場所

- package API 一覧: [src/README.mbt.md](../src/README.mbt.md)
- リリース履歴: [CHANGELOG.md](../CHANGELOG.md)
- Rust bridge 実装: [native/bridge/src/lib.rs](../native/bridge/src/lib.rs)
