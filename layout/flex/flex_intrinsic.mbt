// Intrinsic measurement and main-axis size computation for flex items.

///|
fn uses_svg_default_intrinsic_box(node : @node.Node) -> Bool {
  if !@node.str_has_prefix(node.id, "svg") {
    return false
  }
  match (node.style.width, node.style.height) {
    (@types.Length(w), @types.Length(h)) =>
      (w - 300.0).abs() < 0.01 && (h - 150.0).abs() < 0.01
    _ => false
  }
}

///|
fn uses_svg_auto_viewbox_box(node : @node.Node) -> Bool {
  @node.str_has_prefix(node.id, "svg") &&
  node.children.length() == 0 &&
  node.measure is Some(_) &&
  node.style.width == @types.Auto &&
  node.style.height == @types.Auto &&
  node.style.aspect_ratio is Some(_)
}

///|
fn make_flex_intrinsic_probe(
  node : @node.Node,
  is_row : Bool,
  force_auto_main : Bool,
  ignore_auto_cross_constraints : Bool,
) -> @node.Node {
  let style = node.style
  let cross_is_auto = if is_row {
    style.height == @types.Auto
  } else {
    style.width == @types.Auto
  }
  let has_auto_cross_aspect_ratio = match style.aspect_ratio {
    Some(ratio) => ratio > 0.0 && cross_is_auto
    None => false
  }
  let changes_main_size = if force_auto_main {
    if is_row {
      style.width != @types.Auto
    } else {
      style.height != @types.Auto
    }
  } else {
    false
  }
  let resets_main_constraints = if is_row {
    style.min_width != @types.Auto || style.max_width != @types.Auto
  } else {
    style.min_height != @types.Auto || style.max_height != @types.Auto
  }
  let resets_cross_constraints = if ignore_auto_cross_constraints &&
    has_auto_cross_aspect_ratio {
    if is_row {
      style.min_height != @types.Auto || style.max_height != @types.Auto
    } else {
      style.min_width != @types.Auto || style.max_width != @types.Auto
    }
  } else {
    false
  }
  if !changes_main_size && !resets_main_constraints && !resets_cross_constraints {
    return node
  }
  let probe_style : @style.Style = if is_row {
    {
      ..style,
      width: if force_auto_main {
        @types.Auto
      } else {
        style.width
      },
      min_width: @types.Auto,
      max_width: @types.Auto,
      min_height: if ignore_auto_cross_constraints &&
        has_auto_cross_aspect_ratio {
        @types.Auto
      } else {
        style.min_height
      },
      max_height: if ignore_auto_cross_constraints &&
        has_auto_cross_aspect_ratio {
        @types.Auto
      } else {
        style.max_height
      },
    }
  } else {
    {
      ..style,
      height: if force_auto_main {
        @types.Auto
      } else {
        style.height
      },
      min_height: @types.Auto,
      max_height: @types.Auto,
      min_width: if ignore_auto_cross_constraints && has_auto_cross_aspect_ratio {
        @types.Auto
      } else {
        style.min_width
      },
      max_width: if ignore_auto_cross_constraints && has_auto_cross_aspect_ratio {
        @types.Auto
      } else {
        style.max_width
      },
    }
  }
  @node.Node::with_uid_and_measure(
    node.id,
    node.uid,
    probe_style,
    node.children,
    node.measure,
    node.text,
  )
}

///|
fn compute_trivial_leaf_intrinsic_main_box(
  node : @node.Node,
  is_row : Bool,
  available_cross : Double?,
) -> Double? {
  if node.children.length() > 0 {
    return None
  }
  if node.measure is Some(_) || node.text is Some(_) {
    return None
  }
  match node.style.aspect_ratio {
    Some(ratio) if ratio > 0.0 => return None
    _ => ()
  }
  let box_reference = if is_row { 0.0 } else { available_cross.unwrap_or(0.0) }
  let resolved = node.resolved_rects(box_reference)
  let padding = resolved.padding
  let border = resolved.border
  if is_row {
    Some(padding.horizontal_sum() + border.horizontal_sum())
  } else {
    Some(padding.vertical_sum() + border.vertical_sum())
  }
}

