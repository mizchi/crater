# mizchi/v8

[English](README.md) | [日本語](README.ja.md)

`mizchi/v8` は、MoonBit から V8 を扱うための native 専用バインディングです。Node や Deno のような埋め込みランタイムを、MoonBit 主導で試作するための土台として作っています。

> Experimental release note: Moon `0.1.20260309` / MoonBit `v0.8.3` 時点では、consumer 側に prebuild と link の設定がまだ必要です。

## できること

- script / module を MoonBit から評価する
- JS の値を `String` / JSON / `Bytes` でやり取りする
- pending Promise や top-level await module を host 側 handle として保持する
- preload module、relative import、dynamic import を扱う
- snapshot / runtime image を作って isolate 起動を再利用する
- `MoonBit.opSync(...)` / `MoonBit.opAsync(...)` を使って host 側イベントループを試す
- Deno 風 `opAsync` / top-level await を MoonBit async の event loop で駆動できる
- opt-in の Deno shim を preload して、`Deno.core.op*` / utility helper と最小 `Deno.inspect` / `cwd` / `execPath` を使える
- opt-in の Node 風 shim を preload して、`global` / `process.nextTick` / `Buffer` を最小構成で使える
- `oden/` 配下に sibling module を置いて、`mizchi/v8` を土台にした別 runtime/CLI 実験を分離できる

## ステータス

- バージョン: `0.2.0`
- 対応 target: `native`
- embedder 実験用として使える状態です
- 実装状況と未実装項目は [docs/development-log.ja.md](docs/development-log.ja.md) に分離しています

## mooncakes から使う

```bash
moon add mizchi/v8
node .mooncakes/mizchi/v8/src/scripts/setup-consumer.mjs --main-pkg cmd/main/moon.pkg
moon check --target native
```

Moon `0.1.20260309` / MoonBit `v0.8.3` 時点では、dependency 側の native hook は consumer に自動伝播しません。そこで同梱の setup helper が、よくある mooncakes 利用手順をまとめて処理します。

- `scripts/mizchi-v8-consumer-prebuild.mjs` を配置する
- `moon.mod.json` に `--moonbit-unstable-prebuild` を追加する
- 指定した main package に `${build.MIZCHI_V8_CC_LINK_FLAGS}` と `"supported-targets": "native"` を追加する

main package が別の場所にある場合は明示してください。

```bash
node .mooncakes/mizchi/v8/src/scripts/setup-consumer.mjs --main-pkg app/server/moon.pkg
```

local path dependency で install hook が走らない場合は、同じ helper に `--build-bridge` を付けて checkout 側の native bridge も先に作れます。

```bash
node ../v8.mbt/src/scripts/setup-consumer.mjs --module-root . --main-pkg cmd/main/moon.pkg --build-bridge
```

### 前提

- `git`
- `bash`
- `cargo` を含む Rust toolchain
- native C/C++ toolchain
- 同梱 setup / prebuild script 用の `node`
- GitHub、crates.io、`rusty_v8` release mirror へアクセスできるネットワーク

公開 package 側でも `postadd` hook で bridge build は走ります。consumer module 側の 1 回限りの設定はまだ必要ですが、上の setup script で一般的な mooncakes 導線は自動化できます。

### ソースから開発する

```bash
git clone https://github.com/mizchi/v8.mbt
cd v8.mbt
just bootstrap
just test
```

`just bootstrap` は checkout 済みの repo 向けです。mooncakes から使う利用者は通常これを手で叩く必要はありません。

## 最小例

一発評価だけならトップレベル helper で十分です。

```moonbit
match @v8.eval_string("'Hello' + ', MoonBit!'") {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

長寿命 `Runtime` を使うと、module preload や snapshot 初期化をまとめて扱えます。

```moonbit
let builder = @v8.runtime_builder_new()
  .eval_snapshot("globalThis.base = 40;")
  .load_module("dep", "export const answer = globalThis.base + 2;")

