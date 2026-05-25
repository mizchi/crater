///|
/// UA defaults, CSS cascade, and inline style resolution helpers.

///|
/// Check if a compound selector is the :root pseudo-class
fn is_root_selector(selector : @css.CompoundSelector) -> Bool {
  for sub in selector.subclasses {
    match sub {
      @css.SimpleSelector::PseudoClass(@css.PseudoClass::Root) => return true
      _ => ()
    }
  }
  false
}

///|
fn clone_string_map(source : Map[String, String]) -> Map[String, String] {
  let cloned : Map[String, String] = {}
  for entry in source {
    let (key, value) = entry
    cloned[key] = value
  }
  cloned
}

///|
fn collect_cascaded_custom_properties(
  cascaded : @css.CascadedValues?,
  vars : Map[String, String],
) -> Unit {
  match cascaded {
    Some(cascaded_values) =>
      cascaded_values.each(fn(prop, decl) {
        if prop.has_prefix("--") {
          match decl.value {
            @css.PropertyValue::Value(value) => vars[prop] = value
            _ => ()
          }
        }
      })
    None => ()
  }
}

///|
fn collect_inline_custom_properties(
  inline_css : String?,
  vars : Map[String, String],
) -> Unit {
  match inline_css {
    Some(css) =>
      for declaration in parse_inline_declarations_cached(css) {
        let (prop, value) = declaration
        if prop.has_prefix("--") {
          vars[prop] = value
        }
      }
    None => ()
  }
}

///|
let renderer_effective_color_scheme_key = "--crater-effective-color-scheme"

///|
fn first_color_scheme_keyword_for_renderer(value : String) -> String? {
  let normalized = value.to_lower()
  let tokens = normalized.split(" ")
  for token in tokens {
    let t = token.to_owned().trim()
    if t == "light" || t == "dark" {
      return Some(t.to_owned())
    }
  }
  None
}

///|
fn seed_effective_color_scheme_for_direct_style(
  cascaded : @css.CascadedValues?,
  inline_css : String?,
  vars : Map[String, String],
) -> Unit {
  match vars.get(renderer_effective_color_scheme_key) {
    Some(_) => ()
    None => vars[renderer_effective_color_scheme_key] = "light"
  }
  match cascaded {
    Some(cascaded_values) =>
      match cascaded_values.get_value("color-scheme") {
        Some(value) =>
          match first_color_scheme_keyword_for_renderer(value) {
            Some(scheme) => vars[renderer_effective_color_scheme_key] = scheme
            None => ()
          }
        None => ()
      }
    None => ()
  }
  match inline_css {
    Some(css) =>
      for declaration in parse_inline_declarations_cached(css) {
        let (prop, value) = declaration
        if prop.to_lower() == "color-scheme" {
          match first_color_scheme_keyword_for_renderer(value) {
            Some(scheme) => vars[renderer_effective_color_scheme_key] = scheme
            None => ()
          }
        }
      }
    None => ()
  }
}

///|
/// Check if a complex selector matches :root (simple :root without combinators)
fn is_root_only_selector(selector : @css.ComplexSelector) -> Bool {
  // :root should be a simple selector without combinators
  if selector.tail.length() > 0 {
    return false
  }
  is_root_selector(selector.head)
}