///|
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Compute block content height through Inline Formatting Context when possible.
/// This avoids over-counting inline children like #text/<br>/#text as stacked blocks.
fn compute_inline_flow_height(
  node : @node.Node,
  available_width : Double,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double? {
  if available_width <= 0.0 {
    return None
  }
  let flow_inline_children : Array[@node.Node] = []
  for child in node.children {
    let child_style = child.style
    if child_style.display is @types.Display::None {
      continue
    }
    if child_style.position is @types.Absolute ||
      child_style.position is @types.Fixed {
      continue
    }
    match child_style.float {
      @types.CssFloat::Left | @types.CssFloat::Right => continue
      @types.CssFloat::None => ()
    }
    flow_inline_children.push(child)
  }
  if !@inline.should_establish_ifc(flow_inline_children) {
    return None
  }
  if node.style.writing_mode.is_vertical() {
    // Vertical writing-mode: block-size corresponds to the max inline extent.
    // Summing child heights over-counts <br>-separated inline runs.
    let mut max_height = 0.0
    for child in flow_inline_children {
      let child_style = child.style
      let child_resolved = child.resolved_rects(available_width)
      let child_height = match child_style.height {
        @types.Length(h) => h
        _ =>
          compute_intrinsic_main_size(
            child,
            false,
            Some(available_width),
            cache,
            dispatch,
          )
      }
      let outer_height = child_height +
        child_resolved.margin.top +
        child_resolved.margin.bottom
      max_height = max(max_height, outer_height)
    }
    Some(max_height)
  } else {
    let ifc = @inline.compute_ifc(
      flow_inline_children,
      available_width,
      None,
      0.0,
      0.0,
      dispatch,
      container_writing_mode=node.style.writing_mode,
      container_direction=node.style.direction,
      container_text_align=node.style.text_align,
      container_white_space=node.style.white_space,
    )
    Some(ifc.total_height)
  }
}

///|
/// Compute measured cross size with proportional scaling for text-like content.
/// When the main dimension is constrained below max, the cross dimension scales proportionally.
/// This simulates text wrapping behavior where content area stays constant.
/// Parameters:
///   - intrinsic: The intrinsic size from MeasureFunc
///   - constrained_main: The actual constrained main dimension
///   - is_row: true = main is width, cross is height
fn compute_measured_cross_size(
  intrinsic : @layout_types.IntrinsicSize,
  constrained_main : Double,
  is_row : Bool,
  scale_fixed_intrinsic~ : Bool = true,
) -> Double {
  let is_fixed_intrinsic = intrinsic.min_width == intrinsic.max_width &&
    intrinsic.min_height == intrinsic.max_height
  if is_row {
    // Computing height based on constrained width
    let max_width = intrinsic.max_width
    let max_height = intrinsic.max_height
    if is_fixed_intrinsic && !scale_fixed_intrinsic {
      max_height
    } else if is_fixed_intrinsic && max_width > 0.0 && max_height > 0.0 {
      if constrained_main <= 0.0 {
        0.0
      } else if constrained_main >= max_width {
        max_height
      } else {
        max_height * (constrained_main / max_width)
      }
      // Handle edge cases: unconstrained, no content, or zero/negative constraint
    } else if constrained_main >= max_width ||
      max_width <= 0.0 ||
      constrained_main <= 0.0 {
      max_height
    } else {
      // Proportional scaling: content area = max_width * max_height
      // new_height = area / constrained_width
      let area = max_width * max_height
      let scaled = area / constrained_main
      // Clamp to at least min_height
      max(intrinsic.min_height, scaled)
    }
  } else {
    // Computing width based on constrained height
    let max_width = intrinsic.max_width
    let max_height = intrinsic.max_height
    if is_fixed_intrinsic && !scale_fixed_intrinsic {
      max_width
    } else if is_fixed_intrinsic && max_width > 0.0 && max_height > 0.0 {
      if constrained_main <= 0.0 {
        0.0
      } else if constrained_main >= max_height {
        max_width
      } else {
        max_width * (constrained_main / max_height)
      }
      // Handle edge cases: unconstrained, no content, or zero/negative constraint
    } else if constrained_main >= max_height ||
      max_height <= 0.0 ||
      constrained_main <= 0.0 {
      max_width
    } else {
      // Proportional scaling
      let area = max_width * max_height
      let scaled = area / constrained_main
      max(intrinsic.min_width, scaled)
    }
  }
}

///|
/// Compute the intrinsic (content-based) size of a node on the main axis
/// This is used when flex-basis and main size are both Auto
fn compute_intrinsic_main_size(
  node : @node.Node,
  is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  // Only cache unconstrained sizes; constrained sizes depend on available_cross
  let use_cache = match available_cross {
    Some(_) => false
    None => true
  }
  if use_cache {
    match cache.get(node.uid, is_row) {
      Some(cached) => return cached
      None => ()
    }
  }
  let style = node.style
  let children = node.children

  // CSS containment intrinsic suppression on the current physical main axis.
  // Padding and border are still included; only content contribution is replaced.
  let suppress_main_intrinsic = if is_row {
    style.suppresses_intrinsic_width()
  } else {
    style.suppresses_intrinsic_height()
  }
  if suppress_main_intrinsic {
    let available_width = match available_cross {
      Some(w) if !is_row => w
      _ => 0.0
    }
    let resolved = node.resolved_rects(available_width)
    let padding = resolved.padding
    let border = resolved.border
    let mut result = if is_row {
      padding.horizontal_sum() + border.horizontal_sum()
    } else {
      padding.vertical_sum() + border.vertical_sum()
    }
    if is_row {
      result = result +
        estimate_multicol_intrinsic_inline_width(style, available_width)
    }
    cache.set(node.uid, is_row, result)
    return result
  }

  // Leaf nodes: use MeasureFunc if available, otherwise 0
  let result = if children.length() == 0 {
    match
      compute_trivial_leaf_intrinsic_main_box(node, is_row, available_cross) {
      Some(main_box) => main_box
      None =>
        match estimate_flex_text_intrinsic_main_size(node, is_row) {
          Some(text_main) => {
            let box_reference = if is_row {
              0.0
            } else {
              available_cross.unwrap_or(0.0)
            }
            let padding = @types.resolve_rect(style.padding, box_reference)
            let border = @types.resolve_rect(style.border, box_reference)
            let main_box = if is_row {
              padding.horizontal_sum() + border.horizontal_sum()
            } else {
              padding.vertical_sum() + border.vertical_sum()
            }
            text_main + main_box
          }
          None =>
            match node.measure {
              Some(mf) => {
                // Call MeasureFunc to get intrinsic size
                let intrinsic = (mf.func)(0.0, 0.0)
                let has_aspect_ratio = match style.aspect_ratio {
                  Some(ratio) => ratio > 0.0
                  None => false
                }
                let padding = @types.resolve_rect(style.padding, 0.0)
                let border = @types.resolve_rect(style.border, 0.0)

                // Replaced-like leaf compatibility:
                // when width/height is auto on the main axis and the cross axis is a
                // definite percent/length, derive main size from aspect-ratio.
                fn width_from_height_with_aspect(
                  ratio : Double,
                  box_height : Double,
                ) -> Double {
                  if style.box_sizing == @types.BorderBox {
                    box_height * ratio
                  } else {
                    let content_height = box_height -
                      padding.vertical_sum() -
                      border.vertical_sum()
                    if content_height > 0.0 {
                      content_height * ratio +
                      padding.horizontal_sum() +
                      border.horizontal_sum()
                    } else {
                      intrinsic.max_width
                    }
                  }
                }

                fn height_from_width_with_aspect(
                  ratio : Double,
                  box_width : Double,
                ) -> Double {
                  if style.box_sizing == @types.BorderBox {
                    box_width / ratio
                  } else {
                    let content_width = box_width -
                      padding.horizontal_sum() -
                      border.horizontal_sum()
                    if content_width > 0.0 {
                      content_width / ratio +
                      padding.vertical_sum() +
                      border.vertical_sum()
                    } else {
                      intrinsic.max_height
                    }
                  }
                }

                let aspect_main : Double? = if is_row {
                  match
                    (
                      style.width,
                      style.height,
                      style.aspect_ratio,
                      available_cross,
                    ) {
                    (@types.Auto, @types.Length(h), Some(ratio), _) if ratio >
                      0.0 => Some(width_from_height_with_aspect(ratio, h))
                    (@types.Auto, @types.Percent(p), Some(ratio), Some(cross)) =>
                      if ratio > 0.0 {
                        Some(width_from_height_with_aspect(ratio, cross * p))
                      } else {
                        None
                      }
                    (@types.Auto, @types.Auto, Some(ratio), Some(cross)) =>
                      if ratio > 0.0 {
                        Some(width_from_height_with_aspect(ratio, cross))
                      } else {
                        None
                      }
                    (@types.Percent(_), @types.Length(h), Some(ratio), _) if ratio >
                      0.0 => Some(width_from_height_with_aspect(ratio, h))
                    (
                      @types.Percent(_),
                      @types.Percent(p),
                      Some(ratio),
                      Some(cross),
                    ) =>
                      if ratio > 0.0 {
                        Some(width_from_height_with_aspect(ratio, cross * p))
                      } else {
                        None
                      }
                    (@types.Percent(_), @types.Auto, Some(ratio), Some(cross)) =>
                      if ratio > 0.0 {
                        Some(width_from_height_with_aspect(ratio, cross))
                      } else {
                        None
                      }
                    _ => None
                  }
                } else {
                  match
                    (
                      style.height,
                      style.width,
                      style.aspect_ratio,
                      available_cross,
                    ) {
                    (@types.Auto, @types.Length(w), Some(ratio), _) if ratio >
                      0.0 => Some(height_from_width_with_aspect(ratio, w))
                    (@types.Auto, @types.Percent(p), Some(ratio), Some(cross)) =>
                      if ratio > 0.0 {
                        Some(height_from_width_with_aspect(ratio, cross * p))
                      } else {
                        None
                      }
                    (@types.Auto, @types.Auto, Some(ratio), Some(cross)) =>
                      if ratio > 0.0 {
                        Some(height_from_width_with_aspect(ratio, cross))
                      } else {
                        None
                      }
                    _ => None
                  }
                }

                match aspect_main {
                  Some(main) => main
                  None => {
                    let main_box = if is_row {
                      padding.horizontal_sum() + border.horizontal_sum()
                    } else {
                      padding.vertical_sum() + border.vertical_sum()
                    }
                    let content_main = if is_row {
                      // Computing width - check if height is constrained
                      match available_cross {
                        Some(h) if h < intrinsic.max_height &&
                          intrinsic.max_height > 0.0 =>
                          // Width scales proportionally when height is constrained
                          compute_measured_cross_size(
                            intrinsic,
                            h,
                            false,
                            scale_fixed_intrinsic=has_aspect_ratio,
                          )
                        _ => intrinsic.max_width
                      }
                    } else {
                      // Computing height - check if width is constrained
                      match available_cross {
                        Some(w) if w < intrinsic.max_width &&
                          intrinsic.max_width > 0.0 =>
                          // Height scales proportionally when width is constrained
                          compute_measured_cross_size(
                            intrinsic,
                            w,
                            true,
                            scale_fixed_intrinsic=has_aspect_ratio,
                          )
                        _ => intrinsic.max_height
                      }
                    }
                    content_main + main_box
                  }
                }
              }
              None => {
                let box_reference = if is_row {
                  0.0
                } else {
                  available_cross.unwrap_or(0.0)
                }
                let padding = @types.resolve_rect(style.padding, box_reference)
                let border = @types.resolve_rect(style.border, box_reference)
                let main_box = if is_row {
                  padding.horizontal_sum() + border.horizontal_sum()
                } else {
                  padding.vertical_sum() + border.vertical_sum()
                }

                fn leaf_width_from_height(
                  ratio : Double,
                  box_height : Double,
                ) -> Double {
                  if style.box_sizing == @types.BorderBox {
                    box_height * ratio
                  } else {
                    let content_height = box_height -
                      padding.vertical_sum() -
                      border.vertical_sum()
                    if content_height > 0.0 {
                      content_height * ratio +
                      padding.horizontal_sum() +
                      border.horizontal_sum()
                    } else {
                      0.0
                    }
                  }
                }

                fn leaf_height_from_width(
                  ratio : Double,
                  box_width : Double,
                ) -> Double {
                  if style.box_sizing == @types.BorderBox {
                    box_width / ratio
                  } else {
                    let content_width = box_width -
                      padding.horizontal_sum() -
                      border.horizontal_sum()
                    if content_width > 0.0 {
                      content_width / ratio +
                      padding.vertical_sum() +
                      border.vertical_sum()
                    } else {
                      0.0
                    }
                  }
                }

                let auto_height_from_constraints : Double? = match
                  style.height {
                  @types.Auto => {
                    let min_h = match style.min_height {
                      @types.Length(v) => Some(v)
                      @types.Percent(p) =>
                        match available_cross {
                          Some(cross) => Some(cross * p)
                          None => None
                        }
                      @types.Calc(px, p) =>
                        match available_cross {
                          Some(cross) => Some(cross * p + px)
                          None => None
                        }
                      @types.MathFn(__mop, __mterms) =>
                        match available_cross {
                          Some(cross) =>
                            Some(
                              @types.apply_math_op(
                                __mop,
                                __mterms.map(fn(__t) { cross * __t.1 + __t.0 }),
                              ),
                            )
                          None => None
                        }
                      _ => None
                    }
                    let max_h = match style.max_height {
                      @types.Length(v) => Some(v)
                      @types.Percent(p) =>
                        match available_cross {
                          Some(cross) => Some(cross * p)
                          None => None
                        }
                      @types.Calc(px, p) =>
                        match available_cross {
                          Some(cross) => Some(cross * p + px)
                          None => None
                        }
                      @types.MathFn(__mop, __mterms) =>
                        match available_cross {
                          Some(cross) =>
                            Some(
                              @types.apply_math_op(
                                __mop,
                                __mterms.map(fn(__t) { cross * __t.1 + __t.0 }),
                              ),
                            )
                          None => None
                        }
                      _ => None
                    }
                    match min_h {
                      Some(v) if v > 0.0 => Some(v)
                      _ =>
                        match max_h {
                          Some(v) if v < 1.0e10 => Some(v)
                          _ => None
                        }
                    }
                  }
                  _ => None
                }

                let main_size = if is_row {
                  match
                    (
                      style.width,
                      style.height,
                      style.aspect_ratio,
                      available_cross,
                    ) {
                    (@types.Auto, @types.Length(h), Some(ratio), _) =>
                      if ratio > 0.0 {
                        leaf_width_from_height(ratio, h)
                      } else {
                        0.0
                      }
                    (@types.Auto, @types.Percent(p), Some(ratio), Some(cross)) =>
                      if ratio > 0.0 {
                        leaf_width_from_height(ratio, cross * p)
                      } else {
                        0.0
                      }
                    (@types.Auto, @types.Auto, Some(ratio), _) =>
                      if ratio > 0.0 {
                        match auto_height_from_constraints {
                          Some(h) => leaf_width_from_height(ratio, h)
                          None =>
                            match available_cross {
                              Some(cross) =>
                                leaf_width_from_height(ratio, cross)
                              None => 0.0
                            }
                        }
                      } else {
                        0.0
                      }
                    (@types.Percent(_), @types.Length(h), Some(ratio), _) =>
                      if ratio > 0.0 {
                        leaf_width_from_height(ratio, h)
                      } else {
                        0.0
                      }
                    (
                      @types.Percent(_),
                      @types.Percent(p),
                      Some(ratio),
                      Some(cross),
                    ) =>
                      if ratio > 0.0 {
                        leaf_width_from_height(ratio, cross * p)
                      } else {
                        0.0
                      }
                    (@types.Percent(_), @types.Auto, Some(ratio), _) =>
                      if ratio > 0.0 {
                        match auto_height_from_constraints {
                          Some(h) => leaf_width_from_height(ratio, h)
                          None =>
                            match available_cross {
                              Some(cross) =>
                                leaf_width_from_height(ratio, cross)
                              None => 0.0
                            }
                        }
                      } else {
                        0.0
                      }
                    _ => 0.0
                  }
                } else {
                  match
                    (
                      style.height,
                      style.width,
                      style.aspect_ratio,
                      available_cross,
                    ) {
                    (@types.Auto, @types.Length(w), Some(ratio), _) =>
                      if ratio > 0.0 {
                        leaf_height_from_width(ratio, w)
                      } else {
                        0.0
                      }
                    (@types.Auto, @types.Percent(p), Some(ratio), Some(cross)) =>
                      if ratio > 0.0 {
                        leaf_height_from_width(ratio, cross * p)
                      } else {
                        0.0
                      }
                    (@types.Auto, @types.Auto, Some(ratio), Some(cross)) =>
                      if ratio > 0.0 {
                        leaf_height_from_width(ratio, cross)
                      } else {
                        0.0
                      }
                    _ => 0.0
                  }
                }
                max(main_size, main_box)
              }
            }
        }
    }
  } else {
    // For containers, compute based on display type and children
    match style.display {
      @types.Flex | @types.InlineFlex =>
        compute_intrinsic_flex_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
      @types.Block | @types.Inline | @types.InlineBlock | @types.FlowRoot =>
        compute_intrinsic_block_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
      @types.Contents =>
        if is_row {
          // display: contents contributes inline-size from descendants, but should
          // not force block-size expansion from wrapper-only intrinsic estimates.
          compute_intrinsic_block_main_size(
            node, true, available_cross, cache, dispatch,
          )
        } else {
          0.0
        }
      @types.Grid | @types.InlineGrid =>
        compute_intrinsic_grid_main_size(
          node, is_row, available_cross, dispatch,
        )
      @types.Table | @types.InlineTable =>
        @table.compute_intrinsic_size(node, is_row)
      _ => 0.0
    }
  }

  // Apply explicit main-axis min/max length constraints to intrinsic result.
  // (Percentage constraints need containing block main-size and are resolved later.)
  let mut constrained_result = result
  if !is_row {
    match style.max_height {
      @types.Length(v) => if constrained_result > v { constrained_result = v }
      _ => ()
    }
    match style.min_height {
      @types.Length(v) => if constrained_result < v { constrained_result = v }
      _ => ()
    }
  }

  // Cache the result for future lookups
  if use_cache {
    cache.set(node.uid, is_row, constrained_result)
  }
  constrained_result
}

///|
/// Compute the min-content size of a node on the main axis
/// This is used for automatic minimum size calculation (min-width: auto / min-height: auto)
/// Unlike compute_intrinsic_main_size which returns max-content (full unwrapped width),
/// this returns min-content (longest unbreakable unit, e.g., longest word)
fn compute_min_content_main_size(
  node : @node.Node,
  is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let children = node.children

  let suppress_main_intrinsic = if is_row {
    style.suppresses_intrinsic_width()
  } else {
    style.suppresses_intrinsic_height()
  }
  if suppress_main_intrinsic {
    let available_width = match available_cross {
      Some(w) if !is_row => w
      _ => 0.0
    }
    let resolved = node.resolved_rects(available_width)
    let padding = resolved.padding
    let border = resolved.border
    return if is_row {
      padding.horizontal_sum() + border.horizontal_sum()
    } else {
      padding.vertical_sum() + border.vertical_sum()
    }
  }

  // Leaf nodes: use MeasureFunc if available, otherwise 0
  if children.length() == 0 {
    match estimate_flex_text_min_main_size(node, is_row) {
      Some(text_main) => {
        let box_reference = if is_row {
          0.0
        } else {
          available_cross.unwrap_or(0.0)
        }
        let padding = @types.resolve_rect(style.padding, box_reference)
        let border = @types.resolve_rect(style.border, box_reference)
        let main_box = if is_row {
          padding.horizontal_sum() + border.horizontal_sum()
        } else {
          padding.vertical_sum() + border.vertical_sum()
        }
        text_main + main_box
      }
      None =>
        match node.measure {
          Some(mf) => {
            // Call MeasureFunc to get intrinsic size
            let intrinsic = (mf.func)(0.0, 0.0)
            let has_aspect_ratio = match style.aspect_ratio {
              Some(ratio) => ratio > 0.0
              None => false
            }
            let main_box = if is_row {
              let padding = @types.resolve_rect(style.padding, 0.0)
              let border = @types.resolve_rect(style.border, 0.0)
              padding.horizontal_sum() + border.horizontal_sum()
            } else {
              let padding = @types.resolve_rect(style.padding, 0.0)
              let border = @types.resolve_rect(style.border, 0.0)
              padding.vertical_sum() + border.vertical_sum()
            }
            // For min-content, return min_width (longest unbreakable unit)
            if is_row {
              intrinsic.min_width + main_box
            } else {
              // Fallback: height at min_width
              match available_cross {
                Some(w) if w < intrinsic.max_width && intrinsic.max_width > 0.0 =>
                  compute_measured_cross_size(
                    intrinsic,
                    w,
                    true,
                    scale_fixed_intrinsic=has_aspect_ratio,
                  ) +
                  main_box
                _ => {
                  let constrained = (mf.func)(intrinsic.min_width, 0.0)
                  constrained.max_height + main_box
                }
              }
            }
          }
          None =>
            match style.aspect_ratio {
              Some(ratio) if ratio > 0.0 =>
                compute_intrinsic_main_size(
                  node, is_row, available_cross, cache, dispatch,
                )
              _ => 0.0
            }
        }
    }
  } else {
    // For containers, recursively compute min-content
    // Note: This is simplified - ideally we'd have separate min-content functions
    // for each display type, but for now we reuse the max-content functions
    // which gives us a conservative (larger) minimum
    match style.display {
      @types.Flex | @types.InlineFlex =>
        compute_min_content_flex_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
      @types.Block =>
        compute_min_content_block_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
      @types.Inline | @types.InlineBlock | @types.FlowRoot =>
        compute_min_content_block_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
      @types.Contents =>
        if is_row {
          compute_min_content_block_main_size(
            node, true, available_cross, cache, dispatch,
          )
        } else {
          0.0
        }
      @types.Grid | @types.InlineGrid =>
        compute_min_content_grid_main_size(
          node, is_row, available_cross, dispatch,
        )
      _ =>
        // Fall back to max-content for other display types
        compute_intrinsic_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
    }
  }
}

///|
/// Compute min-content size for a flex container
fn compute_min_content_flex_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let flattened = flatten_children_for_flex(node)

  // Check if this flex container is row or column
  // Account for writing-mode: vertical modes swap row/column
  let axis = @alignment.resolve_flex_axis(
    style.flex_direction,
    style.writing_mode.is_vertical(),
    style.direction.is_rtl(),
  )
  let child_is_row = axis.is_row

  // Determine if we're computing along this container's main axis or cross axis
  let compute_main_axis = parent_is_row == child_is_row
  let child_available_width = if parent_is_row {
    match style.width {
      @types.Length(w) => w
      _ => 0.0
    }
  } else {
    match available_cross {
      Some(w) => w
      None =>
        match style.width {
          @types.Length(w) => w
          _ => 0.0
        }
    }
  }
  let padding = @types.resolve_rect(style.padding, child_available_width)
  let border = @types.resolve_rect(style.border, child_available_width)
  let container_inline = match style.width {
    @types.Length(w) => Some(w)
    @types.Percent(p) =>
      if child_available_width > 0.0 {
        Some(child_available_width * p)
      } else {
        None
      }
    @types.Calc(_, p) =>
      if child_available_width > 0.0 {
        Some(child_available_width * p)
      } else {
        None
      }
    @types.MathFn(__mop, __mterms) => {
      let p = @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.1 }))
      if child_available_width > 0.0 {
        Some(child_available_width * p)
      } else {
        None
      }
    }
    _ => None
  }
  let content_width_for_children = match container_inline {
    Some(w) => {
      let content = w - padding.horizontal_sum() - border.horizontal_sum()
      if content > 0.0 {
        content
      } else {
        0.0
      }
    }
    None => {
      let content = child_available_width -
        padding.horizontal_sum() -
        border.horizontal_sum()
      if content > 0.0 {
        content
      } else {
        0.0
      }
    }
  }
  if compute_main_axis {
    // For min-content on main axis: sum of min-content sizes (no wrapping)
    let mut total_main = 0.0
    for i = 0; i < flattened.length(); i = i + 1 {
      let child = flattened[i].node
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = child.resolved_rects(content_width_for_children)
      let child_main = if child_is_row {
        let intrinsic_cross_for_aspect : Double? = match style.height {
          @types.Length(h) =>
            Some(max(0.0, h - padding.vertical_sum() - border.vertical_sum()))
          @types.Percent(p) =>
            match available_cross {
              Some(ac) =>
                Some(
                  max(
                    0.0,
                    ac * p - padding.vertical_sum() - border.vertical_sum(),
                  ),
                )
              None => None
            }
          @types.Calc(_, p) =>
            match available_cross {
              Some(ac) =>
                Some(
                  max(
                    0.0,
                    ac * p - padding.vertical_sum() - border.vertical_sum(),
                  ),
                )
              None => None
            }
          @types.MathFn(__mop, __mterms) => {
            let p = @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.1 }))
            match available_cross {
              Some(ac) =>
                Some(
                  max(
                    0.0,
                    ac * p - padding.vertical_sum() - border.vertical_sum(),
                  ),
                )
              None => None
            }
          }
          _ => None
        }
        match child_style.width {
          @types.Length(w) => w
          @types.Auto =>
            match child_style.aspect_ratio {
              Some(ratio) if ratio > 0.0 =>
                compute_min_content_main_size(
                  child, true, intrinsic_cross_for_aspect, cache, dispatch,
                )
              _ =>
                compute_min_content_main_size(
                  child,
                  true,
                  None,
                  cache,
                  dispatch,
                )
            }
          _ => compute_min_content_main_size(child, true, None, cache, dispatch)
        }
      } else {
        match child_style.height {
          @types.Length(h) => h
          _ =>
            compute_min_content_main_size(
              child,
              false,
              Some(content_width_for_children),
              cache,
              dispatch,
            )
        }
      }
      let margin_main = if child_is_row {
        child_resolved.margin.left + child_resolved.margin.right
      } else {
        child_resolved.margin.top + child_resolved.margin.bottom
      }
      total_main = total_main + child_main + margin_main
    }
    let padding_border = if child_is_row {
      padding.horizontal_sum() + border.horizontal_sum()
    } else {
      padding.vertical_sum() + border.vertical_sum()
    }
    total_main + padding_border
  } else {
    // Cross axis: max of min-content sizes
    let mut max_cross = 0.0
    for i = 0; i < flattened.length(); i = i + 1 {
      let child = flattened[i].node
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = child.resolved_rects(content_width_for_children)
      let child_cross = if child_is_row {
        match child_style.height {
          @types.Length(h) => h
          _ =>
            compute_min_content_main_size(
              child,
              false,
              Some(content_width_for_children),
              cache,
              dispatch,
            )
        }
      } else {
        match child_style.width {
          @types.Length(w) => w
          _ => compute_min_content_main_size(child, true, None, cache, dispatch)
        }
      }
      let margin_cross = if child_is_row {
        child_resolved.margin.top + child_resolved.margin.bottom
      } else {
        child_resolved.margin.left + child_resolved.margin.right
      }
      max_cross = max(max_cross, child_cross + margin_cross)
    }
    let padding_border_cross = if parent_is_row {
      padding.horizontal_sum() + border.horizontal_sum()
    } else {
      padding.vertical_sum() + border.vertical_sum()
    }
    max_cross + padding_border_cross
  }
}