match builder.with_runtime(fn(runtime) {
  runtime.eval_async_json(
    "(async () => { let mod = await import('dep'); return { answer: mod.answer } })()",
  )
}) {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

host 側イベントループの実験では、`opAsync` を queue として捌けます。

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.register_async_json_op("add"))
    let promise = runtime.eval_promise_string("MoonBit.opAsync('add', [20, 22])")
    match runtime.take_async_json_op() {
      Ok(Some(op)) => ignore(runtime.resolve_async_json_op(op.id, "{\"answer\":42}"))
      _ => ()
    }
    println(
      promise
      |> Result::map(fn(handle) { handle.await_json() })
      |> Result::flatten,
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

## 主要 API

- 評価系: `Runtime`, `eval_*`, `eval_module_*`, `perform_microtask_checkpoint`
- 非同期 handle: `PromiseHandle`, `ModuleEvalHandle`, `ModuleHandle`
- bootstrap: `Runtime::load_module`, `RuntimeBuilder`, `SnapshotBuilder`, `RuntimeImage`
- 値 bridge: `set/get/call_global_json`, `set/get/call_global_bytes`, `eval_json`, `eval_bytes`
- host bridge: `register_*_callback`, `register_*_result_callback`, `register_*_result_callback_with_json_error`, `register_*_op`, `take_*_op`, `resolve_*_op`, `reject_*_op`, `reject_async_*_op_with_json`
- resource table: `add_resource`, `add_resource_with_close`, `ref_resource`, `unref_resource`, `list_resources`, `close_resource`, `try_close_resource`
- direct async callback: `register_async_json_callback`, `register_async_bytes_callback`, `register_async_*_result_callback`
- async event loop bridge: `with_runtime_async`, `register_async_*_task_*`, `eval_promise_*_async`, `PromiseHandle::await_*_async`, `ModuleEvalHandle::await_ready_async`, `Runtime::eval_module_handle_string_async`
- deno compat: `Runtime::install_deno_core_compat`, `RuntimeBuilder::with_deno_core_compat`, `SnapshotBuilder::with_deno_core_compat`, `Deno.sleep`, 最小 `setTimeout` / `clearTimeout` / `setInterval` / `clearInterval`, `Deno.core.refOpPromise` / `unrefOpPromise`
- minimal node shim: `Runtime::install_node_compat`, `RuntimeBuilder::with_node_compat`, `SnapshotBuilder::with_node_compat`
- 失敗 reason は String に加えて JSON value でも返せます

完全な public surface と追加例は [src/README.mbt.md](src/README.mbt.md) を参照してください。

## 制約

- native target 専用です
- embedder 向けの低レベル binding が主眼で、Deno 互換は `Deno.core` の op/util shim と最小の top-level `Deno` utility に限り、Node 互換も `global` / `process` / `Buffer` の最小 shim に限ります
- MoonBit async event loop driver は 1 runtime あたり 1 本だけ同時に回せて、同じ lane の `take_async_*_op` 手動 loop とは混在させない前提です
- `Deno.sleep` と最小 `setTimeout` / `clearTimeout` / `setInterval` / `clearInterval` は queue ベース async op の上に載せつつ runtime resource table にも載り、`Deno.core.refOpPromise` / `unrefOpPromise` はその ref state を更新します
- `oden/` は root とは別の `moon.mod.json` を持つ sibling module として切り出してあり、`mizchi/v8` を local path dependency として使いながら CLI 層を別管理できます。現状は `run` / `check` / `test` / `bundle` / `fmt` / `info` / `task` / `plan` を MoonBit-first に張り替える router をこの module 側に置いています
- mooncakes の consumer 側では現在も 1 回限りの setup が必要です
- local path dependency では install hook は自動実行されませんが、`setup-consumer.mjs --build-bridge` で同等の初期化を寄せられます

## ドキュメント

- パッケージ API と実行例: [src/README.mbt.md](src/README.mbt.md)
- 実装状況と今の制約: [docs/development-log.ja.md](docs/development-log.ja.md)
- English README: [README.md](README.md)
- リリース差分: [CHANGELOG.md](CHANGELOG.md)

## ライセンス

Apache-2.0
