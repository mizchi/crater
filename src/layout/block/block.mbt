///|
/// Create a zero-sized layout for a node (used for display:none)
/// Recursively creates zero layouts for all descendants
fn create_zero_layout(node : @node.Node) -> @types.Layout {
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let children : Array[@types.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    children.push(create_zero_layout(node.children[i]))
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: node.text,
  }
}

///|
/// Collapse two margins according to CSS rules:
/// - Both positive: use the larger one
/// - Both negative: use the more negative (smaller) one
/// - Mixed: add them (positive + negative)
fn collapse_margins(m1 : Double, m2 : Double) -> Double {
  if m1 >= 0.0 && m2 >= 0.0 {
    @types.max(m1, m2)
  } else if m1 <= 0.0 && m2 <= 0.0 {
    @types.min(m1, m2)
  } else {
    m1 + m2
  }
}

///|
/// Resolve a dimension to pixels for intrinsic sizing
/// Percentages resolve to 0 in intrinsic sizing mode
fn resolve_dimension_intrinsic(dim : @types.Dimension) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(_) => 0.0 // Percentages resolve to 0 in intrinsic sizing
    @types.Auto => 0.0
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
  }
}

///|
/// Whether this subtree contains replaced-like measured descendants that rely on
/// percentage sizing. In quirks-like cases browsers propagate a usable
/// block-size through auto-height wrappers for these elements.
fn has_percent_sized_replaced_descendant(node : @node.Node) -> Bool {
  for child in node.children {
    let child_uses_percent_size = match
      (child.style.width, child.style.height) {
      (@types.Percent(_), _) => true
      (_, @types.Percent(_)) => true
      _ => false
    }
    let child_is_measured_leaf = match child.measure {
      Some(_) => child.children.length() == 0
      None => false
    }
    if child_is_measured_leaf && child_uses_percent_size {
      return true
    }
    if has_percent_sized_replaced_descendant(child) {
      return true
    }
  }
  false
}

///|
fn has_percent_sized_descendant(node : @node.Node) -> Bool {
  for child in node.children {
    let child_uses_percent_size = match
      (child.style.width, child.style.height) {
      (@types.Percent(_), _) => true
      (_, @types.Percent(_)) => true
      _ => false
    }
    if child_uses_percent_size {
      return true
    }
    if has_percent_sized_descendant(child) {
      return true
    }
  }
  false
}

///|
/// Collapsed margins that escape from a child element
priv struct CollapsedMargins {
  top : Double? // Margin that escapes upward
  bottom : Double? // Margin that escapes downward
}

///|
/// Internal layout result with collapsed margin tracking
priv struct LayoutWithCollapse {
  layout : @types.Layout
  collapsed : CollapsedMargins
}

///|
/// A flattened table child with its display:contents wrapper path.
priv struct FlattenedTableChild {
  child : @node.Node
  wrappers : Array[@node.Node]
}

///|
/// Deferred override for anonymous table runs in block flow.
priv struct AnonymousTableRunOverride {
  flow_indices : Array[Int]
  layouts : Array[@types.Layout]
}

///|
/// Check if a display type is table-internal.
fn is_table_internal_display(display : @types.Display) -> Bool {
  match display {
    @types.TableRow
    | @types.TableCell
    | @types.TableCaption
    | @types.TableRowGroup
    | @types.TableHeaderGroup
    | @types.TableFooterGroup
    | @types.TableColumn
    | @types.TableColumnGroup => true
    _ => false
  }
}

///|
/// Table-internal displays that do not generate a principal box in block flow.
fn is_no_principal_table_internal_display(display : @types.Display) -> Bool {
  match display {
    @types.TableRow
    | @types.TableRowGroup
    | @types.TableHeaderGroup
    | @types.TableFooterGroup
    | @types.TableColumn
    | @types.TableColumnGroup => true
    _ => false
  }
}

///|
fn is_table_principal_display(display : @types.Display) -> Bool {
  match display {
    @types.Table | @types.InlineTable => true
    _ => false
  }
}

///|
/// Containment effects only apply when the element generates a principal box.
fn containment_applies(display : @types.Display) -> Bool {
  not(is_no_principal_table_internal_display(display)) &&
  display != @types.Inline
}

///|
fn id_matches_tag(node_id : String, tag : String) -> Bool {
  let tlen = tag.length()
  let nlen = node_id.length()
  if nlen < tlen {
    return false
  }
  // Check prefix matches tag
  for i = 0; i < tlen; i = i + 1 {
    if node_id[i] != tag[i] {
      return false
    }
  }
  // Exact match or followed by '#' or '.'
  nlen == tlen || node_id[tlen] == '#' || node_id[tlen] == '.'
}

///|
fn is_ruby_internal_id(node_id : String) -> Bool {
  id_matches_tag(node_id, "rb") ||
  id_matches_tag(node_id, "rbc") ||
  id_matches_tag(node_id, "rt") ||
  id_matches_tag(node_id, "rtc")
}

///|
/// Whether this box establishes containing block for absolute descendants.
fn establishes_abs_containing_block(
  style : @style.Style,
  display : @types.Display,
) -> Bool {
  match style.position {
    @types.Absolute | @types.Fixed | @types.Relative => true
    @types.Static =>
      (
        containment_applies(display) &&
        (style.contain.layout || style.contain.paint)
      ) ||
      not(style.transform.is_none())
  }
}

///|
/// Whether a subtree contains any table-internal node.
fn has_table_internal_descendant(node : @node.Node) -> Bool {
  if is_table_internal_display(node.style.display) {
    return true
  }
  for child in node.children {
    if child.style.display == @types.Display::None {
      continue
    }
    if has_table_internal_descendant(child) {
      return true
    }
  }
  false
}

///|
/// Whether this flow node participates in anonymous table wrapper synthesis.
fn is_table_internal_flow_node(node : @node.Node) -> Bool {
  if is_table_internal_display(node.style.display) {
    return true
  }
  node.style.display == @types.Contents && has_table_internal_descendant(node)
}

///|
/// Clone wrapper path with one additional wrapper.
fn push_wrapper_path(
  wrappers : Array[@node.Node],
  wrapper : @node.Node,
) -> Array[@node.Node] {
  let next : Array[@node.Node] = []
  for existing in wrappers {
    next.push(existing)
  }
  next.push(wrapper)
  next
}

///|
/// Find the first table-internal leaf under a table flow node.
fn flatten_first_table_child(
  node : @node.Node,
  wrappers : Array[@node.Node],
) -> FlattenedTableChild? {
  if node.style.display == @types.Display::None {
    return None
  }
  if is_table_internal_display(node.style.display) {
    return Some({ child: node, wrappers })
  }
  if node.style.display != @types.Contents {
    return None
  }
  let next_wrappers = push_wrapper_path(wrappers, node)
  for child in node.children {
    match flatten_first_table_child(child, next_wrappers) {
      Some(flattened) => return Some(flattened)
      None => ()
    }
  }
  None
}

///|
fn is_table_run_whitespace_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn is_whitespace_only_table_run_text(node : @node.Node) -> Bool {
  if not(node.id.has_prefix("#text")) {
    return false
  }
  match node.text {
    Some(text) => {
      for c in text.iter() {
        if not(is_table_run_whitespace_char(c)) {
          return false
        }
      }
      true
    }
    None => true
  }
}

///|
fn is_flow_whitespace_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn white_space_collapses_edges(white_space : @style.WhiteSpace) -> Bool {
  match white_space {
    @style.WhiteSpace::Normal
    | @style.WhiteSpace::Nowrap
    | @style.WhiteSpace::PreLine => true
    @style.WhiteSpace::Pre | @style.WhiteSpace::PreWrap => false
  }
}

///|
fn text_ends_with_collapsible_flow_whitespace(node : @node.Node) -> Bool {
  if not(node.id.has_prefix("#text")) ||
    not(white_space_collapses_edges(node.style.white_space)) {
    return false
  }
  match node.text {
    Some(text) => {
      let chars : Array[Char] = []
      for c in text.iter() {
        chars.push(c)
      }
      if chars.length() == 0 {
        return false
      }
      is_flow_whitespace_char(chars[chars.length() - 1])
    }
    None => false
  }
}

///|
fn is_whitespace_only_flow_text(node : @node.Node) -> Bool {
  if not(node.id.has_prefix("#text")) {
    return false
  }
  match node.text {
    Some(text) => {
      for c in text.iter() {
        if not(is_flow_whitespace_char(c)) {
          return false
        }
      }
      true
    }
    None => true
  }
}

///|
fn flow_whitespace_contains_line_break(node : @node.Node) -> Bool {
  if not(node.id.has_prefix("#text")) {
    return false
  }
  match node.text {
    Some(text) =>
      for c in text.iter() {
        if c == '\n' || c == '\r' || c == '\t' || c == '\u000C' {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn is_replaced_like_flow_node(node : @node.Node) -> Bool {
  if node.text is Some(_) {
    return false
  }
  match node.measure {
    Some(_) => node.children.length() == 0
    None => false
  }
}

///|
fn has_percent_size_for_flow(node : @node.Node) -> Bool {
  match (node.style.width, node.style.height) {
    (@types.Percent(_), _) => true
    (_, @types.Percent(_)) => true
    _ => false
  }
}

///|
fn participates_inline_for_flow_whitespace(node : @node.Node) -> Bool {
  if node.style.display == @types.Display::None {
    return false
  }
  if node.style.position == @types.Absolute ||
    node.style.position == @types.Fixed {
    return false
  }
  match node.style.float {
    @types.Float::Left | @types.Float::Right => return false
    @types.Float::None => ()
  }
  if node.id.has_prefix("#text") {
    match node.text {
      Some(text) => {
        for c in text.iter() {
          if not(is_flow_whitespace_char(c)) {
            return true
          }
        }
        false
      }
      None => false
    }
  } else if node.style.display == @types.Contents {
    contents_is_inline_flow(node)
  } else {
    @inline.is_inline_level(node.style.display)
  }
}

///|
fn should_preserve_flow_whitespace_text(
  siblings : Array[@node.Node],
  index : Int,
) -> Bool {
  if index <= 0 || index >= siblings.length() - 1 {
    return false
  }
  let mut prev_index : Int? = None
  let mut p = index - 1
  while p >= 0 {
    let sibling = siblings[p]
    if sibling.style.display != @types.Display::None {
      prev_index = Some(p)
      break
    }
    p = p - 1
  }
  let mut next_index : Int? = None
  let mut n = index + 1
  while n < siblings.length() {
    let sibling = siblings[n]
    if sibling.style.display != @types.Display::None {
      next_index = Some(n)
      break
    }
    n = n + 1
  }
  let prev = match prev_index {
    Some(i) => siblings[i]
    None => return false
  }
  let next = match next_index {
    Some(i) => siblings[i]
    None => return false
  }
  if flow_whitespace_contains_line_break(siblings[index]) &&
    is_replaced_like_flow_node(prev) &&
    is_replaced_like_flow_node(next) {
    return false
  }
  if is_replaced_like_flow_node(prev) &&
    is_replaced_like_flow_node(next) &&
    (has_percent_size_for_flow(prev) || has_percent_size_for_flow(next)) {
    return false
  }
  if prev.id == "br" || next.id == "br" {
    return false
  }
  participates_inline_for_flow_whitespace(prev) &&
  participates_inline_for_flow_whitespace(next)
}

///|
fn is_replaced_only_whitespace_separator(
  siblings : Array[@node.Node],
  index : Int,
) -> Bool {
  if index <= 0 || index >= siblings.length() - 1 {
    return false
  }
  let node = siblings[index]
  if not(is_whitespace_only_flow_text(node)) {
    return false
  }
  let mut prev_index : Int? = None
  let mut p = index - 1
  while p >= 0 {
    let sibling = siblings[p]
    if sibling.style.display != @types.Display::None {
      prev_index = Some(p)
      break
    }
    p = p - 1
  }
  let mut next_index : Int? = None
  let mut n = index + 1
  while n < siblings.length() {
    let sibling = siblings[n]
    if sibling.style.display != @types.Display::None {
      next_index = Some(n)
      break
    }
    n = n + 1
  }
  match (prev_index, next_index) {
    (Some(pi), Some(ni)) =>
      is_replaced_like_flow_node(siblings[pi]) &&
      is_replaced_like_flow_node(siblings[ni])
    _ => false
  }
}

///|
fn zero_rect() -> @types.Rect[Double] {
  { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 }
}

///|
fn shift_layout_subtree(
  layout : @types.Layout,
  dx : Double,
  dy : Double,
) -> @types.Layout {
  let shifted_children : Array[@types.Layout] = []
  for child in layout.children {
    shifted_children.push(shift_layout_subtree(child, dx, dy))
  }
  { ..layout, x: layout.x + dx, y: layout.y + dy, children: shifted_children }
}

///|
/// Compute occupied height extent from in-flow descendants only.
/// Absolute/fixed descendants are excluded from parent auto-height accounting.
fn get_inflow_children_flow_extent_height(
  source_node : @node.Node,
  children : Array[@types.Layout],
) -> Double {
  if children.length() == 0 {
    return 0.0
  }
  let mut min_top = @double.infinity
  let mut max_bottom = -@double.infinity
  for i = 0; i < children.length(); i = i + 1 {
    let child_layout = children[i]
    let skip_out_of_flow = if i < source_node.children.length() {
      let child_style = source_node.children[i].style
      child_style.position == @types.Absolute ||
      child_style.position == @types.Fixed
    } else {
      false
    }
    if skip_out_of_flow {
      continue
    }
    let explicit_zero_height = if i < source_node.children.length() {
      match source_node.children[i].style.height {
        @types.Length(v) => v == 0.0
        _ => false
      }
    } else {
      false
    }
    let child_height = if explicit_zero_height {
      0.0
    } else if child_layout.height > 0.0 {
      child_layout.height
    } else if i < source_node.children.length() {
      get_inflow_children_flow_extent_height(
        source_node.children[i],
        child_layout.children,
      )
    } else {
      get_children_flow_extent_height(child_layout.children)
    }
    let top = child_layout.y
    let bottom = child_layout.y + child_height
    if top < min_top {
      min_top = top
    }
    if bottom > max_bottom {
      max_bottom = bottom
    }
  }
  if min_top == @double.infinity || max_bottom == -@double.infinity {
    0.0
  } else {
    let extent = max_bottom - min_top
    if extent > 0.0 {
      extent
    } else {
      0.0
    }
  }
}

///|
fn get_child_descendant_flow_extent_for_auto_height(
  child_node : @node.Node,
  child_layout : @types.Layout,
) -> Double {
  if id_matches_tag(child_node.id, "ruby") {
    return 0.0
  }
  if child_node.style.suppresses_intrinsic_height() {
    return 0.0
  }
  let explicit_zero_height = match child_node.style.height {
    @types.Length(v) => v == 0.0
    _ => false
  }
  if explicit_zero_height && child_layout.height == 0.0 {
    0.0
  } else {
    get_inflow_children_flow_extent_height(child_node, child_layout.children)
  }
}

///|
/// Shift out-of-flow descendants by ancestry offset.
/// Stop propagation when a descendant establishes its own containing block.
fn shift_out_of_flow_descendants(
  layout : @types.Layout,
  node : @node.Node,
  dx : Double,
  dy : Double,
  shift_absolute : Bool,
  shift_fixed : Bool,
) -> @types.Layout {
  let shifted_children : Array[@types.Layout] = []
  let min_len = if layout.children.length() < node.children.length() {
    layout.children.length()
  } else {
    node.children.length()
  }
  for i = 0; i < min_len; i = i + 1 {
    let child_layout = layout.children[i]
    let child_node = node.children[i]
    let child_establishes_abs_cb = establishes_abs_containing_block(
      child_node.style,
      child_node.style.display,
    )
    let shifted = if shift_absolute &&
      child_node.style.position == @types.Absolute {
      shift_layout_subtree(child_layout, dx, dy)
    } else if shift_fixed && child_node.style.position == @types.Fixed {
      shift_layout_subtree(child_layout, dx, dy)
    } else if child_establishes_abs_cb {
      child_layout
    } else {
      shift_out_of_flow_descendants(
        child_layout, child_node, dx, dy, shift_absolute, shift_fixed,
      )
    }
    shifted_children.push(shifted)
  }
  for i = min_len; i < layout.children.length(); i = i + 1 {
    shifted_children.push(layout.children[i])
  }
  { ..layout, children: shifted_children }
}

///|
/// Shift direct in-flow float children when ancestor floats intrude on the
/// available inline space of a non-BFC block container.
fn shift_direct_float_children_for_intrusion(
  layout : @types.Layout,
  node : @node.Node,
  shift_left : Double,
  shift_right : Double,
) -> @types.Layout {
  if layout.children.length() == 0 || node.children.length() == 0 {
    return layout
  }
  let adjusted_children : Array[@types.Layout] = []
  let mut layout_cursor = 0
  for node_child in node.children {
    if layout_cursor >= layout.children.length() {
      break
    }
    if node_child.style.display == @types.Display::None {
      continue
    }
    let mut matched_index = layout_cursor
    if layout.children[matched_index].id != node_child.id {
      let mut scan = layout_cursor
      let mut found = false
      while scan < layout.children.length() {
        if layout.children[scan].id == node_child.id {
          matched_index = scan
          found = true
          break
        }
        scan = scan + 1
      }
      if found {
        for k = layout_cursor; k < matched_index; k = k + 1 {
          adjusted_children.push(layout.children[k])
        }
      } else {
        continue
      }
    }
    let layout_child = layout.children[matched_index]
    let adjusted_child = match node_child.style.float {
      @types.Float::Right =>
        if shift_right > 0.0 {
          shift_layout_subtree(layout_child, -shift_right, 0.0)
        } else {
          layout_child
        }
      @types.Float::Left =>
        if shift_left > 0.0 {
          shift_layout_subtree(layout_child, shift_left, 0.0)
        } else {
          layout_child
        }
      @types.Float::None =>
        if node_child.style.position == @types.Static &&
          not(block_flow_establishes_bfc(node_child.style)) &&
          not(@inline.is_inline_level(node_child.style.display)) {
          shift_direct_float_children_for_intrusion(
            layout_child, node_child, shift_left, shift_right,
          )
        } else {
          layout_child
        }
    }
    adjusted_children.push(adjusted_child)
    layout_cursor = matched_index + 1
  }
  for k = layout_cursor; k < layout.children.length(); k = k + 1 {
    adjusted_children.push(layout.children[k])
  }
  { ..layout, children: adjusted_children }
}

///|
/// Wrap a table child layout with display:contents wrappers.
fn wrap_table_child_layout_with_contents(
  child_layout : @types.Layout,
  wrappers : Array[@node.Node],
) -> @types.Layout {
  let mut wrapped = child_layout
  for i = wrappers.length(); i > 0; i = i - 1 {
    let wrapper = wrappers[i - 1]
    let children : Array[@types.Layout] = []
    children.push(wrapped)
    wrapped = {
      id: wrapper.id,
      x: 0.0,
      y: 0.0,
      width: 0.0,
      height: 0.0,
      margin: zero_rect(),
      padding: zero_rect(),
      border: zero_rect(),
      overflow_x: wrapper.style.overflow_x,
      overflow_y: wrapper.style.overflow_y,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children,
      text: wrapper.text,
    }
  }
  wrapped
}

///|
/// Compute an anonymous table for a contiguous table-internal run.
fn compute_anonymous_table_run(
  run_nodes : Array[@node.Node],
  run_indices : Array[Int],
  available_width : Double,
  available_height : Double?,
  writing_mode : @style.WritingMode,
  viewport_width : Double,
  viewport_height : Double,
  dispatch : @node.DispatchFn,
) -> (LayoutWithCollapse, AnonymousTableRunOverride) {
  let flattened_children : Array[FlattenedTableChild] = []
  let table_children : Array[@node.Node] = []
  for child in run_nodes {
    match flatten_first_table_child(child, []) {
      Some(flattened) => {
        flattened_children.push(flattened)
        table_children.push(flattened.child)
      }
      None => {
        flattened_children.push({ child, wrappers: [] })
        table_children.push(child)
      }
    }
  }

  let anon_table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    writing_mode,
  }
  let anon_table_node = @node.Node::new(
    "__anon-table-run", anon_table_style, table_children,
  )
  let table_ctx : @types.LayoutContext = {
    available_width,
    available_height,
    sizing_mode: @types.Definite,
    viewport_width,
    viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
  let @node.DispatchFn(dispatch_fn) = dispatch
  let table_layout = dispatch_fn(anon_table_node, table_ctx, dispatch)

  let projected_layouts : Array[@types.Layout] = []
  for i = 0; i < flattened_children.length(); i = i + 1 {
    let flattened = flattened_children[i]
    let child_layout = if i < table_layout.children.length() {
      table_layout.children[i]
    } else {
      create_zero_layout(run_nodes[i])
    }
    projected_layouts.push(
      wrap_table_child_layout_with_contents(child_layout, flattened.wrappers),
    )
  }

  let placeholder_layout : @types.Layout = if run_nodes.length() > 0 &&
    run_nodes[0].style.display == @types.Contents {
    let size_probe_children : Array[@types.Layout] = []
    size_probe_children.push({
      id: "__anon-table-size-probe",
      x: 0.0,
      y: 0.0,
      width: table_layout.width,
      height: table_layout.height,
      margin: zero_rect(),
      padding: zero_rect(),
      border: zero_rect(),
      overflow_x: @types.Visible,
      overflow_y: @types.Visible,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: [],
      text: None,
    })
    {
      id: run_nodes[0].id,
      x: 0.0,
      y: 0.0,
      width: table_layout.width,
      height: 0.0,
      margin: zero_rect(),
      padding: zero_rect(),
      border: zero_rect(),
      overflow_x: @types.Visible,
      overflow_y: @types.Visible,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: size_probe_children,
      text: run_nodes[0].text,
    }
  } else {
    {
      id: if run_nodes.length() > 0 {
        run_nodes[0].id
      } else {
        "__anon-table-run"
      },
      x: 0.0,
      y: 0.0,
      width: table_layout.width,
      height: table_layout.height,
      margin: zero_rect(),
      padding: zero_rect(),
      border: zero_rect(),
      overflow_x: @types.Visible,
      overflow_y: @types.Visible,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: [],
      text: None,
    }
  }

  (
    { layout: placeholder_layout, collapsed: { top: None, bottom: None } },
    { flow_indices: run_indices, layouts: projected_layouts },
  )
}

///|
/// Check if element can collapse through (zero height, no border/padding)
fn can_collapse_through(
  height : Double,
  border : @types.Rect[Double],
  padding : @types.Rect[Double],
) -> Bool {
  height == 0.0 &&
  border.top == 0.0 &&
  border.bottom == 0.0 &&
  padding.top == 0.0 &&
  padding.bottom == 0.0
}

///|
fn block_flow_establishes_bfc(style : @style.Style) -> Bool {
  let overflow_blocks = match (style.overflow_x, style.overflow_y) {
    (@types.Overflow::Visible, @types.Overflow::Visible) => false
    _ => true
  }
  let non_normal_block_alignment = match style.align_content {
    @types.Stretch => false
    _ => true
  }
  let containment_establishes_bfc = containment_applies(style.display) &&
    (style.contain.layout || style.contain.paint || style.contain.size)
  overflow_blocks ||
  non_normal_block_alignment ||
  style.display == @types.FlowRoot ||
  containment_establishes_bfc
}

///|
fn compute_block_content_alignment_offset(
  alignment : @types.Alignment,
  container_size : Double,
  content_size : Double,
) -> Double {
  if alignment == @types.Stretch || container_size <= 0.0 || content_size <= 0.0 {
    return 0.0
  }
  let aligned = @core.align_content_tracks(
    [{ position: 0.0, size: content_size, stretchable: false }],
    container_size,
    alignment,
  )
  if aligned.length() == 0 {
    0.0
  } else {
    aligned[0].position
  }
}

///|
fn block_style_has_auto_margin(style : @style.Style) -> Bool {
  match
    (
      style.margin.top,
      style.margin.right,
      style.margin.bottom,
      style.margin.left,
    ) {
    (@types.Auto, _, _, _)
    | (_, @types.Auto, _, _)
    | (_, _, @types.Auto, _)
    | (_, _, _, @types.Auto) => true
    _ => false
  }
}

///|
fn is_simple_block_stack_child(style : @style.Style) -> Bool {
  let default_justify_self = match style.justify_self {
    @types.AlignSelf::Auto
    | @types.AlignSelf::Start
    | @types.AlignSelf::Baseline => true
    _ => false
  }
  let is_simple_display = match style.display {
    @types.Block | @types.FlowRoot => true
    _ => false
  }
  is_simple_display &&
  style.position == @types.Static &&
  style.float == @types.Float::None &&
  style.clear == @types.Clear::None &&
  not(style.writing_mode.is_vertical()) &&
  default_justify_self &&
  not(block_style_has_auto_margin(style))
}

///|
priv struct SimpleBlockStackResult {
  child_layouts : Array[@types.Layout]
  current_pos : Double
  prev_margin_end : Double
  escaped_top : Double?
  escaped_bottom : Double?
}

///|
fn layout_simple_block_stack(
  flow_nodes : Array[@node.Node],
  flow_children : Array[LayoutWithCollapse],
  padding : @types.Rect[Double],
  border : @types.Rect[Double],
  can_collapse_top : Bool,
  can_collapse_bottom : Bool,
) -> SimpleBlockStackResult {
  let child_layouts : Array[@types.Layout] = []
  let mut current_pos = 0.0
  let mut prev_margin_end = 0.0
  let mut escaped_top : Double? = None
  let mut escaped_bottom : Double? = None
  let mut leading_collapse_chain_active = false
  let mut leading_chain_margin = 0.0
  for i = 0; i < flow_children.length(); i = i + 1 {
    let child_result = flow_children[i]
    let child_layout = child_result.layout
    let child_collapsed = child_result.collapsed
    let child_style = flow_nodes[i].style
    let is_first = i == 0
    let is_last = i == flow_children.length() - 1

    let effective_margin_top = match child_collapsed.top {
      Some(escaped) => collapse_margins(child_layout.margin.top, escaped)
      None => child_layout.margin.top
    }
    let effective_margin_bottom = match child_collapsed.bottom {
      Some(escaped) => collapse_margins(child_layout.margin.bottom, escaped)
      None => child_layout.margin.bottom
    }
    let child_establishes_bfc = block_flow_establishes_bfc(child_style)
    let child_has_aspect_ratio = match child_style.aspect_ratio {
      Some(_) => true
      None => false
    }
    let collapses_through = can_collapse_through(
        child_layout.height,
        child_layout.border,
        child_layout.padding,
      ) &&
      not(child_establishes_bfc) &&
      not(child_has_aspect_ratio)

    let child_y : Double = if is_first {
      if can_collapse_top {
        if collapses_through {
          leading_collapse_chain_active = true
          leading_chain_margin = collapse_margins(
            effective_margin_top, effective_margin_bottom,
          )
          escaped_top = Some(leading_chain_margin)
          prev_margin_end = effective_margin_bottom
        } else {
          escaped_top = Some(effective_margin_top)
          prev_margin_end = effective_margin_bottom
        }
        padding.top + border.top
      } else {
        if collapses_through {
          prev_margin_end = collapse_margins(
            effective_margin_top, effective_margin_bottom,
          )
          current_pos = 0.0
        } else {
          prev_margin_end = effective_margin_bottom
          current_pos = effective_margin_top
        }
        effective_margin_top + padding.top + border.top
      }
    } else if leading_collapse_chain_active {
      let collapsed_with_chain = collapse_margins(
        leading_chain_margin, effective_margin_top,
      )
      if collapses_through {
        leading_chain_margin = collapse_margins(
          collapsed_with_chain, effective_margin_bottom,
        )
      } else {
        leading_chain_margin = collapsed_with_chain
      }
      escaped_top = Some(leading_chain_margin)
      prev_margin_end = effective_margin_bottom
      padding.top + border.top
    } else if collapses_through {
      let collapsed_for_position = collapse_margins(
        prev_margin_end, effective_margin_top,
      )
      let all_collapsed = collapse_margins(
        collapsed_for_position, effective_margin_bottom,
      )
      prev_margin_end = all_collapsed
      current_pos + collapsed_for_position + padding.top + border.top
    } else {
      let collapsed = collapse_margins(prev_margin_end, effective_margin_top)
      current_pos = current_pos + collapsed
      prev_margin_end = effective_margin_bottom
      current_pos + padding.top + border.top
    }

    child_layouts.push({
      ..child_layout,
      x: padding.left + border.left + child_layout.margin.left,
      y: child_y,
    })

    if not(collapses_through) {
      if is_first && can_collapse_top {
        current_pos = child_layout.height
      } else if is_first {
        current_pos = effective_margin_top + child_layout.height
      } else {
        current_pos = current_pos + child_layout.height
      }
    }
    if leading_collapse_chain_active && not(collapses_through) {
      leading_collapse_chain_active = false
    }
    if is_last && can_collapse_bottom {
      escaped_bottom = Some(prev_margin_end)
    }
  }
  { child_layouts, current_pos, prev_margin_end, escaped_top, escaped_bottom }
}

///|
/// Calculate max-content width of children for intrinsic sizing
/// This is used when min-width or max-width is max-content/min-content
fn calculate_children_max_content_width(
  node : @node.Node,
  parent_width : Double,
) -> Double {
  let mut max_content_width = 0.0
  let is_vertical_writing = node.style.writing_mode.is_vertical()
  let flow_children : Array[@node.Node] = []
  for child in node.children {
    if child.style.display == @types.Display::None ||
      child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    match child.style.float {
      @types.Float::Left | @types.Float::Right => continue
      @types.Float::None => ()
    }
    flow_children.push(child)
  }
  let inline_only = @inline.should_establish_ifc(flow_children) ||
    is_ruby_internal_id(node.id)
  let mut inline_has_forced_break = false
  if inline_only && not(is_vertical_writing) {
    for child in flow_children {
      if child.id == "br" {
        inline_has_forced_break = true
        break
      }
    }
  }
  let mut current_inline_line_width = 0.0
  // Check if node itself has MeasureFunc (leaf node with intrinsic size)
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      max_content_width = intrinsic.max_width
    }
    None => ()
  }
  // Calculate max-content width from children
  for i = 0; i < flow_children.length(); i = i + 1 {
    let child = flow_children[i]
    if inline_only && is_replaced_only_whitespace_separator(flow_children, i) {
      continue
    }
    let child_style = child.style
    let child_suppress_intrinsic_inline = child_style.suppresses_intrinsic_width() &&
      not(is_ruby_internal_id(child.id))
    // Calculate child's margin contribution (percentages resolve to 0)
    let child_margin_left = resolve_dimension_intrinsic(child_style.margin.left)
    let child_margin_right = resolve_dimension_intrinsic(
      child_style.margin.right,
    )
    let child_margin_sum = child_margin_left + child_margin_right
    // Calculate child's padding (percentages resolve to 0)
    let child_padding_left = resolve_dimension_intrinsic(
      child_style.padding.left,
    )
    let child_padding_right = resolve_dimension_intrinsic(
      child_style.padding.right,
    )
    let child_border = @types.resolve_rect(child_style.border, parent_width)
    let child_min_box = child_padding_left +
      child_padding_right +
      child_border.horizontal_sum()
    // Calculate child's intrinsic width
    let child_intrinsic_width : Double = match child_style.width {
      @types.Length(w) => @types.max(w, child_min_box)
      @types.Percent(p) =>
        if child_style.writing_mode.is_vertical() &&
          child.children.length() == 0 {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.max_width * p + child_min_box, child_min_box)
            }
            None => child_min_box
          }
        } else {
          child_min_box
        }
      @types.Auto =>
        if child_suppress_intrinsic_inline {
          child_style.contained_intrinsic_width_fallback() + child_min_box
        } else {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.max_width + child_min_box, child_min_box)
            }
            None => {
              let recursive_width = calculate_children_max_content_width(
                child, parent_width,
              )
              let grid_track_width = estimate_grid_track_intrinsic_width(
                child_style,
              )
              let content_width = if grid_track_width > recursive_width {
                grid_track_width
              } else {
                recursive_width
              }
              content_width + child_min_box
            }
          }
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        if child_suppress_intrinsic_inline {
          child_style.contained_intrinsic_width_fallback() + child_min_box
        } else {
          child_min_box
        }
    }
    let child_contribution = child_intrinsic_width + child_margin_sum
    if is_vertical_writing {
      // In vertical writing mode, normal-flow blocks advance horizontally.
      max_content_width = max_content_width + child_contribution
    } else if inline_only && inline_has_forced_break {
      // Respect forced line breaks (<br>) in inline formatting contexts.
      // max-content width is the widest forced line, not total sum.
      current_inline_line_width = current_inline_line_width + child_contribution
      if child.id == "br" {
        if current_inline_line_width > max_content_width {
          max_content_width = current_inline_line_width
        }
        current_inline_line_width = 0.0
      }
    } else if inline_only {
      // No forced breaks: max-content is one unwrapped line.
      max_content_width = max_content_width + child_contribution
    } else if child_contribution > max_content_width {
      max_content_width = child_contribution
    }
  }
  if inline_only &&
    inline_has_forced_break &&
    current_inline_line_width > max_content_width {
    max_content_width = current_inline_line_width
  }
  if max_content_width < 0.0 {
    0.0
  } else {
    max_content_width
  }
}