///|
/// Compute min-content size for a grid container
/// (approximate to allow flex items to shrink below max-content)
fn compute_min_content_grid_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let flattened = flatten_children_for_flex(node)
  let available_width = match available_cross {
    Some(w) if !parent_is_row => w
    _ =>
      match style.width {
        @types.Length(w) => w
        _ => 0.0
      }
  }
  let resolved = node.resolved_rects(available_width)
  let padding = resolved.padding
  let border = resolved.border
  let cache = IntrinsicCache::new()

  if parent_is_row {
    // Approximate grid min-content width by max of item min-content widths.
    let mut max_width = 0.0
    for i = 0; i < flattened.length(); i = i + 1 {
      let child = flattened[i].node
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      let child_resolved = child.resolved_rects(available_width)
      let child_width = match child_style.width {
        @types.Length(w) =>
          w + child_resolved.margin.left + child_resolved.margin.right
        _ =>
          compute_min_content_main_size(child, true, None, cache, dispatch) +
          child_resolved.margin.left +
          child_resolved.margin.right
      }
      max_width = max(max_width, child_width)
    }
    max_width + padding.horizontal_sum() + border.horizontal_sum()
  } else {
    // Grid block-size contribution must account for placement and row tracks.
    // Summing every item's height overestimates multi-column grids and makes
    // flex item's automatic min-height clamp to the item count instead of row
    // count.
    compute_intrinsic_grid_main_size(node, false, available_cross, dispatch)
  }
}

