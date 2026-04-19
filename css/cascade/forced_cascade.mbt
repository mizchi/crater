///|
/// Cascade styles for an element with forced pseudo-class states.
/// This evaluates CSS rules as if the specified pseudo-class states
/// (:hover, :focus, :active) were active on the element.
pub fn cascade_element_with_forced_states(
  element : @selector.Element,
  stylesheets : Array[Stylesheet],
  inline_style : Array[Declaration],
  media_env : @media.MediaEnvironment?,
  forced : @selector.ForcedPseudoStates,
) -> CascadedValues {
  let result = CascadedValues::new()
  let mut source_order_offset = 0
  for stylesheet in stylesheets {
    let max_source_order = cascade_stylesheet_forced_into(
      result, stylesheet, element, media_env, forced, source_order_offset,
    )
    if max_source_order >= source_order_offset {
      source_order_offset = max_source_order + 1
    }
  }
  for decl in inline_style {
    accumulate_inline_declaration(result, decl)
  }
  result
}

///|
fn cascade_stylesheet_forced_into(
  result : CascadedValues,
  stylesheet : Stylesheet,
  element : @selector.Element,
  media_env : @media.MediaEnvironment?,
  forced : @selector.ForcedPseudoStates,
  source_order_offset : Int,
) -> Int {
  let mut max_source_order_in_sheet = source_order_offset - 1
  for rule in stylesheet.rules {
    let media_matches = match (rule.media_query, media_env) {
      (Some(mq), Some(env)) => mq.evaluate(env)
      (Some(_), None) => true
      (None, _) => true
    }
    if !media_matches {
      continue
    }
    if @selector.matches_complex_with_forced_states(
        element,
        rule.selector,
        forced,
      ) {
      let specificity = @selector.complex_specificity(rule.selector)
      for decl in rule.declarations {
        let adjusted_source_order = source_order_offset +
          rule.source_order * 10000 +
          decl.source_order
        if adjusted_source_order > max_source_order_in_sheet {
          max_source_order_in_sheet = adjusted_source_order
        }
        accumulate_cascaded_declaration(result, {
          property: decl.property,
          value: decl.value,
          origin: stylesheet.origin,
          importance: decl.importance,
          specificity,
          source_order: adjusted_source_order,
        })
      }
    }
  }
  max_source_order_in_sheet
}
