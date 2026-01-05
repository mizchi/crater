///|
/// HTML Parser Integration with Scheduler
/// HTMLパーサとスケジューラの統合

// =============================================================================
// Resource Discovery
// =============================================================================

///|
/// HTMLパース結果から発見されたリソース
pub(all) struct DiscoveredResource {
  url : String
  resource_type : ResourceType
  /// parser-blocking かどうか (同期スクリプトなど)
  blocking : Bool
  /// defer属性があるか
  is_defer : Bool
  /// async属性があるか
  is_async : Bool
}

///|
/// リソース発見結果
pub(all) struct ResourceDiscoveryResult {
  /// 発見されたリソース
  resources : Array[DiscoveredResource]
  /// インラインスタイル
  inline_styles : Array[String]
  /// インラインスクリプト
  inline_scripts : Array[InlineScript]
}

///|
/// インラインスクリプト情報
pub(all) struct InlineScript {
  source : String
  /// parser-blocking かどうか
  blocking : Bool
}

///|
pub fn ResourceDiscoveryResult::new() -> ResourceDiscoveryResult {
  { resources: [], inline_styles: [], inline_scripts: [] }
}

// =============================================================================
// Element Traversal and Resource Discovery
// =============================================================================

///|
/// Elementからリソースを発見
pub fn discover_resources(element : @html.Element) -> ResourceDiscoveryResult {
  let result = ResourceDiscoveryResult::new()
  discover_resources_recursive(element, result)
  result
}

///|
fn discover_resources_recursive(
  element : @html.Element,
  result : ResourceDiscoveryResult,
) -> Unit {
  let tag = element.tag.to_lower()

  // img要素
  if tag == "img" {
    match element.attributes.get("src") {
      Some(src) =>
        if not(src.is_empty()) {
          result.resources.push({
            url: src,
            resource_type: Image,
            blocking: false,
            is_defer: false,
            is_async: false,
          })
        }
      None => ()
    }
  }

  // link要素 (stylesheet)
  if tag == "link" {
    let rel = element.attributes.get("rel").unwrap_or("").to_lower()
    if rel == "stylesheet" {
      match element.attributes.get("href") {
        Some(href) =>
          if not(href.is_empty()) {
            result.resources.push({
              url: href,
              resource_type: Stylesheet,
              // スタイルシートはレンダリングブロッキング
              blocking: true,
              is_defer: false,
              is_async: false,
            })
          }
        None => ()
      }
    }
  }

  // script要素
  if tag == "script" {
    let has_src = element.attributes.get("src")
    let has_async = element.attributes.contains("async")
    let has_defer = element.attributes.contains("defer")
    let type_attr = element.attributes.get("type").unwrap_or("")

    // type="module" は defer と同様の動作
    let is_module = type_attr == "module"
    match has_src {
      Some(src) =>
        if not(src.is_empty()) {
          // 外部スクリプト
          result.resources.push({
            url: src,
            resource_type: Script,
            // async/defer/module でなければ parser-blocking
            blocking: not(has_async) && not(has_defer) && not(is_module),
            is_defer: has_defer || is_module,
            is_async: has_async,
          })
        }
      None => {
        // インラインスクリプト
        let script_content = extract_text_content(element)
        if not(script_content.is_empty()) {
          result.inline_scripts.push({
            source: script_content,
            // インラインスクリプトは常に parser-blocking (async/defer は外部のみ)
            blocking: not(has_async) && not(is_module),
          })
        }
      }
    }
  }

  // style要素 (インラインスタイル)
  if tag == "style" {
    let style_content = extract_text_content(element)
    if not(style_content.is_empty()) {
      result.inline_styles.push(style_content)
    }
  }

  // 子要素を再帰的に処理
  for child in element.children {
    match child {
      @html.Element(child_elem) =>
        discover_resources_recursive(child_elem, result)
      @html.Text(_) => ()
    }
  }
}

///|
/// 要素からテキストコンテンツを抽出
fn extract_text_content(element : @html.Element) -> String {
  let sb = StringBuilder::new()
  for child in element.children {
    match child {
      @html.Text(text) => sb.write_string(text)
      @html.Element(_) => ()
    }
  }
  sb.to_string()
}

// =============================================================================
// Document Parser (Scheduler Integration)
// =============================================================================

///|
/// ドキュメントパーサ - スケジューラと連携してHTMLをパース
pub struct DocumentParser {
  scheduler : Scheduler
  /// パース済みのルート要素
  mut parsed_root : @html.Element?
  /// 発見されたリソース
  mut discovered : ResourceDiscoveryResult?
  /// ドキュメントのbase URL
  base_url : String
}