///|
/// Compute min-content size for a block container
fn compute_min_content_block_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let children = node.children
  let available_width = match available_cross {
    Some(w) if !parent_is_row => w
    _ =>
      match style.width {
        @types.Length(w) => w
        _ => 0.0
      }
  }
  let resolved = node.resolved_rects(available_width)
  let padding = resolved.padding
  let border = resolved.border
  if parent_is_row {
    let intrinsic_cross_for_children : Double? = match style.height {
      @types.Length(h) => {
        let content_h = if style.box_sizing is @types.BorderBox {
          h - padding.top - padding.bottom - border.top - border.bottom
        } else {
          h
        }
        Some(max(0.0, content_h))
      }
      @types.Percent(p) =>
        match available_cross {
          Some(cross) => {
            let resolved_h = cross * p
            let content_h = if style.box_sizing is @types.BorderBox {
              resolved_h -
              padding.top -
              padding.bottom -
              border.top -
              border.bottom
            } else {
              resolved_h
            }
            Some(max(0.0, content_h))
          }
          None => None
        }
      @types.Calc(_, p) =>
        match available_cross {
          Some(cross) => {
            let resolved_h = cross * p
            let content_h = if style.box_sizing is @types.BorderBox {
              resolved_h -
              padding.top -
              padding.bottom -
              border.top -
              border.bottom
            } else {
              resolved_h
            }
            Some(max(0.0, content_h))
          }
          None => None
        }
      @types.MathFn(__mop, __mterms) => {
        let p = @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.1 }))
        match available_cross {
          Some(cross) => {
            let resolved_h = cross * p
            let content_h = if style.box_sizing is @types.BorderBox {
              resolved_h -
              padding.top -
              padding.bottom -
              border.top -
              border.bottom
            } else {
              resolved_h
            }
            Some(max(0.0, content_h))
          }
          None => None
        }
      }
      @types.Auto
      | @types.MinContent
      | @types.MaxContent
      | @types.FitContent(_) => available_cross
    }
    // Compute min-content width.
    // In vertical writing mode, blocks advance horizontally, so contributions sum.
    let is_vertical_writing = style.writing_mode.is_vertical()
    let mut width_acc = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display is @types.Display::None {
        continue
      }
      if child_style.position is @types.Absolute ||
        child_style.position is @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = child.resolved_rects(available_width)
      let raw_child_width = match child_style.width {
        @types.Length(w) => w
        _ =>
          compute_min_content_main_size(
            child, true, intrinsic_cross_for_children, cache, dispatch,
          )
      }
      let mut constrained_child_width = raw_child_width
      match child_style.max_width {
        @types.Length(v) =>
          if constrained_child_width > v {
            constrained_child_width = v
          }
        @types.MinContent => {
          let v = compute_min_content_main_size(
            child, true, intrinsic_cross_for_children, cache, dispatch,
          )
          if constrained_child_width > v {
            constrained_child_width = v
          }
        }
        @types.MaxContent => {
          let v = compute_intrinsic_main_size(
            child, true, intrinsic_cross_for_children, cache, dispatch,
          )
          if constrained_child_width > v {
            constrained_child_width = v
          }
        }
        @types.FitContent(limit) =>
          if constrained_child_width > limit {
            constrained_child_width = limit
          }
        _ => ()
      }
      match child_style.min_width {
        @types.Length(v) =>
          if constrained_child_width < v {
            constrained_child_width = v
          }
        @types.MinContent => {
          let v = compute_min_content_main_size(
            child, true, intrinsic_cross_for_children, cache, dispatch,
          )
          if constrained_child_width < v {
            constrained_child_width = v
          }
        }
        @types.MaxContent => {
          let v = compute_intrinsic_main_size(
            child, true, intrinsic_cross_for_children, cache, dispatch,
          )
          if constrained_child_width < v {
            constrained_child_width = v
          }
        }
        @types.FitContent(_) => {
          let v = compute_min_content_main_size(
            child, true, intrinsic_cross_for_children, cache, dispatch,
          )
          if constrained_child_width < v {
            constrained_child_width = v
          }
        }
        _ => ()
      }
      let child_width = constrained_child_width +
        child_resolved.margin.left +
        child_resolved.margin.right
      if is_vertical_writing {
        width_acc = width_acc + child_width
      } else {
        width_acc = max(width_acc, child_width)
      }
    }
    width_acc + padding.left + padding.right + border.left + border.right
  } else {
    // Compute min-content height: sum of children's heights
    let ifc_height = match available_cross {
      Some(_) =>
        compute_inline_flow_height(node, available_width, cache, dispatch)
      None => None
    }
    match ifc_height {
      Some(h) => h + padding.top + padding.bottom + border.top + border.bottom
      None => {
        let mut total_height = 0.0
        for i = 0; i < children.length(); i = i + 1 {
          let child = children[i]
          let child_style = child.style
          if child_style.display is @types.Display::None {
            continue
          }
          if child_style.position is @types.Absolute ||
            child_style.position is @types.Fixed {
            continue
          }
          // Use cached resolved rects
          let child_resolved = child.resolved_rects(available_width)
          let child_height = match child_style.height {
            @types.Length(h) => h
            _ =>
              compute_min_content_main_size(
                child,
                false,
                Some(available_width),
                cache,
                dispatch,
              )
          }
          total_height = total_height +
            child_height +
            child_resolved.margin.top +
            child_resolved.margin.bottom
        }
        total_height + padding.top + padding.bottom + border.top + border.bottom
      }
    }
  }
}

