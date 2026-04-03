# Flaker Runbook

`crater` での `flaker` 運用を、前提コンテキストなしで再現するための入口だけをまとめる。

補足:
- local/CI の CLI 解決は `METRIC_CI_CLI_PATH` / `METRIC_CI_ROOT` を最優先に見る
- その次に `node_modules/@mizchi/flaker`、sibling `../metric-ci` を見て、最後に legacy の `flaker` path を見る
- つまり `crater` から見る実体は source repo より `metric-ci` CLI が正
- CI は private npm package を優先し、未導入の間だけ `metric-ci` source checkout に fallback する
- `metric-ci` に寄せる `contract/core` は、出自が `crater` なら「crater から切り出した source」と明記して扱う

## 入口

### 0. compact entrypoint

```bash
just flaker help
just flaker api
just flaker config list
just flaker config check
just flaker config report .flaker/report
just flaker config affected src/layout/block.mbt tests/paint-vrt.test.ts
```

- `just flaker ...` を日常運用の入口にする
- `just flaker api` で API 体系の要約を出せる
- `config report` が推奨形で、top-level の `report` などは後方互換 alias
- 高度な flag が必要なときだけ既存の `just flaker-*` / `node scripts/*` へ降りる

### 1. 設定と所有関係を見る

```bash
just flaker config list
just flaker config check
just flaker config report .flaker/report
just flaker config affected src/layout/block.mbt tests/paint-vrt.test.ts
```

- `flaker config list`: `flaker.star` から task と spec 所有を一覧する
- `flaker config check`: `flaker.star` と Playwright spec の整合性を検証する
- `flaker config report`: config/ownership の markdown/json summary を出す
- `flaker config affected`: changed path から走らせる task を解決する

### 2. 単一 task を dogfood する

```bash
just flaker task config paint-vrt
just flaker task exec paint-vrt flaky --limit 20
just flaker task import paint-vrt paint-vrt-report.json
just flaker task record paint-vrt --workers 1
just flaker task summary paint-vrt .flaker/task-summary
just flaker task sample paint-vrt --count 20
just flaker task run paint-vrt --max-failures 1
```

- `flaker-task-config`: `flaker.star` から task-scoped `flaker.toml` を生成する
- `flaker-task-exec`: task-scoped config で任意の `flaker` サブコマンドを実行する
- `flaker-task-import`: 既存 Playwright JSON report を shared store に import する
- `flaker-task-record`: Playwright task 実行、report 保存、`flaker import` まで一度に行う
- `flaker-task-summary`: task 単位の `flaker eval/reason` を markdown/json に落とす
- `flaker-task-sample`: `task exec <task> sample ...` の shorthand
- `flaker-task-run`: `task exec <task> run ...` の shorthand

### 3. 日次バッチを再現する

```bash
just flaker batch plan
just flaker batch plan flaker-daily-plan
just flaker batch summary flaker-daily-artifacts
```

- `flaker-batch-plan`: nightly 対象 task の matrix を作る
- `flaker-batch-summary`: nightly artifact を集約して全体 summary を作る

### 4. CI / report の入口

```bash
just flaker config report .flaker/report
just flaker quarantine report .flaker/quarantine
just flaker upstream inventory .flaker/upstream
just playwright-report-summary paint-vrt-report.json paint-vrt
just playwright-report-diff base.json head.json paint-vrt
just wpt-vrt-report path/to/shard.json shard-1
just wpt-vrt-report-aggregate wpt-vrt-summary
```

- `flaker-report`: config/ownership の CI summary
- `flaker-quarantine-report`: quarantine manifest の CI summary
- `flaker-upstream-inventory`: `metric-ci (flaker)` と `crater` の境界 inventory
- `playwright-report-summary`: raw Playwright JSON を normalized summary に変換する
- `playwright-report-diff`: normalized summary の base/head diff を出す
- `wpt-vrt-report`: WPT VRT shard を summary 化する
- `wpt-vrt-report-aggregate`: WPT VRT shard summary を集約する

### 5. `metric-ci (flaker)` への upstream 境界を見る

```bash
just flaker upstream inventory
just flaker upstream export playwright-report-core
just flaker upstream export all /tmp/flaker-playwright-report-core/from-crater
```

