///|
/// Document preparation and external CSS cache helpers.

///|
pub struct PseudoRule {
  base_selector : @css.ComplexSelector?
  base_selector_text : String
  declarations : Array[@css.Declaration]
  media_query : @css.MediaQueryList?
}

///|
/// Indexed pseudo rules for fast lookup (same strategy as SelectorIndex)
pub struct PseudoRuleIndex {
  rules : Array[PseudoRule]
  by_id : Map[String, Array[Int]]
  by_class : Map[String, Array[Int]]
  by_tag : Map[String, Array[Int]]
  universal : Array[Int]
}

///|
fn PseudoRuleIndex::build(rules : Array[PseudoRule]) -> PseudoRuleIndex {
  let idx : PseudoRuleIndex = {
    rules,
    by_id: {},
    by_class: {},
    by_tag: {},
    universal: [],
  }
  for i, rule in rules {
    match rule.base_selector {
      Some(sel) => {
        // Index by head compound selector's most selective key
        let mut indexed = false
        // Check ID
        for sub in sel.head.subclasses {
          if !indexed {
            match sub {
              @css.SimpleSelector::Id(name) => {
                match idx.by_id.get(name) {
                  Some(arr) => arr.push(i)
                  None => idx.by_id.set(name, [i])
                }
                indexed = true
              }
              _ => ()
            }
          }
        }
        // Check class
        if !indexed {
          for sub in sel.head.subclasses {
            if !indexed {
              match sub {
                @css.SimpleSelector::Class(name) => {
                  match idx.by_class.get(name) {
                    Some(arr) => arr.push(i)
                    None => idx.by_class.set(name, [i])
                  }
                  indexed = true
                }
                _ => ()
              }
            }
          }
        }
        // Check tag
        if !indexed {
          match sel.head.type_selector {
            Some(@css.SimpleSelector::Type(name)) => {
              let tag = name.to_lower()
              match idx.by_tag.get(tag) {
                Some(arr) => arr.push(i)
                None => idx.by_tag.set(tag, [i])
              }
              indexed = true
            }
            _ => ()
          }
        }
        if !indexed {
          idx.universal.push(i)
        }
      }
      None => idx.universal.push(i)
    }
  }
  idx
}

///|
fn PseudoRuleIndex::get_candidates(
  self : PseudoRuleIndex,
  element : @css.Element,
) -> Array[Int] {
  let candidates : Array[Int] = []
  match element.id {
    Some(id) =>
      match self.by_id.get(id) {
        Some(arr) =>
          for i in arr {
            candidates.push(i)
          }
        None => ()
      }
    None => ()
  }
  for cls in element.classes {
    match self.by_class.get(cls) {
      Some(arr) =>
        for i in arr {
          candidates.push(i)
        }
      None => ()
    }
  }
  let tag = element.tag_name.to_lower()
  match self.by_tag.get(tag) {
    Some(arr) =>
      for i in arr {
        candidates.push(i)
      }
    None => ()
  }
  for i in self.universal {
    candidates.push(i)
  }
  candidates
}

///|
pub struct PreparedExternalCss {
  stylesheets : Array[@css.Stylesheet]
  indexed_stylesheets : Array[@css.IndexedStylesheet]
  before_rules : Array[PseudoRule]
  after_rules : Array[PseudoRule]
  before_index : PseudoRuleIndex
  after_index : PseudoRuleIndex
  total_rules : Int
}

///|
let external_css_bundle_cache : Ref[Map[String, PreparedExternalCss]] = {
  val: {},
}

///|
fn external_css_cache_key(external_css : Array[String]) -> String {
  let mut total_len = 0
  for css in external_css {
    total_len = total_len + css.length() + 16
  }
  let buf = StringBuilder::new(size_hint=total_len)
  for css in external_css {
    buf.write_string(css.length().to_string())
    buf.write_string(":")
    buf.write_string(css)
  }
  buf.to_string()
}