///|
/// Compute intrinsic size for a flex container
/// parent_is_row: true = compute width, false = compute height
fn compute_intrinsic_flex_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let flattened = flatten_children_for_flex(node)

  // Check if this flex container is row or column
  // Account for writing-mode: vertical modes swap row/column
  let axis = @alignment.resolve_flex_axis(
    style.flex_direction,
    style.writing_mode.is_vertical(),
    style.direction.is_rtl(),
  )
  let child_is_row = axis.is_row

  // Determine if we're computing along this container's main axis or cross axis
  // parent_is_row = true means we want WIDTH
  // parent_is_row = false means we want HEIGHT
  // child_is_row = true means container's main axis is WIDTH, cross is HEIGHT
  // child_is_row = false means container's main axis is HEIGHT, cross is WIDTH
  let compute_main_axis = parent_is_row == child_is_row

  // For the child flex container, compute available width for resolving percentages
  let child_available_width = if parent_is_row {
    match style.width {
      @types.Length(w) => w
      _ => 0.0
    }
  } else {
    match available_cross {
      Some(w) => w
      None =>
        match style.width {
          @types.Length(w) => w
          _ => 0.0
        }
    }
  }
  let padding = @types.resolve_rect(style.padding, child_available_width)
  let border = @types.resolve_rect(style.border, child_available_width)
  let container_inline = match style.width {
    @types.Length(w) => Some(w)
    @types.Percent(p) =>
      if child_available_width > 0.0 {
        Some(child_available_width * p)
      } else {
        None
      }
    @types.Calc(_, p) =>
      if child_available_width > 0.0 {
        Some(child_available_width * p)
      } else {
        None
      }
    @types.MathFn(__mop, __mterms) => {
      let p = @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.1 }))
      if child_available_width > 0.0 {
        Some(child_available_width * p)
      } else {
        None
      }
    }
    _ => None
  }
  let has_definite_inline = match container_inline {
    Some(_) => true
    None => false
  }
  let content_width_for_children = match container_inline {
    Some(w) => {
      let content = w - padding.horizontal_sum() - border.horizontal_sum()
      if content > 0.0 {
        content
      } else {
        0.0
      }
    }
    None => {
      let content = child_available_width -
        padding.horizontal_sum() -
        border.horizontal_sum()
      if content > 0.0 {
        content
      } else {
        0.0
      }
    }
  }
  if compute_main_axis {
    // Computing along this container's main axis: sum children's sizes
    let main_gap = if child_is_row {
      style.column_gap.resolve_or(content_width_for_children, 0.0)
    } else {
      style.row_gap.resolve_or(content_width_for_children, 0.0)
    }
    let mut total_main = 0.0
    let mut total_main_margins = 0.0
    let mut _has_flex_grow = false
    let mut item_count = 0
    for i = 0; i < flattened.length(); i = i + 1 {
      let child = flattened[i].node
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects for all child box model values
      let child_resolved = child.resolved_rects(content_width_for_children)
      let child_margin = child_resolved.margin
      let child_padding = child_resolved.padding
      let child_border = child_resolved.border
      let child_min_width = child_padding.horizontal_sum() +
        child_border.horizontal_sum()
      let child_min_height = child_padding.vertical_sum() +
        child_border.vertical_sum()
      if child_style.flex_grow > 0.0 {
        _has_flex_grow = true
      }
      let child_main = if child_is_row {
        let intrinsic_cross_for_aspect : Double? = match style.height {
          @types.Length(h) =>
            Some(max(0.0, h - padding.vertical_sum() - border.vertical_sum()))
          @types.Percent(p) =>
            match available_cross {
              Some(ac) =>
                Some(
                  max(
                    0.0,
                    ac * p - padding.vertical_sum() - border.vertical_sum(),
                  ),
                )
              None => None
            }
          @types.Calc(_, p) =>
            match available_cross {
              Some(ac) =>
                Some(
                  max(
                    0.0,
                    ac * p - padding.vertical_sum() - border.vertical_sum(),
                  ),
                )
              None => None
            }
          @types.MathFn(__mop, __mterms) => {
            let p = @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.1 }))
            match available_cross {
              Some(ac) =>
                Some(
                  max(
                    0.0,
                    ac * p - padding.vertical_sum() - border.vertical_sum(),
                  ),
                )
              None => None
            }
          }
          _ => None
        }
        let child_has_aspect_ratio = match child_style.aspect_ratio {
          Some(ratio) => ratio > 0.0
          None => false
        }
        let child_effective_align = @alignment.resolve_align_self(
          child_style.align_self,
          style.align_items,
        )
        let child_stretches_cross = match child_effective_align {
          @types.Stretch => true
          _ => false
        }
        let intrinsic_cross_for_child : Double? = match
          intrinsic_cross_for_aspect {
          Some(cross) =>
            match child_style.height {
              @types.Length(h) => Some(h)
              @types.Percent(_) => Some(cross)
              @types.Calc(_, _) => Some(cross)
              @types.MathFn(_, _) => Some(cross)
              @types.Auto
              | @types.MinContent
              | @types.MaxContent
              | @types.FitContent(_) =>
                if child_has_aspect_ratio || child_stretches_cross {
                  Some(max(0.0, cross - child_margin.top - child_margin.bottom))
                } else {
                  None
                }
            }
          None => None
        }
        // Main axis is width
        let base_width = match child_style.flex_basis {
          @types.Length(b) =>
            if child.children.length() > 0 {
              max(
                b,
                compute_intrinsic_main_size(
                  child, true, intrinsic_cross_for_child, cache, dispatch,
                ),
              )
            } else {
              match child_style.width {
                @types.Length(w) => max(b, w)
                _ => b
              }
            }
          @types.Percent(p) =>
            if has_definite_inline {
              content_width_for_children * p
            } else {
              compute_intrinsic_main_size(
                child, true, intrinsic_cross_for_child, cache, dispatch,
              )
            }
          @types.Calc(px, p) =>
            if has_definite_inline {
              content_width_for_children * p + px
            } else {
              compute_intrinsic_main_size(
                child, true, intrinsic_cross_for_child, cache, dispatch,
              )
            }
          @types.MathFn(__mop, __mterms) =>
            if has_definite_inline {
              @types.apply_math_op(
                __mop,
                __mterms.map(fn(__t) {
                  content_width_for_children * __t.1 + __t.0
                }),
              )
            } else {
              compute_intrinsic_main_size(
                child, true, intrinsic_cross_for_child, cache, dispatch,
              )
            }
          @types.Auto =>
            match child_style.width {
              @types.Length(w) => w
              @types.Percent(p) =>
                if has_definite_inline {
                  content_width_for_children * p
                } else {
                  compute_intrinsic_main_size(
                    child, true, intrinsic_cross_for_child, cache, dispatch,
                  )
                }
              @types.Calc(px, p) =>
                if has_definite_inline {
                  content_width_for_children * p + px
                } else {
                  compute_intrinsic_main_size(
                    child, true, intrinsic_cross_for_child, cache, dispatch,
                  )
                }
              @types.MathFn(__mop, __mterms) =>
                if has_definite_inline {
                  @types.apply_math_op(
                    __mop,
                    __mterms.map(fn(__t) {
                      content_width_for_children * __t.1 + __t.0
                    }),
                  )
                } else {
                  compute_intrinsic_main_size(
                    child, true, intrinsic_cross_for_child, cache, dispatch,
                  )
                }
              @types.Auto =>
                compute_intrinsic_main_size(
                  child, true, intrinsic_cross_for_child, cache, dispatch,
                )
              @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
                compute_intrinsic_main_size(
                  child, true, intrinsic_cross_for_child, cache, dispatch,
                )
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(
              child, true, intrinsic_cross_for_child, cache, dispatch,
            )
        }
        let mut effective_width = base_width
        match child_style.max_width {
          @types.Length(v) => if effective_width > v { effective_width = v }
          @types.Percent(p) =>
            if has_definite_inline {
              let v = content_width_for_children * p
              if effective_width > v {
                effective_width = v
              }
            }
          @types.Calc(px, p) =>
            if has_definite_inline {
              let v = content_width_for_children * p + px
              if effective_width > v {
                effective_width = v
              }
            }
          @types.MathFn(__mop, __mterms) =>
            if has_definite_inline {
              let v = @types.apply_math_op(
                __mop,
                __mterms.map(fn(__t) {
                  content_width_for_children * __t.1 + __t.0
                }),
              )
              if effective_width > v {
                effective_width = v
              }
            }
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => ()
        }
        match child_style.min_width {
          @types.Length(v) => if effective_width < v { effective_width = v }
          @types.Percent(p) =>
            if has_definite_inline {
              let v = content_width_for_children * p
              if effective_width < v {
                effective_width = v
              }
            }
          @types.Calc(px, p) =>
            if has_definite_inline {
              let v = content_width_for_children * p + px
              if effective_width < v {
                effective_width = v
              }
            }
          @types.MathFn(__mop, __mterms) =>
            if has_definite_inline {
              let v = @types.apply_math_op(
                __mop,
                __mterms.map(fn(__t) {
                  content_width_for_children * __t.1 + __t.0
                }),
              )
              if effective_width < v {
                effective_width = v
              }
            }
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => ()
        }
        if effective_width < child_min_width {
          effective_width = child_min_width
        }
        let margin_main = child_margin.left + child_margin.right
        total_main_margins = total_main_margins + margin_main
        effective_width + margin_main
      } else {
        // Main axis is height
        let base_height = match child_style.flex_basis {
          @types.Length(b) =>
            if child.children.length() > 0 {
              max(
                b,
                compute_intrinsic_main_size(
                  child,
                  false,
                  Some(content_width_for_children),
                  cache,
                  dispatch,
                ),
              )
            } else {
              match child_style.height {
                @types.Length(h) => max(b, h)
                _ => b
              }
            }
          @types.Percent(_) => 0.0
          @types.Calc(_, _) => 0.0
          @types.MathFn(_, _) => 0.0
          @types.Auto =>
            match child_style.height {
              @types.Length(h) => h
              @types.Percent(_) => 0.0
              @types.Calc(_, _) => 0.0
              @types.MathFn(_, _) => 0.0
              @types.Auto =>
                compute_intrinsic_main_size(
                  child,
                  false,
                  Some(content_width_for_children),
                  cache,
                  dispatch,
                )
              @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
                compute_intrinsic_main_size(
                  child,
                  false,
                  Some(content_width_for_children),
                  cache,
                  dispatch,
                )
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(content_width_for_children),
              cache,
              dispatch,
            )
        }
        let mut effective_height = base_height
        match child_style.max_height {
          @types.Length(v) => if effective_height > v { effective_height = v }
          @types.Percent(_) => ()
          @types.Calc(_, _) => ()
          @types.MathFn(_, _) => ()
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => ()
        }
        match child_style.min_height {
          @types.Length(v) => if effective_height < v { effective_height = v }
          @types.Percent(_) => ()
          @types.Calc(_, _) => ()
          @types.MathFn(_, _) => ()
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => ()
        }
        if effective_height < child_min_height {
          effective_height = child_min_height
        }
        let margin_main = child_margin.top + child_margin.bottom
        total_main_margins = total_main_margins + margin_main
        effective_height + margin_main
      }
      total_main = total_main + child_main
      item_count = item_count + 1
    }
    if item_count > 1 {
      total_main = total_main + main_gap * (item_count - 1).to_double()
    }
    // NOTE: an earlier revision floored a flex column's intrinsic main (height)
    // at `container_inline` (the container WIDTH) whenever it had flex-grow
    // children. That is dimensionally wrong (width used as a height floor) and
    // also violates intrinsic sizing — flex-grow does not increase a container's
    // content/intrinsic size. It made flex-column cards with a `flex:1` child
    // (e.g. GitHub pinned-repo cards) measure several times too tall, which then
    // cascaded through align-items:stretch. The content sum (`total_main`) is
    // the correct intrinsic main size.
    if child_is_row {
      total_main + padding.left + padding.right + border.left + border.right
    } else {
      total_main + padding.top + padding.bottom + border.top + border.bottom
    }
  } else {
    // Computing along this container's cross axis
    // For wrap containers, we need to account for multiple lines
    let is_wrap = match style.flex_wrap {
      @types.Wrap | @types.WrapReverse => true
      _ => false
    }

    // Determine available main size for line breaking
    // For percentage widths, we need to resolve against available_cross
    let available_main : Double? = if is_wrap {
      if child_is_row {
        // Row wrap: main is width
        // Use resolved width if explicit, otherwise available_cross
        match style.width {
          @types.Length(w) => Some(w)
          @types.Percent(p) =>
            match available_cross {
              Some(ac) => Some(ac * p)
              None => None
            }
          @types.Calc(px, p) =>
            match available_cross {
              Some(ac) => Some(ac * p + px)
              None => None
            }
          @types.MathFn(__mop, __mterms) =>
            match available_cross {
              Some(ac) =>
                Some(
                  @types.apply_math_op(
                    __mop,
                    __mterms.map(fn(__t) { ac * __t.1 + __t.0 }),
                  ),
                )
              None => None
            }
          @types.Auto => available_cross
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            available_cross
        }
      } else {
        // Column wrap: main is height, available from available_cross parameter
        // But for column containers, we typically don't have available height
        None
      }
    } else {
      None
    }

    // Get gap for line breaking calculation
    let main_gap = if child_is_row {
      style.column_gap.resolve_or(content_width_for_children, 0.0)
    } else {
      style.row_gap.resolve_or(content_width_for_children, 0.0)
    }

    // Collect items with their sizes
    let items : Array[(Double, Double)] = [] // (main_size, cross_size)
    for i = 0; i < flattened.length(); i = i + 1 {
      let child = flattened[i].node
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = child.resolved_rects(content_width_for_children)
      let child_margin = child_resolved.margin
      let (child_main, child_cross) = if child_is_row {
        // Main is width, cross is height
        let main = match child_style.width {
          @types.Length(w) => w + child_margin.left + child_margin.right
          @types.Percent(p) =>
            if has_definite_inline {
              content_width_for_children * p +
              child_margin.left +
              child_margin.right
            } else {
              compute_intrinsic_main_size(child, true, None, cache, dispatch) +
              child_margin.left +
              child_margin.right
            }
          @types.Calc(px, p) =>
            if has_definite_inline {
              content_width_for_children * p +
              px +
              child_margin.left +
              child_margin.right
            } else {
              compute_intrinsic_main_size(child, true, None, cache, dispatch) +
              child_margin.left +
              child_margin.right
            }
          @types.MathFn(__mop, __mterms) =>
            if has_definite_inline {
              @types.apply_math_op(
                __mop,
                __mterms.map(fn(__t) {
                  content_width_for_children * __t.1 + __t.0
                }),
              ) +
              child_margin.left +
              child_margin.right
            } else {
              compute_intrinsic_main_size(child, true, None, cache, dispatch) +
              child_margin.left +
              child_margin.right
            }
          @types.Auto =>
            compute_intrinsic_main_size(child, true, None, cache, dispatch) +
            child_margin.left +
            child_margin.right
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(child, true, None, cache, dispatch) +
            child_margin.left +
            child_margin.right
        }
        let cross = match child_style.height {
          @types.Length(h) => h + child_margin.top + child_margin.bottom
          @types.Percent(_) => child_margin.top + child_margin.bottom
          @types.Calc(_, _) => child_margin.top + child_margin.bottom
          @types.MathFn(_, _) => child_margin.top + child_margin.bottom
          @types.Auto =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(content_width_for_children),
              cache,
              dispatch,
            ) +
            child_margin.top +
            child_margin.bottom
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(content_width_for_children),
              cache,
              dispatch,
            ) +
            child_margin.top +
            child_margin.bottom
        }
        (main, cross)
      } else {
        // Main is height, cross is width
        let main = match child_style.height {
          @types.Length(h) => h + child_margin.top + child_margin.bottom
          @types.Percent(_) => child_margin.top + child_margin.bottom
          @types.Calc(_, _) => child_margin.top + child_margin.bottom
          @types.MathFn(_, _) => child_margin.top + child_margin.bottom
          @types.Auto =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(content_width_for_children),
              cache,
              dispatch,
            ) +
            child_margin.top +
            child_margin.bottom
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(content_width_for_children),
              cache,
              dispatch,
            ) +
            child_margin.top +
            child_margin.bottom
        }
        let cross = match child_style.width {
          @types.Length(w) => w + child_margin.left + child_margin.right
          @types.Percent(p) =>
            if has_definite_inline {
              content_width_for_children * p +
              child_margin.left +
              child_margin.right
            } else {
              compute_intrinsic_main_size(child, true, None, cache, dispatch) +
              child_margin.left +
              child_margin.right
            }
          @types.Calc(px, p) =>
            if has_definite_inline {
              content_width_for_children * p +
              px +
              child_margin.left +
              child_margin.right
            } else {
              compute_intrinsic_main_size(child, true, None, cache, dispatch) +
              child_margin.left +
              child_margin.right
            }
          @types.MathFn(__mop, __mterms) =>
            if has_definite_inline {
              @types.apply_math_op(
                __mop,
                __mterms.map(fn(__t) {
                  content_width_for_children * __t.1 + __t.0
                }),
              ) +
              child_margin.left +
              child_margin.right
            } else {
              compute_intrinsic_main_size(child, true, None, cache, dispatch) +
              child_margin.left +
              child_margin.right
            }
          @types.Auto =>
            compute_intrinsic_main_size(child, true, None, cache, dispatch) +
            child_margin.left +
            child_margin.right
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(child, true, None, cache, dispatch) +
            child_margin.left +
            child_margin.right
        }
        (main, cross)
      }
      items.push((child_main, child_cross))
    }

    // Calculate total cross size
    let total_cross = match available_main {
      Some(avail) if is_wrap && avail > 0.0 => {
        // Wrap: distribute items into lines
        let lines_cross : Array[Double] = []
        let mut line_main = 0.0
        let mut line_max_cross = 0.0
        let mut line_item_count = 0
        for i = 0; i < items.length(); i = i + 1 {
          let (item_main, item_cross) = items[i]
          // Check if adding this item would exceed available main
          let needed = if line_item_count > 0 {
            line_main + main_gap + item_main
          } else {
            item_main
          }
          if line_item_count > 0 && needed > avail {
            // Start new line
            lines_cross.push(line_max_cross)
            line_main = item_main
            line_max_cross = item_cross
            line_item_count = 1
          } else {
            // Add to current line
            line_main = needed
            if item_cross > line_max_cross {
              line_max_cross = item_cross
            }
            line_item_count = line_item_count + 1
          }
        }
        // Add last line
        if line_item_count > 0 {
          lines_cross.push(line_max_cross)
        }
        // Sum all lines
        let mut sum = 0.0
        for line_cross in lines_cross {
          sum = sum + line_cross
        }
        sum
      }
      _ => {
        // No wrap or no available main: max of all cross sizes
        let mut max_cross = 0.0
        for i = 0; i < items.length(); i = i + 1 {
          let (_, item_cross) = items[i]
          if item_cross > max_cross {
            max_cross = item_cross
          }
        }
        max_cross
      }
    }

    // Add padding and border on cross axis
    if child_is_row {
      total_cross + padding.top + padding.bottom + border.top + border.bottom
    } else {
      total_cross + padding.left + padding.right + border.left + border.right
    }
  }
}