///|
/// Collect CSS custom properties from :root rules in stylesheets
/// Evaluates media queries to correctly apply dark mode variables
fn collect_root_css_variables(
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> Map[String, String] {
  let vars : Map[String, String] = {}
  // Create media environment for evaluating @media queries
  let media_env = @css.MediaEnvironment::with_color_scheme(
    ctx.viewport_width,
    ctx.viewport_height,
    ctx.color_scheme,
  )
  for stylesheet in stylesheets {
    for rule in stylesheet.rules {
      // Check media query if present
      let media_matches = match rule.media_query {
        Some(mq) => mq.evaluate(media_env)
        None => true
      }
      if !media_matches {
        continue
      }
      // Check if this rule targets :root
      if is_root_only_selector(rule.selector) {
        // Collect custom properties (--*) from declarations
        for decl in rule.declarations {
          if decl.property.has_prefix("--") {
            match decl.value {
              @css.PropertyValue::Value(v) => vars[decl.property] = v
              _ => ()
            }
          }
        }
      }
    }
  }
  vars
}

///|
/// Get user-agent default style for an element tag
fn get_ua_default_style(tag : String) -> @style.Style {
  let default_style = @style.Style::default()

  // Default margins for block elements (based on typical browser defaults)
  // Values are in em units, converted to px assuming 16px base font
  match tag.to_lower() {
    "html" => { ..default_style, font_family: "serif" }
    "body" =>
      {
        ..default_style,
        font_family: "serif",
        margin: @types.Rect::all(@types.Length(8.0)),
      }
    "frameset" =>
      {
        ..default_style,
        width: @types.Percent(1.0),
        height: @types.Percent(1.0),
      }
    "p" =>
      {
        // p has 1em margin-top and margin-bottom
        ..default_style,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(16.0),
          bottom: @types.Length(16.0),
        },
      }
    "h1" =>
      {
        // h1 UA defaults: bold 2em heading with block margins.
        ..default_style,
        font_size: 32.0,
        font_weight: 700.0,
        line_height: 38.4,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(21.44),
          bottom: @types.Length(21.44),
        },
      }
    "h2" =>
      {
        // h2 UA defaults: 1.5em bold heading with 0.83em block margins.
        ..default_style,
        font_size: 24.0,
        font_weight: 700.0,
        line_height: 28.8,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(19.92),
          bottom: @types.Length(19.92),
        },
      }
    "h3" =>
      {
        // h3 UA defaults: 1.17em bold heading with 1em block margins.
        ..default_style,
        font_size: 18.72,
        font_weight: 700.0,
        line_height: 22.464,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(18.72),
          bottom: @types.Length(18.72),
        },
      }
    "h4" =>
      {
        // h4 UA defaults: 1em bold heading with 1.33em block margins.
        ..default_style,
        font_weight: 700.0,
        line_height: 19.2,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(21.28),
          bottom: @types.Length(21.28),
        },
      }
    "h5" =>
      {
        // h5 UA defaults: 0.83em bold heading with 1.67em block margins.
        ..default_style,
        font_size: 13.28,
        font_weight: 700.0,
        line_height: 15.936,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(22.1776),
          bottom: @types.Length(22.1776),
        },
      }
    "h6" =>
      {
        // h6 UA defaults: 0.67em bold heading with 2.33em block margins.
        ..default_style,
        font_size: 10.72,
        font_weight: 700.0,
        line_height: 12.864,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(24.9776),
          bottom: @types.Length(24.9776),
        },
      }
    "ul" | "ol" =>
      // Lists: margin-block 1em; padding-inline-start 40px.
      // Use named fields because Rect::new ordering is (left, right, top, bottom).
      {
        ..default_style,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(16.0),
          bottom: @types.Length(16.0),
        },
        padding: {
          left: @types.Length(40.0),
          right: @types.Length(0.0),
          top: @types.Length(0.0),
          bottom: @types.Length(0.0),
        },
      }
    "li" =>
      {
        ..default_style
        // Empty list items still occupy one line box in browsers.
        ,
        min_height: @types.Length(19.2),
      }
    "blockquote" =>
      {
        // blockquote has 1em margin and 40px horizontal margins
        ..default_style,
        margin: {
          left: @types.Length(40.0),
          right: @types.Length(40.0),
          top: @types.Length(16.0),
          bottom: @types.Length(16.0),
        },
      }
    "fieldset" =>
      {
        ..default_style,
        margin: {
          left: @types.Length(2.0),
          right: @types.Length(2.0),
          top: @types.Length(0.0),
          bottom: @types.Length(0.0),
        },
        padding: {
          left: @types.Length(12.0),
          right: @types.Length(12.0),
          top: @types.Length(5.6),
          bottom: @types.Length(10.0),
        },
        border: {
          left: @types.Length(2.0),
          right: @types.Length(2.0),
          top: @types.Length(2.0),
          bottom: @types.Length(2.0),
        },
        min_width: @types.MinContent,
      }
    "legend" =>
      {
        ..default_style
        // Browsers render legend with shrink-wrap-like sizing behavior.
        // InlineBlock approximates that without a dedicated fieldset algorithm.
        ,
        display: @types.InlineBlock,
        padding: {
          left: @types.Length(2.0),
          right: @types.Length(2.0),
          top: @types.Length(0.0),
          bottom: @types.Length(0.0),
        },
      }
    // Pre element - preserve formatting, prevent wrapping
    "pre" =>
      {
        // pre uses smaller monospace text, preserves whitespace, and has 1em
        // margins relative to its own default font size.
        ..default_style,
        display: @types.Block,
        font_family: "monospace",
        font_size: 13.0,
        line_height: 15.6,
        white_space: @style.WhiteSpace::Pre,
        overflow_x: @types.Hidden,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(13.0),
          bottom: @types.Length(13.0),
        },
      }
    // Link element - blue color (standard browser UA style)
    "a" =>
      {
        ..default_style,
        display: @types.Inline,
        // Standard link blue: #0000EE (rgb(0, 0, 238))
        color: @types.Color::rgb(0, 0, 238),
        text_decoration_underline: true,
      }
    // Underline elements
    "u" | "ins" =>
      {
        ..default_style,
        display: @types.Inline,
        text_decoration_underline: true,
      }
    "s" | "strike" | "del" =>
      {
        ..default_style,
        display: @types.Inline,
        text_decoration_line_through: true,
      }
    // Bold inline elements
    "strong" | "b" =>
      { ..default_style, display: @types.Inline, font_weight: 700.0 }
    // Inline elements - HTML default display: inline
    "span"
    | "em"
    | "i"
    | "code"
    | "abbr"
    | "cite"
    | "dfn"
    | "kbd"
    | "samp"
    | "var"
    | "sub"
    | "sup"
    | "small"
    | "mark"
    | "q"
    | "time"
    | "data"
    | "picture"
    | "source"
    | "ruby"
    | "rb"
    | "rbc"
    | "rt"
    | "rtc"
    | "rp"
    | "bdi"
    | "bdo"
    | "wbr" => { ..default_style, display: @types.Inline }
    // Replaced inline elements - inline by default
    // SVG has intrinsic size of 300x150 when no width/height specified
    "img"
    | "video"
    | "audio"
    | "canvas"
    | "iframe"
    | "object"
    | "embed"
    | "svg" => { ..default_style, display: @types.Inline }
    // SVG child elements - inline-block to fit content
    "g"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "path"
    | "text"
    | "tspan"
    | "defs"
    | "use"
    | "symbol"
    | "clipPath"
    | "mask"
    | "pattern"
    | "linearGradient"
    | "radialGradient"
    | "stop"
    | "image"
    | "foreignObject" => { ..default_style, display: @types.InlineBlock }
    // Form elements - inline-block and border-box by default
    "input" | "select" | "textarea" =>
      {
        ..default_style,
        display: @types.InlineBlock,
        box_sizing: @types.BorderBox,
        font_size: 13.0,
        line_height: 15.0,
      }
    // Buttons use platform UI metrics in browsers and are typically smaller
    // than inherited body text when no explicit font is set.
    "button" =>
      {
        ..default_style,
        display: @types.InlineBlock,
        box_sizing: @types.BorderBox,
        font_size: 14.0,
        line_height: 16.1,
      }
    "label" => { ..default_style, display: @types.Inline }
    // br is inline with no width
    "br" => { ..default_style, display: @types.Inline }
    // hr: horizontal rule (1px top border + margin)
    "hr" =>
      {
        ..default_style,
        margin: {
          top: @types.Dimension::Length(8.0),
          bottom: @types.Dimension::Length(8.0),
          left: @types.Dimension::Auto,
          right: @types.Dimension::Auto,
        },
        border: {
          top: @types.Dimension::Length(1.0),
          right: @types.Dimension::Length(0.0),
          bottom: @types.Dimension::Length(0.0),
          left: @types.Dimension::Length(0.0),
        },
      }
    // Table elements
    "table" =>
      {
        ..default_style,
        display: @types.Table,
        box_sizing: @types.BorderBox,
        border_spacing: 2.0,
      }
    "tr" => { ..default_style, display: @types.TableRow }
    "td" =>
      {
        ..default_style,
        display: @types.TableCell,
        padding: @types.Rect::all(@types.Length(1.0)),
        vertical_align: @style.Middle,
        text_align: @style.TextAlign::Left, // UA default: start (left for LTR)
      }
    "th" =>
      {
        ..default_style,
        display: @types.TableCell,
        padding: @types.Rect::all(@types.Length(1.0)),
        vertical_align: @style.Middle,
        text_align: @style.TextAlign::Center, // th defaults to center
        font_weight: 700.0,
      }
    "thead" => { ..default_style, display: @types.TableHeaderGroup }
    "tbody" => { ..default_style, display: @types.TableRowGroup }
    "tfoot" => { ..default_style, display: @types.TableFooterGroup }
    "caption" => { ..default_style, display: @types.TableCaption }
    "col" => { ..default_style, display: @types.TableColumn }
    "colgroup" => { ..default_style, display: @types.TableColumnGroup }
    // Hidden elements - display: none by default
    "template"
    | "script"
    | "style"
    | "head"
    | "meta"
    | "link"
    | "title"
    | "track"
    | "param" => { ..default_style, display: @types.Display::None }
    // <center> is deprecated but widely used (e.g., Hacker News)
    "center" => { ..default_style, text_align: @style.TextAlign::Center }
    _ => default_style
  }
}

