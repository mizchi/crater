///|
/// Regression for #64: a non-`none` `filter` (e.g. `filter: blur(0)`, surfaced
/// as `has_filter`) must make an inline-level box a containing block for
/// absolutely positioned descendants. The failing WPT cases were the
/// `filter-cb-abspos-inline-*` fixtures, so this pins the rule at its source
/// (`inline_establishes_abs_containing_block`).
test "filter_establishes_inline_abs_containing_block" {
  let base = { ..@style.Style::default(), display: @types.Inline }
  // A plain inline box is not an abs containing block.
  inspect(inline_establishes_abs_containing_block(base), content="false")
  // A non-none filter flips has_filter and must establish the CB.
  let filtered = { ..base, has_filter: true }
  inspect(inline_establishes_abs_containing_block(filtered), content="true")
}
