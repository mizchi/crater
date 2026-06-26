///|
/// Generated content, pseudo-element, and CSS counter helpers.

///|
priv struct CounterEntry {
  value : Int
  owner : String
  owner_is_style_scope : Bool
}

///|
priv struct CounterDirective {
  name : String
  amount : Int
}

///|
priv enum ContentPart {
  Text(String)
  Counter(String)
  Counters(String, String)
}

///|
priv enum PseudoKind {
  Before
  After
}

///|
fn is_ascii_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn is_ascii_alpha_num_hyphen(c : Char) -> Bool {
  let cp = c.to_int()
  (cp >= 'a'.to_int() && cp <= 'z'.to_int()) ||
  (cp >= 'A'.to_int() && cp <= 'Z'.to_int()) ||
  (cp >= '0'.to_int() && cp <= '9'.to_int()) ||
  c == '-' ||
  c == '_'
}

///|
fn is_ascii_hex_digit(c : Char) -> Bool {
  let cp = c.to_int()
  (cp >= '0'.to_int() && cp <= '9'.to_int()) ||
  (cp >= 'a'.to_int() && cp <= 'f'.to_int()) ||
  (cp >= 'A'.to_int() && cp <= 'F'.to_int())
}

///|
fn ascii_hex_digit_to_int(c : Char) -> Int {
  let cp = c.to_int()
  if cp >= '0'.to_int() && cp <= '9'.to_int() {
    cp - '0'.to_int()
  } else if cp >= 'a'.to_int() && cp <= 'f'.to_int() {
    cp - 'a'.to_int() + 10
  } else {
    cp - 'A'.to_int() + 10
  }
}

///|
fn split_ascii_whitespace_tokens(value : String) -> Array[String] {
  let tokens : Array[String] = []
  let current = StringBuilder::new()
  for c in value.iter() {
    if is_ascii_whitespace(c) {
      if current.to_string().length() > 0 {
        tokens.push(current.to_string())
        current.reset()
      }
    } else {
      current.write_char(c)
    }
  }
  if current.to_string().length() > 0 {
    tokens.push(current.to_string())
  }
  tokens
}

///|
fn first_token_or_empty(tokens : Array[String]) -> String {
  if tokens.is_empty() {
    ""
  } else {
    tokens[0]
  }
}

