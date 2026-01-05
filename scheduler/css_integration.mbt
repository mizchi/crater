///|
/// CSS Cascade Integration with Scheduler
/// CSSカスケードとスケジューラの統合

// =============================================================================
// Style Manager
// =============================================================================

///|
/// スタイル管理 - スタイルシートとカスケード計算を管理
pub struct StyleManager {
  scheduler : Scheduler
  /// パース済みのスタイルシート
  stylesheets : Array[@cascade.Stylesheet]
  /// インラインスタイル (element id -> declarations)
  inline_styles : Map[String, Array[@cascade.Declaration]]
  /// 計算済みスタイル (element id -> cascaded values)
  computed_styles : Map[String, @cascade.CascadedValues]
  /// スタイルシートのソース順序カウンタ
  mut source_order : Int
}

///|
pub fn StyleManager::new(scheduler : Scheduler) -> StyleManager {
  {
    scheduler,
    stylesheets: [],
    inline_styles: {},
    computed_styles: {},
    source_order: 0,
  }
}

// =============================================================================
// Stylesheet Management
// =============================================================================

///|
/// CSSソースからスタイルシートをパースして追加
pub fn StyleManager::add_stylesheet_source(
  self : StyleManager,
  source : String,
) -> @cascade.Stylesheet {
  let stylesheet = @parser.parse_stylesheet(source)
  self.stylesheets.push(stylesheet)
  self.source_order += 1
  // スタイルが変更されたので再計算が必要
  self.invalidate_all_styles()
  stylesheet
}

///|
/// パース済みスタイルシートを追加
pub fn StyleManager::add_stylesheet(
  self : StyleManager,
  stylesheet : @cascade.Stylesheet,
) -> Unit {
  self.stylesheets.push(stylesheet)
  self.source_order += 1
  self.invalidate_all_styles()
}

///|
/// インラインスタイルを追加
pub fn StyleManager::add_inline_style(
  self : StyleManager,
  element_id : String,
  style_text : String,
) -> Unit {
  // インラインスタイルをパースして Declaration に変換
  let declarations = parse_inline_declarations(style_text)
  self.inline_styles[element_id] = declarations
  // この要素のスタイルを無効化
  self.computed_styles.remove(element_id)
}

///|
/// インラインスタイルテキストから Declaration 配列を生成
fn parse_inline_declarations(
  style_text : String,
) -> Array[@cascade.Declaration] {
  let declarations : Array[@cascade.Declaration] = []
  // "property: value; property: value" 形式をパース
  let parts = split_by_semicolon(style_text)
  for part in parts {
    let trimmed = part.trim().to_string()
    if not(trimmed.is_empty()) {
      let colon_idx = find_colon(trimmed)
      if colon_idx >= 0 {
        let prop = trimmed[:colon_idx].to_string() catch { _ => "" }
        let prop_trimmed = prop.trim().to_string()
        let val = trimmed[colon_idx + 1:].to_string() catch { _ => "" }
        let val_trimmed = val.trim().to_string()
        if not(prop_trimmed.is_empty()) && not(val_trimmed.is_empty()) {
          // !important チェック
          let (clean_val, importance) = if val_trimmed
            .to_lower()
            .has_suffix("!important") {
            let clean = val_trimmed[:val_trimmed.length() - 10].to_string() catch {
              _ => ""
            }
            (clean.trim().to_string(), @cascade.Important)
          } else {
            (val_trimmed, @cascade.Normal)
          }
          declarations.push(
            @cascade.Declaration::from_inline(
              prop_trimmed, clean_val, importance,
            ),
          )
        }
      }
    }
  }
  declarations
}