///|
/// Calculate min-content width of children for intrinsic sizing
fn calculate_children_min_content_width(
  node : @node.Node,
  parent_width : Double,
  parent_content_height : Double?,
) -> Double {
  let mut min_content_width = 0.0
  let is_vertical_writing = node.style.writing_mode.is_vertical()
  let flow_children : Array[@node.Node] = []
  for child in node.children {
    // Skip display:none, absolute, fixed, and float elements
    if child.style.display == @types.Display::None ||
      child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    match child.style.float {
      @types.Float::Left | @types.Float::Right => continue
      @types.Float::None => ()
    }
    flow_children.push(child)
  }
  let inline_only = @inline.should_establish_ifc(flow_children) ||
    is_ruby_internal_id(node.id)
  let mut inline_needs_line_width = false
  if inline_only && not(is_vertical_writing) {
    for child in flow_children {
      if child.id == "br" {
        inline_needs_line_width = true
        break
      }
      let margin_left = resolve_dimension_intrinsic(child.style.margin.left)
      let margin_right = resolve_dimension_intrinsic(child.style.margin.right)
      if margin_left + margin_right < 0.0 {
        inline_needs_line_width = true
        break
      }
    }
  }
  let mut current_inline_line_width = 0.0
  // Check if node itself has MeasureFunc (leaf node with intrinsic size)
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      min_content_width = intrinsic.min_width
    }
    None => ()
  }
  // Calculate min-content width from children
  for i = 0; i < flow_children.length(); i = i + 1 {
    let child = flow_children[i]
    if inline_needs_line_width &&
      is_replaced_only_whitespace_separator(flow_children, i) {
      continue
    }
    let child_style = child.style
    let child_suppress_intrinsic_inline = child_style.suppresses_intrinsic_width() &&
      not(is_ruby_internal_id(child.id))
    // Calculate child's margin contribution (percentages resolve to 0)
    let child_margin_left = resolve_dimension_intrinsic(child_style.margin.left)
    let child_margin_right = resolve_dimension_intrinsic(
      child_style.margin.right,
    )
    let child_margin_sum = child_margin_left + child_margin_right
    // Calculate child's padding (percentages resolve to 0)
    let child_padding_left = resolve_dimension_intrinsic(
      child_style.padding.left,
    )
    let child_padding_right = resolve_dimension_intrinsic(
      child_style.padding.right,
    )
    let child_padding_top = resolve_dimension_intrinsic(child_style.padding.top)
    let child_padding_bottom = resolve_dimension_intrinsic(
      child_style.padding.bottom,
    )
    let child_border = @types.resolve_rect(child_style.border, parent_width)
    let child_min_box = child_padding_left +
      child_padding_right +
      child_border.horizontal_sum()
    fn calc_aspect_width(
      ratio : Double,
      h : Double,
      box_sizing : @types.BoxSizing,
      padding_v : Double,
      border_v : Double,
      padding_h : Double,
      border_h : Double,
      min_box : Double,
    ) -> Double {
      if box_sizing == @types.BorderBox {
        if h > 0.0 {
          h * ratio
        } else {
          min_box
        }
      } else {
        let content_height = h - padding_v - border_v
        if content_height > 0.0 {
          content_height * ratio + padding_h + border_h
        } else {
          min_box
        }
      }
    }
    fn fallback_auto_min_width() -> Double {
      if child_suppress_intrinsic_inline {
        return child_style.contained_intrinsic_width_fallback() + child_min_box
      }
      match child.measure {
        Some(mf) => {
          let intrinsic = (mf.func)(0.0, 0.0)
          @types.max(intrinsic.min_width + child_min_box, child_min_box)
        }
        None => {
          let recursive_width = calculate_children_min_content_width(
            child, parent_width, parent_content_height,
          )
          recursive_width + child_min_box
        }
      }
    }
    fn apply_intrinsic_inline_constraints(raw_width : Double) -> Double {
      let mut resolved = raw_width
      let width_is_inline_axis = not(child_style.writing_mode.is_vertical())
      let is_table_principal = is_table_principal_display(child_style.display)
      let intrinsic_min_width = if child_suppress_intrinsic_inline {
        child_style.contained_intrinsic_width_fallback() + child_min_box
      } else {
        calculate_children_min_content_width(
          child, parent_width, parent_content_height,
        ) +
        child_min_box
      }
      let intrinsic_max_width = if child_suppress_intrinsic_inline {
        child_style.contained_intrinsic_width_fallback() + child_min_box
      } else {
        calculate_children_max_content_width(child, parent_width) +
        child_min_box
      }
      // For intrinsic min-content contribution, percentages are indefinite and
      // resolve to 0 for inline-size constraints.
      match child_style.max_width {
        @types.Length(max_w) => if resolved > max_w { resolved = max_w }
        @types.Percent(_) =>
          if width_is_inline_axis && resolved > 0.0 {
            resolved = 0.0
          }
        @types.MinContent =>
          if resolved > intrinsic_min_width {
            resolved = intrinsic_min_width
          }
        @types.MaxContent | @types.FitContent(_) =>
          if resolved > intrinsic_max_width {
            resolved = intrinsic_max_width
          }
        _ => ()
      }
      // min-width takes precedence over max-width when both are specified.
      match child_style.min_width {
        @types.Length(min_w) => if resolved < min_w { resolved = min_w }
        @types.Percent(_) =>
          if width_is_inline_axis && resolved < 0.0 {
            resolved = 0.0
          }
        @types.MinContent | @types.FitContent(_) =>
          if resolved < intrinsic_min_width {
            resolved = intrinsic_min_width
          }
        @types.MaxContent =>
          if resolved < intrinsic_max_width {
            resolved = intrinsic_max_width
          }
        _ => ()
      }
      if is_table_principal && resolved < intrinsic_min_width {
        resolved = intrinsic_min_width
      }
      if resolved < child_min_box {
        child_min_box
      } else {
        resolved
      }
    }
    // Calculate child's intrinsic min-content width
    let child_intrinsic_width_raw : Double = match child_style.width {
      @types.Length(w) => @types.max(w, child_min_box)
      @types.Percent(p) =>
        if child_style.writing_mode.is_vertical() &&
          child.children.length() == 0 {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.min_width * p + child_min_box, child_min_box)
            }
            None => child_min_box
          }
        } else {
          child_min_box
        }
      @types.Auto =>
        match (child_style.aspect_ratio, child_style.height) {
          (Some(ratio), @types.Length(h)) if ratio > 0.0 =>
            calc_aspect_width(
              ratio,
              h,
              child_style.box_sizing,
              child_padding_top + child_padding_bottom,
              child_border.vertical_sum(),
              child_padding_left + child_padding_right,
              child_border.horizontal_sum(),
              child_min_box,
            )
          (Some(ratio), @types.Percent(p)) if ratio > 0.0 =>
            match parent_content_height {
              Some(parent_h) =>
                calc_aspect_width(
                  ratio,
                  parent_h * p,
                  child_style.box_sizing,
                  child_padding_top + child_padding_bottom,
                  child_border.vertical_sum(),
                  child_padding_left + child_padding_right,
                  child_border.horizontal_sum(),
                  child_min_box,
                )
              None => fallback_auto_min_width()
            }
          (Some(ratio), @types.Auto) if ratio > 0.0 => {
            let is_flex_row_parent = match
              (node.style.display, node.style.flex_direction) {
              (@types.Flex | @types.InlineFlex, @types.Row | @types.RowReverse) =>
                true
              _ => false
            }
            let align_cross = match child_style.align_self {
              @types.AlignSelf::Auto => node.style.align_items
              @types.AlignSelf::Start => @types.Start
              @types.AlignSelf::End => @types.End
              @types.AlignSelf::Center => @types.Center
              @types.AlignSelf::Stretch => @types.Stretch
              @types.AlignSelf::Baseline => @types.Baseline
            }
            if is_flex_row_parent && align_cross == @types.Stretch {
              match parent_content_height {
                Some(parent_h) =>
                  calc_aspect_width(
                    ratio,
                    parent_h,
                    child_style.box_sizing,
                    child_padding_top + child_padding_bottom,
                    child_border.vertical_sum(),
                    child_padding_left + child_padding_right,
                    child_border.horizontal_sum(),
                    child_min_box,
                  )
                None => fallback_auto_min_width()
              }
            } else {
              fallback_auto_min_width()
            }
          }
          _ => fallback_auto_min_width()
        }
      @types.MinContent | @types.FitContent(_) =>
        if child_suppress_intrinsic_inline {
          child_style.contained_intrinsic_width_fallback() + child_min_box
        } else {
          let recursive_width = calculate_children_min_content_width(
            child,
            parent_width,
            None,
          )
          recursive_width + child_min_box
        }
      @types.MaxContent =>
        if child_suppress_intrinsic_inline {
          child_style.contained_intrinsic_width_fallback() + child_min_box
        } else {
          let recursive_width = calculate_children_max_content_width(
            child, parent_width,
          )
          recursive_width + child_min_box
        }
    }
    let child_intrinsic_width = apply_intrinsic_inline_constraints(
      child_intrinsic_width_raw,
    )
    let child_contribution = child_intrinsic_width + child_margin_sum
    if is_vertical_writing {
      min_content_width = min_content_width + child_contribution
    } else if inline_needs_line_width {
      current_inline_line_width = current_inline_line_width + child_contribution
      if child.id == "br" {
        if current_inline_line_width > min_content_width {
          min_content_width = current_inline_line_width
        }
        current_inline_line_width = 0.0
      }
    } else if child_contribution > min_content_width {
      min_content_width = child_contribution
    }
  }
  if inline_needs_line_width && current_inline_line_width > min_content_width {
    min_content_width = current_inline_line_width
  }
  if min_content_width < 0.0 {
    0.0
  } else {
    min_content_width
  }
}

///|
fn resolve_single_track_intrinsic(track : @types.SingleTrackSizing) -> Double {
  match track {
    @types.SingleTrackSizing::Length(v) => v
    @types.SingleTrackSizing::FitContentLength(v) => v
    @types.SingleTrackSizing::MinMax(min_track, _max_track) =>
      match min_track {
        @types.MinTrackSizing::Length(v) => v
        _ => 0.0
      }
    _ => 0.0
  }
}

///|
fn resolve_track_intrinsic(track : @types.TrackSizingFunction) -> Double {
  match track {
    @types.TrackSizingFunction::Length(v) => v
    @types.FitContentLength(v) => v
    @types.TrackSizingFunction::MinMax(min_track, _max_track) =>
      match min_track {
        @types.MinTrackSizing::Length(v) => v
        _ => 0.0
      }
    @types.TrackSizingFunction::Repeat(count, tracks) =>
      match count {
        @types.RepeatCount::Count(n) => {
          let mut unit = 0.0
          for t in tracks {
            unit = unit + resolve_single_track_intrinsic(t)
          }
          unit * n.to_double()
        }
        _ => 0.0
      }
    _ => 0.0
  }
}

///|
fn estimate_grid_track_intrinsic_width(style : @style.Style) -> Double {
  if style.display != @types.Grid && style.display != @types.InlineGrid {
    return 0.0
  }
  let mut width = 0.0
  for track in style.grid_template_columns {
    width = width + resolve_track_intrinsic(track)
  }
  if style.grid_template_columns.length() > 1 {
    let gap = resolve_dimension_intrinsic(style.column_gap)
    width = width + gap * (style.grid_template_columns.length() - 1).to_double()
  }
  width
}

///|
/// Calculate max-content height of children for intrinsic sizing
/// This is used when min-height or max-height is max-content/min-content
fn calculate_children_max_content_height(
  node : @node.Node,
  parent_width : Double,
) -> Double {
  let mut total_height = 0.0
  // Check if node itself has MeasureFunc (leaf node with intrinsic size)
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      total_height = intrinsic.min_height
    }
    None => ()
  }
  // Calculate height from children (simplified - sum of heights)
  for child in node.children {
    // Skip display:none, absolute, fixed elements
    if child.style.display == @types.Display::None ||
      child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    // Skip floats for height calculation in normal flow
    match child.style.float {
      @types.Float::Left | @types.Float::Right => continue
      @types.Float::None => ()
    }
    let child_style = child.style
    // Calculate child's vertical margins (percentages resolve to parent WIDTH, not height)
    let child_margin_top = resolve_dimension_intrinsic(child_style.margin.top)
    let child_margin_bottom = resolve_dimension_intrinsic(
      child_style.margin.bottom,
    )
    // Calculate child's padding and border
    let child_padding_top = resolve_dimension_intrinsic(child_style.padding.top)
    let child_padding_bottom = resolve_dimension_intrinsic(
      child_style.padding.bottom,
    )
    let child_border = @types.resolve_rect(child_style.border, parent_width)
    let child_min_box = child_padding_top +
      child_padding_bottom +
      child_border.vertical_sum()
    // Calculate child's intrinsic height
    let child_intrinsic_height : Double = match child_style.height {
      @types.Length(h) => @types.max(h, child_min_box)
      @types.Percent(_) => child_min_box
      @types.Auto =>
        match child.measure {
          Some(mf) => {
            let intrinsic = (mf.func)(0.0, 0.0)
            @types.max(intrinsic.min_height + child_min_box, child_min_box)
          }
          None =>
            // Recursively calculate for nested elements
            calculate_children_max_content_height(child, parent_width) +
            child_min_box
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        child_min_box
    }
    // Add to total (simplified - not doing margin collapsing here)
    total_height = total_height +
      child_intrinsic_height +
      child_margin_top +
      child_margin_bottom
  }
  total_height
}

///|
fn resolve_box_height_from_style(
  style : @style.Style,
  box_width : Double,
  content_height_for_auto : Double,
  parent_height_opt : Double?,
  fill_vertical_auto_height : Bool,
  margin : @types.Rect[Double],
  padding : @types.Rect[Double],
  border : @types.Rect[Double],
) -> Double {
  match style.height {
    @types.Length(h) =>
      if style.box_sizing == @types.BorderBox {
        h
      } else {
        h + padding.vertical_sum() + border.vertical_sum()
      }
    @types.Percent(p) =>
      match parent_height_opt {
        Some(ph) =>
          if style.box_sizing == @types.BorderBox {
            ph * p
          } else {
            ph * p + padding.vertical_sum() + border.vertical_sum()
          }
        None =>
          content_height_for_auto +
          padding.vertical_sum() +
          border.vertical_sum()
      }
    @types.Auto =>
      match style.aspect_ratio {
        Some(ratio) =>
          if style.box_sizing == @types.BorderBox {
            box_width / ratio
          } else {
            let content_width = box_width -
              padding.horizontal_sum() -
              border.horizontal_sum()
            content_width / ratio +
            padding.vertical_sum() +
            border.vertical_sum()
          }
        None =>
          if fill_vertical_auto_height {
            match parent_height_opt {
              Some(ph) => @types.max(0.0, ph - margin.top - margin.bottom)
              None =>
                content_height_for_auto +
                padding.vertical_sum() +
                border.vertical_sum()
            }
          } else {
            content_height_for_auto +
            padding.vertical_sum() +
            border.vertical_sum()
          }
      }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
      content_height_for_auto + padding.vertical_sum() + border.vertical_sum()
  }
}

///|
fn apply_content_driven_height_constraints(
  box_height : Double,
  style : @style.Style,
  node : @node.Node,
  parent_width : Double,
  content_height_for_auto : Double,
  padding : @types.Rect[Double],
  border : @types.Rect[Double],
) -> Double {
  let mut resolved = box_height
  match style.min_height {
    @types.Length(min_h) => if resolved < min_h { resolved = min_h }
    @types.MaxContent | @types.MinContent => {
      let intrinsic_height = if style.suppresses_intrinsic_height() {
        content_height_for_auto + padding.vertical_sum() + border.vertical_sum()
      } else {
        calculate_children_max_content_height(node, parent_width) +
        padding.vertical_sum() +
        border.vertical_sum()
      }
      if resolved < intrinsic_height {
        resolved = intrinsic_height
      }
    }
    _ => ()
  }
  match style.max_height {
    @types.Length(max_h) => if resolved > max_h { resolved = max_h }
    @types.MaxContent | @types.MinContent => {
      let intrinsic_height = if style.suppresses_intrinsic_height() {
        content_height_for_auto + padding.vertical_sum() + border.vertical_sum()
      } else {
        calculate_children_max_content_height(node, parent_width) +
        padding.vertical_sum() +
        border.vertical_sum()
      }
      if resolved > intrinsic_height {
        resolved = intrinsic_height
      }
    }
    _ => ()
  }
  let min_box_height = padding.vertical_sum() + border.vertical_sum()
  if resolved < min_box_height {
    resolved = min_box_height
  }
  resolved
}

///|
fn apply_block_height_constraints(
  box_height : Double,
  style : @style.Style,
  parent_height : Double,
  content_height_for_auto : Double,
  padding : @types.Rect[Double],
  border : @types.Rect[Double],
) -> Double {
  let mut resolved = box_height
  match style.min_height {
    @types.Length(min_h) => if resolved < min_h { resolved = min_h }
    @types.Percent(p) => {
      let min_h = parent_height * p
      if resolved < min_h {
        resolved = min_h
      }
    }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => {
      let min_h = content_height_for_auto +
        padding.vertical_sum() +
        border.vertical_sum()
      if resolved < min_h {
        resolved = min_h
      }
    }
    @types.Auto => ()
  }
  match style.max_height {
    @types.Length(max_h) => if resolved > max_h { resolved = max_h }
    @types.Percent(p) => {
      let max_h = parent_height * p
      if resolved > max_h {
        resolved = max_h
      }
    }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => {
      let max_h = content_height_for_auto +
        padding.vertical_sum() +
        border.vertical_sum()
      if resolved > max_h {
        resolved = max_h
      }
    }
    @types.Auto => ()
  }
  let min_box_height = padding.vertical_sum() + border.vertical_sum()
  if resolved < min_box_height {
    resolved = min_box_height
  }
  resolved
}