///|
fn uses_table_normal_line_height(tag : String) -> Bool {
  match tag.to_lower() {
    "table" | "thead" | "tbody" | "tfoot" | "tr" | "td" | "th" | "caption" =>
      true
    _ => false
  }
}

///|
fn is_display_contents_suppressed_html_element(tag : String) -> Bool {
  match tag.to_lower() {
    "br"
    | "wbr"
    | "meter"
    | "progress"
    | "canvas"
    | "embed"
    | "object"
    | "audio"
    | "iframe"
    | "img"
    | "video"
    | "input"
    | "textarea"
    | "select" => true
    _ => false
  }
}

///|
fn normalize_display_contents_for_unusual_html(
  tag : String,
  style : @style.Style,
) -> @style.Style {
  if style.display == @types.Contents &&
    is_display_contents_suppressed_html_element(tag) {
    { ..style, display: @types.Display::None }
  } else {
    style
  }
}

///|
/// Compute element style using indexed stylesheets for better performance
fn compute_element_style_indexed(
  selector_elem : @css.Element,
  inline_css : String?,
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  is_root : Bool,
  ctx : RenderContext,
  parent_style : @style.Style?,
  css_vars : Map[String, String],
) -> @style.Style {
  let cascaded = if indexed_stylesheets.length() > 0 {
    // Create media environment for media query evaluation only when needed.
    let media_env = @css.MediaEnvironment::with_color_scheme(
      ctx.viewport_width,
      ctx.viewport_height,
      ctx.color_scheme,
    )
    Some(
      @css.cascade_element_indexed(
        selector_elem,
        indexed_stylesheets,
        [],
        Some(media_env),
      ),
    )
  } else {
    None
  }
  let element_css_vars = clone_string_map(css_vars)
  collect_cascaded_custom_properties(cascaded, element_css_vars)
  collect_inline_custom_properties(inline_css, element_css_vars)
  seed_effective_color_scheme_for_direct_style(
    cascaded, inline_css, element_css_vars,
  )
  let mut author_line_height_present = false
  match cascaded {
    Some(cascaded_values) =>
      if cascaded_values.get("line-height") is Some(_) {
        author_line_height_present = true
      }
    None => ()
  }
  match inline_css {
    Some(css) =>
      for declaration in parse_inline_declarations_cached(css) {
        let (prop, _value) = declaration
        let prop = prop.to_lower()
        if prop == "line-height" {
          author_line_height_present = true
        }
      }
    None => ()
  }
  // Keep this cache conservative: only reuse when stylesheet cascade and
  // inherited context cannot change the inline-only result.
  let mut inline_only_cache_css : String? = None
  let mut inline_only_cache_variant_key : String? = None
  match (cascaded, inline_css) {
    (None, Some(css)) =>
      if string_map_is_empty(element_css_vars) &&
        has_default_inherited_inline_context(parent_style) {
        inline_only_cache_css = Some(css)
        inline_only_cache_variant_key = Some(
          make_inline_only_style_cache_variant_key(
            selector_elem.tag_name,
            is_root,
            ctx.viewport_width,
            ctx.viewport_height,
          ),
        )
      }
    _ => ()
  }
  match (inline_only_cache_css, inline_only_cache_variant_key) {
    (Some(css), Some(variant_key)) =>
      match @inline_style_cache.inline_only_style_cache_get(css, variant_key) {
        Some(cached) => return cached
        None => ()
      }
    _ => ()
  }

  // Start with default style
  let default_style = @style.Style::default()
  let mut style = {
    ..default_style
    // CSS `normal` behaves as flex-start for flex layout. The lower-level
    // layout default stays logical Start for direct layout tests.
    ,
    justify_content: @types.FlexStart,
  }

  // Inherit properties from parent first
  match parent_style {
    Some(ps) => {
      let lh_ratio = if ps.font_size > 0.0 {
        ps.line_height / ps.font_size
      } else {
        1.2
      }
      style = {
        ..style,
        color: ps.color,
        font_size: ps.font_size,
        font_family: ps.font_family,
        line_height: ps.font_size * lh_ratio,
        white_space: ps.white_space,
        writing_mode: ps.writing_mode,
        direction: ps.direction,
        pointer_events: ps.pointer_events,
        letter_spacing: ps.letter_spacing,
        word_spacing: ps.word_spacing,
      }
    }
    None => ()
  }

  // Apply user-agent default style
  let ua_style = get_ua_default_style(selector_elem.tag_name)
  if ua_style.color != @types.Color::black() {
    style = { ..style, color: ua_style.color }
  }
  style = { ..style, display: ua_style.display }
  style = { ..style, box_sizing: ua_style.box_sizing }
  if ua_style.text_align != default_style.text_align {
    style = { ..style, text_align: ua_style.text_align }
  }
  if ua_style.vertical_align != default_style.vertical_align {
    style = { ..style, vertical_align: ua_style.vertical_align }
  }
  if ua_style.white_space != default_style.white_space {
    style = { ..style, white_space: ua_style.white_space }
  }
  if ua_style.overflow_x != default_style.overflow_x ||
    ua_style.overflow_y != default_style.overflow_y {
    style = {
      ..style,
      overflow_x: ua_style.overflow_x,
      overflow_y: ua_style.overflow_y,
    }
  }
  style = { ..style, margin: ua_style.margin, padding: ua_style.padding }
  if ua_style.font_size != default_style.font_size {
    style = { ..style, font_size: ua_style.font_size }
  }
  if ua_style.line_height != default_style.line_height {
    style = { ..style, line_height: ua_style.line_height }
  }
  if ua_style.font_family != "" {
    style = { ..style, font_family: ua_style.font_family }
  }
  if ua_style.font_weight != 400.0 {
    style = { ..style, font_weight: ua_style.font_weight }
  }
  style = {
    ..style,
    border_spacing: ua_style.border_spacing,
    border_collapse: ua_style.border_collapse,
    text_decoration_underline: ua_style.text_decoration_underline,
    text_decoration_line_through: ua_style.text_decoration_line_through,
    text_decoration_overline: ua_style.text_decoration_overline,
  }
  style = { ..style, min_height: ua_style.min_height }
  if selector_elem.tag_name.to_lower() == "rt" {
    let inherited_font_size = match parent_style {
      Some(ps) => ps.font_size
      None => style.font_size
    }
    let rt_font_size = inherited_font_size * 0.5
    style = {
      ..style,
      font_size: rt_font_size,
      line_height: rt_font_size * 1.2,
    }
  }
  if uses_table_normal_line_height(selector_elem.tag_name) {
    style = { ..style, line_height: style.font_size * normal_line_height_ratio }
  }

  // Apply presentational HTML attributes (bgcolor, width, align, etc.)
  // These act as low-priority CSS and are overridden by stylesheets.
  match selector_elem.get_attribute("bgcolor") {
    Some(bg_value) => {
      let parsed = @css.parse_color(bg_value)
      match parsed.get_color() {
        Some(color) => style = { ..style, background_color: color }
        None => ()
      }
    }
    None => ()
  }
  match selector_elem.get_attribute("width") {
    Some(width_value) => {
      let tag = selector_elem.tag_name.to_lower()
      if tag == "table" ||
        tag == "td" ||
        tag == "th" ||
        tag == "col" ||
        tag == "colgroup" {
        let dim = if width_value.has_suffix("%") {
          match width_value.strip_suffix("%") {
            Some(num_str) => {
              let n = @string.parse_double(num_str.to_owned()) catch {
                _ => -1.0
              }
              if n >= 0.0 {
                @types.Dimension::Percent(n / 100.0)
              } else {
                @types.Dimension::Auto
              }
            }
            None => @types.Dimension::Auto
          }
        } else {
          let n = @string.parse_double(width_value.to_string()) catch {
            _ => -1.0
          }
          if n >= 0.0 {
            @types.Dimension::Length(n)
          } else {
            @types.Dimension::Auto
          }
        }
        if dim != @types.Dimension::Auto {
          style = { ..style, width: dim }
        }
      }
    }
    None => ()
  }
  match selector_elem.get_attribute("align") {
    Some(align_value) =>
      match align_value.to_lower() {
        "center" => style = { ..style, text_align: @style.TextAlign::Center }
        "right" => style = { ..style, text_align: @style.TextAlign::Right }
        "left" => style = { ..style, text_align: @style.TextAlign::Left }
        _ => ()
      }
    None => ()
  }
  // HTML valign attribute → vertical-align CSS
  match selector_elem.get_attribute("valign") {
    Some(valign_value) =>
      match valign_value.to_lower() {
        "top" => style = { ..style, vertical_align: @style.Top }
        "middle" => style = { ..style, vertical_align: @style.Middle }
        "bottom" => style = { ..style, vertical_align: @style.Bottom }
        "baseline" => style = { ..style, vertical_align: @style.Baseline }
        _ => ()
      }
    None => ()
  }
  // HTML border attribute on table → border on all sides
  if selector_elem.tag_name.to_lower() == "table" {
    match selector_elem.get_attribute("border") {
      Some(border_value) => {
        let n = @string.parse_double(border_value.to_string()) catch {
          _ => 0.0
        }
        if n > 0.0 {
          let bw = @types.Dimension::Length(n)
          style = {
            ..style,
            border: { top: bw, right: bw, bottom: bw, left: bw },
            border_style: {
              top: @style.BorderStyle::Solid,
              right: @style.BorderStyle::Solid,
              bottom: @style.BorderStyle::Solid,
              left: @style.BorderStyle::Solid,
            },
          }
        }
      }
      None => ()
    }
  }

  // Apply font metrics first so em/ch/ex units in later properties
  // (width/height/gap/etc.) resolve against the element's own font.
  match cascaded {
    Some(cascaded_values) => {
      let mut font_present = false
      let mut font_order = 0
      let mut font_value = ""
      let mut font_size_present = false
      let mut font_size_order = 0
      let mut font_size_value = ""
      let mut line_height_present = false
      let mut line_height_order = 0
      let mut line_height_value = ""
      match cascaded_values.get("font") {
        Some(decl) =>
          match decl.value {
            @css.PropertyValue::Value(value) => {
              font_present = true
              font_order = decl.source_order
              font_value = value
            }
            _ => ()
          }
        None => ()
      }
      match cascaded_values.get("font-size") {
        Some(decl) =>
          match decl.value {
            @css.PropertyValue::Value(value) => {
              font_size_present = true
              font_size_order = decl.source_order
              font_size_value = value
            }
            _ => ()
          }
        None => ()
      }
      match cascaded_values.get("line-height") {
        Some(decl) =>
          match decl.value {
            @css.PropertyValue::Value(value) => {
              line_height_present = true
              line_height_order = decl.source_order
              line_height_value = value
            }
            _ => ()
          }
        None => ()
      }
      for idx = 0; idx < 3; idx = idx + 1 {
        let mut next_prop = ""
        let mut next_value = ""
        let mut next_order = 2147483647
        if font_present && font_order < next_order {
          next_prop = "font"
          next_value = font_value
          next_order = font_order
        }
        if font_size_present && font_size_order < next_order {
          next_prop = "font-size"
          next_value = font_size_value
          next_order = font_size_order
        }
        if line_height_present && line_height_order < next_order {
          next_prop = "line-height"
          next_value = line_height_value
        }
        if next_prop == "" {
          break
        }
        style = apply_css_property_with_viewport(
          style,
          next_prop,
          next_value,
          ctx.viewport_width,
          ctx.viewport_height,
          element_css_vars,
          parent_style,
        )
        match next_prop {
          "font" => font_present = false
          "font-size" => font_size_present = false
          "line-height" => line_height_present = false
          _ => ()
        }
      }

      // Apply remaining cascaded values
      cascaded_values.each(fn(prop, decl) {
        if prop == "font" || prop == "font-size" || prop == "line-height" {
          ()
        } else {
          match decl.value {
            @css.PropertyValue::Value(value) =>
              style = apply_css_property_with_viewport(
                style,
                prop,
                value,
                ctx.viewport_width,
                ctx.viewport_height,
                element_css_vars,
                parent_style,
              )
            _ => ()
          }
        }
      })
    }
    None => ()
  }

  // Preserve table layout
  let tag = selector_elem.tag_name
  if is_table_element(tag) {
    let keeps_non_table_display = style.display == @types.Contents ||
      style.display == @types.Display::None
    if !is_table_display(style.display) && !keeps_non_table_display {
      style = { ..style, display: ua_style.display }
    }
  }
  // Size containment does not apply to table-cell elements, while
  // layout/paint/style containment still can.
  if style.display == @types.TableCell && style.contain.size {
    style = { ..style, contain: { ..style.contain, size: false } }
  }

  // Apply inline styles
  match inline_css {
    Some(css) =>
      style = apply_inline_css_with_vars(
        style,
        css,
        element_css_vars,
        ctx.viewport_width,
        ctx.viewport_height,
        parent_style,
      )
    None => ()
  }
  style = apply_browser_normal_line_height_if_needed(
    style, parent_style, author_line_height_present,
  )
  style = normalize_display_contents_for_unusual_html(
    selector_elem.tag_name,
    style,
  )

  // Effects that establish a containing block for positioned descendants:
  // filter and backdrop-filter (non-none values).
  let mut establishes_effect_cb = false
  match cascaded {
    Some(cascaded_values) =>
      match cascaded_values.get_value("filter") {
        Some(value) =>
          if value.to_lower().trim() != "none" {
            establishes_effect_cb = true
          }
        None => ()
      }
    None => ()
  }
  match cascaded {
    Some(cascaded_values) =>
      match cascaded_values.get_value("backdrop-filter") {
        Some(value) =>
          if value.to_lower().trim() != "none" {
            establishes_effect_cb = true
          }
        None => ()
      }
    None => ()
  }
  match inline_css {
    Some(css) =>
      if inline_css_establishes_effect_containing_block(css) {
        establishes_effect_cb = true
      }
    None => ()
  }
  if establishes_effect_cb {
    style = {
      ..style,
      has_filter: true,
      contain: { ..style.contain, paint: true },
    }
  }

  // Apply viewport dimensions if root
  if is_root {
    let is_out_of_flow_root = style.position == @types.Absolute ||
      style.position == @types.Fixed
    if is_out_of_flow_root {
      style = resolve_out_of_flow_root_auto_size(
        style,
        ctx.viewport_width,
        ctx.viewport_height,
      )
    }
    let has_horizontal_inset_pair = is_out_of_flow_root &&
      inset_is_definite_for_root(style.inset.left, ctx.viewport_width) &&
      inset_is_definite_for_root(style.inset.right, ctx.viewport_width)
    if !has_horizontal_inset_pair {
      match style.width {
        @types.Dimension::Auto =>
          style = {
            ..style,
            width: @types.Dimension::Length(ctx.viewport_width),
          }
        _ => ()
      }
    }
  }
  let adjusted = adjust_for_box_sizing(style)
  match (inline_only_cache_css, inline_only_cache_variant_key) {
    (Some(css), Some(variant_key)) =>
      @inline_style_cache.inline_only_style_cache_put(
        css, variant_key, adjusted,
      )
    _ => ()
  }
  adjusted
}