///|
fn collect_pseudo_rules_from_stylesheet(
  stylesheet : @css.Stylesheet,
  before_rules : Array[PseudoRule],
  after_rules : Array[PseudoRule],
) -> Unit {
  for rule in stylesheet.rules {
    let sel = rule.selector_text
    if sel.contains("before") {
      match selector_text_without_pseudo(sel, Before) {
        Some(base_text) => {
          let base_sel = @css.parse_selector(base_text)
          before_rules.push({
            base_selector: base_sel,
            base_selector_text: base_text,
            declarations: rule.declarations,
            media_query: rule.media_query,
          })
        }
        None => ()
      }
    }
    if sel.contains("after") {
      match selector_text_without_pseudo(sel, After) {
        Some(base_text) => {
          let base_sel = @css.parse_selector(base_text)
          after_rules.push({
            base_selector: base_sel,
            base_selector_text: base_text,
            declarations: rule.declarations,
            media_query: rule.media_query,
          })
        }
        None => ()
      }
    }
  }
}

///|
fn empty_prepared_external_css() -> PreparedExternalCss {
  {
    stylesheets: [],
    indexed_stylesheets: [],
    before_rules: [],
    after_rules: [],
    before_index: {
      rules: [],
      by_id: {},
      by_class: {},
      by_tag: {},
      universal: [],
    },
    after_index: {
      rules: [],
      by_id: {},
      by_class: {},
      by_tag: {},
      universal: [],
    },
    total_rules: 0,
  }
}

///|
pub fn prepare_external_css(
  external_css : Array[String],
) -> PreparedExternalCss {
  if external_css.is_empty() {
    return empty_prepared_external_css()
  }
  let key = external_css_cache_key(external_css)
  match external_css_bundle_cache.val.get(key) {
    Some(bundle) => bundle
    None => {
      let stylesheets : Array[@css.Stylesheet] = []
      let indexed_stylesheets : Array[@css.IndexedStylesheet] = []
      let before_rules : Array[PseudoRule] = []
      let after_rules : Array[PseudoRule] = []
      let mut total_rules = 0
      for css in external_css {
        let stylesheet = @css.parse_stylesheet(
          @html.flatten_css_cascade_layers(css),
        )
        total_rules += stylesheet.rules.length()
        collect_pseudo_rules_from_stylesheet(
          stylesheet, before_rules, after_rules,
        )
        stylesheets.push(stylesheet)
        indexed_stylesheets.push(@css.IndexedStylesheet::new(stylesheet))
      }
      let bundle : PreparedExternalCss = {
        stylesheets,
        indexed_stylesheets,
        before_rules,
        after_rules,
        before_index: PseudoRuleIndex::build(before_rules),
        after_index: PseudoRuleIndex::build(after_rules),
        total_rules,
      }
      external_css_bundle_cache.val.set(key, bundle)
      bundle
    }
  }
}

///|
pub struct PreparedRenderDocument {
  stylesheets : Array[@css.Stylesheet]
  indexed_stylesheets : Array[@css.IndexedStylesheet]
  css_vars : Map[String, String]
  doc_root_selector : @css.Element
  doc_root_style : @style.Style
  render_root : @html.Element
  render_root_tag : String
  body_uses_document_root_style : Bool
  suppress_quirks_body_ua_top_margin : Bool
  before_index : PseudoRuleIndex
  after_index : PseudoRuleIndex
}

///|
fn text_is_whitespace_only(s : String) -> Bool {
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    if c != ' ' && c != '\t' && c != '\n' && c != '\r' {
      return false
    }
  }
  true
}

///|
fn tag_has_ua_top_margin(tag : String) -> Bool {
  match tag.to_lower() {
    "p"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "ul"
    | "ol"
    | "menu"
    | "dl"
    | "pre"
    | "blockquote"
    | "figure" => true
    _ => false
  }
}

///|
fn leading_margin_is_ua_default(elem : @html.Element) -> Bool {
  if elem.style is Some(_) {
    return false
  }
  if tag_has_ua_top_margin(elem.tag) {
    return true
  }
  for child in elem.children {
    match child {
      @html.Node::Text(t) => if !text_is_whitespace_only(t) { return false }
      @html.Node::Element(child_elem) =>
        if leading_margin_is_ua_default(child_elem) {
          return true
        } else if child_elem.style is Some(_) {
          return false
        }
    }
  }
  false
}

