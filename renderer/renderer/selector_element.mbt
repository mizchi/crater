///|
// HTML element to CSS selector element conversion helpers.

///|
/// Convert HTML Element to Selector Element
fn html_to_selector_element(
  elem : @html.Element,
  parent : @css.Element?,
) -> @css.Element {
  let mut sel_elem = @css.Element::new(elem.tag)

  // Set ID
  match elem.id {
    Some(id) => sel_elem = sel_elem.set_id(id)
    None => ()
  }

  // Set classes
  for cls in elem.classes {
    sel_elem = sel_elem.add_class(cls)
  }

  // Set attributes
  elem.attributes.each(fn(name, value) {
    if name != crater_dom_id_attr {
      sel_elem = sel_elem.set_attribute(name, value)
    }
  })

  // Set parent
  match parent {
    Some(p) => sel_elem = sel_elem.set_parent(p)
    None => ()
  }
  sel_elem
}

///|
fn html_to_selector_element_minimal(
  elem : @html.Element,
  parent : @css.Element?,
) -> @css.Element {
  let mut sel_elem = @css.Element::new(elem.tag)
  match elem.id {
    Some(id) => sel_elem = sel_elem.set_id(id)
    None => ()
  }
  for cls in elem.classes {
    sel_elem = sel_elem.add_class(cls)
  }
  // Copy presentational HTML attributes needed for UA styling
  elem.attributes.each(fn(name, value) {
    if name != crater_dom_id_attr {
      sel_elem = sel_elem.set_attribute(name, value)
    }
  })
  match parent {
    Some(p) => sel_elem = sel_elem.set_parent(p)
    None => ()
  }
  sel_elem
}

///|
/// Convert HTML Element to Selector Element with parent and sibling info
fn html_to_selector_element_with_parent(
  elem : @html.Element,
  parent : @css.Element,
  sibling_index : Int,
  sibling_count : Int,
  prev_sibling : @css.Element?,
) -> @css.Element {
  let mut sel_elem = @css.Element::new(elem.tag)

  // Set ID
  match elem.id {
    Some(id) => sel_elem = sel_elem.set_id(id)
    None => ()
  }

  // Set classes
  for cls in elem.classes {
    sel_elem = sel_elem.add_class(cls)
  }

  // Set attributes
  elem.attributes.each(fn(name, value) {
    if name != crater_dom_id_attr {
      sel_elem = sel_elem.set_attribute(name, value)
    }
  })

  // Set parent and sibling info
  sel_elem = sel_elem.set_parent(parent)
  sel_elem = sel_elem.set_sibling_info(sibling_index, sibling_count)
  sel_elem = { ..sel_elem, prev_sibling, }
  sel_elem
}