///|
fn compute_element_css_vars_indexed(
  selector_elem : @css.Element,
  inline_css : String?,
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  ctx : RenderContext,
  css_vars : Map[String, String],
) -> Map[String, String] {
  let cascaded = if indexed_stylesheets.length() > 0 {
    let media_env = @css.MediaEnvironment::with_color_scheme(
      ctx.viewport_width,
      ctx.viewport_height,
      ctx.color_scheme,
    )
    Some(
      @css.cascade_element_indexed(
        selector_elem,
        indexed_stylesheets,
        [],
        Some(media_env),
      ),
    )
  } else {
    None
  }
  let element_css_vars = clone_string_map(css_vars)
  collect_cascaded_custom_properties(cascaded, element_css_vars)
  collect_inline_custom_properties(inline_css, element_css_vars)
  seed_effective_color_scheme_for_direct_style(
    cascaded, inline_css, element_css_vars,
  )
  element_css_vars
}

///|
/// Apply a CSS property value to a style (internal)
/// Uses default viewport (1920x1080) for vh/vw resolution
fn apply_css_property(
  style : @style.Style,
  property : String,
  value : String,
) -> @style.Style {
  // Use direct property application to avoid string parsing overhead
  @css.apply_property_direct(style, property, value, @css.ComputeContext::new())
}

