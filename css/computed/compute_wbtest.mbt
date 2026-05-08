///|
test "resolve_all_vars replaces embedded grid track custom property" {
  let ctx : ComputeContext = {
    ..ComputeContext::with_viewport(800.0, 600.0),
    custom_properties: { "--content": "48rem" },
  }
  let resolved = resolve_all_vars(
    "16px 1fr minmax(0, var(--content)) 1fr 16px", ctx,
  )
  inspect(resolved, content="16px 1fr minmax(0, 48rem) 1fr 16px")
}

///|
test "normalize_grid_template_math_functions does not rewrite minmax" {
  let ctx = ComputeContext::with_viewport(800.0, 600.0)
  let resolved = normalize_grid_template_math_functions(
    "16px 1fr minmax(0, 48rem) 1fr max(1rem, calc(50vw - 720px + 1rem))", ctx,
  )
  inspect(resolved, content="16px 1fr minmax(0, 48rem) 1fr 16px")
}