///|
/// Compute intrinsic main size for a grid container
fn compute_intrinsic_grid_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  dispatch : @node.DispatchFn,
) -> Double {
  // Use the layout dispatcher to compute Grid layout and get its size
  // For Grid containers as flex items, we need to compute actual layout
  // to determine intrinsic size
  let available_width = if parent_is_row {
    // Computing width - use max-content (large available)
    1.0e10
  } else {
    // Computing height - use available cross as width if provided
    match available_cross {
      Some(w) => w
      None => 1.0e10
    }
  }
  let available_height = if parent_is_row {
    // Computing width - height comes from available_cross
    available_cross
  } else {
    // Computing height - use max-content
    None
  }
  // When computing grid intrinsic height for column flex items and the cross size
  // (inline size) is known, treat that inline size as extrinsically definite so
  // percentage inline sizes inside grid resolve against the final cross size.
  let use_definite_for_column_height = !parent_is_row &&
    available_cross is Some(_)
  let ctx : @layout_types.LayoutContext = {
    available_width,
    available_height,
    sizing_mode: if use_definite_for_column_height {
      @layout_types.Definite
    } else {
      @layout_types.MaxContent
    },
    viewport_width: available_width,
    viewport_height: available_height.unwrap_or(0.0),
    stretch_width: use_definite_for_column_height,
    stretch_height: false,
  }
  let @node.DispatchFn(dispatch_fn) = dispatch
  let layout = dispatch_fn(node, ctx, dispatch)
  if parent_is_row {
    layout.width
  } else {
    layout.height
  }
}