///|
fn is_css_calc_space(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\t' || c == '\r' || c == '\u{0C}'
}

///|
fn parse_number_with_suffix(token : String, suffix : String) -> Double? {
  match token.strip_suffix(suffix) {
    Some(raw) => {
      let parsed = @string.parse_double(raw.to_owned()) catch {
        _ => return None
      }
      Some(parsed)
    }
    None => None
  }
}

///|
fn parse_calc_length_or_percent_token(
  token : String,
  ctx : @css.ComputeContext,
) -> (Double, Double)? {
  let t = token.trim().to_owned()
  if t.is_empty() {
    return None
  }
  match parse_number_with_suffix(t, "%") {
    Some(n) => return Some((0.0, n / 100.0))
    None => ()
  }
  match parse_number_with_suffix(t, "px") {
    Some(n) => return Some((n, 0.0))
    None => ()
  }
  match parse_number_with_suffix(t, "vh") {
    Some(n) => return Some((ctx.viewport_height * n / 100.0, 0.0))
    None => ()
  }
  match parse_number_with_suffix(t, "vw") {
    Some(n) => return Some((ctx.viewport_width * n / 100.0, 0.0))
    None => ()
  }
  let parsed = @string.parse_double(t) catch { _ => return None }
  Some((parsed, 0.0))
}