///|
pub fn DocumentParser::new(
  scheduler : Scheduler,
  base_url? : String = "",
) -> DocumentParser {
  { scheduler, parsed_root: None, discovered: None, base_url }
}

///|
/// HTMLパースタスクを開始
pub fn DocumentParser::start_parse(
  self : DocumentParser,
  html : String,
) -> TaskId {
  self.scheduler.enqueue(ParseHTMLChunk(html~), MainThreadOnly)
}

///|
/// パース完了後の処理 - リソース発見とタスク生成
/// 外部から ParseHTMLChunk タスク完了時に呼ばれる
pub fn DocumentParser::on_parse_complete(
  self : DocumentParser,
  html : String,
) -> ParseCompleteResult {
  // HTMLをパース
  let root = @html.parse_fragment_v2(html)
  self.parsed_root = Some(root)

  // リソースを発見
  let discovered = discover_resources(root)
  self.discovered = Some(discovered)

  // リソースフェッチタスクを生成
  let fetch_tasks : Array[TaskId] = []
  let blocking_tasks : Array[TaskId] = []
  for resource in discovered.resources {
    let constraint = if resource.blocking {
      // blocking リソースは他のタスクをブロック
      Blocking([DOM, Styling])
    } else if resource.is_async {
      // async は並列実行可能
      Parallel
    } else {
      MainThreadOnly
    }
    let task_id = self.scheduler.enqueue(
      FetchResource(url=resource.url, resource_type=resource.resource_type),
      constraint,
    )
    fetch_tasks.push(task_id)
    if resource.blocking {
      blocking_tasks.push(task_id)
    }
  }

  // インラインスタイルのパースタスク
  let style_tasks : Array[TaskId] = []
  for style_source in discovered.inline_styles {
    let task_id = self.scheduler.enqueue(
      ParseCSS(source=style_source),
      MainThreadOnly,
    )
    style_tasks.push(task_id)
  }

  // インラインスクリプトの実行タスク
  let script_tasks : Array[TaskId] = []
  for script in discovered.inline_scripts {
    let constraint = if script.blocking {
      Blocking([DOM])
    } else {
      MainThreadOnly
    }
    let task_id = self.scheduler.enqueue(
      ExecuteScript(source=script.source),
      constraint,
    )
    script_tasks.push(task_id)
  }
  {
    root,
    fetch_tasks,
    style_tasks,
    script_tasks,
    blocking_tasks,
    resource_count: discovered.resources.length(),
    inline_style_count: discovered.inline_styles.length(),
    inline_script_count: discovered.inline_scripts.length(),
  }
}

///|
/// パース済みのルート要素を取得
pub fn DocumentParser::get_root(self : DocumentParser) -> @html.Element? {
  self.parsed_root
}

///|
/// 発見されたリソースを取得
pub fn DocumentParser::get_discovered_resources(
  self : DocumentParser,
) -> ResourceDiscoveryResult? {
  self.discovered
}

// =============================================================================
// Parse Complete Result
// =============================================================================

///|
/// パース完了時の結果
pub(all) struct ParseCompleteResult {
  /// パース済みのルート要素
  root : @html.Element
  /// 生成されたフェッチタスク
  fetch_tasks : Array[TaskId]
  /// 生成されたスタイルパースタスク
  style_tasks : Array[TaskId]
  /// 生成されたスクリプト実行タスク
  script_tasks : Array[TaskId]
  /// blocking タスク
  blocking_tasks : Array[TaskId]
  /// 発見されたリソース数
  resource_count : Int
  /// インラインスタイル数
  inline_style_count : Int
  /// インラインスクリプト数
  inline_script_count : Int
}

// =============================================================================
// Convenience Functions
// =============================================================================

///|
/// HTMLを解析してすべてのタスクを生成する便利関数
pub fn parse_and_schedule(
  scheduler : Scheduler,
  html : String,
  base_url? : String = "",
) -> ParseCompleteResult {
  let parser = DocumentParser::new(scheduler, base_url~)
  parser.on_parse_complete(html)
}

///|
/// 発見されたリソースのURLリストを取得
pub fn ResourceDiscoveryResult::get_urls(
  self : ResourceDiscoveryResult,
) -> Array[String] {
  self.resources.map(fn(r) { r.url })
}

///|
/// 特定タイプのリソースをフィルタ
pub fn ResourceDiscoveryResult::filter_by_type(
  self : ResourceDiscoveryResult,
  resource_type : ResourceType,
) -> Array[DiscoveredResource] {
  self.resources.filter(fn(r) { r.resource_type == resource_type })
}

///|
/// blocking リソースのみ取得
pub fn ResourceDiscoveryResult::get_blocking(
  self : ResourceDiscoveryResult,
) -> Array[DiscoveredResource] {
  self.resources.filter(fn(r) { r.blocking })
}
