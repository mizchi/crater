///|
fn has_property_change(
  diff : PaintTreeDiff,
  node_id : String,
  property : String,
) -> Bool {
  for change in diff.changes {
    if change.node_id == node_id && change.property == property {
      return true
    }
  }
  false
}

///|
fn make_text_node(
  text : String,
  bold : Bool,
  underline : Bool,
  line_through : Bool,
  overline : Bool,
) -> PaintNode {
  PaintNode::new(
    "#text",
    "#text",
    0.0,
    0.0,
    64.0,
    16.0,
    {
      ..PaintProperties::default(),
      is_bold: bold,
      text_decoration_underline: underline,
      text_decoration_line_through: line_through,
      text_decoration_overline: overline,
    },
    [],
    text=Some(text),
  )
}

///|
test "diff_trees reports paint property changes and layout shifts" {
  let before = PaintNode::new(
    "body",
    "body",
    0.0,
    0.0,
    200.0,
    120.0,
    PaintProperties::default(),
    [
      PaintNode::new(
        "div.card",
        "div",
        10.0,
        20.0,
        100.0,
        50.0,
        {
          ..PaintProperties::default(),
          background_color: @types.Color::rgb(240, 240, 240),
        },
        [make_text_node("Hello", false, false, false, false)],
      ),
    ],
  )
  let after = PaintNode::new(
    "body",
    "body",
    0.0,
    0.0,
    200.0,
    120.0,
    PaintProperties::default(),
    [
      PaintNode::new(
        "div.card",
        "div",
        14.0,
        20.0,
        100.0,
        60.0,
        {
          ..PaintProperties::default(),
          background_color: @types.Color::rgb(255, 0, 0),
        },
        [make_text_node("Hello", true, true, true, true)],
      ),
    ],
  )

  let diff = diff_trees(before, after)
  inspect(diff.layout_shifts.length(), content="1")
  inspect(
    has_property_change(diff, "div.card", "background_color"),
    content="true",
  )
  inspect(has_property_change(diff, "#text", "is_bold"), content="true")
  inspect(
    has_property_change(diff, "#text", "text_decoration_underline"),
    content="true",
  )
  inspect(
    has_property_change(diff, "#text", "text_decoration_line_through"),
    content="true",
  )
  inspect(
    has_property_change(diff, "#text", "text_decoration_overline"),
    content="true",
  )
}