///|
fn adjust_auto_width_from_height_constrained_aspect_ratio(
  style : @style.Style,
  box_width : Double,
  box_height : Double,
  parent_width : Double,
  padding : @types.Rect[Double],
  border : @types.Rect[Double],
) -> Double {
  match (style.aspect_ratio, style.width, style.height) {
    (Some(ratio), @types.Auto, @types.Auto) if ratio > 0.0 => {
      let expected_height_from_width = (
          box_width - padding.horizontal_sum() - border.horizontal_sum()
        ) /
        ratio +
        padding.vertical_sum() +
        border.vertical_sum()
      if box_height != expected_height_from_width {
        let content_height = box_height -
          padding.vertical_sum() -
          border.vertical_sum()
        let new_width = content_height * ratio +
          padding.horizontal_sum() +
          border.horizontal_sum()
        let new_width = match style.max_width {
          @types.Length(max_w) =>
            if new_width > max_w {
              max_w
            } else {
              new_width
            }
          @types.Percent(p) => {
            let max_w = parent_width * p
            if new_width > max_w {
              max_w
            } else {
              new_width
            }
          }
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => new_width
        }
        match style.min_width {
          @types.Length(min_w) =>
            if new_width < min_w {
              min_w
            } else {
              new_width
            }
          @types.Percent(p) => {
            let min_w = parent_width * p
            if new_width < min_w {
              min_w
            } else {
              new_width
            }
          }
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => new_width
        }
      } else {
        box_width
      }
    }
    _ => box_width
  }
}

///|
fn try_layout_empty_block_leaf_with_definite_height(
  node : @node.Node,
  available_width : Double,
  available_height : Double?,
  sizing_mode : @types.SizingMode,
) -> LayoutWithCollapse? {
  let style = node.style
  let is_simple_display = match style.display {
    @types.Block | @types.FlowRoot => true
    _ => false
  }
  let has_definite_height = match style.height {
    @types.Length(_) => true
    @types.Percent(_) => available_height is Some(_)
    _ => false
  }
  if sizing_mode != @types.Definite ||
    node.children.length() > 0 ||
    node.measure is Some(_) ||
    node.text is Some(_) ||
    not(is_simple_display) ||
    not(has_definite_height) ||
    style.position != @types.Static ||
    style.float != @types.Float::None ||
    style.clear != @types.Clear::None ||
    style.writing_mode.is_vertical() ||
    style.aspect_ratio is Some(_) ||
    style.contain.layout ||
    style.contain.paint ||
    style.contain.size ||
    style.contain.inline_size ||
    block_style_has_auto_margin(style) {
    return None
  }
  match style.width {
    @types.Auto | @types.Length(_) | @types.Percent(_) => ()
    _ => return None
  }
  match style.min_width {
    @types.Auto => ()
    _ => return None
  }
  match style.max_width {
    @types.Auto => ()
    _ => return None
  }
  match style.min_height {
    @types.Auto => ()
    _ => return None
  }
  match style.max_height {
    @types.Auto => ()
    _ => return None
  }

  let margin = @types.resolve_rect(style.margin, available_width)
  let padding = @types.resolve_rect(style.padding, available_width)
  let border = @types.resolve_rect(style.border, available_width)
  let mut box_width = match style.width {
    @types.Length(w) =>
      if style.box_sizing == @types.BorderBox {
        w
      } else {
        w + padding.horizontal_sum() + border.horizontal_sum()
      }
    @types.Percent(p) => {
      let resolved = available_width * p
      if style.box_sizing == @types.BorderBox {
        resolved
      } else {
        resolved + padding.horizontal_sum() + border.horizontal_sum()
      }
    }
    @types.Auto => available_width - margin.horizontal_sum()
    _ => return None
  }
  let mut box_height = match style.height {
    @types.Length(h) =>
      if style.box_sizing == @types.BorderBox {
        h
      } else {
        h + padding.vertical_sum() + border.vertical_sum()
      }
    @types.Percent(p) =>
      match available_height {
        Some(parent_height) => {
          let resolved = parent_height * p
          if style.box_sizing == @types.BorderBox {
            resolved
          } else {
            resolved + padding.vertical_sum() + border.vertical_sum()
          }
        }
        None => return None
      }
    _ => return None
  }
  let min_box_width = padding.horizontal_sum() + border.horizontal_sum()
  if box_width < min_box_width {
    box_width = min_box_width
  }
  let min_box_height = padding.vertical_sum() + border.vertical_sum()
  if box_height < min_box_height {
    box_height = min_box_height
  }
  Some({
    layout: {
      id: node.id,
      x: 0.0,
      y: 0.0,
      width: box_width,
      height: box_height,
      margin,
      padding,
      border,
      overflow_x: style.overflow_x,
      overflow_y: style.overflow_y,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: [],
      text: node.text,
    },
    collapsed: { top: None, bottom: None },
  })
}

///|
fn place_absolute_children_at_static_y(
  node : @node.Node,
  box_width : Double,
  box_height : Double,
  border : @types.Rect[Double],
  static_y : Double,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
  layout_map : Map[Int, @types.Layout],
) -> Unit {
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.position == @types.Absolute {
      let abs_layout = layout_absolute_child(
        child, box_width, box_height, border, static_y, warnings, dispatch,
      )
      layout_map[i] = abs_layout
    }
  }
}

///|
fn place_fixed_children_for_parent(
  node : @node.Node,
  parent_style : @style.Style,
  parent_width : Double,
  parent_height : Double,
  box_width : Double,
  box_height : Double,
  border : @types.Rect[Double],
  viewport_width : Double,
  viewport_height : Double,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
  layout_map : Map[Int, @types.Layout],
) -> Unit {
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.position == @types.Fixed {
      let fixed_layout = layout_fixed_child_for_parent(
        child, parent_style, parent_width, parent_height, box_width, box_height,
        border, viewport_width, viewport_height, warnings, dispatch,
      )
      layout_map[i] = fixed_layout
    }
  }
}

///|
fn collect_child_layouts_in_source_order(
  node : @node.Node,
  layout_map : Map[Int, @types.Layout],
) -> Array[@types.Layout] {
  let child_layouts : Array[@types.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    match layout_map.get(i) {
      Some(layout) => child_layouts.push(layout)
      None => ()
    }
  }
  child_layouts
}

///|
fn adjust_float_only_inline_wrapper_for_parent(
  layout : @types.Layout,
  child_node : @node.Node,
  parent_style : @style.Style,
  is_vertical_writing : Bool,
  include_inline_quirk_fallback : Bool,
) -> @types.Layout {
  let parent_is_floated_auto_block = not(is_vertical_writing) &&
    parent_style.height == @types.Auto &&
    parent_style.float != @types.Float::None
  if parent_is_floated_auto_block &&
    id_matches_tag(child_node.id, "span") &&
    source_children_only_contribute_floats(child_node.children) &&
    layout.width > 0.0 &&
    layout.children.length() > 0 {
    let shifted_children : Array[@types.Layout] = []
    let mut has_visible_child = false
    for child_layout in layout.children {
      if child_layout.width > 0.0 || child_layout.height > 0.0 {
        has_visible_child = true
      }
      shifted_children.push({ ..child_layout, x: child_layout.x - layout.width })
    }
    if has_visible_child {
      {
        ..layout,
        x: layout.x + layout.width,
        width: 0.0,
        height: 0.0,
        children: shifted_children,
      }
    } else {
      layout
    }
  } else if include_inline_quirk_fallback {
    adjust_inline_span_float_quirk(layout, child_node, is_vertical_writing)
  } else {
    layout
  }
}

///|
/// Compute layout with collapse at root level (no parent to escape to)
fn compute_root_layout(
  node : @node.Node,
  ctx : @types.LayoutContext,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let result = compute_with_collapse(node, ctx, warnings, dispatch)
  let layout = result.layout

  let adjusted_for_margin = if node.id == "body" {
    // Browser compatibility: body box metrics should remain content-based.
    layout
  } else {
    // For non-body roots, preserve escaped margin behavior used by internal layout tests.
    match result.collapsed.top {
      Some(escaped_margin) =>
        if layout.children.length() > 0 {
          let adjusted_children : Array[@types.Layout] = []
          for i = 0; i < layout.children.length(); i = i + 1 {
            let child = layout.children[i]
            adjusted_children.push({
              id: child.id,
              x: child.x,
              y: child.y + escaped_margin,
              width: child.width,
              height: child.height,
              margin: child.margin,
              padding: child.padding,
              border: child.border,
              overflow_x: child.overflow_x,
              overflow_y: child.overflow_y,
              scroll_width: child.scroll_width,
              scroll_height: child.scroll_height,
              children: child.children,
              text: child.text,
            })
          }
          let escaped_bottom = match result.collapsed.bottom {
            Some(m) => m
            None => 0.0
          }
          let new_height = layout.height + escaped_margin + escaped_bottom
          {
            id: layout.id,
            x: layout.x,
            y: layout.y,
            width: layout.width,
            height: new_height,
            margin: layout.margin,
            padding: layout.padding,
            border: layout.border,
            overflow_x: layout.overflow_x,
            overflow_y: layout.overflow_y,
            scroll_width: layout.scroll_width,
            scroll_height: layout.scroll_height,
            children: adjusted_children,
            text: layout.text,
          }
        } else {
          layout
        }
      None =>
        match result.collapsed.bottom {
          Some(escaped_margin) =>
            {
              id: layout.id,
              x: layout.x,
              y: layout.y,
              width: layout.width,
              height: layout.height + escaped_margin,
              margin: layout.margin,
              padding: layout.padding,
              border: layout.border,
              overflow_x: layout.overflow_x,
              overflow_y: layout.overflow_y,
              scroll_width: layout.scroll_width,
              scroll_height: layout.scroll_height,
              children: layout.children,
              text: layout.text,
            }
          None => layout
        }
    }
  }
  apply_initial_scroll_snap(node, adjusted_for_margin)
}