- `flaker-upstream-inventory`: `metric-ci (flaker)` に寄せる層と `crater` に残す層を一覧する
- `flaker-upstream-export`: upstream 候補 group を staging export する
- `flaker-upstream-export all`: `from-crater/` に `crater` 由来の参照実装と参照テストを一括で置く
- upstream 候補は「`crater` から切り出された source 群」であることを inventory/export に明記する

## 最短フロー

### ローカルで 1 task を記録して flaky を見る

```bash
just flaker config report .flaker/report
just flaker task import paint-vrt paint-vrt-report.json
just flaker task record paint-vrt
just flaker task summary paint-vrt
just flaker task sample paint-vrt --count 20
```

### changed path から対象 task を決める

```bash
just flaker config affected src/layout/block.mbt tests/paint-vrt.test.ts
just flaker task record paint-vrt
```

### nightly artifact を集約する

```bash
just flaker batch plan
just flaker batch summary flaker-daily-artifacts
```

## API 体系

`crater` 側の script は基本的に次の層で揃える。

1. `contract`
   型契約だけを持つ。wrapper を import しない。
   例: `playwright-report-contract.ts`, `flaker-task-summary-contract.ts`, `flaker-quarantine-contract.ts`

2. `parser`
   `metric-ci` 側が理解する設定フォーマットを pure に parse する。
   例: `flaker-config-parser.ts`

3. `core`
   pure な build / summarize / diff / render を持つ。repo 固有の file scan をしない。
   例: `playwright-report-summary-core.ts`, `playwright-report-diff-core.ts`, `flaker-task-summary-core.ts`, `flaker-batch-summary-core.ts`, `flaker-quarantine-summary-core.ts`, `flaker-batch-plan-core.ts`

3.5. `task/core helper`
   pure な task 解決 helper。`core` が task summary を必要とするときの共有部品。
   例: `flaker-config-task.ts`

4. `loader`
   repo 上の file / artifact / spec ownership を解決して core input に変換する。
   例: `flaker-batch-summary-loader.ts`, `flaker-quarantine-loader.ts`

5. `adapter / plan / execution`
   `crater` 固有の task graph や workspace 構成を `flaker` の入力へ変換する。
   例: `flaker-task-config.ts`, `flaker-task-runtime.ts`, `flaker-task-record-plan.ts`, `flaker-task-record-execution.ts`, `flaker-batch-plan.ts`

6. `CLI wrapper`
   `parse args -> load -> core -> writes/stdout` の façade。
   例: `flaker-config.ts`, `flaker-quarantine.ts`, `flaker-batch-summary.ts`, `flaker-task-summary.ts`, `flaker-task-record.ts`

## `metric-ci (flaker)` に寄せるもの / `crater` に残すもの

### `metric-ci (flaker)` に寄せる

- config parser / contract / task resolver / affected selection core / summary core / report renderer
- config task resolver (`resolveTaskSummary`, `resolveTaskSummaries`, `isFilteredTask`)
- normalized report の contract / summary / diff
- task summary contract / core
- batch plan core / batch aggregate core
- quarantine contract / parser / match / expiry / summary / report
- これらは `crater` から切り出した source 群として管理し、出自を inventory で追えるようにする

この層は `crater` の task graph や renderer を知らなくても成立する。

### `crater` に残す

- repo 上の spec discovery / ownership 解決
- task-scoped `flaker.toml` 生成
- task workspace の構築
- Playwright task 実行、report 保存、artifact 配置
- VRT / WPT / paint diff の domain metadata

この層は `crater` の repo layout と renderer domain に依存する。

## 参照順

1. `justfile`
   入口のコマンド名を見る
2. `docs/flaker-runbook.md`
   どの入口を使うか決める
3. `scripts/*-core.ts`
   pure な build/summarize を追う
4. `scripts/*-loader.ts`
   repo 上の input 解決を見る
5. `scripts/*-record.ts` / `scripts/*-summary.ts`
   実行時の wrapper を追う

## 現状の基準

- 日常の入口は `just ...`
- `metric-ci (flaker)` に寄せるものは `contract/core`
- `crater` に残すものは `adapter/loader/workspace bridge`
- `script-boundary.test.ts` で wrapper 逆依存を防ぐ
