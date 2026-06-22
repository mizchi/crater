///|
/// Regression for #64: a non-`none` `filter` (e.g. `filter: blur(0)`, surfaced
/// as `has_filter`) must make a statically positioned block a containing block
/// for absolutely positioned descendants, exactly like `transform`. This pins
/// the rule at its source (`establishes_abs_containing_block`) so it cannot
/// quietly regress.
test "filter_establishes_abs_containing_block" {
  let base = @style.Style::default()
  // A plain static block is not an abs containing block.
  inspect(establishes_abs_containing_block(base, base.display), content="false")
  // A non-none filter flips has_filter and must establish the CB.
  let filtered = { ..base, has_filter: true }
  inspect(
    establishes_abs_containing_block(filtered, filtered.display),
    content="true",
  )
  // The filter rule is independent of transform: dropping it would regress the
  // filter-cb-abspos WPT cases even while transform still works.
  let transformed = { ..base, has_filter: false }
  inspect(
    establishes_abs_containing_block(transformed, transformed.display),
    content="false",
  )
}