///|
/// Compute block layout with warnings for unsupported features
pub fn compute_with_warnings(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.LayoutResult {
  let warnings : Array[@types.LayoutWarning] = []
  let layout = compute_root_layout(node, ctx, warnings, dispatch)
  { layout, warnings }
}

///|
/// Compute block layout for a node and its children
pub fn compute(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let warnings : Array[@types.LayoutWarning] = []
  compute_root_layout(node, ctx, warnings, dispatch)
}

///|
/// Internal function that computes layout with margin collapse tracking
fn compute_with_collapse(
  node : @node.Node,
  ctx : @types.LayoutContext,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> LayoutWithCollapse {
  let style = node.style

  // Handle no-principal-box displays (display: contents and table-internal no-principal
  // values) - element doesn't generate a box but children do.
  if style.display == @types.Contents ||
    is_no_principal_table_internal_display(style.display) {
    let keep_intrinsic_size = is_no_principal_table_internal_display(
      style.display,
    )
    // Inline-only contents should participate in IFC, not block stacking.
    let flow_inline_nodes : Array[@node.Node] = []
    let mut has_out_of_flow = false
    for child in node.children {
      if child.style.display == @types.Display::None {
        continue
      }
      if child.style.position == @types.Absolute ||
        child.style.position == @types.Fixed {
        has_out_of_flow = true
        break
      }
      match child.style.float {
        @types.Float::Left | @types.Float::Right => {
          has_out_of_flow = true
          break
        }
        @types.Float::None => ()
      }
      flow_inline_nodes.push(child)
    }
    if not(has_out_of_flow) && @inline.should_establish_ifc(flow_inline_nodes) {
      let ifc_result = @inline.compute_ifc(
        flow_inline_nodes,
        ctx.available_width,
        ctx.available_height,
        0.0,
        0.0,
        dispatch,
        container_writing_mode=style.writing_mode,
        container_direction=style.direction,
        container_text_align=style.text_align,
        container_white_space=style.white_space,
      )
      let normalized_ifc_layouts : Array[@types.Layout] = []
      for i = 0; i < ifc_result.layouts.length(); i = i + 1 {
        let child_layout = ifc_result.layouts[i]
        let normalized_layout = if i < flow_inline_nodes.length() &&
          flow_inline_nodes[i].style.display == @types.Contents {
          {
            ..child_layout,
            width: 0.0,
            height: 0.0,
            padding: @types.Rect::zero(),
            border: @types.Rect::zero(),
            scroll_width: 0.0,
            scroll_height: 0.0,
          }
        } else {
          child_layout
        }
        normalized_ifc_layouts.push(normalized_layout)
      }
      let mut inline_width = 0.0
      let mut inline_height = 0.0
      if keep_intrinsic_size {
        for child_layout in normalized_ifc_layouts {
          let right = child_layout.x + child_layout.width
          if right > inline_width {
            inline_width = right
          }
          let bottom = child_layout.y + child_layout.height
          if bottom > inline_height {
            inline_height = bottom
          }
        }
        if inline_height > 0.0 && style.line_height > inline_height {
          inline_height = style.line_height
        }
      }
      return {
        layout: {
          id: node.id,
          x: 0.0,
          y: 0.0,
          width: inline_width,
          height: inline_height,
          margin: @types.Rect::zero(),
          padding: @types.Rect::zero(),
          border: @types.Rect::zero(),
          overflow_x: @types.Visible,
          overflow_y: @types.Visible,
          scroll_width: 0.0,
          scroll_height: 0.0,
          children: normalized_ifc_layouts,
          text: node.text,
        },
        collapsed: { top: None, bottom: None },
      }
    }

    // Compute children layouts as mixed inline/block flow so inline runs are
    // preserved even when this contents subtree also contains block children.
    let flow_nodes : Array[@node.Node] = []
    let flow_indices : Array[Int] = []
    let layout_map : Map[Int, @types.Layout] = {}
    for i = 0; i < node.children.length(); i = i + 1 {
      let child = node.children[i]
      if is_whitespace_only_flow_text(child) &&
        not(should_preserve_flow_whitespace_text(node.children, i)) {
        continue
      }
      if child.style.position == @types.Absolute {
        let abs_layout_raw = layout_absolute_child(
          child,
          ctx.available_width,
          ctx.available_height.unwrap_or(0.0),
          @types.Rect::zero(),
          0.0,
          warnings,
          dispatch,
        )
        let abs_layout = if child.style.width == @types.Auto &&
          abs_layout_raw.height > 0.0 {
          let min_width_from_font = abs_layout_raw.height * 0.6
          if abs_layout_raw.width < min_width_from_font {
            { ..abs_layout_raw, width: min_width_from_font }
          } else {
            abs_layout_raw
          }
        } else {
          abs_layout_raw
        }
        layout_map[i] = abs_layout
        continue
      }
      if child.style.position == @types.Fixed {
        layout_map[i] = layout_fixed_child(
          child,
          ctx.viewport_width,
          ctx.viewport_height,
          warnings,
          dispatch,
        )
        continue
      }
      flow_nodes.push(child)
      flow_indices.push(i)
    }
    let groups = group_flow_children_for_anonymous_blocks(
      flow_nodes, flow_indices,
    )
    let mixed_result = compute_mixed_content_layout(
      groups,
      ctx.available_width,
      ctx.available_height,
      @types.Rect::zero(),
      @types.Rect::zero(),
      ctx,
      warnings,
      layout_map,
      dispatch,
      writing_mode=style.writing_mode,
      direction=style.direction,
      text_align=style.text_align,
      white_space=style.white_space,
      justify_items=style.justify_items,
      allow_mixed_auto_shrink=false,
    )
    let children_layouts : Array[@types.Layout] = []
    let mut max_in_flow_width = 0.0
    let mut max_in_flow_height = 0.0
    for i = 0; i < node.children.length(); i = i + 1 {
      match layout_map.get(i) {
        Some(layout) => {
          children_layouts.push(layout)
          let child_style_for_size = node.children[i].style
          if keep_intrinsic_size &&
            contributes_to_no_principal_intrinsic_size(child_style_for_size) {
            let child_right = layout.x + layout.width
            if child_right > max_in_flow_width {
              max_in_flow_width = child_right
            }
            let child_bottom = layout.y + layout.height
            if child_bottom > max_in_flow_height {
              max_in_flow_height = child_bottom
            }
          }
        }
        None => ()
      }
    }
    let intrinsic_width = if keep_intrinsic_size {
      max_in_flow_width
    } else {
      0.0
    }
    let mut intrinsic_height = if keep_intrinsic_size {
      max_in_flow_height
    } else {
      0.0
    }
    if keep_intrinsic_size &&
      intrinsic_height > 0.0 &&
      style.line_height > intrinsic_height {
      intrinsic_height = style.line_height
    }
    return {
      layout: {
        id: node.id,
        x: 0.0,
        y: 0.0,
        width: intrinsic_width,
        height: intrinsic_height,
        margin: @types.Rect::zero(),
        padding: @types.Rect::zero(),
        border: @types.Rect::zero(),
        overflow_x: @types.Visible,
        overflow_y: @types.Visible,
        scroll_width: 0.0,
        scroll_height: 0.0,
        children: children_layouts,
        text: node.text,
      },
      // Pass through the first child's margin for collapse with siblings
      collapsed: {
        top: mixed_result.escaped_top,
        bottom: mixed_result.escaped_bottom,
      },
    }
  }

  // Note: Float is now supported - no warning needed

  // Handle leaf nodes with MeasureFunc (e.g., text nodes)
  // These nodes have no children but need intrinsic size from their measure function
  if node.children.length() == 0 {
    match node.measure {
      Some(mf) => {
        let parent_width = ctx.available_width
        let parent_height_opt = ctx.available_height
        let parent_height = parent_height_opt.unwrap_or(0.0)
        let margin = @types.resolve_rect(style.margin, parent_width)
        let padding = @types.resolve_rect(style.padding, parent_width)
        let border = @types.resolve_rect(style.border, parent_width)
        let available_h = ctx.available_height.unwrap_or(0.0)
        let intrinsic = (mf.func)(parent_width, available_h)
        let suppress_inline_intrinsic = style.suppresses_intrinsic_width()
        let suppress_block_intrinsic = style.suppresses_intrinsic_height()
        let intrinsic_width = if suppress_inline_intrinsic {
          style.contained_intrinsic_width_fallback()
        } else {
          intrinsic.max_width
        }
        let intrinsic_height = if suppress_block_intrinsic {
          style.contained_intrinsic_height_fallback()
        } else {
          intrinsic.max_height
        }
        let intrinsic_ratio : Double? = if intrinsic.max_width > 0.0 &&
          intrinsic.max_height > 0.0 {
          Some(intrinsic.max_width / intrinsic.max_height)
        } else {
          None
        }
        let ratio_for_auto = match style.aspect_ratio {
          Some(r) => Some(r)
          None => intrinsic_ratio
        }
        let width_is_auto = match style.width {
          @types.Auto => true
          _ => false
        }
        let height_is_auto = match style.height {
          @types.Auto => true
          _ => false
        }

        // Resolve min/max constraints
        let min_width = style.min_width.resolve_or(parent_width, 0.0)
        let max_width = style.max_width.resolve_or(
          parent_width, @double.infinity,
        )
        let min_height = style.min_height.resolve_or(parent_height, 0.0)
        let max_height = style.max_height.resolve_or(
          parent_height, @double.infinity,
        )

        // Check if height/width are definite (non-Auto) for aspect_ratio handling
        let height_is_definite = match style.height {
          @types.Length(_) => true
          @types.Percent(_) => parent_height_opt is Some(_)
          _ => false
        }
        let width_is_definite = match style.width {
          @types.Length(_) | @types.Percent(_) => true
          _ => false
        }

        // Calculate initial width
        // For replaced elements with aspect_ratio:
        // - If width is Auto AND height is definite, let aspect_ratio compute width
        let initial_width : Double? = match style.width {
          @types.Length(w) => Some(w)
          @types.Percent(p) => Some(parent_width * p)
          @types.Auto =>
            // If aspect_ratio is set and height is definite, use None to let aspect_ratio calculate
            if ratio_for_auto is Some(_) && height_is_definite {
              None
            } else {
              let content_width = intrinsic_width +
                padding.horizontal_sum() +
                border.horizontal_sum()
              // Text nodes should wrap to available inline size, but replaced elements
              // keep their intrinsic width contribution for shrink-to-fit/abspos sizing.
              if node.text is Some(_) && ctx.sizing_mode == @types.Definite {
                Some(@types.min(content_width, parent_width))
              } else {
                Some(content_width)
              }
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            Some(
              intrinsic_width +
              padding.horizontal_sum() +
              border.horizontal_sum(),
            )
        }

        // Calculate initial height
        // For replaced elements with aspect_ratio:
        // - If height is Auto AND width is definite, let aspect_ratio compute height
        let initial_height : Double? = match style.height {
          @types.Length(h) => Some(h)
          @types.Percent(p) =>
            match parent_height_opt {
              Some(ph) => Some(ph * p)
              None =>
                Some(
                  intrinsic_height +
                  padding.vertical_sum() +
                  border.vertical_sum(),
                )
            }
          @types.Auto =>
            // If aspect_ratio is set and width is definite, use None to let aspect_ratio calculate
            if ratio_for_auto is Some(_) && width_is_definite {
              None
            } else {
              Some(
                intrinsic_height +
                padding.vertical_sum() +
                border.vertical_sum(),
              )
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            Some(
              intrinsic_height + padding.vertical_sum() + border.vertical_sum(),
            )
        }

        let aspect_ratio_for_resolution = if style.aspect_ratio is Some(_) {
          style.aspect_ratio
        } else if initial_width is None || initial_height is None {
          ratio_for_auto
        } else {
          None
        }

        // Apply aspect_ratio and constraints
        let (final_width, final_height) = @types.resolve_dimensions_with_aspect_ratio(
          initial_width, initial_height, aspect_ratio_for_resolution, min_width,
          max_width, min_height, max_height,
        )
        let box_width = final_width.unwrap_or(0.0)
        let box_height = final_height.unwrap_or(0.0)

        // Re-apply aspect_ratio after min/max constraints if needed
        let used_ratio_resolution = aspect_ratio_for_resolution is Some(_)
        let style_with_ratio = if used_ratio_resolution &&
          style.aspect_ratio is None &&
          ratio_for_auto is Some(r) {
          { ..style, aspect_ratio: Some(r) }
        } else {
          style
        }
        let (box_width, box_height) = @absolute.apply_constraints_with_aspect_ratio(
          box_width, box_height, style_with_ratio, min_width, max_width, min_height,
          max_height,
        )
        let (box_width, box_height) = if width_is_auto && height_is_auto {
          match (ratio_for_auto, initial_width, initial_height) {
            (Some(ratio), Some(initial_box_width), Some(initial_box_height)) =>
              if ratio > 0.0 &&
                initial_box_width > 0.0 &&
                initial_box_height > 0.0 {
                let width_scale = box_width / initial_box_width
                let height_scale = box_height / initial_box_height
                if width_scale + 0.0001 < height_scale {
                  (
                    box_width,
                    @types.clamp(box_width / ratio, min_height, max_height),
                  )
                } else if height_scale + 0.0001 < width_scale {
                  (
                    @types.clamp(box_height * ratio, min_width, max_width),
                    box_height,
                  )
                } else {
                  (box_width, box_height)
                }
              } else {
                (box_width, box_height)
              }
            _ => (box_width, box_height)
          }
        } else {
          (box_width, box_height)
        }
        return {
          layout: {
            id: node.id,
            x: 0.0,
            y: 0.0,
            width: box_width,
            height: box_height,
            margin,
            padding,
            border,
            overflow_x: style.overflow_x,
            overflow_y: style.overflow_y,
            scroll_width: 0.0,
            scroll_height: 0.0,
            children: [],
            text: node.text,
          },
          collapsed: { top: None, bottom: None },
        }
      }
      None => ()
    }
    match
      try_layout_empty_block_leaf_with_definite_height(
        node,
        ctx.available_width,
        ctx.available_height,
        ctx.sizing_mode,
      ) {
      Some(layout) => return layout
      None => ()
    }
  }

  // Resolve box model
  // For MaxContent sizing, percentage values resolve to 0 (CSS intrinsic sizing spec)
  let parent_width = ctx.available_width
  let parent_height_opt = ctx.available_height
  let parent_height = ctx.available_height.unwrap_or(0.0)
  let is_intrinsic_sizing = match ctx.sizing_mode {
    @types.MaxContent => true
    @types.Definite => false
  }
  let margin = if is_intrinsic_sizing {
    @types.resolve_rect_intrinsic(style.margin)
  } else {
    @types.resolve_rect(style.margin, parent_width)
  }
  let padding = if is_intrinsic_sizing {
    @types.resolve_rect_intrinsic(style.padding)
  } else {
    @types.resolve_rect(style.padding, parent_width)
  }
  let border = @types.resolve_rect(style.border, parent_width)

  // Check if margins can collapse with children
  // Collapse blocked by: border/padding, BFC-establishing properties.
  // contain:layout/paint/size also establish an independent formatting context.
  let is_float_container = match style.float {
    @types.Float::None => false
    _ => true
  }
  let establishes_bfc = is_float_container || block_flow_establishes_bfc(style)
  // TODO: logical-block-axis margin collapse in vertical writing mode.
  // For now keep vertical flow non-collapsing to avoid double-applying
  // escaped margins during coordinate remapping.
  let collapse_with_children = not(style.writing_mode.is_vertical()) &&
    not(establishes_bfc)
  let can_collapse_top = border.top == 0.0 &&
    padding.top == 0.0 &&
    collapse_with_children
  let can_collapse_bottom = border.bottom == 0.0 &&
    padding.bottom == 0.0 &&
    collapse_with_children
  let has_available_height = match ctx.available_height {
    Some(_) => true
    None => false
  }
  let auto_height_with_percent_replaced = match style.height {
    @types.Auto => has_percent_sized_replaced_descendant(node)
    _ => false
  }
  let supports_vertical_auto_fill = style.display == @types.Block ||
    style.display == @types.FlowRoot ||
    style.display == @types.Table
  let is_empty_leaf_for_vertical_fill = supports_vertical_auto_fill &&
    node.children.length() == 0 &&
    node.measure is None
  let should_fill_from_percent_replaced = style.writing_mode.is_vertical() &&
    has_available_height &&
    auto_height_with_percent_replaced
  let fill_vertical_auto_height = style.writing_mode.is_vertical() &&
    has_available_height &&
    supports_vertical_auto_fill &&
    (
      ctx.stretch_height ||
      should_fill_from_percent_replaced ||
      is_empty_leaf_for_vertical_fill
    )

  // Box width - depends on sizing mode and aspect_ratio
  // For MaxContent mode with width:Auto, or explicit width: max-content/min-content
  // InlineBlock elements also use shrink-to-fit (max-content) when width is auto
  let is_inline_block = style.display == @types.Inline ||
    style.display == @types.InlineBlock ||
    style.display == @types.TableCell
  let use_max_content = match (ctx.sizing_mode, style.width) {
    (@types.MaxContent, @types.Auto) => true
    (_, @types.MaxContent) => true
    (_, @types.MinContent) => true
    (_, @types.FitContent(_)) => true
    (_, @types.Auto) if is_inline_block => true
    _ => false
  }
  // Check if we can calculate width from height + aspect_ratio
  let width_from_aspect_ratio : Double? = match
    (style.width, style.height, style.aspect_ratio) {
    (@types.Auto, @types.Length(h), Some(ratio)) =>
      // With box-sizing: border-box, aspect-ratio applies to border-box dimensions
      // With content-box (default), it applies to content dimensions
      if style.box_sizing == @types.BorderBox {
        // aspect-ratio applies to border-box: width = height * ratio
        Some(h * ratio)
      } else {
        // aspect-ratio applies to content-box:
        // Width = content-height * ratio + padding + border.
        let content_height = h
        Some(
          content_height * ratio +
          padding.horizontal_sum() +
          border.horizontal_sum(),
        )
      }
    (@types.Auto, @types.Percent(p), Some(ratio)) =>
      match parent_height_opt {
        Some(ph) => {
          let h = ph * p
          if style.box_sizing == @types.BorderBox {
            Some(h * ratio)
          } else {
            let content_height = h
            Some(
              content_height * ratio +
              padding.horizontal_sum() +
              border.horizontal_sum(),
            )
          }
        }
        None => None
      }
    _ => None
  }
  let mut box_width = match width_from_aspect_ratio {
    Some(w) => w
    None =>
      match style.width {
        @types.Length(w) =>
          if style.box_sizing == @types.BorderBox {
            w
          } else {
            w + padding.horizontal_sum() + border.horizontal_sum()
          }
        @types.Percent(p) => {
          let content_w = parent_width * p
          if style.box_sizing == @types.BorderBox {
            content_w
          } else {
            content_w + padding.horizontal_sum() + border.horizontal_sum()
          }
        }
        @types.Auto =>
          if use_max_content {
            // Will be computed from content - use parent_width as initial value for children
            parent_width - margin.horizontal_sum()
          } else {
            parent_width - margin.horizontal_sum()
          }
        @types.MinContent | @types.MaxContent =>
          // Will be computed from content - use parent_width as initial value
          parent_width - margin.horizontal_sum()
        @types.FitContent(_) =>
          // fit-content: use parent_width, will be clamped later
          parent_width - margin.horizontal_sum()
      }
  }

  // Apply min/max width constraints
  // CSS spec: min-width takes precedence over max-width when they conflict
  // So apply max first, then min
  match style.max_width {
    @types.Length(max_w) => {
      let max_box_w = if style.box_sizing == @types.BorderBox {
        max_w
      } else {
        max_w + padding.horizontal_sum() + border.horizontal_sum()
      }
      if box_width > max_box_w {
        box_width = max_box_w
      }
    }
    @types.Percent(p) => {
      let max_content_w = parent_width * p
      let max_box_w = if style.box_sizing == @types.BorderBox {
        max_content_w
      } else {
        max_content_w + padding.horizontal_sum() + border.horizontal_sum()
      }
      if box_width > max_box_w {
        box_width = max_box_w
      }
    }
    @types.MaxContent => {
      // Calculate intrinsic width for max-width constraint
      // For elements with aspect-ratio, use the larger of:
      // 1. Children's max-content width
      // 2. Width from aspect-ratio (if height is specified)
      let children_width = calculate_children_max_content_width(
          node, parent_width,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      let aspect_width = match (style.aspect_ratio, style.height) {
        (Some(ar), @types.Length(h)) if ar > 0.0 =>
          if style.box_sizing == @types.BorderBox {
            h * ar
          } else {
            h * ar + padding.horizontal_sum() + border.horizontal_sum()
          }
        (Some(ar), @types.Percent(p)) if ar > 0.0 =>
          match parent_height_opt {
            Some(ph) => {
              let h = ph * p
              if style.box_sizing == @types.BorderBox {
                h * ar
              } else {
                h * ar + padding.horizontal_sum() + border.horizontal_sum()
              }
            }
            None => 0.0
          }
        _ => 0.0
      }
      let intrinsic_width = @types.max(children_width, aspect_width)
      if box_width > intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.FitContent(_) => {
      // fit-content = min(max-content, max(min-content, available-width))
      let max_content_w = calculate_children_max_content_width(
          node, parent_width,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      let min_content_w = calculate_children_min_content_width(
          node,
          parent_width,
          None,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      let fit_content_w = @types.min(
        max_content_w,
        @types.max(min_content_w, parent_width),
      )
      if box_width > fit_content_w {
        box_width = fit_content_w
      }
    }
    @types.MinContent => {
      let intrinsic_width = calculate_children_min_content_width(
          node,
          parent_width,
          None,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      if box_width > intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.Auto => ()
  }
  match style.min_width {
    @types.Length(min_w) => {
      let min_box_w = if style.box_sizing == @types.BorderBox {
        min_w
      } else {
        min_w + padding.horizontal_sum() + border.horizontal_sum()
      }
      if box_width < min_box_w {
        box_width = min_box_w
      }
    }
    @types.Percent(p) => {
      let min_content_w = parent_width * p
      let min_box_w = if style.box_sizing == @types.BorderBox {
        min_content_w
      } else {
        min_content_w + padding.horizontal_sum() + border.horizontal_sum()
      }
      if box_width < min_box_w {
        box_width = min_box_w
      }
    }
    @types.MaxContent => {
      // Calculate max-content width of children
      let intrinsic_width = calculate_children_max_content_width(
          node, parent_width,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      if box_width < intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.MinContent => {
      let intrinsic_width = calculate_children_min_content_width(
          node,
          parent_width,
          None,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      if box_width < intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.FitContent(_) => {
      // fit-content = min(max-content, max(min-content, available-width))
      let max_content_w = calculate_children_max_content_width(
          node, parent_width,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      let min_content_w = calculate_children_min_content_width(
          node,
          parent_width,
          None,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      let fit_content_w = @types.min(
        max_content_w,
        @types.max(min_content_w, parent_width),
      )
      if box_width < fit_content_w {
        box_width = fit_content_w
      }
    }
    @types.Auto => ()
  }

  // Ensure box_width is at least padding + border (CSS rule: padding/border override max-size)
  let min_box_width = padding.horizontal_sum() + border.horizontal_sum()
  if box_width < min_box_width {
    box_width = min_box_width
  }

  // Available width for children (content area)
  let child_available_width = box_width -
    padding.horizontal_sum() -
    border.horizontal_sum()

  // Calculate available height for children
  let child_available_height : Double? = match style.height {
    @types.Length(h) =>
      if style.box_sizing == @types.BorderBox {
        Some(h - padding.vertical_sum() - border.vertical_sum())
      } else {
        Some(h)
      }
    @types.Percent(p) =>
      match parent_height_opt {
        Some(ph) =>
          if style.box_sizing == @types.BorderBox {
            Some(ph * p - padding.vertical_sum() - border.vertical_sum())
          } else {
            Some(ph * p)
          }
        None =>
          // Percentage height in an indefinite containing block behaves like auto.
          // If max-height is definite, use that constrained content height so
          // descendants with percentage heights can resolve against the used size.
          match style.max_height {
            @types.Length(max_h) =>
              if style.box_sizing == @types.BorderBox {
                Some(
                  @types.max(
                    0.0,
                    max_h - padding.vertical_sum() - border.vertical_sum(),
                  ),
                )
              } else {
                Some(@types.max(0.0, max_h))
              }
            _ => None
          }
      }
    @types.Auto =>
      if ctx.stretch_height {
        match ctx.available_height {
          Some(available_h) =>
            Some(
              @types.max(
                0.0,
                available_h - padding.vertical_sum() - border.vertical_sum(),
              ),
            )
          None => None
        }
      } else {
        match (ctx.sizing_mode, style.aspect_ratio) {
          (@types.Definite, Some(ratio)) if ratio > 0.0 =>
            if style.box_sizing == @types.BorderBox {
              Some(
                @types.max(
                  0.0,
                  box_width / ratio -
                  padding.vertical_sum() -
                  border.vertical_sum(),
                ),
              )
            } else {
              let content_w = box_width -
                padding.horizontal_sum() -
                border.horizontal_sum()
              Some(@types.max(0.0, content_w / ratio))
            }
          _ =>
            match ctx.available_height {
              // Compatibility: propagate a usable block-size through auto wrappers
              // when percent-sized descendants need it. The root body also
              // uses viewport-height as the percentage basis in practice.
              Some(available_h) if style.writing_mode.is_vertical() ||
                node.id == "body" ||
                has_percent_sized_descendant(node) =>
                Some(
                  @types.max(
                    0.0,
                    available_h - padding.vertical_sum() - border.vertical_sum(),
                  ),
                )
              _ => None
            }
        }
      }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
      match ctx.available_height {
        Some(available_h) if style.writing_mode.is_vertical() ||
          node.id == "body" ||
          has_percent_sized_descendant(node) =>
          Some(
            @types.max(
              0.0,
              available_h - padding.vertical_sum() - border.vertical_sum(),
            ),
          )
        _ => None
      }
  }

  // Map to store layouts by original index
  let layout_map : Map[Int, @types.Layout] = {}

  // Map to store static positions for absolute children (their position in flow order)
  let absolute_static_positions : Map[Int, Int] = {} // index -> flow position (0 = before all, 1 = after first flow child, etc.)

  // Collect flow children nodes, styles, and indices
  // Also track where absolute children appear in the flow order
  // And separate float elements for special handling
  let flow_nodes : Array[@node.Node] = []
  let flow_styles : Array[@style.Style] = []
  let flow_indices : Array[Int] = []
  let float_nodes : Array[@node.Node] = []
  let float_indices : Array[Int] = []
  let mut has_non_flow_children = false
  let mut flow_position = 0
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if is_whitespace_only_flow_text(child) &&
      not(should_preserve_flow_whitespace_text(node.children, i)) {
      has_non_flow_children = true
      continue
    }
    if child.style.display == @types.Display::None {
      // Add zero-sized layout for display:none children (including descendants)
      layout_map[i] = create_zero_layout(child)
      has_non_flow_children = true
      continue
    }
    if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      // Record where this absolute/fixed child appears in flow order
      absolute_static_positions[i] = flow_position
      has_non_flow_children = true
      continue
    }
    // Check if this is a float element
    match child.style.float {
      @types.Float::Left | @types.Float::Right => {
        float_nodes.push(child)
        float_indices.push(i)
        has_non_flow_children = true
        // Float elements still advance flow position for absolute static positioning
        flow_position = flow_position + 1
      }
      @types.Float::None => {
        flow_nodes.push(child)
        flow_styles.push(child.style)
        flow_indices.push(i)
        flow_position = flow_position + 1
      }
    }
  }

  // Create float context for managing float positions
  let float_ctx = if style.writing_mode.is_vertical() {
    let float_container_height = match child_available_height {
      Some(h) if h > 0.0 => h
      _ => if parent_height > 0.0 { parent_height } else { ctx.viewport_height }
    }
    @float.FloatContext::new_vertical(
      child_available_width,
      padding.left + border.left,
      float_container_height,
      padding.top + border.top,
      style.writing_mode.is_block_rtl(),
      not(style.direction.is_rtl()),
    )
  } else {
    @float.FloatContext::new(child_available_width, padding.left + border.left)
  }

  // For MaxContent mode, first determine max-content width from children's contributions
  // But if aspect-ratio calculated width is available, prefer that
  if use_max_content && width_from_aspect_ratio is None {
    let mut max_content_width = 0.0
    let multicol_intrinsic_content_width = estimate_multicol_intrinsic_content_width(
      style, parent_width,
    )
    let inline_only = @inline.should_establish_ifc(flow_nodes) ||
      is_ruby_internal_id(node.id)
    let mut inline_has_forced_break = false
    if inline_only && not(style.writing_mode.is_vertical()) {
      for child in flow_nodes {
        if child.id == "br" {
          inline_has_forced_break = true
          break
        }
      }
    }
    let mut current_inline_line_width = 0.0
    // CSS Containment: contain: inline-size means intrinsic width is 0 (no content contribution)
    let skip_content_contribution = style.suppresses_intrinsic_width()
    if skip_content_contribution {
      max_content_width = style.contained_intrinsic_width_fallback()
    } else {
      // Check if root itself has MeasureFunc (leaf node with intrinsic size)
      match node.measure {
        Some(mf) => {
          let intrinsic = (mf.func)(0.0, 0.0)
          max_content_width = intrinsic.max_width
        }
        None => ()
      }
    }
    // Skip children content calculation when contain: inline-size or size is set
    if not(skip_content_contribution) {
      for i = 0; i < flow_nodes.length(); i = i + 1 {
        let child = flow_nodes[i]
        let child_style = flow_styles[i]

        // For intrinsic sizing, percentage margins resolve to 0 (CSS spec)
        // Only fixed margins contribute to intrinsic width
        let child_margin_left : Double = match child_style.margin.left {
          @types.Length(l) => l
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_margin_right : Double = match child_style.margin.right {
          @types.Length(r) => r
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_margin_sum = child_margin_left + child_margin_right

        // Calculate child's intrinsic width contribution
        // Note: padding+border override explicit width if too small
        // For intrinsic sizing, percentage padding also resolves to 0
        let child_padding_left : Double = match child_style.padding.left {
          @types.Length(l) => l
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_padding_right : Double = match child_style.padding.right {
          @types.Length(r) => r
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_border = @types.resolve_rect(child_style.border, parent_width)
        let child_min_box = child_padding_left +
          child_padding_right +
          child_border.horizontal_sum()
        let has_intrinsic_width_constraint = match
          (child_style.min_width, child_style.max_width) {
          (@types.MinContent | @types.MaxContent | @types.FitContent(_), _) =>
            true
          (_, @types.MinContent | @types.MaxContent | @types.FitContent(_)) =>
            true
          _ => false
        }
        let child_recursive_intrinsic_width : Double? = if has_intrinsic_width_constraint &&
          child.children.length() > 0 {
          // Recursively compute child's intrinsic width so min/max intrinsic
          // constraints (e.g. fit-content) are applied on the child itself.
          let intrinsic_ctx : @types.LayoutContext = {
            available_width: parent_width,
            available_height: child_available_height,
            sizing_mode: @types.MaxContent,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          }
          let @node.DispatchFn(dispatch_fn) = dispatch
          let child_width = match child_style.display {
            @types.Flex
            | @types.InlineFlex
            | @types.Grid
            | @types.InlineGrid
            | @types.Table
            | @types.InlineTable =>
              dispatch_fn(child, intrinsic_ctx, dispatch).width
            _ =>
              compute_with_collapse(child, intrinsic_ctx, warnings, dispatch).layout.width
          }
          Some(child_width)
        } else {
          None
        }
        // Helper function to calculate width from aspect-ratio
        fn calc_aspect_width(
          ratio : Double,
          h : Double,
          box_sizing : @types.BoxSizing,
          padding_v : Double,
          border_v : Double,
          padding_h : Double,
          border_h : Double,
          min_box : Double,
        ) -> Double {
          if box_sizing == @types.BorderBox {
            h * ratio
          } else {
            let content_height = h - padding_v - border_v
            if content_height > 0.0 {
              content_height * ratio + padding_h + border_h
            } else {
              min_box
            }
          }
        }

        let child_padding_v = resolve_dimension_intrinsic(
            child_style.padding.top,
          ) +
          resolve_dimension_intrinsic(child_style.padding.bottom)
        fn compute_recursive_child_width() -> Double {
          let intrinsic_ctx : @types.LayoutContext = {
            available_width: parent_width, // Use parent_width as reference for percentages
            available_height: child_available_height,
            sizing_mode: @types.MaxContent,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          }
          let @node.DispatchFn(dispatch_fn) = dispatch
          match child_style.display {
            @types.Flex
            | @types.InlineFlex
            | @types.Grid
            | @types.InlineGrid
            | @types.Table
            | @types.InlineTable =>
              dispatch_fn(child, intrinsic_ctx, dispatch).width
            _ =>
              compute_with_collapse(child, intrinsic_ctx, warnings, dispatch).layout.width
          }
        }
        let mut child_intrinsic_width : Double = match child_style.width {
          @types.Length(w) =>
            match child_recursive_intrinsic_width {
              Some(recursive_w) => recursive_w
              None => @types.max(w, child_min_box)
            }
          @types.Percent(p) =>
            if child_style.writing_mode.is_vertical() &&
              child.children.length() == 0 {
              match child.measure {
                Some(mf) => {
                  let intrinsic = (mf.func)(0.0, 0.0)
                  @types.max(
                    intrinsic.max_width * p + child_min_box,
                    child_min_box,
                  )
                }
                None => child_min_box
              }
            } else if child.children.length() == 0 {
              let measured_aspect_width : Double? = match
                (child.measure, child_style.aspect_ratio) {
                (Some(mf), Some(ratio)) if ratio > 0.0 => {
                  let intrinsic = (mf.func)(0.0, 0.0)
                  let resolved_height : Double? = match child_style.height {
                    @types.Length(h) => Some(h)
                    @types.Percent(height_p) =>
                      match child_available_height {
                        Some(parent_content_h) =>
                          Some(parent_content_h * height_p)
                        None => None
                      }
                    @types.Auto
                    | @types.MinContent
                    | @types.MaxContent
                    | @types.FitContent(_) => {
                      let min_h = match child_style.min_height {
                        @types.Length(h) => h
                        @types.Percent(height_p) =>
                          match child_available_height {
                            Some(parent_content_h) =>
                              parent_content_h * height_p
                            None => 0.0
                          }
                        _ => 0.0
                      }
                      let max_h = match child_style.max_height {
                        @types.Length(h) => h
                        @types.Percent(height_p) =>
                          match child_available_height {
                            Some(parent_content_h) =>
                              parent_content_h * height_p
                            None => @double.infinity
                          }
                        _ => @double.infinity
                      }
                      if max_h < @double.infinity || min_h > 0.0 {
                        Some(
                          @types.clamp(
                            intrinsic.max_height +
                            child_padding_v +
                            child_border.vertical_sum(),
                            min_h,
                            max_h,
                          ),
                        )
                      } else {
                        None
                      }
                    }
                  }
                  match resolved_height {
                    Some(h) =>
                      Some(
                        calc_aspect_width(
                          ratio,
                          h,
                          child_style.box_sizing,
                          child_padding_v,
                          child_border.vertical_sum(),
                          child_padding_left + child_padding_right,
                          child_border.horizontal_sum(),
                          child_min_box,
                        ),
                      )
                    None => None
                  }
                }
                _ => None
              }
              match measured_aspect_width {
                Some(w) => @types.max(w, child_min_box)
                None =>
                  if has_intrinsic_width_constraint {
                    match child_recursive_intrinsic_width {
                      Some(recursive_w) => recursive_w
                      None => child_min_box
                    }
                  } else if has_percent_sized_replaced_descendant(child) {
                    match child_available_height {
                      Some(h) =>
                        @types.max(h * p + child_min_box, child_min_box)
                      None =>
                        if child.children.length() == 0 {
                          child_min_box
                        } else {
                          let recursive_w = compute_recursive_child_width()
                          @types.max(recursive_w, child_min_box)
                        }
                    }
                  } else {
                    child_min_box
                  }
              }
            } else if has_intrinsic_width_constraint {
              match child_recursive_intrinsic_width {
                Some(recursive_w) => recursive_w
                None => child_min_box
              }
            } else if has_percent_sized_replaced_descendant(child) {
              match child_available_height {
                Some(h) => @types.max(h * p + child_min_box, child_min_box)
                None =>
                  if child.children.length() == 0 {
                    child_min_box
                  } else {
                    let recursive_w = compute_recursive_child_width()
                    @types.max(recursive_w, child_min_box)
                  }
              }
            } else {
              child_min_box // At minimum, padding+border
            }
          @types.Auto =>
            // For width:auto, check if aspect-ratio can determine width from height
            // This applies to both MeasureFunc elements (canvas, img) and regular elements
            match (child_style.aspect_ratio, child_style.height) {
              (Some(ratio), @types.Length(h)) if ratio > 0.0 =>
                // Height is explicit length, use aspect-ratio
                calc_aspect_width(
                  ratio,
                  h,
                  child_style.box_sizing,
                  child_padding_v,
                  child_border.vertical_sum(),
                  child_padding_left + child_padding_right,
                  child_border.horizontal_sum(),
                  child_min_box,
                )
              (Some(ratio), @types.Percent(p)) if ratio > 0.0 =>
                // Height is percentage, resolve from parent height
                match child_available_height {
                  Some(parent_content_h) => {
                    // Percentage heights resolve against containing block content box.
                    let h = parent_content_h * p
                    calc_aspect_width(
                      ratio,
                      h,
                      child_style.box_sizing,
                      child_padding_v,
                      child_border.vertical_sum(),
                      child_padding_left + child_padding_right,
                      child_border.horizontal_sum(),
                      child_min_box,
                    )
                  }
                  None => child_min_box // Parent has no definite height
                }
              _ =>
                // No aspect-ratio or height is auto, fall back to intrinsic/content width
                match child.measure {
                  Some(mf) => {
                    let intrinsic = (mf.func)(0.0, 0.0)
                    @types.max(
                      intrinsic.max_width + child_min_box,
                      child_min_box,
                    )
                  }
                  None =>
                    if child.children.length() == 0 {
                      child_min_box // Leaf nodes with no content have padding+border as minimum
                    } else if child_style.display == @types.Contents {
                      if has_table_internal_descendant(child) {
                        // Measure contiguous table-internal descendants as one
                        // anonymous table run so intrinsic width is not fragmented.
                        let run_nodes : Array[@node.Node] = []
                        let run_indices : Array[Int] = []
                        let mut run_index = 0
                        let mut j = i
                        while j < flow_nodes.length() {
                          let run_child = flow_nodes[j]
                          if is_table_internal_flow_node(run_child) {
                            run_nodes.push(run_child)
                            run_indices.push(run_index)
                            run_index = run_index + 1
                            j = j + 1
                            continue
                          }
                          if is_whitespace_only_table_run_text(run_child) {
                            j = j + 1
                            continue
                          }
                          break
                        }
                        if run_nodes.length() > 0 {
                          let (run_result, _) = compute_anonymous_table_run(
                            run_nodes,
                            run_indices,
                            parent_width,
                            child_available_height,
                            style.writing_mode,
                            ctx.viewport_width,
                            ctx.viewport_height,
                            dispatch,
                          )
                          @types.max(run_result.layout.width, child_min_box)
                        } else {
                          child_min_box
                        }
                      } else {
                        // display: contents has no own box, but its descendants
                        // still contribute to intrinsic width.
                        let recursive_w = calculate_children_max_content_width(
                          child, parent_width,
                        )
                        @types.max(recursive_w, child_min_box)
                      }
                    } else {
                      // Recursively compute child's max-content width.
                      // Grid/Flex/Table children must be dispatched to their own
                      // layout algorithms in intrinsic sizing.
                      compute_recursive_child_width()
                    }
                }
            }
          @types.MinContent | @types.MaxContent => child_min_box
          @types.FitContent(_) =>
            if child.children.length() == 0 {
              child_min_box
            } else {
              let recursive_w = compute_recursive_child_width()
              @types.max(recursive_w, child_min_box)
            }
        }
        if is_ruby_internal_id(child.id) {
          let ruby_internal_width = calculate_children_max_content_width(
              child, parent_width,
            ) +
            child_min_box
          if ruby_internal_width > child_intrinsic_width {
            child_intrinsic_width = ruby_internal_width
          }
        }
        let child_contribution = child_intrinsic_width + child_margin_sum
        if style.writing_mode.is_vertical() {
          max_content_width = max_content_width + child_contribution
        } else if inline_only && inline_has_forced_break {
          current_inline_line_width = current_inline_line_width +
            child_contribution
          if child.id == "br" {
            if current_inline_line_width > max_content_width {
              max_content_width = current_inline_line_width
            }
            current_inline_line_width = 0.0
          }
        } else if inline_only {
          max_content_width = max_content_width + child_contribution
        } else if child_contribution > max_content_width {
          max_content_width = child_contribution
        }
      }
      if inline_only &&
        inline_has_forced_break &&
        current_inline_line_width > max_content_width {
        max_content_width = current_inline_line_width
      }

      // Floats also contribute to shrink-to-fit/max-content width.
      // Use the total inline span of floats to match fit-content behavior.
      let mut float_total_width = 0.0
      for child in float_nodes {
        let child_style = child.style
        let child_margin_left : Double = match child_style.margin.left {
          @types.Length(l) => l
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_margin_right : Double = match child_style.margin.right {
          @types.Length(r) => r
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_margin_sum = child_margin_left + child_margin_right
        let child_padding_left : Double = match child_style.padding.left {
          @types.Length(l) => l
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_padding_right : Double = match child_style.padding.right {
          @types.Length(r) => r
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_border = @types.resolve_rect(child_style.border, parent_width)
        let child_min_box = child_padding_left +
          child_padding_right +
          child_border.horizontal_sum()
        let child_padding_v = resolve_dimension_intrinsic(
            child_style.padding.top,
          ) +
          resolve_dimension_intrinsic(child_style.padding.bottom)
        fn calc_float_aspect_width(
          ratio : Double,
          h : Double,
          box_sizing : @types.BoxSizing,
          padding_v : Double,
          border_v : Double,
          padding_h : Double,
          border_h : Double,
          min_box : Double,
        ) -> Double {
          if box_sizing == @types.BorderBox {
            h * ratio
          } else {
            let content_height = h - padding_v - border_v
            if content_height > 0.0 {
              content_height * ratio + padding_h + border_h
            } else {
              min_box
            }
          }
        }
        fn compute_float_recursive_width(
          width_keyword : @types.Dimension,
        ) -> Double {
          let intrinsic_basis_width = if parent_width > 0.0 {
            parent_width
          } else {
            ctx.viewport_width
          }
          let intrinsic_child = @node.Node::with_uid_and_measure(
            child.id,
            child.uid,
            { ..child_style, width: width_keyword },
            child.children,
            child.measure,
            child.text,
          )
          let intrinsic_ctx : @types.LayoutContext = {
            available_width: intrinsic_basis_width,
            available_height: child_available_height,
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          }
          let @node.DispatchFn(dispatch_fn) = dispatch
          match child_style.display {
            @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
              dispatch_fn(intrinsic_child, intrinsic_ctx, dispatch).width
            _ =>
              compute_with_collapse(
                intrinsic_child, intrinsic_ctx, warnings, dispatch,
              ).layout.width
          }
        }
        let child_intrinsic_width : Double = match child_style.width {
          @types.Length(w) => @types.max(w, child_min_box)
          @types.Percent(_) => child_min_box
          @types.Auto =>
            match (child_style.aspect_ratio, child_style.height) {
              (Some(ratio), @types.Length(h)) if ratio > 0.0 =>
                calc_float_aspect_width(
                  ratio,
                  h,
                  child_style.box_sizing,
                  child_padding_v,
                  child_border.vertical_sum(),
                  child_padding_left + child_padding_right,
                  child_border.horizontal_sum(),
                  child_min_box,
                )
              (Some(ratio), @types.Percent(p)) if ratio > 0.0 =>
                match child_available_height {
                  Some(parent_content_h) => {
                    let h = parent_content_h * p
                    calc_float_aspect_width(
                      ratio,
                      h,
                      child_style.box_sizing,
                      child_padding_v,
                      child_border.vertical_sum(),
                      child_padding_left + child_padding_right,
                      child_border.horizontal_sum(),
                      child_min_box,
                    )
                  }
                  None => child_min_box
                }
              _ =>
                match child.measure {
                  Some(mf) => {
                    let intrinsic = (mf.func)(0.0, 0.0)
                    @types.max(
                      intrinsic.max_width + child_min_box,
                      child_min_box,
                    )
                  }
                  None =>
                    if child.children.length() == 0 {
                      child_min_box
                    } else {
                      let recursive_w = compute_float_recursive_width(
                        @types.MaxContent,
                      )
                      @types.max(recursive_w, child_min_box)
                    }
                }
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            child_min_box
        }
        float_total_width = float_total_width +
          child_intrinsic_width +
          child_margin_sum
      }
      if float_total_width > max_content_width {
        max_content_width = float_total_width
      }
    }
    if multicol_intrinsic_content_width > max_content_width {
      max_content_width = multicol_intrinsic_content_width
    }
    if max_content_width < 0.0 {
      max_content_width = 0.0
    }
    let skip_intrinsic_inline = style.suppresses_intrinsic_width()
    let mut min_content_width = if skip_intrinsic_inline {
      style.contained_intrinsic_width_fallback() +
      padding.horizontal_sum() +
      border.horizontal_sum()
    } else {
      calculate_children_min_content_width(
        node, parent_width, child_available_height,
      ) +
      padding.horizontal_sum() +
      border.horizontal_sum()
    }
    if min_content_width < multicol_intrinsic_content_width {
      min_content_width = multicol_intrinsic_content_width
    }
    let shrink_available_width = if box_width > 0.0 { box_width } else { 0.0 }
    // Update box_width from intrinsic width according to specified width keyword.
    box_width = match style.width {
      @types.MinContent => min_content_width
      @types.Auto =>
        if is_inline_block {
          // Inline-block width:auto uses shrink-to-fit.
          let preferred_max = max_content_width +
            padding.horizontal_sum() +
            border.horizontal_sum()
          let mut shrink_to_fit = @types.max(
            min_content_width, shrink_available_width,
          )
          if shrink_to_fit > preferred_max {
            shrink_to_fit = preferred_max
          }
          shrink_to_fit
        } else {
          max_content_width + padding.horizontal_sum() + border.horizontal_sum()
        }
      @types.MaxContent | @types.FitContent(_) =>
        max_content_width + padding.horizontal_sum() + border.horizontal_sum()
      _ =>
        max_content_width + padding.horizontal_sum() + border.horizontal_sum()
    }
    let intrinsic_max_width_for_constraints = if skip_intrinsic_inline {
      style.contained_intrinsic_width_fallback() +
      padding.horizontal_sum() +
      border.horizontal_sum()
    } else {
      calculate_children_max_content_width(node, parent_width) +
      padding.horizontal_sum() +
      border.horizontal_sum()
    }
    let intrinsic_min_width_for_constraints = if skip_intrinsic_inline {
      style.contained_intrinsic_width_fallback() +
      padding.horizontal_sum() +
      border.horizontal_sum()
    } else {
      calculate_children_min_content_width(
        node, parent_width, child_available_height,
      ) +
      padding.horizontal_sum() +
      border.horizontal_sum()
    }
    // Re-apply min/max constraints (max first, then min for precedence)
    match style.max_width {
      @types.Length(max_w) => if box_width > max_w { box_width = max_w }
      @types.Percent(p) => {
        let max_w = parent_width * p
        if box_width > max_w {
          box_width = max_w
        }
      }
      @types.MaxContent | @types.FitContent(_) => {
        let intrinsic_width = intrinsic_max_width_for_constraints
        if box_width > intrinsic_width {
          box_width = intrinsic_width
        }
      }
      @types.MinContent => {
        let intrinsic_width = intrinsic_min_width_for_constraints
        if box_width > intrinsic_width {
          box_width = intrinsic_width
        }
      }
      @types.Auto => ()
    }
    match style.min_width {
      @types.Length(min_w) => if box_width < min_w { box_width = min_w }
      @types.Percent(p) => {
        let min_w = parent_width * p
        if box_width < min_w {
          box_width = min_w
        }
      }
      @types.MaxContent => {
        let intrinsic_width = intrinsic_max_width_for_constraints
        if box_width < intrinsic_width {
          box_width = intrinsic_width
        }
      }
      @types.MinContent | @types.FitContent(_) => {
        let intrinsic_width = intrinsic_min_width_for_constraints
        if box_width < intrinsic_width {
          box_width = intrinsic_width
        }
      }
      @types.Auto => ()
    }
    // Ensure box_width is at least padding + border (CSS rule: padding/border override max-size)
    if box_width < min_box_width {
      box_width = min_box_width
    }
  }

  // Calculate actual child_available_width from final box_width
  let actual_child_available_width = box_width -
    padding.horizontal_sum() -
    border.horizontal_sum()
  let multicol_enabled = style.has_multicol()
  let (multicol_column_count, multicol_column_width, multicol_column_gap) = if multicol_enabled {
    resolve_multicol_track_geometry(
      style, actual_child_available_width, parent_width,
    )
  } else {
    (1, actual_child_available_width, 0.0)
  }
  if multicol_enabled &&
    float_nodes.length() == 0 &&
    not(has_non_flow_children) &&
    flow_nodes.length() == 1 &&
    flow_nodes[0].style.display == @types.Contents {
    let contents_child = flow_nodes[0]
    let synthetic_node = @node.Node::with_uid_and_measure(
      node.id,
      node.uid,
      style,
      contents_child.children,
      node.measure,
      node.text,
    )
    let synthetic_result = compute_with_collapse(
      synthetic_node, ctx, warnings, dispatch,
    )
    let contents_layout : @types.Layout = {
      id: contents_child.id,
      x: 0.0,
      y: 0.0,
      width: 0.0,
      height: 0.0,
      margin: @types.Rect::zero(),
      padding: @types.Rect::zero(),
      border: @types.Rect::zero(),
      overflow_x: @types.Visible,
      overflow_y: @types.Visible,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: synthetic_result.layout.children,
      text: contents_child.text,
    }
    return {
      layout: { ..synthetic_result.layout, children: [contents_layout] },
      collapsed: synthetic_result.collapsed,
    }
  }

  // Check if we should use Inline Formatting Context (IFC)
  // IFC is used when all flow children are inline-level elements
  // Floats require float-context placement and cannot be handled by pure IFC path.
  let has_table_internal_flow = has_table_internal_flow_content(flow_nodes)
  let use_ifc = (
      @inline.should_establish_ifc(flow_nodes) ||
      should_establish_ifc_with_contents(flow_nodes)
    ) &&
    float_nodes.length() == 0 &&
    not(multicol_enabled) &&
    not(has_table_internal_flow)
  // Check for mixed inline/block content (needs anonymous block boxes)
  let has_mixed = not(has_table_internal_flow) &&
    has_mixed_inline_block_content(flow_nodes)
  if use_ifc {
    let width_is_fit_content = match style.width {
      @types.FitContent(_) => true
      _ => false
    }
    let suppress_ifc_inline_progress = style.contain.inline_size &&
      not(style.writing_mode.is_vertical()) &&
      width_is_fit_content
    let ifc_available_width = if style.contain.inline_size &&
      not(style.writing_mode.is_vertical()) {
      match style.width {
        @types.FitContent(_) =>
          if parent_width > actual_child_available_width {
            parent_width
          } else {
            actual_child_available_width
          }
        _ => actual_child_available_width
      }
    } else {
      actual_child_available_width
    }
    // Use IFC for inline layout
    let ifc_result = @inline.compute_ifc(
      flow_nodes,
      ifc_available_width,
      child_available_height,
      padding.left + border.left,
      padding.top + border.top,
      dispatch,
      container_writing_mode=style.writing_mode,
      container_direction=style.direction,
      container_text_align=style.text_align,
      container_white_space=style.white_space,
    )

    // Store IFC layouts with original indices
    for i = 0; i < flow_indices.length(); i = i + 1 {
      if i < ifc_result.layouts.length() {
        let flow_node = flow_nodes[i]
        let ifc_layout = ifc_result.layouts[i]
        let normalized_layout = if flow_node.style.display == @types.Contents {
          {
            ..ifc_layout,
            width: 0.0,
            height: 0.0,
            padding: @types.Rect::zero(),
            border: @types.Rect::zero(),
            scroll_width: 0.0,
            scroll_height: 0.0,
          }
        } else {
          ifc_layout
        }
        let normalized_layout = if suppress_ifc_inline_progress {
          {
            ..normalized_layout,
            x: padding.left + border.left + normalized_layout.margin.left,
          }
        } else {
          normalized_layout
        }
        layout_map[flow_indices[i]] = adjust_inline_span_float_quirk(
          normalized_layout,
          flow_node,
          style.writing_mode.is_vertical(),
        )
      }
    }

    // Calculate box height from IFC content
    let mut content_height = ifc_result.total_height
    // Include descendant visual overflow from inline children (e.g. large
    // top-aligned inline descendants) in IFC content height.
    let mut ifc_descendant_extent = 0.0
    for i = 0; i < flow_indices.length(); i = i + 1 {
      match layout_map.get(flow_indices[i]) {
        Some(layout) => {
          let descendant_h = if i < flow_nodes.length() &&
            id_matches_tag(flow_nodes[i].id, "ruby") {
            0.0
          } else {
            get_inflow_children_flow_extent_height(
              flow_nodes[i],
              layout.children,
            )
          }
          let child_block = if layout.height > descendant_h {
            layout.height
          } else {
            descendant_h
          }
          let extent = layout.y + child_block
          if extent > ifc_descendant_extent {
            ifc_descendant_extent = extent
          }
        }
        None => ()
      }
    }
    // Subtract content offset (padding+border top) since IFC child positions
    // include this offset but content_height should be relative to content area.
    let ifc_content_offset = padding.top + border.top
    let adjusted_ifc_descendant_extent = if ifc_descendant_extent >
      ifc_content_offset {
      ifc_descendant_extent - ifc_content_offset
    } else {
      ifc_descendant_extent
    }
    if adjusted_ifc_descendant_extent > content_height {
      content_height = adjusted_ifc_descendant_extent
    }
    if style.writing_mode.is_vertical() {
      let content_left = padding.left + border.left
      let content_right = content_left + actual_child_available_width
      let mut min_inline_x = content_right
      let mut max_inline_right = content_left
      for i = 0; i < flow_indices.length(); i = i + 1 {
        match layout_map.get(flow_indices[i]) {
          Some(layout) => {
            if layout.x < min_inline_x {
              min_inline_x = layout.x
            }
            let layout_right = layout.x + layout.width
            if layout_right > max_inline_right {
              max_inline_right = layout_right
            }
          }
          None => ()
        }
      }
      let ifc_block_extent = if style.writing_mode.is_block_rtl() {
        let extent = content_right - min_inline_x
        if extent > 0.0 {
          extent
        } else {
          0.0
        }
      } else {
        let extent = max_inline_right - content_left
        if extent > 0.0 {
          extent
        } else {
          0.0
        }
      }
      match (style.width, style.min_width, style.max_width) {
        (@types.Auto, @types.Auto, @types.Auto) =>
          box_width = ifc_block_extent +
            padding.horizontal_sum() +
            border.horizontal_sum()
        _ => ()
      }
    }
    let content_height_for_auto = if style.suppresses_intrinsic_height() {
      style.contained_intrinsic_height_fallback()
    } else {
      content_height
    }
    let box_height = resolve_box_height_from_style(
      style, box_width, content_height_for_auto, parent_height_opt, fill_vertical_auto_height,
      margin, padding, border,
    )
    let box_height = apply_content_driven_height_constraints(
      box_height, style, node, parent_width, content_height_for_auto, padding, border,
    )
    let block_content_alignment_offset = if not(
        style.writing_mode.is_vertical(),
      ) {
      let content_box_height = box_height -
        padding.vertical_sum() -
        border.vertical_sum()
      compute_block_content_alignment_offset(
        style.align_content,
        content_box_height,
        content_height,
      )
    } else {
      0.0
    }
    if block_content_alignment_offset.abs() > 0.0001 {
      for idx in flow_indices {
        match layout_map.get(idx) {
          Some(positioned_layout) =>
            layout_map[idx] = {
              ..positioned_layout,
              y: positioned_layout.y + block_content_alignment_offset,
            }
          None => ()
        }
      }
    }
    place_absolute_children_at_static_y(
      node, box_width, box_height, border, content_height, warnings, dispatch, layout_map,
    )
    place_fixed_children_for_parent(
      node,
      style,
      parent_width,
      if parent_height > 0.0 {
        parent_height
      } else {
        ctx.viewport_height
      },
      box_width,
      box_height,
      border,
      ctx.viewport_width,
      ctx.viewport_height,
      warnings,
      dispatch,
      layout_map,
    )
    let child_layouts : Array[@types.Layout] = []
    for i = 0; i < node.children.length(); i = i + 1 {
      match layout_map.get(i) {
        Some(raw_layout) => {
          let adjusted_layout = adjust_float_only_inline_wrapper_for_parent(
            raw_layout,
            node.children[i],
            style,
            style.writing_mode.is_vertical(),
            false,
          )
          child_layouts.push(adjusted_layout)
        }
        None => ()
      }
    }
    // Calculate scroll dimensions
    let (scroll_width, scroll_height) = calculate_scroll_dimensions(
      box_width, box_height, padding, child_layouts,
    )
    let layout : @types.Layout = {
      id: node.id,
      x: 0.0,
      y: 0.0,
      width: box_width,
      height: box_height,
      margin,
      padding,
      border,
      overflow_x: style.overflow_x,
      overflow_y: style.overflow_y,
      scroll_width,
      scroll_height,
      children: child_layouts,
      text: node.text,
    }
    return { layout, collapsed: { top: None, bottom: None } }
  } else if has_mixed && float_nodes.length() == 0 && not(multicol_enabled) {
    // Mixed inline/block content - use anonymous block boxes
    let groups = group_flow_children_for_anonymous_blocks(
      flow_nodes, flow_indices,
    )
    let mixed_result = compute_mixed_content_layout(
      groups,
      actual_child_available_width,
      child_available_height,
      padding,
      border,
      ctx,
      warnings,
      layout_map,
      dispatch,
      writing_mode=style.writing_mode,
      direction=style.direction,
      text_align=style.text_align,
      white_space=style.white_space,
      justify_items=style.justify_items,
    )
    // fieldset legend overlays the top border line instead of participating in
    // normal block-flow vertical positioning.
    if not(style.writing_mode.is_vertical()) && node.id.has_prefix("fieldset") {
      for i = 0; i < node.children.length(); i = i + 1 {
        let child = node.children[i]
        if child.id.has_prefix("legend") {
          match layout_map.get(i) {
            Some(legend_layout) => {
              let overlay = (border.top - legend_layout.height) / 2.0
              let legend_y = if overlay > 0.0 { overlay } else { 0.0 }
              layout_map[i] = { ..legend_layout, y: legend_y }
            }
            None => ()
          }
          break
        }
      }
    }
    // Calculate box height from mixed content
    let mut content_height = mixed_result.content_height
    if establishes_bfc {
      // Floats in descendant anonymous/block wrappers still participate in this BFC.
      // Include their visual block extent when mixed-content grouping is used.
      let mut mixed_descendant_extent = 0.0
      for i = 0; i < node.children.length(); i = i + 1 {
        match layout_map.get(i) {
          Some(layout) => {
            let descendant_h = get_child_descendant_flow_extent_for_auto_height(
              node.children[i],
              layout,
            )
            let child_block = if layout.height > descendant_h {
              layout.height
            } else {
              descendant_h
            }
            let extent = layout.y + child_block
            if extent > mixed_descendant_extent {
              mixed_descendant_extent = extent
            }
          }
          None => ()
        }
      }
      if mixed_descendant_extent > content_height {
        content_height = mixed_descendant_extent
      }
    }
    let content_height_for_auto = if style.suppresses_intrinsic_height() {
      style.contained_intrinsic_height_fallback()
    } else {
      content_height
    }
    let box_height = resolve_box_height_from_style(
      style, box_width, content_height_for_auto, parent_height_opt, fill_vertical_auto_height,
      margin, padding, border,
    )
    let box_height = apply_content_driven_height_constraints(
      box_height, style, node, parent_width, content_height_for_auto, padding, border,
    )
    let block_content_alignment_offset = if not(
        style.writing_mode.is_vertical(),
      ) {
      let content_box_height = box_height -
        padding.vertical_sum() -
        border.vertical_sum()
      compute_block_content_alignment_offset(
        style.align_content,
        content_box_height,
        content_height,
      )
    } else {
      0.0
    }
    if block_content_alignment_offset.abs() > 0.0001 {
      for i = 0; i < node.children.length(); i = i + 1 {
        match layout_map.get(i) {
          Some(positioned_layout) =>
            layout_map[i] = {
              ..positioned_layout,
              y: positioned_layout.y + block_content_alignment_offset,
            }
          None => ()
        }
      }
    }
    place_absolute_children_at_static_y(
      node, box_width, box_height, border, content_height, warnings, dispatch, layout_map,
    )
    place_fixed_children_for_parent(
      node,
      style,
      parent_width,
      if parent_height > 0.0 {
        parent_height
      } else {
        ctx.viewport_height
      },
      box_width,
      box_height,
      border,
      ctx.viewport_width,
      ctx.viewport_height,
      warnings,
      dispatch,
      layout_map,
    )
    let child_layouts = collect_child_layouts_in_source_order(node, layout_map)
    // Calculate scroll dimensions
    let (scroll_width, scroll_height) = calculate_scroll_dimensions(
      box_width, box_height, padding, child_layouts,
    )
    let layout : @types.Layout = {
      id: node.id,
      x: 0.0,
      y: 0.0,
      width: box_width,
      height: box_height,
      margin,
      padding,
      border,
      overflow_x: style.overflow_x,
      overflow_y: style.overflow_y,
      scroll_width,
      scroll_height,
      children: child_layouts,
      text: node.text,
    }
    // Return with escaped margins from mixed content
    return {
      layout,
      collapsed: {
        top: mixed_result.escaped_top,
        bottom: mixed_result.escaped_bottom,
      },
    }
  }

  // Now compute children's actual layout with the resolved width (BFC path)
  let flow_child_available_width = if multicol_enabled {
    if multicol_column_width > 0.0 {
      multicol_column_width
    } else {
      actual_child_available_width
    }
  } else {
    actual_child_available_width
  }
  let flow_children : Array[LayoutWithCollapse] = []
  let table_run_overrides : Array[AnonymousTableRunOverride] = []
  let mut flow_i = 0
  while flow_i < flow_nodes.length() {
    let child = flow_nodes[flow_i]
    let child_is_orthogonal = child.style.writing_mode.is_vertical() !=
      style.writing_mode.is_vertical()
    let child_has_auto_margin = match
      (
        child.style.margin.top,
        child.style.margin.right,
        child.style.margin.bottom,
        child.style.margin.left,
      ) {
      (@types.Auto, _, _, _)
      | (_, @types.Auto, _, _)
      | (_, _, @types.Auto, _)
      | (_, _, _, @types.Auto) => true
      _ => false
    }
    let child_for_layout = if child_is_orthogonal &&
      child_has_auto_margin &&
      child.style.width == @types.Auto {
      // Orthogonal-flow auto inline-size behaves closer to fit-content than
      // fill-available for these WPT containment cases.
      @node.Node::with_uid_and_measure(
        child.id,
        child.uid,
        { ..child.style, width: @types.MaxContent },
        child.children,
        child.measure,
        child.text,
      )
    } else {
      child
    }
    let skip_anonymous_table_run = is_no_principal_table_internal_display(
      child.style.display,
    )
    if is_table_internal_flow_node(child) && not(skip_anonymous_table_run) {
      // Consecutive table-internal/table-contents siblings form one anonymous table.
      let run_nodes : Array[@node.Node] = []
      let run_indices : Array[Int] = []
      let mut run_end = flow_i
      while run_end < flow_nodes.length() &&
            (
              is_table_internal_flow_node(flow_nodes[run_end]) ||
              is_whitespace_only_table_run_text(flow_nodes[run_end])
            ) {
        let run_child = flow_nodes[run_end]
        if is_table_internal_flow_node(run_child) {
          run_nodes.push(run_child)
          run_indices.push(flow_indices[run_end])
        }
        run_end = run_end + 1
      }
      let (first_result, run_override) = compute_anonymous_table_run(
        run_nodes,
        run_indices,
        flow_child_available_width,
        child_available_height,
        style.writing_mode,
        ctx.viewport_width,
        ctx.viewport_height,
        dispatch,
      )
      flow_children.push(first_result)
      table_run_overrides.push(run_override)
      for j = flow_i + 1; j < run_end; j = j + 1 {
        flow_children.push({
          layout: create_zero_layout(flow_nodes[j]),
          collapsed: { top: None, bottom: None },
        })
      }
      flow_i = run_end
      continue
    }
    // Flex, Grid, Table, and InlineBlock containers establish a new BFC, so use dispatch for them
    // and don't participate in margin collapsing

    let child_result = match child.style.display {
      @types.Flex
      | @types.InlineFlex
      | @types.Grid
      | @types.InlineGrid
      | @types.InlineBlock
      | @types.Table
      | @types.InlineTable => {
        // For BFC-establishing children with auto height, don't pass available_height
        // This allows them to size to their content rather than stretching to fill
        // the available space. Flex item sizing should be decided by the flex/grid parent.
        let child_height_for_ctx : Double? = match child.style.height {
          @types.Auto =>
            if child.style.writing_mode.is_vertical() {
              child_available_height
            } else {
              None
            }
          _ => child_available_height
        }
        let child_ctx : @types.LayoutContext = {
          available_width: flow_child_available_width,
          available_height: child_height_for_ctx,
          sizing_mode: @types.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        // Use dispatch for flex/grid/table containers
        let @node.DispatchFn(dispatch_fn) = dispatch
        let layout = dispatch_fn(child_for_layout, child_ctx, dispatch)
        { layout, collapsed: { top: None, bottom: None } }
      }
      _ => {
        let child_ctx : @types.LayoutContext = {
          available_width: flow_child_available_width,
          available_height: child_available_height,
          sizing_mode: @types.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        let raw = compute_with_collapse(
          child_for_layout, child_ctx, warnings, dispatch,
        )
        {
          ..raw,
          layout: apply_initial_scroll_snap(child_for_layout, raw.layout),
        }
      }
    }
    flow_children.push(child_result)
    flow_i = flow_i + 1
  }

  let has_simple_block_stack_hint = flow_nodes.length() == 1 ||
    padding.horizontal_sum() > 0.0 ||
    padding.vertical_sum() > 0.0 ||
    border.horizontal_sum() > 0.0 ||
    border.vertical_sum() > 0.0
  let can_use_simple_block_stack = ctx.sizing_mode == @types.Definite &&
    has_simple_block_stack_hint &&
    style.align_content == @types.Stretch &&
    not(style.writing_mode.is_vertical()) &&
    not(multicol_enabled) &&
    not(use_ifc) &&
    not(has_mixed) &&
    not(has_non_flow_children) &&
    not(node.id.has_prefix("fieldset")) &&
    float_nodes.length() == 0 &&
    flow_nodes.length() == node.children.length() &&
    flow_children.length() == flow_nodes.length()
  let can_use_simple_block_stack = if can_use_simple_block_stack {
    let mut all_simple = true
    for child in flow_nodes {
      if not(is_simple_block_stack_child(child.style)) {
        all_simple = false
        break
      }
    }
    all_simple
  } else {
    false
  }
  if can_use_simple_block_stack {
    let simple_result = layout_simple_block_stack(
      flow_nodes, flow_children, padding, border, can_collapse_top, can_collapse_bottom,
    )
    let adjusted_child_layouts : Array[@types.Layout] = []
    for i = 0
        i < simple_result.child_layouts.length() && i < flow_nodes.length()
        i = i + 1 {
      adjusted_child_layouts.push(
        adjust_float_only_inline_wrapper_for_parent(
          simple_result.child_layouts[i],
          flow_nodes[i],
          style,
          style.writing_mode.is_vertical(),
          false,
        ),
      )
    }
    let flow_content_height = if flow_children.length() == 0 {
      0.0
    } else if can_collapse_bottom {
      @types.max(0.0, simple_result.current_pos)
    } else {
      @types.max(0.0, simple_result.current_pos + simple_result.prev_margin_end)
    }
    let mut content_height = flow_content_height
    if style.height == @types.Auto {
      let mut adjusted_flow_extent = 0.0
      let content_offset_y = padding.top + border.top
      for i = 0
          i < adjusted_child_layouts.length() && i < flow_nodes.length()
          i = i + 1 {
        let child_style = flow_nodes[i].style
        let skip_out_of_flow = child_style.position == @types.Absolute ||
          child_style.position == @types.Fixed ||
          child_style.float != @types.Float::None
        if skip_out_of_flow {
          continue
        }
        let descendant_h = get_child_descendant_flow_extent_for_auto_height(
          flow_nodes[i],
          adjusted_child_layouts[i],
        )
        let child_block = if adjusted_child_layouts[i].height > descendant_h {
          adjusted_child_layouts[i].height
        } else {
          descendant_h
        }
        let child_content_y = if adjusted_child_layouts[i].y > content_offset_y {
          adjusted_child_layouts[i].y - content_offset_y
        } else {
          0.0
        }
        let extent = child_content_y + child_block
        if extent > adjusted_flow_extent {
          adjusted_flow_extent = extent
        }
      }
      if adjusted_flow_extent > content_height {
        content_height = adjusted_flow_extent
      }
    }
    let content_height_for_auto = if style.suppresses_intrinsic_height() {
      style.contained_intrinsic_height_fallback()
    } else {
      content_height
    }
    let mut box_height = resolve_box_height_from_style(
      style, box_width, content_height_for_auto, parent_height_opt, fill_vertical_auto_height,
      margin, padding, border,
    )

    box_height = apply_block_height_constraints(
      box_height, style, parent_height, content_height_for_auto, padding, border,
    )
    box_width = adjust_auto_width_from_height_constrained_aspect_ratio(
      style, box_width, box_height, parent_width, padding, border,
    )

    let (scroll_width, scroll_height) = calculate_scroll_dimensions(
      box_width, box_height, padding, adjusted_child_layouts,
    )
    let layout : @types.Layout = {
      id: node.id,
      x: 0.0,
      y: 0.0,
      width: box_width,
      height: box_height,
      margin,
      padding,
      border,
      overflow_x: style.overflow_x,
      overflow_y: style.overflow_y,
      scroll_width,
      scroll_height,
      children: adjusted_child_layouts,
      text: node.text,
    }
    return {
      layout,
      collapsed: {
        top: simple_result.escaped_top,
        bottom: simple_result.escaped_bottom,
      },
    }
  }

  // Layout float elements in source order as flow advances.
  let float_layouts : Array[@types.Layout] = []
  fn place_float_layout(
    float_index : Int,
    start_pos : Double,
  ) -> @types.Layout {
    let child = float_nodes[float_index]
    let child_style = child.style

    // Resolve child's box model
    let child_margin = @types.resolve_rect(
      child_style.margin,
      actual_child_available_width,
    )
    let child_padding = @types.resolve_rect(
      child_style.padding,
      actual_child_available_width,
    )
    let child_border = @types.resolve_rect(
      child_style.border,
      actual_child_available_width,
    )

    // For floats with explicit height, use that height for children's percentage resolution
    // This is important for intrinsic sizing when children have height: %
    let float_available_height : Double? = match child_style.height {
      @types.Length(h) =>
        Some(h - child_padding.vertical_sum() - child_border.vertical_sum())
      @types.Percent(_) =>
        // Keep parent content height as the percentage basis.
        // The float node itself resolves its own percentage height later.
        child_available_height
      _ => child_available_height
    }

    let @node.DispatchFn(keyword_dispatch_fn) = dispatch
    fn compute_float_keyword_width(width_keyword : @types.Dimension) -> Double {
      let keyword_style = { ..child_style, width: width_keyword }
      let keyword_child = @node.Node::with_uid_and_measure(
        child.id,
        child.uid,
        keyword_style,
        child.children,
        child.measure,
        child.text,
      )
      let keyword_padding = @types.resolve_rect(
        keyword_style.padding,
        actual_child_available_width,
      )
      let keyword_border = @types.resolve_rect(
        keyword_style.border,
        actual_child_available_width,
      )
      let provisional_width = actual_child_available_width
      let content_width = provisional_width -
        keyword_padding.horizontal_sum() -
        keyword_border.horizontal_sum()
      let keyword_height_for_ctx : Double? = match keyword_style.display {
        @types.Flex
        | @types.InlineFlex
        | @types.Grid
        | @types.InlineGrid
        | @types.Table
        | @types.InlineTable =>
          match keyword_style.height {
            @types.Auto =>
              if keyword_style.writing_mode.is_vertical() {
                float_available_height
              } else {
                None
              }
            _ => float_available_height
          }
        _ => float_available_height
      }
      let keyword_ctx : @types.LayoutContext = {
        available_width: if content_width > 0.0 {
          content_width
        } else {
          0.0
        },
        available_height: keyword_height_for_ctx,
        sizing_mode: @types.Definite,
        viewport_width: ctx.viewport_width,
        viewport_height: ctx.viewport_height,
        stretch_width: false,
        stretch_height: false,
      }
      match keyword_style.display {
        @types.Flex
        | @types.InlineFlex
        | @types.Grid
        | @types.InlineGrid
        | @types.Table
        | @types.InlineTable =>
          keyword_dispatch_fn(keyword_child, keyword_ctx, dispatch).width
        _ =>
          compute_with_collapse(keyword_child, keyword_ctx, warnings, dispatch).layout.width
      }
    }

    // Calculate child's width (float elements use shrink-to-fit)
    let child_width = match child_style.width {
      @types.Length(w) => w
      @types.Percent(p) => actual_child_available_width * p
      @types.Auto => {
        let preferred_max = compute_float_keyword_width(@types.MaxContent)
        let mut preferred_min = compute_float_keyword_width(@types.MinContent)
        if float_available_height is Some(_) &&
          has_percent_sized_replaced_descendant(child) &&
          preferred_max > preferred_min {
          // Browser-compat quirk: percent-sized replaced descendants in auto-height
          // wrappers behave as if preferred-min tracks preferred width.
          preferred_min = preferred_max
        }
        let available_for_shrink = if actual_child_available_width > 0.0 {
          actual_child_available_width
        } else {
          0.0
        }
        let mut shrink_to_fit = @types.max(preferred_min, available_for_shrink)
        if shrink_to_fit > preferred_max {
          shrink_to_fit = preferred_max
        }
        if shrink_to_fit < 0.0 {
          0.0
        } else {
          shrink_to_fit
        }
      }
      @types.MinContent => compute_float_keyword_width(@types.MinContent)
      @types.MaxContent => compute_float_keyword_width(@types.MaxContent)
      @types.FitContent(limit) => {
        let preferred_max = compute_float_keyword_width(@types.MaxContent)
        let preferred_min = compute_float_keyword_width(@types.MinContent)
        let mut fit = limit
        if fit < preferred_min {
          fit = preferred_min
        }
        if fit > preferred_max {
          fit = preferred_max
        }
        if fit < 0.0 {
          0.0
        } else {
          fit
        }
      }
    }

    // Compute child layout with determined width
    let child_content_width = child_width -
      child_padding.horizontal_sum() -
      child_border.horizontal_sum()
    let child_for_layout = match child_style.width {
      @types.Auto =>
        @node.Node::with_uid_and_measure(
          child.id,
          child.uid,
          { ..child_style, width: @types.Length(child_width) },
          child.children,
          child.measure,
          child.text,
        )
      _ => child
    }
    // For BFC-establishing children (flex/grid/table) with auto height, don't pass available_height
    // This allows them to size to their content rather than stretching
    // Use float_available_height which accounts for float's own explicit height
    let child_height_for_ctx : Double? = match child_style.display {
      @types.Flex
      | @types.InlineFlex
      | @types.Grid
      | @types.InlineGrid
      | @types.Table
      | @types.InlineTable =>
        match child_style.height {
          @types.Auto =>
            if child_style.writing_mode.is_vertical() {
              float_available_height
            } else {
              None
            }
          _ => float_available_height
        }
      _ => float_available_height
    }
    let child_ctx : @types.LayoutContext = {
      available_width: if child_content_width > 0.0 {
        child_content_width
      } else {
        0.0
      },
      available_height: child_height_for_ctx,
      sizing_mode: @types.Definite,
      viewport_width: ctx.viewport_width,
      viewport_height: ctx.viewport_height,
      stretch_width: false,
      stretch_height: false,
    }
    // Use dispatch for flex/grid/table elements, block layout for others
    let @node.DispatchFn(dispatch_fn) = dispatch
    let child_inner = match child_style.display {
      @types.Flex
      | @types.InlineFlex
      | @types.Grid
      | @types.InlineGrid
      | @types.Table
      | @types.InlineTable => dispatch_fn(child_for_layout, child_ctx, dispatch)
      _ => {
        let raw = compute_with_collapse(
          child_for_layout, child_ctx, warnings, dispatch,
        )
        apply_initial_scroll_snap(child_for_layout, raw.layout)
      }
    }

    // Get child dimensions
    let final_width = child_inner.width
    let final_height = child_inner.height

    // Place the float using float context
    let (float_x, float_y) = float_ctx.place_float(
      child_style.float,
      final_width,
      final_height,
      child_margin.left,
      child_margin.right,
      child_margin.top,
      child_margin.bottom,
      start_pos,
    )
    {
      id: child.id,
      x: float_x,
      y: float_y,
      width: final_width,
      height: final_height,
      margin: child_margin,
      padding: child_inner.padding,
      border: child_inner.border,
      overflow_x: child.style.overflow_x,
      overflow_y: child.style.overflow_y,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: child_inner.children,
      text: child.text,
    }
  }

  // Track escaped margins for parent
  let mut escaped_top : Double? = None
  let mut escaped_bottom : Double? = None

  // Check for vertical writing mode - affects block flow direction
  let is_vertical_writing = style.writing_mode.is_vertical()
  let is_block_rtl = style.writing_mode.is_block_rtl()

  // Track positions after each flow child (for absolute static positioning)
  // In horizontal mode: tracks y position. In vertical mode: tracks x position.
  let flow_y_positions : Array[Double] = []
  let mut current_pos = 0.0 // y in horizontal, x in vertical
  let mut prev_margin_end = 0.0
  let mut leading_collapse_chain_active = false
  let mut leading_chain_margin = 0.0
  let mut next_float_index = 0
  let float_start_positions : Map[Int, Double] = {}
  let mut vertical_multicol_simple_width_override : Double? = None
  fn has_inline_float_only_wrapper() -> Bool {
    for i = 0; i < flow_nodes.length() && i < flow_styles.length(); i = i + 1 {
      let child_node = flow_nodes[i]
      let child_style = flow_styles[i]
      if child_node.id == "br" || child_node.id.has_prefix("#text") {
        continue
      }
      if not(is_inline_flow_participant(child_node, child_style)) {
        continue
      }
      if source_children_only_contribute_floats(child_node.children) {
        return true
      }
    }
    false
  }
  let enable_float_inline_run = not(is_vertical_writing) &&
    (float_nodes.length() > 0 || has_inline_float_only_wrapper())
  let mut inline_run_active = false
  let mut inline_run_x = 0.0
  let mut inline_run_height = 0.0
  let mut inline_run_align_offset = 0.0
  let mut inline_run_trailing_whitespace_adjust = 0.0
  fn reset_inline_run_state() -> Unit {
    inline_run_active = false
    inline_run_x = 0.0
    inline_run_height = 0.0
    inline_run_align_offset = 0.0
    inline_run_trailing_whitespace_adjust = 0.0
    prev_margin_end = 0.0
  }
  fn flush_inline_run_state() -> Unit {
    current_pos = current_pos + inline_run_height
    reset_inline_run_state()
  }
  fn current_float_start_pos() -> Double {
    if inline_run_active {
      current_pos + inline_run_height
    } else {
      current_pos
    }
  }
  fn resolve_vertical_float_whitespace_adjust(flow_index : Int) -> Double {
    if not(is_vertical_writing) || flow_index <= 0 {
      return 0.0
    }
    let prev_node = flow_nodes[flow_index - 1]
    let prev_style = flow_styles[flow_index - 1]
    if text_ends_with_collapsible_flow_whitespace(prev_node) {
      if prev_style.line_height > 0.0 {
        prev_style.line_height
      } else if style.line_height > 0.0 {
        style.line_height
      } else {
        0.0
      }
    } else {
      0.0
    }
  }
  fn resolve_inline_run_line_height(
    inline_item_height : Double,
    child_line_height : Double,
  ) -> Double {
    let mut line_height = if inline_run_height > inline_item_height {
      inline_run_height
    } else {
      inline_item_height
    }
    let inline_strut_height = if child_line_height > 0.0 {
      child_line_height
    } else if style.line_height > 0.0 {
      style.line_height
    } else {
      inline_item_height
    }
    if inline_strut_height > line_height {
      line_height = inline_strut_height
    }
    line_height
  }
  fn extend_inline_run(
    inline_advance : Double,
    inline_item_height : Double,
  ) -> Unit {
    inline_run_x = inline_run_x + inline_advance
    if inline_item_height > inline_run_height {
      inline_run_height = inline_item_height
    }
    inline_run_active = true
  }
  let default_text_align = style.text_align == @style.TextAlign::Start
  let multicol_height_limit = if multicol_enabled {
    estimate_multicol_column_height_limit(
      child_available_height,
      flow_children,
      flow_styles,
      flow_nodes,
      multicol_column_count,
      style.column_fill,
    )
  } else {
    None
  }
  let multicol_fragment_contained = multicol_enabled &&
    (
      style.column_fill == @style.ColumnFill::Balance ||
      style.contain.inline_size ||
      style.contain.size
    ) &&
    multicol_column_count > 1
  for i = 0; i < flow_children.length(); i = i + 1 {
    let child_result = flow_children[i]
    let mut child_layout = child_result.layout
    let mut child_collapsed = child_result.collapsed
    let is_first = i == 0
    let is_last = i == flow_children.length() - 1
    let child_style = flow_styles[i]
    let child_node = flow_nodes[i]
    while next_float_index < float_nodes.length() &&
          float_indices[next_float_index] < flow_indices[i] {
      let float_start_pos = if inline_run_active {
        let raw_start = current_float_start_pos()
        let adjusted_start = if inline_run_trailing_whitespace_adjust > 0.0 &&
          raw_start > inline_run_trailing_whitespace_adjust {
          raw_start - inline_run_trailing_whitespace_adjust
        } else {
          raw_start
        }
        flush_inline_run_state()
        adjusted_start
      } else {
        let raw_start = current_float_start_pos()
        let adjust = resolve_vertical_float_whitespace_adjust(i)
        if adjust > 0.0 && raw_start > adjust {
          raw_start - adjust
        } else {
          raw_start
        }
      }
      let float_layout = place_float_layout(next_float_index, float_start_pos)
      float_layouts.push(float_layout)
      layout_map[float_indices[next_float_index]] = float_layout
      float_start_positions[float_indices[next_float_index]] = float_start_pos
      next_float_index = next_float_index + 1
    }
    if multicol_enabled {
      let (
        next_current_pos,
        next_prev_margin_end,
        next_inline_run_active,
        next_inline_run_x,
        next_inline_run_height,
        next_inline_run_align_offset,
      ) = process_multicol_flow_child(
        i, current_pos, prev_margin_end, inline_run_active, inline_run_x, inline_run_height,
        inline_run_align_offset, padding, border, style, flow_children, flow_styles,
        flow_nodes, flow_indices, multicol_column_count, multicol_column_width, multicol_column_gap,
        multicol_height_limit, multicol_fragment_contained, default_text_align, layout_map,
        flow_y_positions,
      )
      current_pos = next_current_pos
      prev_margin_end = next_prev_margin_end
      inline_run_active = next_inline_run_active
      inline_run_x = next_inline_run_x
      inline_run_height = next_inline_run_height
      inline_run_align_offset = next_inline_run_align_offset
      continue
    }
    let is_inline_float_only_wrapper = not(is_vertical_writing) &&
      @inline.is_inline_level(child_style.display) &&
      child_node.id != "br" &&
      not(child_node.id.has_prefix("#text")) &&
      source_children_only_contribute_floats(child_node.children)
    let participates_in_inline_run = enable_float_inline_run &&
      (
        is_inline_flow_participant(child_node, child_style) ||
        is_inline_float_only_wrapper
      ) &&
      child_style.position != @types.Absolute &&
      child_style.position != @types.Fixed
    if not(participates_in_inline_run) && inline_run_active {
      flush_inline_run_state()
    }
    if participates_in_inline_run &&
      child_node.id != "br" &&
      inline_run_x == 0.0 {
      let line_width = estimate_multicol_inline_line_width(
        i, flow_children, flow_styles, flow_nodes, child_available_width,
      )
      inline_run_align_offset = if default_text_align {
        0.0
      } else {
        resolve_text_align_offset(
          style.text_align,
          style.direction,
          child_available_width,
          line_width,
        )
      }
    }

    let mut deferred_clear_y = current_pos
    let defer_inline_clear = child_node.id == "br" &&
      child_style.display == @types.Inline &&
      child_style.clear != @types.Clear::None
    // Handle clear property - move current_pos below cleared floats
    match child_style.clear {
      @types.Clear::Left | @types.Clear::Right | @types.Clear::Both => {
        let clear_y = float_ctx.get_clear_y(child_style.clear, current_pos)
        if defer_inline_clear {
          deferred_clear_y = clear_y
        } else if clear_y > current_pos {
          current_pos = clear_y
          prev_margin_end = 0.0 // Reset margin collapse after clear
        }
      }
      @types.Clear::None => ()
    }

    // Get effective margins (including any that escaped from grandchildren)
    let effective_margin_top = match child_collapsed.top {
      Some(escaped) => collapse_margins(child_layout.margin.top, escaped)
      None => child_layout.margin.top
    }
    let effective_margin_bottom = match child_collapsed.bottom {
      Some(escaped) => collapse_margins(child_layout.margin.bottom, escaped)
      None => child_layout.margin.bottom
    }

    let child_establishes_bfc = block_flow_establishes_bfc(child_style)
    if not(is_vertical_writing) &&
      child_establishes_bfc &&
      float_ctx.has_floats() &&
      not(participates_in_inline_run) &&
      child_style.position != @types.Absolute &&
      child_style.position != @types.Fixed {
      let probe_height = if child_layout.height > 0.0 {
        child_layout.height
      } else if style.line_height > 0.0 {
        style.line_height
      } else {
        1.0
      }
      let probe_y = if current_pos > 0.0 { current_pos } else { 0.0 }
      let (left_edge, right_edge) = float_ctx.get_available_space(
        probe_y, probe_height,
      )
      let constrained_parent_width = right_edge - left_edge
      if constrained_parent_width > 0.0 &&
        constrained_parent_width + 0.01 < flow_child_available_width {
        let child_height_for_ctx : Double? = match child_style.display {
          @types.Flex
          | @types.InlineFlex
          | @types.Grid
          | @types.InlineGrid
          | @types.Table
          | @types.InlineTable =>
            match child_style.height {
              @types.Auto =>
                if child_style.writing_mode.is_vertical() {
                  child_available_height
                } else {
                  None
                }
              _ => child_available_height
            }
          _ => child_available_height
        }
        let child_ctx : @types.LayoutContext = {
          available_width: constrained_parent_width,
          available_height: child_height_for_ctx,
          sizing_mode: @types.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        match child_style.display {
          @types.Flex
          | @types.InlineFlex
          | @types.Grid
          | @types.InlineGrid
          | @types.Table
          | @types.InlineTable => {
            let @node.DispatchFn(dispatch_fn) = dispatch
            child_layout = dispatch_fn(child_node, child_ctx, dispatch)
            child_collapsed = { top: None, bottom: None }
          }
          _ => {
            let raw = compute_with_collapse(
              child_node, child_ctx, warnings, dispatch,
            )
            child_layout = apply_initial_scroll_snap(child_node, raw.layout)
            child_collapsed = raw.collapsed
          }
        }
      }
    }

    // Check if child collapses through
    // Blocked by: height, border, padding, BFC-establishing properties, aspect_ratio
    let child_has_aspect_ratio = match child_style.aspect_ratio {
      Some(_) => true
      None => false
    }
    // For display: contents, use children's height for collapse check
    let effective_height_for_collapse = if child_style.display ==
      @types.Contents {
      get_children_total_height(child_layout.children)
    } else {
      child_layout.height
    }
    let collapses_through = can_collapse_through(
        effective_height_for_collapse,
        child_layout.border,
        child_layout.padding,
      ) &&
      not(child_establishes_bfc) &&
      not(child_has_aspect_ratio)

    // BFC-establishing normal-flow blocks are shifted downward until their
    // margin box can fit alongside preceding floats.
    let mut float_clearance_offset = 0.0
    if not(is_vertical_writing) &&
      child_establishes_bfc &&
      float_ctx.has_floats() &&
      child_style.position != @types.Absolute &&
      child_style.position != @types.Fixed {
      let required_width = child_layout.width +
        child_layout.margin.left +
        child_layout.margin.right
      let required_height = child_layout.height +
        effective_margin_top +
        effective_margin_bottom
      let start_y = @types.max(0.0, current_pos)
      let clear_to_y = float_ctx.find_y_with_space(
        start_y,
        @types.max(0.0, required_width),
        @types.max(0.0, required_height),
      )
      if clear_to_y > start_y {
        float_clearance_offset = clear_to_y - start_y
      }
    }

    // Calculate position and track escaping margins
    let child_y : Double = if participates_in_inline_run {
      current_pos + padding.top + border.top
    } else if is_first && current_pos <= 0.01 {
      if can_collapse_top {
        // First child margin escapes to parent
        if collapses_through {
          leading_collapse_chain_active = true
          leading_chain_margin = collapse_margins(
            effective_margin_top, effective_margin_bottom,
          )
          escaped_top = Some(leading_chain_margin)
          prev_margin_end = effective_margin_bottom
        } else {
          escaped_top = Some(effective_margin_top)
          prev_margin_end = effective_margin_bottom
        }
        padding.top + border.top // Child at y=0 relative to content
      } else {
        // Margin blocked by border/padding
        if collapses_through {
          // Empty first child with collapsing margins contributes only the
          // collapsed margin amount, not top+bottom separately.
          prev_margin_end = collapse_margins(
            effective_margin_top, effective_margin_bottom,
          )
          current_pos = 0.0
        } else {
          prev_margin_end = effective_margin_bottom
          current_pos = effective_margin_top
        }
        effective_margin_top + padding.top + border.top
      }
    } else if leading_collapse_chain_active {
      // Leading self-collapsing chain keeps collapsing into parent block-start.
      let collapsed_with_chain = collapse_margins(
        leading_chain_margin, effective_margin_top,
      )
      if collapses_through {
        leading_chain_margin = collapse_margins(
          collapsed_with_chain, effective_margin_bottom,
        )
      } else {
        leading_chain_margin = collapsed_with_chain
      }
      escaped_top = Some(leading_chain_margin)
      prev_margin_end = effective_margin_bottom
      padding.top + border.top
      // Sibling collapse
    } else if collapses_through {
      // Collapse-through: element positioned after collapsed margin gap
      let collapsed_for_position = collapse_margins(
        prev_margin_end, effective_margin_top,
      )
      let all_collapsed = collapse_margins(
        collapsed_for_position, effective_margin_bottom,
      )
      prev_margin_end = all_collapsed
      // Position at the same y as where next sibling would be
      current_pos + collapsed_for_position + padding.top + border.top
    } else {
      let collapsed = collapse_margins(prev_margin_end, effective_margin_top)
      current_pos = current_pos + collapsed
      prev_margin_end = effective_margin_bottom
      current_pos + padding.top + border.top
    }

    // Calculate x position considering margin auto
    let (float_inline_offset, float_inline_constrained) = if not(
        is_vertical_writing,
      ) &&
      float_ctx.has_floats() &&
      (@inline.is_inline_level(child_style.display) || child_establishes_bfc) &&
      child_style.position != @types.Absolute &&
      child_style.position != @types.Fixed {
      let probe_height = if child_layout.height > 0.0 {
        child_layout.height
      } else if style.line_height > 0.0 {
        style.line_height
      } else {
        1.0
      }
      let probe_height = if child_establishes_bfc {
        probe_height + effective_margin_top + effective_margin_bottom
      } else {
        probe_height
      }
      let probe_y = child_y - padding.top - border.top + float_clearance_offset
      let probe_y = if probe_y > 0.0 { probe_y } else { 0.0 }
      let (left_edge, right_edge) = float_ctx.get_available_space(
        probe_y, probe_height,
      )
      let base_left = padding.left + border.left
      let base_right = base_left + child_available_width
      let constrained = left_edge > base_left || right_edge < base_right
      let inline_offset = if left_edge > base_left {
        left_edge - base_left
      } else {
        0.0
      }
      (inline_offset, constrained)
    } else {
      (0.0, false)
    }
    let (float_intrusion_left, float_intrusion_right) = if not(
        is_vertical_writing,
      ) &&
      float_ctx.has_floats() &&
      not(@inline.is_inline_level(child_style.display)) &&
      not(child_establishes_bfc) &&
      child_style.position != @types.Absolute &&
      child_style.position != @types.Fixed {
      let probe_height = if child_layout.height > 0.0 {
        child_layout.height
      } else if style.line_height > 0.0 {
        style.line_height
      } else {
        1.0
      }
      let probe_y = child_y - padding.top - border.top + float_clearance_offset
      let probe_y = if probe_y > 0.0 { probe_y } else { 0.0 }
      let (left_edge, right_edge) = float_ctx.get_available_space(
        probe_y, probe_height,
      )
      let base_left = padding.left + border.left
      let base_right = base_left + child_available_width
      let intrusion_left = if left_edge > base_left {
        left_edge - base_left
      } else {
        0.0
      }
      let intrusion_right = if right_edge < base_right {
        base_right - right_edge
      } else {
        0.0
      }
      (intrusion_left, intrusion_right)
    } else {
      (0.0, 0.0)
    }
    let inline_run_offset = if participates_in_inline_run {
      inline_run_align_offset + inline_run_x
    } else {
      0.0
    }
    let explicit_justify_self = match child_style.justify_self {
      @types.AlignSelf::End => @types.Alignment::End
      @types.AlignSelf::Center => @types.Alignment::Center
      @types.AlignSelf::Stretch => @types.Alignment::Stretch
      @types.AlignSelf::Start
      | @types.AlignSelf::Auto
      | @types.AlignSelf::Baseline => @types.Alignment::Start
    }
    let mut positioned_child_width = child_layout.width
    if not(is_vertical_writing) &&
      not(participates_in_inline_run) &&
      child_style.position != @types.Absolute &&
      child_style.position != @types.Fixed &&
      explicit_justify_self == @types.Alignment::Stretch {
      let stretch_width = child_available_width -
        child_layout.margin.left -
        child_layout.margin.right
      if stretch_width > 0.0 {
        positioned_child_width = stretch_width
      } else {
        positioned_child_width = 0.0
      }
    }
    let child_x = {
      let margin_left_auto = match child_style.margin.left {
        @types.Auto => true
        _ => false
      }
      let margin_right_auto = match child_style.margin.right {
        @types.Auto => true
        _ => false
      }
      // Available space for auto margins
      let available = child_available_width -
        positioned_child_width -
        child_layout.margin.left -
        child_layout.margin.right
      if margin_left_auto && margin_right_auto {
        // Both auto: center
        let auto_margin = if available > 0.0 { available / 2.0 } else { 0.0 }
        auto_margin +
        padding.left +
        border.left +
        float_inline_offset +
        inline_run_offset
      } else if margin_left_auto {
        // Only left auto: push to right
        let auto_margin = if available > 0.0 { available } else { 0.0 }
        auto_margin +
        padding.left +
        border.left +
        float_inline_offset +
        inline_run_offset
      } else {
        // No auto or only right auto: use left margin
        let base_x = child_layout.margin.left +
          padding.left +
          border.left +
          float_inline_offset +
          inline_run_offset
        let self_align_offset = if not(is_vertical_writing) &&
          not(participates_in_inline_run) &&
          child_style.position != @types.Absolute &&
          child_style.position != @types.Fixed {
          let free_space = child_available_width -
            positioned_child_width -
            child_layout.margin.left -
            child_layout.margin.right
          if free_space <= 0.0 {
            0.0
          } else {
            match explicit_justify_self {
              @types.Alignment::End => free_space
              @types.Alignment::Center => free_space / 2.0
              @types.Alignment::Start | @types.Alignment::Stretch => 0.0
              _ => 0.0
            }
          }
        } else {
          0.0
        }
        base_x + self_align_offset
      }
    }

    // Relative positioning offsets apply only to position:relative.
    let (raw_final_x, raw_final_y) = if child_style.position == @types.Relative {
      let height_context = match child_available_height {
        Some(h) => Some(h + padding.vertical_sum() + border.vertical_sum())
        None =>
          if style.position == @types.Relative {
            ctx.available_height
          } else {
            None
          }
      }
      let (x_offset, y_offset) = @core.resolve_relative_inset_offsets(
        child_style.inset,
        box_width,
        height_context,
      )
      (child_x + x_offset, child_y + y_offset + float_clearance_offset)
    } else {
      (child_x, child_y + float_clearance_offset)
    }
    let inline_br_prefers_baseline_offset = if participates_in_inline_run &&
      child_node.id == "br" &&
      i > 0 {
      let prev_style = flow_styles[i - 1]
      match prev_style.vertical_align {
        @style.VerticalAlign::Top | @style.VerticalAlign::TextTop => false
        _ => true
      }
    } else {
      false
    }
    let inline_br_offset = if participates_in_inline_run &&
      child_node.id == "br" &&
      inline_run_height > child_layout.height &&
      (float_inline_constrained || inline_br_prefers_baseline_offset) {
      inline_run_height - child_layout.height
    } else {
      0.0
    }
    let final_x = raw_final_x
    let final_y = raw_final_y + inline_br_offset

    // Position child and store in map with original index
    // In vertical writing mode, swap x/y positioning
    let (positioned_x, positioned_y) = if is_vertical_writing {
      // In vertical mode: blocks flow horizontally (x advances), y is fixed
      // child_y was calculated as block position (should be x), child_x as cross position (should be y)
      let x_from_left = final_y -
        padding.top -
        border.top +
        padding.left +
        border.left
      let final_x_pos = if is_block_rtl {
        // For vertical-rl: position from right side of container
        box_width - x_from_left - positioned_child_width
      } else {
        // For vertical-lr: position from left side (normal)
        x_from_left
      }
      let margin_top_auto = match child_style.margin.top {
        @types.Auto => true
        _ => false
      }
      let margin_bottom_auto = match child_style.margin.bottom {
        @types.Auto => true
        _ => false
      }
      let parent_cross_size = match child_available_height {
        Some(h) => h
        None => 0.0
      }
      let mut cross_y = child_layout.margin.top + padding.top + border.top
      if margin_top_auto || margin_bottom_auto {
        let free_cross = parent_cross_size -
          child_layout.height -
          child_layout.margin.top -
          child_layout.margin.bottom
        if free_cross > 0.0 {
          let extra_top = if margin_top_auto && margin_bottom_auto {
            free_cross / 2.0
          } else if margin_top_auto {
            free_cross
          } else {
            0.0
          }
          cross_y = cross_y + extra_top
        }
      }
      (final_x_pos, cross_y)
    } else {
      (final_x, final_y)
    }
    let is_first_legend_in_fieldset = not(is_vertical_writing) &&
      i == 0 &&
      node.id.has_prefix("fieldset") &&
      child_layout.id.has_prefix("legend")
    let legend_border_overlay_y = if is_first_legend_in_fieldset {
      let overlay = (border.top - child_layout.height) / 2.0
      if overlay > 0.0 {
        overlay
      } else {
        0.0
      }
    } else {
      positioned_y
    }
    let adjusted_layout = adjust_inline_span_float_quirk(
      { ..child_layout, x: positioned_x, width: positioned_child_width },
      child_node,
      is_vertical_writing,
    )
    let has_partial_float_intrusion = (
        float_intrusion_left > 0.0 || float_intrusion_right > 0.0
      ) &&
      float_intrusion_left + float_intrusion_right < child_available_width
    let adjusted_layout = if has_partial_float_intrusion {
      shift_direct_float_children_for_intrusion(
        adjusted_layout, child_node, float_intrusion_left, float_intrusion_right,
      )
    } else {
      adjusted_layout
    }
    let is_display_contents = child_style.display == @types.Contents
    let no_principal = is_no_principal_table_internal_display(
      child_style.display,
    )
    let parent_containment_abs_cb = containment_applies(style.display) &&
      (style.contain.layout || style.contain.paint)
    let establishes_abs_cb = establishes_abs_containing_block(
      child_style,
      child_style.display,
    )
    let should_offset_for_containment = parent_containment_abs_cb &&
      not(establishes_abs_cb) &&
      (positioned_x != 0.0 || legend_border_overlay_y != 0.0)
    let parent_is_abs_cb = establishes_abs_containing_block(
      style,
      style.display,
    )
    let should_offset_no_principal_abs = no_principal &&
      parent_is_abs_cb &&
      not(establishes_abs_cb) &&
      (positioned_x != 0.0 || legend_border_overlay_y != 0.0)
    let adjusted_for_no_principal = if is_display_contents {
      // display: contents descendants are already laid out in the local flow
      // coordinate space; additional subtree shifting double-counts offsets.
      adjusted_layout
    } else if should_offset_for_containment {
      shift_out_of_flow_descendants(
        adjusted_layout,
        child_node,
        -positioned_x,
        -legend_border_overlay_y,
        true,
        false,
      )
    } else if should_offset_no_principal_abs {
      // No-principal table-internal elements (e.g. table-row-group) don't generate
      // a principal box. Their absolute descendants should be positioned relative to
      // the actual containing block (this parent), not the no-principal element.
      // Shift by the negative of the no-principal element's flow position.
      shift_out_of_flow_descendants(
        adjusted_layout,
        child_node,
        -positioned_x,
        -legend_border_overlay_y,
        true,
        false,
      )
    } else {
      adjusted_layout
    }
    let positioned_layout_x = if no_principal {
      0.0
    } else {
      adjusted_for_no_principal.x
    }
    let positioned_layout_y = if no_principal {
      0.0
    } else {
      legend_border_overlay_y
    }
    let positioned_layout : @types.Layout = {
      id: adjusted_for_no_principal.id,
      x: positioned_layout_x,
      y: positioned_layout_y,
      width: adjusted_for_no_principal.width,
      height: adjusted_for_no_principal.height,
      margin: adjusted_for_no_principal.margin,
      padding: adjusted_for_no_principal.padding,
      border: adjusted_for_no_principal.border,
      overflow_x: adjusted_for_no_principal.overflow_x,
      overflow_y: adjusted_for_no_principal.overflow_y,
      scroll_width: adjusted_for_no_principal.scroll_width,
      scroll_height: adjusted_for_no_principal.scroll_height,
      children: adjusted_for_no_principal.children,
      text: adjusted_for_no_principal.text,
    }
    layout_map[flow_indices[i]] = positioned_layout

    if participates_in_inline_run {
      let inline_descendant_height = get_inflow_children_flow_extent_height(
        child_node,
        child_layout.children,
      )
      let inline_visual_height = if child_style.contain.size {
        child_layout.height
      } else if inline_descendant_height > child_layout.height {
        inline_descendant_height
      } else {
        child_layout.height
      }
      let inline_item_height = inline_visual_height +
        child_layout.margin.top +
        child_layout.margin.bottom
      if child_node.id == "br" {
        let line_height = resolve_inline_run_line_height(
          inline_item_height,
          child_style.line_height,
        )
        if line_height > 0.0 {
          current_pos = current_pos + line_height
        }
        reset_inline_run_state()
      } else {
        let inline_advance = child_layout.width +
          child_layout.margin.left +
          child_layout.margin.right
        extend_inline_run(inline_advance, inline_item_height)
        if text_ends_with_collapsible_flow_whitespace(child_node) {
          inline_run_trailing_whitespace_adjust = if child_style.line_height >
            0.0 {
            child_style.line_height
          } else if style.line_height > 0.0 {
            style.line_height
          } else {
            0.0
          }
        } else {
          inline_run_trailing_whitespace_adjust = 0.0
        }
      }
    } else {
      // Update current_pos (only if not collapsing through)
      if not(collapses_through) {
        // For display: contents, use children's total height instead of element's height (which is 0)
        // In vertical mode, we advance by width instead of height
        let effective_size = if child_style.display == @types.Contents {
          if is_vertical_writing {
            get_children_flow_extent_width(child_layout.children)
          } else {
            get_inflow_children_flow_extent_height(
              child_node,
              child_layout.children,
            )
          }
        } else if is_vertical_writing {
          child_layout.width
        } else {
          child_layout.height
        }
        if is_first && can_collapse_top {
          current_pos = effective_size
        } else if is_first {
          current_pos = effective_margin_top + effective_size
        } else {
          current_pos = current_pos + effective_size
        }
      }
      if leading_collapse_chain_active && not(collapses_through) {
        leading_collapse_chain_active = false
      }
    }

    // Float clearance shifts the flow cursor even when the element collapses
    // through and contributes no own block-size.
    if float_clearance_offset > 0.0 {
      current_pos = current_pos + float_clearance_offset
    }
    if defer_inline_clear && deferred_clear_y > current_pos {
      current_pos = deferred_clear_y
      prev_margin_end = 0.0
    }

    // Record y position after this flow child (for absolute static positioning)
    flow_y_positions.push(current_pos)

    // Handle last child's bottom margin escape
    if is_last && can_collapse_bottom {
      escaped_bottom = Some(prev_margin_end)
    }
  }
  while next_float_index < float_nodes.length() {
    let float_start_pos = if inline_run_active {
      let raw_start = current_float_start_pos()
      let adjusted_start = if inline_run_trailing_whitespace_adjust > 0.0 &&
        raw_start > inline_run_trailing_whitespace_adjust {
        raw_start - inline_run_trailing_whitespace_adjust
      } else {
        raw_start
      }
      flush_inline_run_state()
      adjusted_start
    } else {
      let raw_start = current_float_start_pos()
      let adjust = resolve_vertical_float_whitespace_adjust(
        flow_children.length(),
      )
      if adjust > 0.0 && raw_start > adjust {
        raw_start - adjust
      } else {
        raw_start
      }
    }
    let float_layout = place_float_layout(next_float_index, float_start_pos)
    float_layouts.push(float_layout)
    layout_map[float_indices[next_float_index]] = float_layout
    float_start_positions[float_indices[next_float_index]] = float_start_pos
    next_float_index = next_float_index + 1
  }
  if inline_run_active {
    flush_inline_run_state()
  }

  if multicol_enabled {
    match multicol_height_limit {
      Some(limit) if limit > 0.0 =>
        for idx in float_indices {
          match (float_start_positions.get(idx), layout_map.get(idx)) {
            (Some(start_pos), Some(float_layout)) => {
              let absolute_col = (start_pos / limit).to_int()
              let row_index = if multicol_fragment_contained {
                absolute_col / multicol_column_count
              } else {
                0
              }
              let column_index = if multicol_fragment_contained {
                absolute_col % multicol_column_count
              } else {
                absolute_col
              }
              let local_y = start_pos - absolute_col.to_double() * limit
              layout_map[idx] = {
                ..float_layout,
                x: column_index.to_double() *
                (multicol_column_width + multicol_column_gap) +
                float_layout.x,
                y: row_index.to_double() * limit + local_y,
              }
            }
            _ => ()
          }
        }
      _ => ()
    }
  }

  if multicol_enabled &&
    is_vertical_writing &&
    float_indices.length() == 0 &&
    flow_children.length() > 0 {
    let mut simple_vertical_multicol = true
    let mut item_width = 0.0
    for i = 0; i < flow_children.length() && i < flow_styles.length(); i = i + 1 {
      let child_style = flow_styles[i]
      let child_layout = flow_children[i].layout
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed ||
        child_style.float != @types.Float::None ||
        @inline.is_inline_level(child_style.display) ||
        child_layout.children.length() > 0 {
        simple_vertical_multicol = false
        break
      }
      let candidate_width = match child_style.min_width {
        @types.Length(v) => v
        _ => 0.0
      }
      if candidate_width <= 0.0 {
        simple_vertical_multicol = false
        break
      }
      if candidate_width > item_width {
        item_width = candidate_width
      }
    }
    let track_extent = match style.height {
      @types.Length(h) =>
        if multicol_column_count > 0 {
          let total_gaps = multicol_column_gap *
            (multicol_column_count - 1).to_double()
          if h > total_gaps {
            (h - total_gaps) / multicol_column_count.to_double()
          } else {
            0.0
          }
        } else {
          0.0
        }
      _ => 0.0
    }
    if simple_vertical_multicol && item_width > 0.0 && track_extent > 0.0 {
      for i = 0
          i < flow_indices.length() && i < flow_children.length()
          i = i + 1 {
        let child_layout = flow_children[i].layout
        layout_map[flow_indices[i]] = {
          ..child_layout,
          x: 0.0,
          y: i.to_double() * (track_extent + multicol_column_gap),
          width: item_width,
          height: track_extent,
        }
      }
      vertical_multicol_simple_width_override = Some(item_width)
    }
  }

  // Replace anonymous-table placeholders with projected original children.
  for run_override in table_run_overrides {
    if run_override.flow_indices.length() == 0 {
      continue
    }
    let anchor_index = run_override.flow_indices[0]
    match layout_map.get(anchor_index) {
      Some(anchor_layout) =>
        for i = 0; i < run_override.flow_indices.length(); i = i + 1 {
          let child_index = run_override.flow_indices[i]
          if i < run_override.layouts.length() {
            let projected = run_override.layouts[i]
            layout_map[child_index] = {
              ..projected,
              x: anchor_layout.x + projected.x,
              y: anchor_layout.y + projected.y,
            }
          } else {
            layout_map[child_index] = create_zero_layout(
              node.children[child_index],
            )
          }
        }
      None => ()
    }
  }

  // Calculate content height
  // If this is a BFC (overflow is not visible, or display:flow-root), include float heights
  let float_height = if establishes_bfc {
    // BFC contains floats - include their height
    float_ctx.get_float_height()
  } else {
    0.0
  }
  fn estimate_multicol_rendered_height() -> Double {
    let mut max_bottom = 0.0
    for i = 0; i < flow_indices.length() && i < flow_styles.length(); i = i + 1 {
      match layout_map.get(flow_indices[i]) {
        Some(positioned_layout) => {
          let child_descendant_height = get_child_descendant_flow_extent_for_auto_height(
            flow_nodes[i],
            positioned_layout,
          )
          let child_visual_height = if child_descendant_height >
            positioned_layout.height {
            child_descendant_height
          } else {
            positioned_layout.height
          }
          let child_bottom = positioned_layout.y +
            child_visual_height +
            positioned_layout.margin.bottom
          if child_bottom > max_bottom {
            max_bottom = child_bottom
          }
        }
        None => ()
      }
    }
    max_bottom
  }
  let flow_content_height = if flow_children.length() == 0 {
    0.0
  } else if multicol_enabled {
    estimate_multicol_rendered_height()
  } else if can_collapse_bottom {
    @types.max(0.0, current_pos) // Don't include escaped bottom margin
  } else {
    @types.max(0.0, current_pos + prev_margin_end)
  }
  let content_height = @types.max(flow_content_height, float_height)
  let mut content_height_for_auto = content_height

  if style.suppresses_intrinsic_height() {
    // Size containment: auto/intrinsic sizing behaves as if the box were empty.
    content_height_for_auto = style.contained_intrinsic_height_fallback()
  } else if is_vertical_writing {
    // In vertical writing mode, block-flow accumulates on x while auto height
    // should use the inline-axis extent (max cross-size of in-flow children).
    let mut inline_cross_extent = 0.0
    for idx in flow_indices {
      match layout_map.get(idx) {
        Some(child_layout) => {
          let extent = child_layout.y +
            child_layout.height +
            child_layout.margin.bottom
          if extent > inline_cross_extent {
            inline_cross_extent = extent
          }
        }
        None => ()
      }
    }
    for idx in float_indices {
      match layout_map.get(idx) {
        Some(child_layout) => {
          let extent = child_layout.y +
            child_layout.height +
            child_layout.margin.bottom
          if extent > inline_cross_extent {
            inline_cross_extent = extent
          }
        }
        None => ()
      }
    }
    content_height_for_auto = @types.max(inline_cross_extent, float_height)
    match vertical_multicol_simple_width_override {
      Some(width_override) => {
        let width_is_auto = match style.width {
          @types.Auto => true
          _ => false
        }
        if width_is_auto {
          box_width = width_override +
            padding.horizontal_sum() +
            border.horizontal_sum()
        }
      }
      None => ()
    }

    // For unconstrained vertical blocks, auto width should follow block-flow extent.
    match vertical_multicol_simple_width_override {
      Some(_) => ()
      None =>
        match (style.width, style.min_width, style.max_width) {
          (@types.Auto, @types.Auto, @types.Auto) => {
            box_width = content_height +
              padding.horizontal_sum() +
              border.horizontal_sum()
            let min_box_width = padding.horizontal_sum() +
              border.horizontal_sum()
            if box_width < min_box_width {
              box_width = min_box_width
            }
          }
          _ => ()
        }
    }
  }

  // Box height - consider aspect_ratio
  let mut box_height = resolve_box_height_from_style(
    style, box_width, content_height_for_auto, parent_height_opt, fill_vertical_auto_height,
    margin, padding, border,
  )

  // Apply min/max height constraints
  box_height = apply_block_height_constraints(
    box_height, style, parent_height, content_height_for_auto, padding, border,
  )
  box_width = adjust_auto_width_from_height_constrained_aspect_ratio(
    style, box_width, box_height, parent_width, padding, border,
  )

  let block_content_alignment_offset = if not(is_vertical_writing) {
    let content_box_height = box_height -
      padding.vertical_sum() -
      border.vertical_sum()
    compute_block_content_alignment_offset(
      style.align_content,
      content_box_height,
      content_height,
    )
  } else {
    0.0
  }
  if block_content_alignment_offset.abs() > 0.0001 {
    for idx in flow_indices {
      match layout_map.get(idx) {
        Some(positioned_layout) =>
          layout_map[idx] = {
            ..positioned_layout,
            y: positioned_layout.y + block_content_alignment_offset,
          }
        None => ()
      }
    }
    for idx in float_indices {
      match layout_map.get(idx) {
        Some(positioned_layout) =>
          layout_map[idx] = {
            ..positioned_layout,
            y: positioned_layout.y + block_content_alignment_offset,
          }
        None => ()
      }
    }
    for i = 0; i < flow_y_positions.length(); i = i + 1 {
      flow_y_positions[i] = flow_y_positions[i] + block_content_alignment_offset
    }
  }

  // Now handle absolute positioned children
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.position == @types.Absolute {
      // Get static y position for this absolute child
      let static_y = match absolute_static_positions.get(i) {
        Some(pos) =>
          // pos is the flow position (0 = before all flow children, 1 = after first, etc.)
          if pos == 0 {
            0.0
          } else if pos <= flow_y_positions.length() {
            flow_y_positions[pos - 1]
          } else {
            content_height
          }
        None => content_height // Default to end of flow content
      }
      let abs_layout = layout_absolute_child(
        child, box_width, box_height, border, static_y, warnings, dispatch,
      )
      layout_map[i] = abs_layout
    }
  }

  place_fixed_children_for_parent(
    node,
    style,
    parent_width,
    if parent_height > 0.0 {
      parent_height
    } else {
      ctx.viewport_height
    },
    box_width,
    box_height,
    border,
    ctx.viewport_width,
    ctx.viewport_height,
    warnings,
    dispatch,
    layout_map,
  )

  if is_vertical_writing && is_block_rtl && float_indices.length() > 0 {
    let final_float_content_width = box_width -
      padding.horizontal_sum() -
      border.horizontal_sum()
    for idx in float_indices {
      match (float_start_positions.get(idx), layout_map.get(idx)) {
        (Some(start_pos), Some(float_layout)) => {
          let child_margin = @types.resolve_rect(
            node.children[idx].style.margin,
            final_float_content_width,
          )
          let outer_x = padding.left +
            border.left +
            final_float_content_width -
            start_pos -
            float_layout.width -
            child_margin.left -
            child_margin.right
          layout_map[idx] = { ..float_layout, x: outer_x + child_margin.left }
        }
        _ => ()
      }
    }
  }

  let child_layouts : Array[@types.Layout] = []
  let mut adjusted_flow_extent = 0.0
  let content_offset_y = padding.top + border.top
  for i = 0; i < node.children.length(); i = i + 1 {
    match layout_map.get(i) {
      Some(raw_layout) => {
        let child_node = node.children[i]
        let adjusted_layout = adjust_float_only_inline_wrapper_for_parent(
          raw_layout, child_node, style, is_vertical_writing, true,
        )
        let child_style = child_node.style
        let skip_out_of_flow = child_style.position == @types.Absolute ||
          child_style.position == @types.Fixed ||
          child_style.float != @types.Float::None
        if not(skip_out_of_flow) {
          let descendant_h = get_child_descendant_flow_extent_for_auto_height(
            child_node, adjusted_layout,
          )
          let child_block = if adjusted_layout.height > descendant_h {
            adjusted_layout.height
          } else {
            descendant_h
          }
          let child_content_y = if adjusted_layout.y > content_offset_y {
            adjusted_layout.y - content_offset_y
          } else {
            0.0
          }
          let extent = child_content_y +
            child_block +
            adjusted_layout.margin.bottom
          if extent > adjusted_flow_extent {
            adjusted_flow_extent = extent
          }
        }
        child_layouts.push(adjusted_layout)
      }
      None => ()
    }
  }
  let adjusted_content_height_for_auto = match style.height {
    @types.Auto =>
      if style.suppresses_intrinsic_height() {
        content_height_for_auto
      } else if adjusted_flow_extent > content_height_for_auto {
        @types.max(adjusted_flow_extent, float_height)
      } else {
        content_height_for_auto
      }
    _ => content_height_for_auto
  }
  if adjusted_content_height_for_auto != content_height_for_auto {
    box_height = resolve_box_height_from_style(
      style, box_width, adjusted_content_height_for_auto, parent_height_opt, fill_vertical_auto_height,
      margin, padding, border,
    )
    box_height = apply_block_height_constraints(
      box_height, style, parent_height, adjusted_content_height_for_auto, padding,
      border,
    )
  }
  // Calculate scroll dimensions
  let (scroll_width, scroll_height) = calculate_scroll_dimensions(
    box_width, box_height, padding, child_layouts,
  )
  let layout : @types.Layout = {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: box_width,
    height: box_height,
    margin,
    padding,
    border,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    scroll_width,
    scroll_height,
    children: child_layouts,
    text: node.text,
  }
  { layout, collapsed: { top: escaped_top, bottom: escaped_bottom } }
}

///|
fn resolve_fixed_inset_offset(
  dim : @types.Dimension,
  available : Double,
) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(p) => available * p
    _ => 0.0
  }
}

///|
fn establishes_fixed_containing_block(style : @style.Style) -> Bool {
  let containment_establishes_cb = containment_applies(style.display) &&
    (style.contain.paint || style.contain.layout)
  containment_establishes_cb || not(style.transform.is_none())
}

///|
fn estimate_self_offset_for_fixed(
  style : @style.Style,
  parent_width : Double,
  parent_height : Double,
) -> (Double, Double) {
  match style.position {
    @types.Absolute | @types.Fixed =>
      (
        resolve_fixed_inset_offset(style.inset.left, parent_width),
        resolve_fixed_inset_offset(style.inset.top, parent_height),
      )
    _ => (0.0, 0.0)
  }
}

///|
fn layout_fixed_child_for_parent(
  child : @node.Node,
  parent_style : @style.Style,
  parent_width : Double,
  parent_height : Double,
  container_width : Double,
  container_height : Double,
  parent_border : @types.Rect[Double],
  viewport_width : Double,
  viewport_height : Double,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  if establishes_fixed_containing_block(parent_style) {
    // Transform/filter/backdrop-filter/perspective/containment establish CB for fixed descendants.
    return layout_absolute_child(
      child, container_width, container_height, parent_border, 0.0, warnings, dispatch,
    )
  }
  let fixed_layout = layout_fixed_child(
    child, viewport_width, viewport_height, warnings, dispatch,
  )
  // Fixed boxes are viewport-relative; convert to parent-relative coordinates.
  let (parent_offset_x, parent_offset_y) = estimate_self_offset_for_fixed(
    parent_style, parent_width, parent_height,
  )
  {
    ..fixed_layout,
    x: fixed_layout.x - parent_offset_x,
    y: fixed_layout.y - parent_offset_y,
  }
}

///|
/// Layout an absolutely positioned child within a block container
fn layout_absolute_child(
  child : @node.Node,
  container_width : Double,
  container_height : Double,
  parent_border : @types.Rect[Double],
  static_y : Double, // Y position where the element would be in normal flow
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let child_style = child.style
  let cb_width = if container_width > parent_border.horizontal_sum() {
    container_width - parent_border.horizontal_sum()
  } else {
    0.0
  }
  let cb_height = if container_height > parent_border.vertical_sum() {
    container_height - parent_border.vertical_sum()
  } else {
    0.0
  }

  // Handle display:none - return zero-sized layout
  if child_style.display == @types.Display::None {
    return @absolute.create_zero_layout(child.id)
  }

  // Use shared absolute module for size calculation
  let params = @absolute.compute_size_params(child_style, cb_width, cb_height)

  // When used size is already resolved for abs/fixed items, passing that value
  // directly as available size would re-resolve percentage widths/heights.
  // Convert used size back to the containing-block basis for nested layout.
  fn nested_basis_width(used_width : Double) -> Double {
    match child_style.width {
      @types.Percent(p) if p > 0.0 => used_width / p
      _ => used_width
    }
  }
  fn nested_basis_height(used_height : Double?) -> Double? {
    match used_height {
      Some(h) =>
        match child_style.height {
          @types.Percent(p) if p > 0.0 => Some(h / p)
          _ => Some(h)
        }
      None => None
    }
  }

  // Apply aspect ratio to calculate missing dimension
  let (initial_width, initial_height) = @types.resolve_dimensions_with_aspect_ratio(
    params.initial_width,
    params.initial_height,
    child_style.aspect_ratio,
    params.min_width,
    params.max_width,
    params.min_height,
    params.max_height,
  )

  fn compute_abs_intrinsic_width(
    width_keyword : @types.Dimension,
    intrinsic_height : Double?,
  ) -> Double {
    let intrinsic_child = @node.Node::with_uid_and_measure(
      child.id,
      child.uid,
      { ..child_style, width: width_keyword },
      child.children,
      child.measure,
      child.text,
    )
    compute_nested_intrinsic(
      intrinsic_child, intrinsic_height, warnings, dispatch,
    ).width
  }

  fn resolve_abs_shrink_to_fit_width(intrinsic_height : Double?) -> Double {
    let preferred_max = compute_abs_intrinsic_width(
      @types.MaxContent,
      intrinsic_height,
    )
    let mut preferred_min = compute_abs_intrinsic_width(
      @types.MinContent,
      intrinsic_height,
    )
    if intrinsic_height is Some(_) &&
      has_percent_sized_replaced_descendant(child) &&
      preferred_max > preferred_min {
      preferred_min = preferred_max
    }
    let available_for_shrink = if cb_width > 0.0 { cb_width } else { 0.0 }
    let mut shrink_to_fit = @types.max(preferred_min, available_for_shrink)
    if shrink_to_fit > preferred_max {
      shrink_to_fit = preferred_max
    }
    if shrink_to_fit < 0.0 {
      0.0
    } else {
      shrink_to_fit
    }
  }

  fn find_percent_axis_aspect_ratio(
    node : @node.Node,
    percent_on_height : Bool,
  ) -> Double? {
    for child in node.children {
      match child.style.aspect_ratio {
        Some(ar) if ar > 0.0 => {
          let has_percent_axis = if percent_on_height {
            match child.style.height {
              @types.Percent(p) => p > 0.0
              _ => false
            }
          } else {
            match child.style.width {
              @types.Percent(p) => p > 0.0
              _ => false
            }
          }
          if has_percent_axis {
            return Some(ar)
          }
        }
        _ => ()
      }
      match find_percent_axis_aspect_ratio(child, percent_on_height) {
        Some(ar) => return Some(ar)
        None => ()
      }
    }
    None
  }

  // Compute intrinsic size if needed, and get child's inner layout
  let (child_width, child_height, child_inner) = match
    (initial_width, initial_height) {
    (Some(w), Some(h)) => {
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        nested_basis_height(Some(h)),
        warnings,
        dispatch,
      )
      (w, h, inner)
    }
    (Some(w), None) => {
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        None,
        warnings,
        dispatch,
      )
      let mut h = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => w / ar
        _ => inner.height
      }
      if h <= 0.0 {
        match find_percent_axis_aspect_ratio(child, false) {
          Some(ar) => h = w / ar
          None => ()
        }
      }
      (w, h, inner)
    }
    (None, Some(h)) => {
      // Width is auto: use shrink-to-fit approach
      let shrink_to_fit_width = resolve_abs_shrink_to_fit_width(Some(h))
      let mut w = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => h * ar
        _ => shrink_to_fit_width
      }
      if w <= 0.0 {
        match find_percent_axis_aspect_ratio(child, true) {
          Some(ar) => w = h * ar
          None => ()
        }
      }
      // Step 2: Re-layout with definite width
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        nested_basis_height(Some(h)),
        warnings,
        dispatch,
      )
      (w, h, inner)
    }
    (None, None) => {
      // Both width and height are auto: use shrink-to-fit approach
      let shrink_to_fit_width = resolve_abs_shrink_to_fit_width(None)
      match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => {
          let w = shrink_to_fit_width
          let h = w / ar
          // Re-layout with definite size
          let inner = compute_nested(
            child,
            nested_basis_width(w),
            nested_basis_height(Some(h)),
            warnings,
            dispatch,
          )
          (w, h, inner)
        }
        _ => {
          // Re-layout with definite width
          let inner = compute_nested(
            child,
            nested_basis_width(shrink_to_fit_width),
            None,
            warnings,
            dispatch,
          )
          (shrink_to_fit_width, inner.height, inner)
        }
      }
    }
  }

  // Calculate actual min/max constraints, handling max-content/min-content
  // For intrinsic sizing, we need to compute the child's intrinsic size first
  let needs_intrinsic = match child_style.max_width {
    @types.MaxContent | @types.MinContent => true
    _ =>
      match child_style.max_height {
        @types.MaxContent | @types.MinContent => true
        _ =>
          match child_style.min_width {
            @types.MaxContent | @types.MinContent => true
            _ =>
              match child_style.min_height {
                @types.MaxContent | @types.MinContent => true
                _ => false
              }
          }
      }
  }
  let intrinsic_size = if needs_intrinsic {
    compute_nested_intrinsic(child, None, warnings, dispatch)
  } else {
    child_inner
  }
  let actual_min_width = match child_style.min_width {
    @types.MaxContent | @types.MinContent | @types.FitContent(_) =>
      intrinsic_size.width
    _ => params.min_width
  }
  let actual_max_width = match child_style.max_width {
    @types.MaxContent | @types.MinContent | @types.FitContent(_) =>
      intrinsic_size.width
    _ => params.max_width
  }
  let actual_min_height = match child_style.min_height {
    @types.MaxContent | @types.MinContent | @types.FitContent(_) =>
      intrinsic_size.height
    _ => params.min_height
  }
  let actual_max_height = match child_style.max_height {
    @types.MaxContent | @types.MinContent | @types.FitContent(_) =>
      intrinsic_size.height
    _ => params.max_height
  }

  // Apply min/max constraints and re-apply aspect ratio
  let (child_width, child_height) = @absolute.apply_constraints_with_aspect_ratio(
    child_width, child_height, child_style, actual_min_width, actual_max_width, actual_min_height,
    actual_max_height,
  )

  // CSS rule: padding+border override explicit size constraints
  let child_padding = @types.resolve_rect(child_style.padding, cb_width)
  let child_border = @types.resolve_rect(child_style.border, cb_width)
  let min_child_width = child_padding.horizontal_sum() +
    child_border.horizontal_sum()
  let min_child_height = child_padding.vertical_sum() +
    child_border.vertical_sum()
  let child_width = if child_width < min_child_width {
    min_child_width
  } else {
    child_width
  }
  let child_height = if child_height < min_child_height {
    min_child_height
  } else {
    child_height
  }

  // Check if margins are Auto (for centering behavior)
  let margin_left_is_auto = @absolute.is_margin_auto(child_style.margin.left)
  let margin_right_is_auto = @absolute.is_margin_auto(child_style.margin.right)
  let margin_top_is_auto = @absolute.is_margin_auto(child_style.margin.top)
  let margin_bottom_is_auto = @absolute.is_margin_auto(
    child_style.margin.bottom,
  )

  // Calculate position
  // Note: For absolute positioning, the containing block is the padding box
  let child_x = match (params.inset_left, params.inset_right) {
    (Some(l), Some(r)) =>
      // Both insets specified
      // Check for margin auto centering behavior
      if margin_left_is_auto && margin_right_is_auto {
        // Both margins auto: try to center the element
        let available = cb_width - l - r - child_width
        if available >= 0.0 {
          // Enough space: center by distributing margins equally
          l + available / 2.0 + parent_border.left
        } else {
          // Not enough space: CSS spec says for LTR, margin-left becomes 0
          // This makes child overflow on the right side
          l + parent_border.left
        }
      } else if margin_left_is_auto {
        // Only left margin auto: push to right
        cb_width - child_width - r - params.margin_right + parent_border.left
      } else if margin_right_is_auto {
        // Only right margin auto: push to left
        l + params.margin_left + parent_border.left
      } else {
        // No auto margins: over-constrained, use left inset
        l + params.margin_left + parent_border.left
      }
    (Some(l), None) => l + params.margin_left + parent_border.left
    (None, Some(r)) =>
      cb_width - child_width - r - params.margin_right - parent_border.right
    (None, None) => params.margin_left + parent_border.left
  }
  let child_y = match (params.inset_top, params.inset_bottom) {
    (Some(t), Some(b)) =>
      // Both insets specified
      // Check for margin auto centering behavior
      if margin_top_is_auto && margin_bottom_is_auto {
        // Both margins auto: try to center the element
        let available = cb_height - t - b - child_height
        if available >= 0.0 {
          // Enough space: center by distributing margins equally
          t + available / 2.0 + parent_border.top
        } else {
          // Not enough space: CSS spec says margin-top becomes 0
          // This makes child overflow on the bottom side
          t + parent_border.top
        }
      } else if margin_top_is_auto {
        // Only top margin auto: push to bottom
        cb_height - child_height - b - params.margin_bottom + parent_border.top
      } else if margin_bottom_is_auto {
        // Only bottom margin auto: push to top
        t + params.margin_top + parent_border.top
      } else {
        // No auto margins: over-constrained, use top inset
        t + params.margin_top + parent_border.top
      }
    (Some(t), None) => t + params.margin_top + parent_border.top
    (None, Some(b)) =>
      cb_height - child_height - b - params.margin_bottom - parent_border.bottom
    (None, None) => static_y + params.margin_top + parent_border.top
  }
  let child_margin = @types.resolve_rect(child_style.margin, cb_width)
  {
    id: child.id,
    x: child_x,
    y: child_y,
    width: child_width,
    height: child_height,
    margin: child_margin,
    padding: child_inner.padding,
    border: child_inner.border,
    overflow_x: child_style.overflow_x,
    overflow_y: child_style.overflow_y,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: child_inner.children,
    text: child.text,
  }
}

///|
/// Layout a fixed-position child (positioned relative to viewport)
fn layout_fixed_child(
  child : @node.Node,
  viewport_width : Double,
  viewport_height : Double,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let child_style = child.style

  // Handle display:none - return zero-sized layout
  if child_style.display == @types.Display::None {
    return @absolute.create_zero_layout(child.id)
  }

  // Use shared absolute module for size calculation with viewport as containing block
  let params = @absolute.compute_size_params(
    child_style, viewport_width, viewport_height,
  )

  fn nested_basis_width(used_width : Double) -> Double {
    match child_style.width {
      @types.Percent(p) if p > 0.0 => used_width / p
      _ => used_width
    }
  }
  fn nested_basis_height(used_height : Double?) -> Double? {
    match used_height {
      Some(h) =>
        match child_style.height {
          @types.Percent(p) if p > 0.0 => Some(h / p)
          _ => Some(h)
        }
      None => None
    }
  }

  // Apply aspect ratio to calculate missing dimension
  let (initial_width, initial_height) = @types.resolve_dimensions_with_aspect_ratio(
    params.initial_width,
    params.initial_height,
    child_style.aspect_ratio,
    params.min_width,
    params.max_width,
    params.min_height,
    params.max_height,
  )

  fn compute_fixed_intrinsic_width(
    width_keyword : @types.Dimension,
    intrinsic_height : Double?,
  ) -> Double {
    let intrinsic_child = @node.Node::with_uid_and_measure(
      child.id,
      child.uid,
      { ..child_style, width: width_keyword },
      child.children,
      child.measure,
      child.text,
    )
    compute_nested_intrinsic(
      intrinsic_child, intrinsic_height, warnings, dispatch,
    ).width
  }

  fn resolve_fixed_shrink_to_fit_width(intrinsic_height : Double?) -> Double {
    let preferred_max = compute_fixed_intrinsic_width(
      @types.MaxContent,
      intrinsic_height,
    )
    let mut preferred_min = compute_fixed_intrinsic_width(
      @types.MinContent,
      intrinsic_height,
    )
    if intrinsic_height is Some(_) &&
      has_percent_sized_replaced_descendant(child) &&
      preferred_max > preferred_min {
      preferred_min = preferred_max
    }
    let available_for_shrink = if viewport_width > 0.0 {
      viewport_width
    } else {
      0.0
    }
    let mut shrink_to_fit = @types.max(preferred_min, available_for_shrink)
    if shrink_to_fit > preferred_max {
      shrink_to_fit = preferred_max
    }
    if shrink_to_fit < 0.0 {
      0.0
    } else {
      shrink_to_fit
    }
  }

  // Compute intrinsic size if needed, and get child's inner layout
  let (child_width, child_height, child_inner) = match
    (initial_width, initial_height) {
    (Some(w), Some(h)) => {
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        nested_basis_height(Some(h)),
        warnings,
        dispatch,
      )
      (w, h, inner)
    }
    (Some(w), None) => {
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        None,
        warnings,
        dispatch,
      )
      let h = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => w / ar
        _ => inner.height
      }
      (w, h, inner)
    }
    (None, Some(h)) => {
      // Width is auto: use shrink-to-fit approach
      let shrink_to_fit_width = resolve_fixed_shrink_to_fit_width(Some(h))
      let w = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => h * ar
        _ => shrink_to_fit_width
      }
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        nested_basis_height(Some(h)),
        warnings,
        dispatch,
      )
      (w, h, inner)
    }
    (None, None) => {
      // Both width and height are auto: use shrink-to-fit approach
      let shrink_to_fit_width = resolve_fixed_shrink_to_fit_width(None)
      match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => {
          let w = shrink_to_fit_width
          let h = w / ar
          let inner = compute_nested(
            child,
            nested_basis_width(w),
            nested_basis_height(Some(h)),
            warnings,
            dispatch,
          )
          (w, h, inner)
        }
        _ => {
          let inner = compute_nested(
            child,
            nested_basis_width(shrink_to_fit_width),
            None,
            warnings,
            dispatch,
          )
          (shrink_to_fit_width, inner.height, inner)
        }
      }
    }
  }

  // Calculate actual min/max constraints, handling max-content/min-content
  let actual_min_width = match child_style.min_width {
    @types.MaxContent | @types.MinContent | @types.FitContent(_) =>
      child_inner.width
    _ => params.min_width
  }
  let actual_max_width = match child_style.max_width {
    @types.MaxContent | @types.MinContent | @types.FitContent(_) =>
      child_inner.width
    _ => params.max_width
  }
  let actual_min_height = match child_style.min_height {
    @types.MaxContent | @types.MinContent | @types.FitContent(_) =>
      child_inner.height
    _ => params.min_height
  }
  let actual_max_height = match child_style.max_height {
    @types.MaxContent | @types.MinContent | @types.FitContent(_) =>
      child_inner.height
    _ => params.max_height
  }

  // Apply min/max constraints and re-apply aspect ratio
  let (child_width, child_height) = @absolute.apply_constraints_with_aspect_ratio(
    child_width, child_height, child_style, actual_min_width, actual_max_width, actual_min_height,
    actual_max_height,
  )

  // CSS rule: padding+border override explicit size constraints
  let child_padding = @types.resolve_rect(child_style.padding, viewport_width)
  let child_border = @types.resolve_rect(child_style.border, viewport_width)
  let min_child_width = child_padding.horizontal_sum() +
    child_border.horizontal_sum()
  let min_child_height = child_padding.vertical_sum() +
    child_border.vertical_sum()
  let child_width = if child_width < min_child_width {
    min_child_width
  } else {
    child_width
  }
  let child_height = if child_height < min_child_height {
    min_child_height
  } else {
    child_height
  }

  // Calculate position relative to viewport (0, 0), including margin:auto behavior
  let (child_x, child_y) = @absolute.compute_position_with_margin_auto(
    params, child_style, child_width, child_height, 0.0, 0.0, viewport_width, viewport_height,
  )
  let child_margin = @types.resolve_rect(child_style.margin, viewport_width)
  {
    id: child.id,
    x: child_x,
    y: child_y,
    width: child_width,
    height: child_height,
    margin: child_margin,
    padding: child_inner.padding,
    border: child_inner.border,
    overflow_x: child_style.overflow_x,
    overflow_y: child_style.overflow_y,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: child_inner.children,
    text: child.text,
  }
}

///|
/// Compute nested children for a block item
fn compute_nested(
  node : @node.Node,
  available_width : Double,
  available_height : Double?,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let style = node.style
  let padding = @types.resolve_rect(style.padding, available_width)
  let border = @types.resolve_rect(style.border, available_width)

  // For leaf nodes, return intrinsic size based on style
  if node.children.length() == 0 {
    // Get intrinsic size from MeasureFunc if available
    let intrinsic = match node.measure {
      Some(mf) => {
        let available_h = available_height.unwrap_or(0.0)
        Some((mf.func)(available_width, available_h))
      }
      None => None
    }

    // Check if explicit size is set, otherwise use intrinsic or fallback
    let mut width = match style.width {
      @types.Length(w) => w
      @types.Percent(p) => available_width * p
      @types.Auto =>
        match intrinsic {
          Some(intr) =>
            intr.max_width + padding.horizontal_sum() + border.horizontal_sum()
          None => padding.horizontal_sum() + border.horizontal_sum()
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        padding.horizontal_sum() + border.horizontal_sum()
    }
    let mut height = match style.height {
      @types.Length(h) => h
      @types.Percent(p) =>
        match available_height {
          Some(ah) => ah * p
          None => padding.vertical_sum() + border.vertical_sum()
        }
      @types.Auto =>
        match intrinsic {
          Some(intr) =>
            intr.max_height + padding.vertical_sum() + border.vertical_sum()
          None => padding.vertical_sum() + border.vertical_sum()
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        padding.vertical_sum() + border.vertical_sum()
    }
    // Leaf boxes with aspect-ratio should derive the auto axis from the definite axis.
    match style.aspect_ratio {
      Some(ratio) if ratio > 0.0 => {
        let width_auto = match style.width {
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => true
          _ => false
        }
        let height_auto = match style.height {
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => true
          _ => false
        }
        if width_auto && not(height_auto) {
          width = height * ratio
        } else if height_auto && not(width_auto) {
          height = width / ratio
        }
      }
      _ => ()
    }
    return {
      id: node.id,
      x: 0.0,
      y: 0.0,
      width,
      height,
      margin: @types.Rect::zero(),
      padding,
      border,
      overflow_x: node.style.overflow_x,
      overflow_y: node.style.overflow_y,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: [],
      text: node.text,
    }
  }

  // For containers, recurse
  let ctx : @types.LayoutContext = {
    available_width,
    available_height,
    sizing_mode: @types.Definite,
    viewport_width: available_width,
    viewport_height: available_height.unwrap_or(0.0),
    stretch_width: false,
    stretch_height: false,
  }
  // Use dispatch for flex/grid containers, block layout for others
  let @node.DispatchFn(dispatch_fn) = dispatch
  match node.style.display {
    @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
      dispatch_fn(node, ctx, dispatch)
    _ => compute_with_collapse(node, ctx, warnings, dispatch).layout
  }
}

///|
/// Compute nested children for intrinsic sizing (MaxContent mode)
/// This is used for shrink-to-fit calculations in absolute positioning
fn compute_nested_intrinsic(
  node : @node.Node,
  available_height : Double?,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let style = node.style
  // Use 0 for percentage resolution in intrinsic sizing
  let padding = @types.resolve_rect(style.padding, 0.0)
  let border = @types.resolve_rect(style.border, 0.0)

  // For leaf nodes, return intrinsic size based on style
  if node.children.length() == 0 {
    // Get intrinsic size from MeasureFunc if available
    let intrinsic = match node.measure {
      Some(mf) => {
        let available_h = available_height.unwrap_or(0.0)
        Some((mf.func)(0.0, available_h))
      }
      None => None
    }

    // For intrinsic sizing, percentage widths resolve to 0
    let mut width = match style.width {
      @types.Length(w) => w
      @types.Percent(_) => 0.0 // Percentage resolves to 0 in intrinsic sizing
      @types.Auto =>
        match intrinsic {
          Some(intr) =>
            intr.max_width + padding.horizontal_sum() + border.horizontal_sum()
          None => padding.horizontal_sum() + border.horizontal_sum()
        }
      @types.MinContent =>
        match intrinsic {
          Some(intr) =>
            intr.min_width + padding.horizontal_sum() + border.horizontal_sum()
          None => padding.horizontal_sum() + border.horizontal_sum()
        }
      @types.MaxContent | @types.FitContent(_) =>
        match intrinsic {
          Some(intr) =>
            intr.max_width + padding.horizontal_sum() + border.horizontal_sum()
          None => padding.horizontal_sum() + border.horizontal_sum()
        }
    }
    let mut height = match style.height {
      @types.Length(h) => h
      @types.Percent(p) =>
        match available_height {
          Some(ah) => ah * p
          None => padding.vertical_sum() + border.vertical_sum()
        }
      @types.Auto =>
        match intrinsic {
          Some(intr) =>
            intr.max_height + padding.vertical_sum() + border.vertical_sum()
          None => padding.vertical_sum() + border.vertical_sum()
        }
      @types.MinContent =>
        match intrinsic {
          Some(intr) =>
            intr.min_height + padding.vertical_sum() + border.vertical_sum()
          None => padding.vertical_sum() + border.vertical_sum()
        }
      @types.MaxContent | @types.FitContent(_) =>
        match intrinsic {
          Some(intr) =>
            intr.max_height + padding.vertical_sum() + border.vertical_sum()
          None => padding.vertical_sum() + border.vertical_sum()
        }
    }
    match style.aspect_ratio {
      Some(ratio) if ratio > 0.0 => {
        let width_auto = match style.width {
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => true
          _ => false
        }
        let height_auto = match style.height {
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => true
          _ => false
        }
        if width_auto && not(height_auto) {
          width = height * ratio
        } else if height_auto && not(width_auto) {
          height = width / ratio
        }
      }
      _ => ()
    }
    return {
      id: node.id,
      x: 0.0,
      y: 0.0,
      width,
      height,
      margin: @types.Rect::zero(),
      padding,
      border,
      overflow_x: node.style.overflow_x,
      overflow_y: node.style.overflow_y,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: [],
      text: node.text,
    }
  }

  // For containers, use MaxContent sizing mode
  let ctx : @types.LayoutContext = {
    available_width: @double.infinity,
    available_height,
    sizing_mode: @types.MaxContent,
    viewport_width: 0.0,
    viewport_height: available_height.unwrap_or(0.0),
    stretch_width: false,
    stretch_height: false,
  }
  // Use dispatch for flex/grid containers, block layout for others
  let @node.DispatchFn(dispatch_fn) = dispatch
  match node.style.display {
    @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
      dispatch_fn(node, ctx, dispatch)
    _ => compute_with_collapse(node, ctx, warnings, dispatch).layout
  }
}

///|
fn contributes_to_no_principal_intrinsic_size(
  child_style : @style.Style,
) -> Bool {
  child_style.position != @types.Absolute &&
  child_style.position != @types.Fixed &&
  child_style.float == @types.Float::None
}