///|
fn split_by_semicolon(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == ';' {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  let last = current.to_string()
  if not(last.is_empty()) {
    result.push(last)
  }
  result
}

///|
fn find_colon(s : String) -> Int {
  let mut i = 0
  for c in s {
    if c == ':' {
      return i
    }
    i += 1
  }
  -1
}

// =============================================================================
// Style Computation
// =============================================================================

///|
/// 要素のスタイルを計算
pub fn StyleManager::compute_style(
  self : StyleManager,
  element : @selector.Element,
) -> @cascade.CascadedValues {
  let element_id = element.id.unwrap_or("")

  // キャッシュチェック
  match self.computed_styles.get(element_id) {
    Some(cached) => return cached
    None => ()
  }

  // インラインスタイルを取得
  let inline_decls = match self.inline_styles.get(element_id) {
    Some(decls) => decls
    None => []
  }

  // カスケード計算
  let cascaded = @cascade.cascade_element(
    element,
    self.stylesheets,
    inline_decls,
  )

  // キャッシュに保存
  if not(element_id.is_empty()) {
    self.computed_styles[element_id] = cascaded
  }
  cascaded
}

///|
/// 全スタイルキャッシュを無効化
pub fn StyleManager::invalidate_all_styles(self : StyleManager) -> Unit {
  self.computed_styles.clear()
}

///|
/// 特定要素のスタイルを無効化
pub fn StyleManager::invalidate_style(
  self : StyleManager,
  element_id : String,
) -> Unit {
  self.computed_styles.remove(element_id)
}

// =============================================================================
// Scheduler Integration
// =============================================================================

///|
/// CSSパースタスクを開始
pub fn StyleManager::schedule_parse_css(
  self : StyleManager,
  source : String,
) -> TaskId {
  self.scheduler.enqueue(ParseCSS(source~), MainThreadOnly)
}

///|
/// スタイル計算タスクを開始
pub fn StyleManager::schedule_compute_style(
  self : StyleManager,
  node_ids : Array[String],
) -> TaskId {
  self.scheduler.enqueue(ComputeStyle(node_ids~), MainThreadOnly)
}

///|
/// CSSパースタスク完了時の処理
pub fn StyleManager::on_css_parsed(
  self : StyleManager,
  source : String,
) -> CSSParseResult {
  let stylesheet = self.add_stylesheet_source(source)

  // スタイル再計算タスクを生成（影響を受ける可能性のある全要素）
  let recompute_task = if not(self.computed_styles.is_empty()) {
    let node_ids : Array[String] = []
    self.computed_styles.each(fn(id, _) { node_ids.push(id) })
    Some(self.schedule_compute_style(node_ids))
  } else {
    None
  }
  { stylesheet, recompute_task, rule_count: stylesheet.rules.length() }
}

///|
/// CSS パース結果
pub(all) struct CSSParseResult {
  stylesheet : @cascade.Stylesheet
  recompute_task : TaskId?
  rule_count : Int
}

// =============================================================================
// HTML + CSS Coordination
// =============================================================================

///|
/// HTMLとCSSを統合してスタイル計算をスケジュール
pub struct DocumentStyleCoordinator {
  scheduler : Scheduler
  style_manager : StyleManager
  /// パース完了したスタイルシートの数
  mut parsed_stylesheets : Int
  /// 期待されるスタイルシート数
  mut expected_stylesheets : Int
  /// スタイル計算の準備ができているか
  mut ready_for_style : Bool
}

///|
pub fn DocumentStyleCoordinator::new(
  scheduler : Scheduler,
) -> DocumentStyleCoordinator {
  {
    scheduler,
    style_manager: StyleManager::new(scheduler),
    parsed_stylesheets: 0,
    expected_stylesheets: 0,
    ready_for_style: false,
  }
}

///|
/// HTMLパース結果からスタイルシートを登録
pub fn DocumentStyleCoordinator::register_stylesheets(
  self : DocumentStyleCoordinator,
  parse_result : ParseCompleteResult,
  discovered : ResourceDiscoveryResult,
) -> Unit {
  // 外部スタイルシートの数を記録
  let external_count = discovered.filter_by_type(Stylesheet).length()

  // インラインスタイルを即座に追加
  for style_source in discovered.inline_styles {
    let _ = self.style_manager.add_stylesheet_source(style_source)
    self.parsed_stylesheets += 1
  }
  self.expected_stylesheets = external_count + discovered.inline_styles.length()

  // 外部スタイルシートがなければ即座にスタイル計算可能
  if external_count == 0 {
    self.ready_for_style = true
  }

  // HTMLから発見したインラインスタイル属性を処理
  process_element_inline_styles(parse_result.root, self.style_manager)
}

///|
/// 要素の style 属性を再帰的に処理
fn process_element_inline_styles(
  element : @html.Element,
  style_manager : StyleManager,
) -> Unit {
  // style 属性があれば追加
  match element.style {
    Some(style_text) => {
      let element_id = element.id.unwrap_or("")
      if not(element_id.is_empty()) {
        style_manager.add_inline_style(element_id, style_text)
      }
    }
    None => ()
  }

  // 子要素を再帰処理
  for child in element.children {
    match child {
      @html.Element(child_elem) =>
        process_element_inline_styles(child_elem, style_manager)
      @html.Text(_) => ()
    }
  }
}

///|
/// 外部スタイルシートのフェッチ完了時
pub fn DocumentStyleCoordinator::on_stylesheet_fetched(
  self : DocumentStyleCoordinator,
  css_source : String,
) -> CSSParseResult {
  let result = self.style_manager.on_css_parsed(css_source)
  self.parsed_stylesheets += 1

  // 全スタイルシートがパースされたかチェック
  if self.parsed_stylesheets >= self.expected_stylesheets {
    self.ready_for_style = true
  }
  result
}

///|
/// スタイル計算の準備ができているか
pub fn DocumentStyleCoordinator::is_ready_for_style(
  self : DocumentStyleCoordinator,
) -> Bool {
  self.ready_for_style
}

///|
/// スタイル計算をスケジュール
pub fn DocumentStyleCoordinator::schedule_style_computation(
  self : DocumentStyleCoordinator,
  node_ids : Array[String],
) -> TaskId {
  self.style_manager.schedule_compute_style(node_ids)
}

///|
/// スタイルマネージャへのアクセス
pub fn DocumentStyleCoordinator::get_style_manager(
  self : DocumentStyleCoordinator,
) -> StyleManager {
  self.style_manager
}

// =============================================================================
// Convenience Functions
// =============================================================================

///|
/// HTMLElementからselector.Elementに変換
pub fn html_element_to_selector(element : @html.Element) -> @selector.Element {
  let mut sel_elem = @selector.Element::new(element.tag)

  // IDを設定
  match element.id {
    Some(id) => sel_elem = sel_elem.set_id(id)
    None => ()
  }

  // クラスを追加
  for class in element.classes {
    sel_elem = sel_elem.add_class(class)
  }

  // 属性を追加
  element.attributes.each(fn(name, value) {
    sel_elem = sel_elem.set_attribute(name, value)
  })
  sel_elem
}

///|
/// HTMLElementのスタイルを計算
pub fn compute_element_style(
  style_manager : StyleManager,
  element : @html.Element,
) -> @cascade.CascadedValues {
  let selector_elem = html_element_to_selector(element)
  style_manager.compute_style(selector_elem)
}