///|
fn should_suppress_quirks_body_ua_top_margin(
  doc : @html.Document,
  render_root : @html.Element,
  external_bundle : PreparedExternalCss,
) -> Bool {
  if !doc.quirks_mode ||
    render_root.tag.to_lower() != "body" ||
    !doc.stylesheets.is_empty() ||
    external_bundle.total_rules > 0 {
    return false
  }
  for child in render_root.children {
    match child {
      @html.Node::Text(t) => if !text_is_whitespace_only(t) { return false }
      @html.Node::Element(elem) =>
        if leading_margin_is_ua_default(elem) {
          return true
        } else if elem.style is Some(_) {
          return false
        }
    }
  }
  false
}

///|
pub fn prepare_render_document(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : Array[String],
) -> PreparedRenderDocument {
  let _t0 = perf_clock_us()
  let external_bundle = prepare_external_css(external_css)
  prepare_render_document_with_external_css_bundle(
    doc, ctx, external_bundle, _t0,
  )
}

///|
pub fn prepare_render_document_with_prepared_external_css(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : PreparedExternalCss,
) -> PreparedRenderDocument {
  let _t0 = perf_clock_us()
  prepare_render_document_with_external_css_bundle(doc, ctx, external_css, _t0)
}

///|
fn prepare_render_document_with_external_css_bundle(
  doc : @html.Document,
  ctx : RenderContext,
  external_bundle : PreparedExternalCss,
  t0 : Int64,
) -> PreparedRenderDocument {
  let stylesheets : Array[@css.Stylesheet] = []
  for stylesheet in external_bundle.stylesheets {
    stylesheets.push(stylesheet)
  }
  let indexed_stylesheets : Array[@css.IndexedStylesheet] = []
  for indexed in external_bundle.indexed_stylesheets {
    indexed_stylesheets.push(indexed)
  }
  let before_rules = external_bundle.before_rules.copy()
  let after_rules = external_bundle.after_rules.copy()
  let mut total_rules = external_bundle.total_rules
  for css in doc.stylesheets {
    let stylesheet = @css.parse_stylesheet(
      @html.flatten_css_cascade_layers(css),
    )
    total_rules += stylesheet.rules.length()
    collect_pseudo_rules_from_stylesheet(stylesheet, before_rules, after_rules)
    stylesheets.push(stylesheet)
    indexed_stylesheets.push(@css.IndexedStylesheet::new(stylesheet))
  }
  let _t1 = perf_clock_us()
  maybe_log_perf(
    "[perf] css_parse=" +
    ((_t1 - t0) / 1000L).to_string() +
    "ms rules=" +
    total_rules.to_string(),
  )
  let _t2 = perf_clock_us()
  let css_vars = collect_root_css_variables(stylesheets, ctx)
  let doc_root_selector = if indexed_stylesheets.length() == 0 {
    html_to_selector_element_minimal(doc.root, None)
  } else {
    html_to_selector_element(doc.root, None)
  }
  let doc_root_style = compute_element_style_indexed(
    doc_root_selector,
    doc.root.style,
    indexed_stylesheets,
    true,
    ctx,
    None,
    css_vars,
  )
  let render_root = select_render_root(doc.root, doc_root_style)
  let render_root_tag = render_root.tag.to_lower()
  let suppress_quirks_body_ua_top_margin = should_suppress_quirks_body_ua_top_margin(
    doc, render_root, external_bundle,
  )
  let prepared : PreparedRenderDocument = {
    stylesheets,
    indexed_stylesheets,
    css_vars,
    doc_root_selector,
    doc_root_style,
    render_root,
    render_root_tag,
    body_uses_document_root_style: render_root_tag == "body" &&
    doc.root.tag.to_lower() != "body",
    suppress_quirks_body_ua_top_margin,
    before_index: if doc.stylesheets.is_empty() {
      external_bundle.before_index
    } else {
      PseudoRuleIndex::build(before_rules)
    },
    after_index: if doc.stylesheets.is_empty() {
      external_bundle.after_index
    } else {
      PseudoRuleIndex::build(after_rules)
    },
  }
  maybe_log_perf(
    "[perf] css_parse=" +
    ((_t1 - t0) / 1000L).to_string() +
    "ms index=" +
    ((_t2 - _t1) / 1000L).to_string() +
    "ms rules=" +
    total_rules.to_string() +
    " pseudo_before=" +
    before_rules.length().to_string() +
    " pseudo_after=" +
    after_rules.length().to_string(),
  )
  prepared
}