///|
fn find_char_index(value : String, target : Char) -> Int? {
  let mut i = 0
  while i < value.length() {
    if value[i].to_int().unsafe_to_char() == target {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn parse_counter_directives(
  value : String,
  default_amount : Int,
) -> Array[CounterDirective] {
  let lowered = value.trim().to_lower().to_owned()
  if lowered.is_empty() || lowered == "none" {
    return []
  }
  let tokens = split_ascii_whitespace_tokens(value)
  let directives : Array[CounterDirective] = []
  let mut i = 0
  while i < tokens.length() {
    let name = tokens[i].trim().to_owned()
    i += 1
    if name.is_empty() {
      continue
    }
    let mut amount = default_amount
    if i < tokens.length() {
      let parsed = @string.parse_int(tokens[i]) catch { _ => default_amount }
      // Heuristic: only treat token as number when parsing changed it from default
      // or when token is explicit zero/negative.
      if parsed != default_amount ||
        tokens[i] == "0" ||
        tokens[i].has_prefix("-") ||
        tokens[i].has_prefix("+") {
        amount = parsed
        i += 1
      }
    }
    directives.push({ name, amount })
  }
  directives
}

///|
fn copy_counter_state(
  state : Map[String, CounterEntry],
) -> Map[String, CounterEntry] {
  let copied : Map[String, CounterEntry] = {}
  state.each(fn(name, entry) { copied[name] = entry })
  copied
}

///|
fn filter_counter_state_for_style_containment(
  state : Map[String, CounterEntry],
  owner_id : String,
) -> Map[String, CounterEntry] {
  let filtered : Map[String, CounterEntry] = {}
  state.each(fn(name, entry) {
    if entry.owner == owner_id {
      filtered[name] = entry
    }
  })
  filtered
}

///|
fn apply_counter_reset_directives(
  state : Map[String, CounterEntry],
  directives : Array[CounterDirective],
  owner_id : String,
  owner_is_style_scope : Bool,
) -> Unit {
  for directive in directives {
    state[directive.name] = {
      value: directive.amount,
      owner: owner_id,
      owner_is_style_scope,
    }
  }
}

///|
fn apply_counter_increment_directives(
  state : Map[String, CounterEntry],
  directives : Array[CounterDirective],
  owner_id : String,
  owner_is_style_scope : Bool,
) -> Unit {
  for directive in directives {
    let amount = directive.amount
    match state.get(directive.name) {
      Some(entry) =>
        if entry.owner_is_style_scope && entry.owner != owner_id {
          state[directive.name] = {
            value: amount,
            owner: owner_id,
            owner_is_style_scope,
          }
        } else {
          state[directive.name] = { ..entry, value: entry.value + amount }
        }
      None =>
        state[directive.name] = {
          value: amount,
          owner: owner_id,
          owner_is_style_scope,
        }
    }
  }
}

///|
fn counter_value(state : Map[String, CounterEntry], name : String) -> Int {
  match state.get(name) {
    Some(entry) => entry.value
    None => 0
  }
}

///|
fn parse_css_quoted_string(value : String, start : Int) -> (String, Int)? {
  if start >= value.length() {
    return None
  }
  let quote = value[start].to_int().unsafe_to_char()
  if quote != '"' && quote != '\'' {
    return None
  }
  let buf = StringBuilder::new()
  let mut i = start + 1
  while i < value.length() {
    let c = value[i].to_int().unsafe_to_char()
    if c == quote {
      return Some((buf.to_string(), i - start + 1))
    }
    if c == '\\' {
      if i + 1 >= value.length() {
        i += 1
        continue
      }
      let next = value[i + 1].to_int().unsafe_to_char()
      if is_ascii_hex_digit(next) {
        let mut code = 0
        let mut hex_i = i + 1
        let mut count = 0
        while hex_i < value.length() && count < 6 {
          let hc = value[hex_i].to_int().unsafe_to_char()
          if !is_ascii_hex_digit(hc) {
            break
          }
          code = code * 16 + ascii_hex_digit_to_int(hc)
          hex_i += 1
          count += 1
        }
        if code > 0 {
          buf.write_char(code.unsafe_to_char())
        }
        if hex_i < value.length() {
          let ws = value[hex_i].to_int().unsafe_to_char()
          if is_ascii_whitespace(ws) {
            hex_i += 1
          }
        }
        i = hex_i
        continue
      }
      if next == '\n' || next == '\r' {
        i += 2
        continue
      }
      buf.write_char(next)
      i += 2
      continue
    }
    buf.write_char(c)
    i += 1
  }
  Some((buf.to_string(), value.length() - start))
}

///|
fn escape_css_string_content(value : String) -> String {
  let buf = StringBuilder::new()
  for c in value.iter() {
    if c == '\\' || c == '"' {
      buf.write_char('\\')
    }
    buf.write_char(c)
  }
  buf.to_string()
}

///|
fn resolve_pseudo_attr_functions(
  value : String,
  element_attributes : Map[String, String],
) -> String {
  if !value.contains("attr(") {
    return value
  }
  let buf = StringBuilder::new()
  let mut i = 0
  while i < value.length() {
    let remaining = value.length() - i
    if remaining >= 5 {
      let chunk = value.unsafe_substring(start=i, end=i + 5)
      if chunk == "attr(" {
        let mut depth = 1
        let arg_start = i + 5
        let mut j = arg_start
        while j < value.length() {
          let c = value[j].to_int().unsafe_to_char()
          if c == '(' {
            depth += 1
          } else if c == ')' {
            depth -= 1
            if depth == 0 {
              break
            }
          }
          j += 1
        }
        if j < value.length() && depth == 0 {
          let raw_args = value.unsafe_substring(start=arg_start, end=j)
          let attr_name = first_token_or_empty(
            split_ascii_whitespace_tokens(raw_args),
          )
          let attr_value = match element_attributes.get(attr_name) {
            Some(found) => found
            None => ""
          }
          buf.write_char('"')
          buf.write_string(escape_css_string_content(attr_value))
          buf.write_char('"')
          i = j + 1
          continue
        }
      }
    }
    buf.write_char(value[i].to_int().unsafe_to_char())
    i += 1
  }
  buf.to_string()
}

///|
fn find_top_level_comma(value : String) -> Int? {
  let mut depth = 0
  let mut i = 0
  while i < value.length() {
    let c = value[i].to_int().unsafe_to_char()
    if c == '(' {
      depth += 1
    } else if c == ')' {
      if depth > 0 {
        depth -= 1
      }
    } else if c == ',' && depth == 0 {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn resolve_pseudo_content_value(
  value : String,
  css_vars : Map[String, String],
  element_attributes : Map[String, String],
) -> String {
  let mut resolved = value
  let mut loop_count = 0
  while loop_count < 16 && resolved.contains("var(") {
    let buf = StringBuilder::new()
    let mut i = 0
    let mut changed = false
    while i < resolved.length() {
      let remaining = resolved.length() - i
      if remaining >= 4 {
        let chunk = resolved.unsafe_substring(start=i, end=i + 4)
        if chunk == "var(" {
          let mut depth = 1
          let arg_start = i + 4
          let mut j = arg_start
          while j < resolved.length() {
            let c = resolved[j].to_int().unsafe_to_char()
            if c == '(' {
              depth += 1
            } else if c == ')' {
              depth -= 1
              if depth == 0 {
                break
              }
            }
            j += 1
          }
          if j < resolved.length() && depth == 0 {
            let raw_args = resolved.unsafe_substring(start=arg_start, end=j)
            let replacement = match find_top_level_comma(raw_args) {
              Some(comma_index) => {
                let name = raw_args.unsafe_substring(start=0, end=comma_index)
                let fallback = raw_args.unsafe_substring(
                  start=comma_index + 1,
                  end=raw_args.length(),
                )
                match css_vars.get(name.trim().to_owned()) {
                  Some(found) =>
                    resolve_pseudo_content_value(
                      found, css_vars, element_attributes,
                    )
                  None =>
                    resolve_pseudo_content_value(
                      fallback, css_vars, element_attributes,
                    )
                }
              }
              None => {
                let name = raw_args.trim().to_owned()
                match css_vars.get(name) {
                  Some(found) =>
                    resolve_pseudo_content_value(
                      found, css_vars, element_attributes,
                    )
                  None => ""
                }
              }
            }
            buf.write_string(replacement)
            i = j + 1
            changed = true
            continue
          }
        }
      }
      buf.write_char(resolved[i].to_int().unsafe_to_char())
      i += 1
    }
    resolved = if changed { buf.to_string() } else { resolved }
    if !changed {
      break
    }
    loop_count += 1
  }
  resolve_pseudo_attr_functions(resolved, element_attributes)
}

///|
fn parse_content_parts(value : String) -> Array[ContentPart]? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() || trimmed == "none" || trimmed == "normal" {
    return None
  }
  let parts : Array[ContentPart] = []
  let mut i = 0
  while i < trimmed.length() {
    let c = trimmed[i].to_int().unsafe_to_char()
    if is_ascii_whitespace(c) {
      i += 1
      continue
    }
    if c == '"' || c == '\'' {
      match parse_css_quoted_string(trimmed, i) {
        Some((text, consumed)) => {
          parts.push(Text(text))
          i += consumed
          continue
        }
        None => ()
      }
    }
    if is_ascii_alpha_num_hyphen(c) {
      let mut end = i + 1
      while end < trimmed.length() {
        let ec = trimmed[end].to_int().unsafe_to_char()
        if !is_ascii_alpha_num_hyphen(ec) {
          break
        }
        end += 1
      }
      let ident = trimmed.unsafe_substring(start=i, end~)
      let ident_lower = ident.to_lower()
      let mut j = end
      while j < trimmed.length() {
        let jc = trimmed[j].to_int().unsafe_to_char()
        if !is_ascii_whitespace(jc) {
          break
        }
        j += 1
      }
      if j < trimmed.length() && trimmed[j].to_int().unsafe_to_char() == '(' {
        let mut depth = 1
        let arg_start = j + 1
        let mut k = j + 1
        while k < trimmed.length() {
          let kc = trimmed[k].to_int().unsafe_to_char()
          if kc == '(' {
            depth += 1
          } else if kc == ')' {
            depth -= 1
            if depth == 0 {
              break
            }
          }
          k += 1
        }
        if k < trimmed.length() && depth == 0 {
          let args = trimmed.unsafe_substring(start=arg_start, end=k)
          if ident_lower == "counter" {
            let name = first_token_or_empty(split_ascii_whitespace_tokens(args))
            let name = name.trim().to_owned()
            if !name.is_empty() {
              parts.push(Counter(name))
            }
          } else if ident_lower == "counters" {
            let comma_index = find_char_index(args, ',')
            match comma_index {
              Some(ci) => {
                let name = args.unsafe_substring(start=0, end=ci)
                let raw_sep = args.unsafe_substring(
                  start=ci + 1,
                  end=args.length(),
                )
                let sep = match
                  parse_css_quoted_string(raw_sep.trim().to_owned(), 0) {
                  Some((s, _)) => s
                  None => raw_sep.trim().to_owned()
                }
                let counter_name = name.trim().to_owned()
                if !counter_name.is_empty() {
                  parts.push(Counters(counter_name, sep))
                }
              }
              None => {
                let name = args.trim().to_owned()
                if !name.is_empty() {
                  parts.push(Counter(name))
                }
              }
            }
          }
          i = k + 1
          continue
        }
      }
    }
    i += 1
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts)
  }
}

///|
fn evaluate_content_parts(
  parts : Array[ContentPart],
  counters : Map[String, CounterEntry],
) -> String {
  let buf = StringBuilder::new()
  for part in parts {
    match part {
      Text(text) => buf.write_string(text)
      Counter(name) =>
        buf.write_string(counter_value(counters, name).to_string())
      Counters(name, _sep) =>
        // For current WPT subset we keep only the active innermost value.
        buf.write_string(counter_value(counters, name).to_string())
    }
  }
  buf.to_string()
}

///|
fn parse_relative_left_offset(
  value : String,
  host_style : @style.Style,
) -> Double {
  let trimmed = value.trim().to_lower().to_owned()
  if trimmed.is_empty() {
    return 0.0
  }
  let base_font_size = if host_style.font_size > 0.0 {
    host_style.font_size
  } else {
    16.0
  }
  if trimmed.has_suffix("ch") {
    let num = @string.parse_double(remove_suffix(trimmed, 2).to_string()) catch {
      _ => 0.0
    }
    num * base_font_size * 0.5
  } else if trimmed.has_suffix("em") {
    let num = @string.parse_double(remove_suffix(trimmed, 2).to_string()) catch {
      _ => 0.0
    }
    num * base_font_size
  } else if trimmed.has_suffix("px") {
    @string.parse_double(remove_suffix(trimmed, 2).to_string()) catch {
      _ => 0.0
    }
  } else {
    @string.parse_double(trimmed) catch {
      _ => 0.0
    }
  }
}

///|
fn selector_text_without_pseudo(
  selector_text : String,
  pseudo_kind : PseudoKind,
) -> String? {
  let trimmed = selector_text.trim().to_owned()
  let (double_suffix, single_suffix) = match pseudo_kind {
    Before => ("::before", ":before")
    After => ("::after", ":after")
  }
  if trimmed.has_suffix(double_suffix) {
    let len = trimmed.length()
    let base_len = len - double_suffix.length()
    let base = trimmed.unsafe_substring(start=0, end=base_len)
    let cleaned = base.trim().to_owned()
    if cleaned.is_empty() {
      None
    } else {
      Some(cleaned)
    }
  } else if trimmed.has_suffix(single_suffix) {
    let len = trimmed.length()
    let base_len = len - single_suffix.length()
    let base = trimmed.unsafe_substring(start=0, end=base_len)
    let cleaned = base.trim().to_owned()
    if cleaned.is_empty() {
      None
    } else {
      Some(cleaned)
    }
  } else {
    None
  }
}

///|
fn selector_text_fallback_matches(
  selector_text : String,
  selector_elem : @css.Element,
) -> Bool {
  let lowered = selector_text.to_lower()
  let tag_lower = selector_elem.tag_name.to_lower()
  if lowered.contains(":is(") {
    if lowered.contains(tag_lower) {
      return true
    }
  }
  match selector_elem.id {
    Some(id) => if lowered.contains("#" + id.to_lower()) { return true }
    None => ()
  }
  for cls in selector_elem.classes {
    if lowered.contains("." + cls.to_lower()) {
      return true
    }
  }
  lowered.contains(tag_lower)
}

///|
priv struct AfterPseudoSpec {
  content : String
  position_relative : Bool
  out_of_flow : Bool
  left_offset : Double
  generated_style : @style.Style
}

///|
fn apply_generated_pseudo_host_style_offsets(
  style : @style.Style,
  before_pseudo : AfterPseudoSpec?,
  after_pseudo : AfterPseudoSpec?,
) -> @style.Style {
  match after_pseudo {
    Some(spec) if spec.position_relative && spec.left_offset != 0.0 =>
      {
        ..style,
        position: @types.Relative,
        inset: { ..style.inset, left: @types.Length(spec.left_offset) },
      }
    _ =>
      match before_pseudo {
        Some(spec) if spec.position_relative && spec.left_offset != 0.0 =>
          {
            ..style,
            position: @types.Relative,
            inset: { ..style.inset, left: @types.Length(spec.left_offset) },
          }
        _ => style
      }
  }
}

///|
fn resolve_element_counter_pseudos(
  incoming_counters : Map[String, CounterEntry],
  selector_elem : @css.Element,
  style : @style.Style,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
  owner_id : String,
  below_viewport : Bool,
  element_css_vars : Map[String, String],
  element_attributes : Map[String, String],
) -> (
  Map[String, CounterEntry],
  AfterPseudoSpec?,
  AfterPseudoSpec?,
  @style.Style,
) {
  let own_counters = if stylesheets.length() == 0 {
    incoming_counters
  } else {
    compute_element_own_counters(
      incoming_counters, selector_elem, style, stylesheets, ctx, owner_id,
    )
  }
  let before_pseudo = if below_viewport || stylesheets.length() == 0 {
    None
  } else {
    resolve_pseudo_spec_fast(
      selector_elem,
      style,
      ctx,
      Before,
      own_counters,
      element_css_vars,
      element_attributes,
    )
  }
  let after_pseudo = if below_viewport || stylesheets.length() == 0 {
    None
  } else {
    resolve_pseudo_spec_fast(
      selector_elem,
      style,
      ctx,
      After,
      own_counters,
      element_css_vars,
      element_attributes,
    )
  }
  let style = apply_generated_pseudo_host_style_offsets(
    style, before_pseudo, after_pseudo,
  )
  (own_counters, before_pseudo, after_pseudo, style)
}

///|
fn create_generated_pseudo_node(
  spec : AfterPseudoSpec,
  pseudo_kind : PseudoKind,
) -> @node.Node {
  let pseudo_id = match pseudo_kind {
    Before => "#pseudo::before"
    After => "#pseudo::after"
  }
  let pseudo_is_contents = spec.generated_style.display == @types.Contents
  let inline_plain_generated_text = spec.generated_style.display ==
    @types.Inline &&
    !spec.position_relative &&
    !spec.out_of_flow &&
    spec.left_offset.abs() <= 0.01
  if spec.content.is_empty() {
    @node.Node::leaf(pseudo_id, spec.generated_style)
  } else if pseudo_is_contents {
    // display: contents pseudo-elements should expose generated text as child content.
    let text_child = create_text_node(spec.content, spec.generated_style)
    @node.Node::new(pseudo_id, spec.generated_style, [text_child])
  } else if inline_plain_generated_text {
    // Static inline generated content behaves like regular inline text runs.
    create_text_node(spec.content, spec.generated_style)
  } else {
    let font_size = spec.generated_style.font_size
    let text_line_height = spec.generated_style.line_height
    let white_space = spec.generated_style.white_space
    let writing_mode = spec.generated_style.writing_mode
    @node.Node::with_measure(
      pseudo_id,
      spec.generated_style,
      create_text_measure_with_provider(
        spec.content,
        font_size,
        text_line_height,
        white_space,
        writing_mode,
      ),
      text=spec.content,
    )
  }
}

///|
fn pseudo_base_style_from_host(host_style : @style.Style) -> @style.Style {
  {
    ..@style.Style::default(),
    display: @types.Inline,
    visibility: host_style.visibility,
    pointer_events: host_style.pointer_events,
    color: host_style.color,
    font_size: host_style.font_size,
    font_weight: host_style.font_weight,
    font_family: host_style.font_family,
    line_height: host_style.line_height,
    text_align: host_style.text_align,
    white_space: host_style.white_space,
    writing_mode: host_style.writing_mode,
    direction: host_style.direction,
    text_decoration_underline: host_style.text_decoration_underline,
    text_decoration_line_through: host_style.text_decoration_line_through,
    text_decoration_overline: host_style.text_decoration_overline,
    letter_spacing: host_style.letter_spacing,
    word_spacing: host_style.word_spacing,
  }
}

///|
fn resolve_pseudo_spec(
  selector_elem : @css.Element,
  host_style : @style.Style,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
  pseudo_kind : PseudoKind,
  counters : Map[String, CounterEntry],
  css_vars : Map[String, String],
  element_attributes : Map[String, String],
) -> AfterPseudoSpec? {
  let media_env = @css.MediaEnvironment::with_color_scheme(
    ctx.viewport_width,
    ctx.viewport_height,
    ctx.color_scheme,
  )
  let mut content_parts : Array[ContentPart]? = None
  let mut content_specified = false
  let mut content_disabled = false
  let mut position_relative = false
  let mut out_of_flow = false
  let mut left_offset = 0.0
  let pseudo_css_vars = clone_string_map(css_vars)
  // ::before/::after inherit text properties, not host box dimensions.
  let mut generated_style = pseudo_base_style_from_host(host_style)

  // Quick suffix check keyword to skip rules that can't match this pseudo
  let pseudo_keyword = match pseudo_kind {
    Before => "before"
    After => "after"
  }
  for stylesheet in stylesheets {
    for rule in stylesheet.rules {
      // Fast path: skip rules whose selector text doesn't contain the pseudo keyword
      if !rule.selector_text.contains(pseudo_keyword) {
        continue
      }
      let media_matches = match rule.media_query {
        Some(mq) => mq.evaluate(media_env)
        None => true
      }
      if !media_matches {
        continue
      }
      match selector_text_without_pseudo(rule.selector_text, pseudo_kind) {
        Some(base_selector_text) => {
          let matches_selector = match @css.parse_selector(base_selector_text) {
            Some(base_selector) =>
              @css.matches_selector(selector_elem, base_selector)
            None =>
              selector_text_fallback_matches(base_selector_text, selector_elem)
          }
          if matches_selector {
            for decl in rule.declarations {
              match decl.value {
                @css.PropertyValue::Value(v) => {
                  let prop = decl.property.to_lower()
                  if prop.has_prefix("--") {
                    pseudo_css_vars[prop] = v
                  } else if prop == "content" {
                    content_specified = true
                    let resolved_value = resolve_pseudo_content_value(
                      v, pseudo_css_vars, element_attributes,
                    )
                    let normalized = resolved_value.trim().to_lower().to_owned()
                    if normalized == "none" || normalized == "normal" {
                      content_parts = None
                      content_disabled = true
                    } else {
                      content_parts = parse_content_parts(resolved_value)
                      content_disabled = false
                    }
                  } else if prop == "position" {
                    let pos = v.trim().to_lower()
                    if pos == "relative" {
                      position_relative = true
                    } else if pos == "absolute" || pos == "fixed" {
                      out_of_flow = true
                    }
                  } else if prop == "left" {
                    left_offset = parse_relative_left_offset(v, host_style)
                  }
                  if prop != "content" && !prop.has_prefix("--") {
                    generated_style = apply_css_property_with_viewport(
                      generated_style,
                      prop,
                      v,
                      ctx.viewport_width,
                      ctx.viewport_height,
                      pseudo_css_vars,
                      Some(host_style),
                    )
                  }
                }
                _ => ()
              }
            }
          }
        }
        None => ()
      }
    }
  }

  if content_disabled || !content_specified {
    return None
  }
  let text = match content_parts {
    Some(parts) => evaluate_content_parts(parts, counters)
    None => ""
  }
  Some({
    content: text,
    position_relative,
    out_of_flow,
    left_offset,
    generated_style,
  })
}

///|
fn resolve_pseudo_spec_fast(
  selector_elem : @css.Element,
  host_style : @style.Style,
  ctx : RenderContext,
  pseudo_kind : PseudoKind,
  counters : Map[String, CounterEntry],
  css_vars : Map[String, String],
  element_attributes : Map[String, String],
) -> AfterPseudoSpec? {
  let media_env = @css.MediaEnvironment::with_color_scheme(
    ctx.viewport_width,
    ctx.viewport_height,
    ctx.color_scheme,
  )
  let mut content_parts : Array[ContentPart]? = None
  let mut content_specified = false
  let mut content_disabled = false
  let mut position_relative = false
  let mut out_of_flow = false
  let mut left_offset = 0.0
  let pseudo_css_vars = clone_string_map(css_vars)
  let mut generated_style = pseudo_base_style_from_host(host_style)
  let index = match pseudo_kind {
    Before => active_before_index.val
    After => active_after_index.val
  }
  if index.rules.is_empty() {
    return None
  }
  // Use index to get candidates (much faster than scanning all rules)
  let candidates = index.get_candidates(selector_elem)
  for rule_idx in candidates {
    let rule = index.rules[rule_idx]
    let media_matches = match rule.media_query {
      Some(mq) => mq.evaluate(media_env)
      None => true
    }
    if !media_matches {
      continue
    }
    let matches_selector = match rule.base_selector {
      Some(base_selector) => @css.matches_selector(selector_elem, base_selector)
      None =>
        selector_text_fallback_matches(rule.base_selector_text, selector_elem)
    }
    if matches_selector {
      for decl in rule.declarations {
        match decl.value {
          @css.PropertyValue::Value(v) => {
            let prop = decl.property.to_lower()
            if prop.has_prefix("--") {
              pseudo_css_vars[prop] = v
            } else if prop == "content" {
              content_specified = true
              let resolved_value = resolve_pseudo_content_value(
                v, pseudo_css_vars, element_attributes,
              )
              let normalized = resolved_value.trim().to_lower().to_owned()
              if normalized == "none" || normalized == "normal" {
                content_parts = None
                content_disabled = true
              } else {
                content_parts = parse_content_parts(resolved_value)
                content_disabled = false
              }
            } else if prop == "position" {
              let pos = v.trim().to_lower()
              if pos == "relative" {
                position_relative = true
              } else if pos == "absolute" || pos == "fixed" {
                out_of_flow = true
              }
            } else if prop == "left" {
              left_offset = parse_relative_left_offset(v, host_style)
            }
            if prop != "content" && !prop.has_prefix("--") {
              generated_style = apply_css_property_with_viewport(
                generated_style,
                prop,
                v,
                ctx.viewport_width,
                ctx.viewport_height,
                pseudo_css_vars,
                Some(host_style),
              )
            }
          }
          _ => ()
        }
      }
    }
  }
  if content_disabled || !content_specified {
    return None
  }
  let text = match content_parts {
    Some(parts) => evaluate_content_parts(parts, counters)
    None => ""
  }
  Some({
    content: text,
    position_relative,
    out_of_flow,
    left_offset,
    generated_style,
  })
}

///|
fn get_counter_directives(
  selector_elem : @css.Element,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> (Array[CounterDirective], Array[CounterDirective]) {
  let media_env = @css.MediaEnvironment::with_color_scheme(
    ctx.viewport_width,
    ctx.viewport_height,
    ctx.color_scheme,
  )
  let cascaded = @css.cascade_element_with_media(
    selector_elem,
    stylesheets,
    [],
    Some(media_env),
  )
  let reset_raw = match cascaded.get_value("counter-reset") {
    Some(v) => v
    None => ""
  }
  let increment_raw = match cascaded.get_value("counter-increment") {
    Some(v) => v
    None => ""
  }
  (
    parse_counter_directives(reset_raw, 0),
    parse_counter_directives(increment_raw, 1),
  )
}

///|
fn selector_has_generated_pseudo_content(
  selector_elem : @css.Element,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  // `stylesheets` is retained for signature compatibility; the fast variant
  // resolves against the precomputed before/after pseudo-rule indexes instead
  // of re-scanning every rule's selector text per element (which on text-heavy
  // pages dominated the render — O(elements x rules) substring searches; #316).
  ignore(stylesheets)
  let empty_counters : Map[String, CounterEntry] = {}
  let empty_css_vars : Map[String, String] = {}
  let empty_attributes : Map[String, String] = {}
  let default_style = @style.Style::default()
  let has_before = resolve_pseudo_spec_fast(
      selector_elem,
      default_style,
      ctx,
      Before,
      empty_counters,
      empty_css_vars,
      empty_attributes,
    )
    is Some(_)
  let has_after = resolve_pseudo_spec_fast(
      selector_elem,
      default_style,
      ctx,
      After,
      empty_counters,
      empty_css_vars,
      empty_attributes,
    )
    is Some(_)
  has_before || has_after
}

///|
fn establishes_style_containment_scope(style : @style.Style) -> Bool {
  style.contain.style && style.display != @types.Contents
}

///|
fn compute_element_own_counters(
  incoming_counters : Map[String, CounterEntry],
  selector_elem : @css.Element,
  style : @style.Style,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
  owner_id : String,
) -> Map[String, CounterEntry] {
  let own_counters = copy_counter_state(incoming_counters)
  let is_style_scope = establishes_style_containment_scope(style)
  let (counter_resets, counter_increments) = get_counter_directives(
    selector_elem, stylesheets, ctx,
  )
  apply_counter_reset_directives(
    own_counters, counter_resets, owner_id, is_style_scope,
  )
  apply_counter_increment_directives(
    own_counters, counter_increments, owner_id, is_style_scope,
  )
  own_counters
}
