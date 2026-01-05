# Scheduler Module

ブラウザの Event Loop / Task Scheduler に相当するモジュール。
HTML評価のタスクをキュー管理し、並列実行可能性を判定する。

## 設計方針

1. **外部委譲**: ネットワーク、非同期ランタイム、スクリプト実行は外部に委譲
2. **内部実行**: スタイル計算、レイアウト計算は同期的に内部実行可能
3. **依存グラフ**: タスク間の依存関係を明示的に管理
4. **並列性判定**: 各タスクに並列実行可能かのフラグを付与

## ブラウザとの対応

| Browser Concept | This Module |
|-----------------|-------------|
| Event Loop | `Scheduler` |
| Task Queue | `TaskQueue` |
| Task Source | `TaskSource` |
| Microtask | (未実装、必要に応じて追加) |
| parser-blocking | `TaskConstraint::Blocking` |

## ファイル構成

```
scheduler/
├── README.md          # このファイル
├── moon.pkg.json      # パッケージ設定
├── task.mbt           # Task型定義
├── queue.mbt          # TaskQueue管理
├── scheduler.mbt      # Scheduler本体
└── task_test.mbt      # テスト
```

## 実装計画

### Phase 1: 基本型定義 (task.mbt) ✅

- [x] `TaskId` - タスク識別子
- [x] `TaskSource` - タスクの種類 (DOM, Styling, Layout, Networking, Scripting, ImageDecode)
- [x] `TaskConstraint` - 実行制約 (MainThreadOnly, Parallel, Blocking)
- [x] `TaskState` - タスク状態 (Pending, Ready, Running, Completed, Cancelled, Failed)
- [x] `TaskAction` - 実行内容 (ParseHTMLChunk, ParseCSS, ComputeStyle, ComputeLayout, FetchResource, DecodeImage, ExecuteScript)
- [x] `Task` - タスク本体
- [x] `TaskResult` - 実行結果
- [x] `ResourceType` - リソースの種類

### Phase 2: キュー管理 (queue.mbt) ✅

- [x] `TaskQueue` - 基本キュー
- [x] 優先度付きソート (`sort_by_priority`)
- [x] `SourceQueueManager` - ソース別キュー管理

### Phase 3: スケジューラ本体 (scheduler.mbt) ✅

- [x] `Scheduler` 構造体
- [x] `enqueue` - タスク追加
- [x] `enqueue_after` - 依存付きタスク追加
- [x] `enqueue_with_priority` - 優先度付きタスク追加
- [x] `poll_ready` - 実行可能タスク取得
- [x] `poll_parallel` - 並列実行可能タスク取得
- [x] `poll_main_thread` - メインスレッド専用タスク取得
- [x] `complete` - タスク完了通知
- [x] `fail` / `cancel` - 失敗・キャンセル通知
- [x] `resolve_dependencies` - 依存解決
- [x] `apply_blocks` / `is_source_blocked` - ブロック管理
- [x] `cleanup` - 完了タスクのクリーンアップ

### Phase 4: 統合 (TODO)

- [ ] HTML Parser との統合
- [ ] CSS Cascade との統合
- [ ] LayoutTree との統合
- [ ] ResourceId との連携

## 型設計

### TaskSource

```moonbit
pub(all) enum TaskSource {
  DOM          // DOM操作（パース、ツリー構築）
  Styling      // スタイル計算
  Layout       // レイアウト計算
  Networking   // リソースフェッチ（外部委譲）
  Scripting    // スクリプト実行（外部委譲）
  ImageDecode  // 画像デコード（外部委譲）
}
```

### TaskConstraint

```moonbit
pub(all) enum TaskConstraint {
  MainThreadOnly  // メインスレッド必須
  Parallel        // 並列実行可能
  Blocking        // 他タスクをブロック
}
```

### TaskAction

```moonbit
pub(all) enum TaskAction {
  // 内部実行可能
  ParseHTMLChunk(html~ : String)
  ParseCSS(source~ : String)
  ComputeStyle(node_ids~ : Array[String])
  ComputeLayout

  // 外部委譲
  FetchResource(url~ : String, resource_type~ : ResourceType)
  DecodeImage(resource_id~ : Int)
  ExecuteScript(source~ : String)
}
```

## 使用例

```moonbit
// スケジューラ作成
let scheduler = Scheduler::new()

// HTMLパースタスクを追加
let parse_task = scheduler.enqueue(
  ParseHTMLChunk(html="<div>...</div>"),
  MainThreadOnly,
)

// 発見したリソースのフェッチタスクを追加（パース完了後）
let fetch_task = scheduler.enqueue_after(
  FetchResource(url="image.png", resource_type=Image),
  [parse_task],
)

// 外部ランタイムがポーリング
loop {
  // 並列実行可能なタスクを取得
  let parallel_tasks = scheduler.poll_parallel()
  // → 外部で並列実行

  // メインスレッド専用タスクを取得
  let main_tasks = scheduler.poll_ready()
  // → 順次実行

  // 完了通知
  scheduler.complete(task_id, Ok(result))
}
```

## 外部ランタイムとの連携

```
┌─────────────────────────────────────────────────────────┐
│                    External Runtime                      │
│  (async runtime, network, script engine, image decoder) │
└─────────────────────────────┬───────────────────────────┘
                              │
          poll_ready()        │        complete()
          poll_parallel()     │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                       Scheduler                          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐    │
│  │ DOM     │  │ Styling │  │ Network │  │ Script  │    │
│  │ Queue   │  │ Queue   │  │ Queue   │  │ Queue   │    │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘    │
│                              │                          │
│              ┌───────────────┴───────────────┐          │
│              │      Dependency Graph         │          │
│              └───────────────────────────────┘          │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│              Internal Modules (sync execution)           │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐    │
│  │  HTML   │  │   CSS   │  │ Cascade │  │  Layout │    │
│  │ Parser  │  │ Parser  │  │         │  │  Tree   │    │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘    │
└─────────────────────────────────────────────────────────┘
```

## 注意事項

- このモジュールは実際の非同期実行を行わない
- 外部ランタイムがタスクをポーリングして実行する
- 依存関係の解決とタスクの状態管理のみを担当