///|
/// Compute intrinsic size for a block container
fn compute_intrinsic_block_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let children = node.children
  let available_width = match available_cross {
    Some(w) if !parent_is_row => w
    _ =>
      match style.width {
        @types.Length(w) => w
        _ => 0.0
      }
  }
  let resolved = node.resolved_rects(available_width)
  let padding = resolved.padding
  let border = resolved.border

  // For block layout, if parent is row, intrinsic width is max of children's widths
  // If parent is column, intrinsic height is sum of children's heights
  if parent_is_row {
    // Replaced-like block compatibility:
    // when inline size is auto/percent and cross size is definite, transfer
    // the cross size through aspect-ratio for intrinsic width contribution.
    let aspect_width_from_cross : Double? = match
      (style.width, style.height, style.aspect_ratio) {
      (@types.Auto, _, Some(ratio)) | (@types.Percent(_), _, Some(ratio)) =>
        if ratio > 0.0 {
          let raw_height : Double? = match style.height {
            @types.Length(h) => Some(h)
            @types.Percent(p) =>
              match available_cross {
                Some(cross) => Some(cross * p)
                None => None
              }
            @types.Calc(px, p) =>
              match available_cross {
                Some(cross) => Some(cross * p + px)
                None => None
              }
            @types.MathFn(__mop, __mterms) =>
              match available_cross {
                Some(cross) =>
                  Some(
                    @types.apply_math_op(
                      __mop,
                      __mterms.map(fn(__t) { cross * __t.1 + __t.0 }),
                    ),
                  )
                None => None
              }
            @types.Auto
            | @types.MinContent
            | @types.MaxContent
            | @types.FitContent(_) => available_cross
          }
          match raw_height {
            Some(h) => {
              let min_h = match style.min_height {
                @types.Length(v) => v
                @types.Percent(p) =>
                  match available_cross {
                    Some(cross) => cross * p
                    None => 0.0
                  }
                @types.Calc(_, p) =>
                  match available_cross {
                    Some(cross) => cross * p
                    None => 0.0
                  }
                @types.MathFn(__mop, __mterms) => {
                  let p = @types.apply_math_op(
                    __mop,
                    __mterms.map(fn(__t) { __t.1 }),
                  )
                  match available_cross {
                    Some(cross) => cross * p
                    None => 0.0
                  }
                }
                _ => 0.0
              }
              let max_h = match style.max_height {
                @types.Length(v) => v
                @types.Percent(p) =>
                  match available_cross {
                    Some(cross) => cross * p
                    None => @double.infinity
                  }
                _ => @double.infinity
              }
              let clamped_h = @types.clamp(h, min_h, max_h)
              if style.box_sizing is @types.BorderBox {
                Some(clamped_h * ratio)
              } else {
                let content_h = clamped_h -
                  padding.top -
                  padding.bottom -
                  border.top -
                  border.bottom
                if content_h > 0.0 {
                  Some(
                    content_h * ratio +
                    padding.left +
                    padding.right +
                    border.left +
                    border.right,
                  )
                } else {
                  Some(
                    padding.left + padding.right + border.left + border.right,
                  )
                }
              }
            }
            None => None
          }
        } else {
          None
        }
      _ => None
    }
    match aspect_width_from_cross {
      Some(w) => return w
      None => ()
    }

    // Children with percentage heights (or aspect-ratio transfer via stretch)
    // should resolve against this block's used content-box height when definite.
    let intrinsic_cross_for_children : Double? = match style.height {
      @types.Length(h) => {
        let content_h = if style.box_sizing is @types.BorderBox {
          h - padding.top - padding.bottom - border.top - border.bottom
        } else {
          h
        }
        Some(max(0.0, content_h))
      }
      @types.Percent(p) =>
        match available_cross {
          Some(cross) => {
            let resolved_h = cross * p
            let content_h = if style.box_sizing is @types.BorderBox {
              resolved_h -
              padding.top -
              padding.bottom -
              border.top -
              border.bottom
            } else {
              resolved_h
            }
            Some(max(0.0, content_h))
          }
          None => None
        }
      @types.Calc(_, p) =>
        match available_cross {
          Some(cross) => {
            let resolved_h = cross * p
            let content_h = if style.box_sizing is @types.BorderBox {
              resolved_h -
              padding.top -
              padding.bottom -
              border.top -
              border.bottom
            } else {
              resolved_h
            }
            Some(max(0.0, content_h))
          }
          None => None
        }
      @types.MathFn(__mop, __mterms) => {
        let p = @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.1 }))
        match available_cross {
          Some(cross) => {
            let resolved_h = cross * p
            let content_h = if style.box_sizing is @types.BorderBox {
              resolved_h -
              padding.top -
              padding.bottom -
              border.top -
              border.bottom
            } else {
              resolved_h
            }
            Some(max(0.0, content_h))
          }
          None => None
        }
      }
      @types.Auto
      | @types.MinContent
      | @types.MaxContent
      | @types.FitContent(_) => available_cross
    }

    if style.writing_mode.is_vertical() {
      // Vertical writing-mode inline flow advances horizontally by line/column.
      // For inline-only children, accumulate per-line max thickness and line breaks.
      let mut has_flow_child = false
      let mut only_inline_flow = true
      let mut inline_advance = 0.0
      let mut current_line_cross = 0.0
      for i = 0; i < children.length(); i = i + 1 {
        let child = children[i]
        let child_style = child.style
        if child_style.display is @types.Display::None {
          continue
        }
        if child_style.position is @types.Absolute ||
          child_style.position is @types.Fixed {
          continue
        }
        match child_style.float {
          @types.CssFloat::Left | @types.CssFloat::Right => continue
          @types.CssFloat::None => ()
        }
        has_flow_child = true
        if !@inline.is_inline_level(child_style.display) {
          only_inline_flow = false
          break
        }
        let child_resolved = child.resolved_rects(available_width)
        let child_margin = child_resolved.margin
        let child_width = match child_style.width {
          @types.Length(w) => w + child_margin.left + child_margin.right
          _ =>
            compute_intrinsic_main_size(
              child, true, intrinsic_cross_for_children, cache, dispatch,
            ) +
            child_margin.left +
            child_margin.right
        }
        if child.id == "br" {
          let line_cross = max(current_line_cross, child_width)
          inline_advance = inline_advance + line_cross
          current_line_cross = 0.0
        } else {
          current_line_cross = max(current_line_cross, child_width)
        }
      }
      if has_flow_child && only_inline_flow {
        let content_width = inline_advance + current_line_cross
        return content_width +
          padding.left +
          padding.right +
          border.left +
          border.right
      }
    } else {
      // Horizontal writing-mode inline flow advances on x-axis.
      // For inline-only children, intrinsic width is the max line advance.
      let mut has_flow_child = false
      let mut only_inline_flow = true
      let mut max_line_width = 0.0
      let mut current_line_width = 0.0
      for i = 0; i < children.length(); i = i + 1 {
        let child = children[i]
        let child_style = child.style
        if child_style.display is @types.Display::None {
          continue
        }
        if child_style.position is @types.Absolute ||
          child_style.position is @types.Fixed {
          continue
        }
        match child_style.float {
          @types.CssFloat::Left | @types.CssFloat::Right => continue
          @types.CssFloat::None => ()
        }
        has_flow_child = true
        if child.id == "br" {
          if current_line_width > max_line_width {
            max_line_width = current_line_width
          }
          current_line_width = 0.0
          continue
        }
        if !(child_style.display is @types.Contents) &&
          !@inline.is_inline_level(child_style.display) {
          only_inline_flow = false
          break
        }
        let child_resolved = child.resolved_rects(available_width)
        let child_margin = child_resolved.margin
        let child_width = match child_style.width {
          @types.Length(w) => w + child_margin.left + child_margin.right
          _ =>
            compute_intrinsic_main_size(
              child, true, intrinsic_cross_for_children, cache, dispatch,
            ) +
            child_margin.left +
            child_margin.right
        }
        current_line_width = current_line_width + child_width
      }
      if has_flow_child && only_inline_flow {
        let content_width = if current_line_width > max_line_width {
          current_line_width
        } else {
          max_line_width
        }
        return content_width +
          padding.left +
          padding.right +
          border.left +
          border.right
      }
    }
    // Compute intrinsic width
    let mut max_width = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display is @types.Display::None {
        continue
      }
      if child_style.position is @types.Absolute ||
        child_style.position is @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = child.resolved_rects(available_width)
      let child_margin = child_resolved.margin
      let child_width = match child_style.width {
        @types.Length(w) => w + child_margin.left + child_margin.right
        _ =>
          compute_intrinsic_main_size(
            child, true, intrinsic_cross_for_children, cache, dispatch,
          ) +
          child_margin.left +
          child_margin.right
      }
      max_width = max(max_width, child_width)
    }
    max_width + padding.left + padding.right + border.left + border.right
  } else {
    // Compute intrinsic height
    let ifc_height = match available_cross {
      Some(_) =>
        compute_inline_flow_height(node, available_width, cache, dispatch)
      None => None
    }
    match ifc_height {
      Some(h) => h + padding.top + padding.bottom + border.top + border.bottom
      None => {
        let mut total_height = 0.0
        for i = 0; i < children.length(); i = i + 1 {
          let child = children[i]
          let child_style = child.style
          if child_style.display is @types.Display::None {
            continue
          }
          if child_style.position is @types.Absolute ||
            child_style.position is @types.Fixed {
            continue
          }
          // Use cached resolved rects
          let child_resolved = child.resolved_rects(available_width)
          let child_margin = child_resolved.margin
          let child_is_table = child_style.display is @types.Table ||
            child_style.display is @types.InlineTable
          let child_height = match child_style.height {
            @types.Length(h) if !child_is_table =>
              h + child_margin.top + child_margin.bottom
            _ =>
              compute_intrinsic_main_size(
                child,
                false,
                Some(available_width),
                cache,
                dispatch,
              ) +
              child_margin.top +
              child_margin.bottom
          }
          total_height = total_height + child_height
        }
        total_height + padding.top + padding.bottom + border.top + border.bottom
      }
    }
  }
}
