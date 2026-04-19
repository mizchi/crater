///|
test "font shorthand applies font-family and font-weight" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("font: bold 20px/1 Ahem", ctx)

  inspect(style.font_size, content="20")
  inspect(style.line_height, content="20")
  inspect(style.font_weight, content="700")
  inspect(style.font_family, content="ahem")
}

///|
test "later font shorthand resets earlier font longhands" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "font-weight: bold; font-family: serif; font: 10px/1 monospace", ctx,
  )

  inspect(style.font_size, content="10")
  inspect(style.line_height, content="10")
  inspect(style.font_weight, content="400")
  inspect(style.font_family, content="monospace")
}

///|
test "later font longhands override earlier shorthand values" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "font: 10px/1 monospace; font-weight: bold; font-family: serif", ctx,
  )

  inspect(style.font_size, content="10")
  inspect(style.line_height, content="10")
  inspect(style.font_weight, content="700")
  inspect(style.font_family, content="serif")
}
