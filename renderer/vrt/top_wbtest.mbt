///|
test "vrt mutations_to_css generates valid css" {
  let mutations : Array[CssMutation] = [
    {
      selector: ".card",
      property: "padding",
      action: CssMutationAction::Remove,
    },
    {
      selector: ".card",
      property: "color",
      action: CssMutationAction::Override("blue"),
    },
  ]
  let css = mutations_to_css(mutations)
  assert_true(css.contains(".card"))
  assert_true(css.contains("padding: unset !important"))
  assert_true(css.contains("color: blue !important"))
}