///|
fn parse_simple_calc_length_percent_terms(
  value : String,
  ctx : @css.ComputeContext,
) -> (Double, Double)? {
  let v = value.trim().to_owned()
  if !v.has_prefix("calc(") || !v.has_suffix(")") {
    return None
  }
  let inner = v.unsafe_substring(start=5, end=v.length() - 1)
  let mut i = 0
  let mut sign = 1.0
  let mut length_px = 0.0
  let mut percent = 0.0
  let mut saw_term = false
  while i < inner.length() {
    while i < inner.length() &&
          is_css_calc_space(inner[i].to_int().unsafe_to_char()) {
      i = i + 1
    }
    if i >= inner.length() {
      break
    }
    let c = inner[i].to_int().unsafe_to_char()
    if c == '+' {
      sign = 1.0
      i = i + 1
      continue
    }
    if c == '-' {
      sign = -1.0
      i = i + 1
      continue
    }
    let start = i
    while i < inner.length() {
      let ch = inner[i].to_int().unsafe_to_char()
      if ch == '+' || ch == '-' || is_css_calc_space(ch) {
        break
      }
      i = i + 1
    }
    if start == i {
      return None
    }
    let token = inner.unsafe_substring(start~, end=i)
    match parse_calc_length_or_percent_token(token, ctx) {
      Some((term_px, term_percent)) => {
        length_px = length_px + sign * term_px
        percent = percent + sign * term_percent
        saw_term = true
        sign = 1.0
      }
      None => return None
    }
  }
  if saw_term {
    Some((length_px, percent))
  } else {
    None
  }
}

