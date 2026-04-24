///|
test "font aware text provider is used for generic and named families" {
  assert_true(should_use_font_aware_text_provider("serif"))
  assert_true(should_use_font_aware_text_provider("sans-serif"))
  assert_true(should_use_font_aware_text_provider("monospace"))
  assert_true(should_use_font_aware_text_provider("Times New Roman"))
  assert_true(should_use_font_aware_text_provider("\"Georgia\", serif"))
}

///|
test "font aware text provider skips empty and inherited keywords" {
  assert_false(should_use_font_aware_text_provider(""))
  assert_false(should_use_font_aware_text_provider("   "))
  assert_false(should_use_font_aware_text_provider("inherit"))
  assert_false(should_use_font_aware_text_provider("initial"))
  assert_false(should_use_font_aware_text_provider("unset"))
  assert_false(should_use_font_aware_text_provider("revert"))
  assert_false(should_use_font_aware_text_provider("revert-layer"))
}