///|
fn mixed_calc_height_reference(ctx : @css.ComputeContext) -> Double {
  match ctx.parent_style {
    Some(parent) =>
      match parent.height {
        @types.Length(h) => h
        @types.Percent(p) => ctx.viewport_height * p
        _ => ctx.viewport_height
      }
    None => ctx.viewport_height
  }
}

///|
fn resolve_axis_mixed_calc_dimension(
  property : String,
  value : String,
  ctx : @css.ComputeContext,
) -> @types.Dimension? {
  if property != "height" && property != "max-height" {
    return None
  }
  match parse_simple_calc_length_percent_terms(value, ctx) {
    Some((length_px, percent)) =>
      if length_px.abs() < 0.0001 || percent.abs() < 0.0001 {
        None
      } else {
        let resolved = mixed_calc_height_reference(ctx) * percent + length_px
        Some(@types.Length(if resolved < 0.0 { 0.0 } else { resolved }))
      }
    None => None
  }
}

///|
/// Apply a CSS property value to a style with custom viewport and CSS variables
fn apply_css_property_with_viewport(
  style : @style.Style,
  property : String,
  value : String,
  viewport_width : Double,
  viewport_height : Double,
  css_vars : Map[String, String],
  inherited_parent_style : @style.Style?,
) -> @style.Style {
  let inherited_font_size = match inherited_parent_style {
    Some(parent) => parent.font_size
    None => style.font_size
  }
  let context_font_size = if property == "font-size" || property == "font" {
    inherited_font_size
  } else {
    style.font_size
  }
  // Use direct property application to avoid string parsing overhead
  let ctx : @css.ComputeContext = {
    parent_style: inherited_parent_style,
    root_font_size: 16.0,
    font_size: context_font_size,
    viewport_width,
    viewport_height,
    custom_properties: css_vars,
  }
  let resolved = @css.apply_property_direct(style, property, value, ctx)
  match resolve_axis_mixed_calc_dimension(property, value, ctx) {
    Some(dim) =>
      match property {
        "height" => { ..resolved, height: dim }
        "max-height" => { ..resolved, max_height: dim }
        _ => resolved
      }
    None => resolved
  }
}

///|
/// Apply a CSS property value to a style (public for testing)
pub fn apply_css_property_debug(
  style : @style.Style,
  property : String,
  value : String,
) -> @style.Style {
  apply_css_property(style, property, value)
}

///|
/// Parse inline CSS and apply properties to style with CSS variables
fn apply_inline_css_with_vars(
  target : @style.Style,
  inline_css : String,
  css_vars : Map[String, String],
  viewport_width : Double,
  viewport_height : Double,
  inherited_parent_style : @style.Style?,
) -> @style.Style {
  let mut result = target
  let declarations = parse_inline_declarations_cached(inline_css)
  for i = 0; i < declarations.length(); i = i + 1 {
    let (prop, value) = declarations[i]
    result = apply_css_property_with_viewport(
      result, prop, value, viewport_width, viewport_height, css_vars, inherited_parent_style,
    )
  }
  result
}
