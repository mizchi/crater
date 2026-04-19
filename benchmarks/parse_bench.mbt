// =============================================================================
// Parse Speed Benchmarks
// =============================================================================
// Measures HTML parsing and document construction time

// =============================================================================
// Simple Pattern Parse Benchmarks
// =============================================================================

///|
test "bench_parse_flat_100" (b : @bench.T) {
  let html = simple_flat(100)
  b.bench(name="parse_flat_100", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_flat_500" (b : @bench.T) {
  let html = simple_flat(500)
  b.bench(name="parse_flat_500", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_flat_1000" (b : @bench.T) {
  let html = simple_flat(1000)
  b.bench(name="parse_flat_1000", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_nested_20" (b : @bench.T) {
  let html = nested_depth(20)
  b.bench(name="parse_nested_20", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_nested_50" (b : @bench.T) {
  let html = nested_depth(50)
  b.bench(name="parse_nested_50", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_nested_100" (b : @bench.T) {
  let html = nested_depth(100)
  b.bench(name="parse_nested_100", fn() { b.keep(@html.parse_document(html)) })
}

// =============================================================================
// Flexbox Pattern Parse Benchmarks
// =============================================================================

///|
test "bench_parse_flex_row_50" (b : @bench.T) {
  let html = flex_row(50)
  b.bench(name="parse_flex_row_50", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_flex_column_100" (b : @bench.T) {
  let html = flex_column(100)
  b.bench(name="parse_flex_col_100", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_flex_wrap_100" (b : @bench.T) {
  let html = flex_wrap(100, 150)
  b.bench(name="parse_flex_wrap_100", fn() {
    b.keep(@html.parse_document(html))
  })
}

///|
test "bench_parse_flex_nested_d5" (b : @bench.T) {
  let html = flex_nested(5, 3)
  b.bench(name="parse_flex_nest_d5", fn() { b.keep(@html.parse_document(html)) })
}

// =============================================================================
// Grid Pattern Parse Benchmarks
// =============================================================================

///|
test "bench_parse_grid_10x10" (b : @bench.T) {
  let html = grid_simple(10, 10)
  b.bench(name="parse_grid_10x10", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_grid_20x5" (b : @bench.T) {
  let html = grid_simple(20, 5)
  b.bench(name="parse_grid_20x5", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_grid_explicit" (b : @bench.T) {
  let html = grid_explicit(10, 6, 50)
  b.bench(name="parse_grid_explicit", fn() {
    b.keep(@html.parse_document(html))
  })
}

// =============================================================================
// Complex Pattern Parse Benchmarks
// =============================================================================

///|
test "bench_parse_card_grid_24" (b : @bench.T) {
  let html = card_grid(24)
  b.bench(name="parse_cards_24", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_card_grid_48" (b : @bench.T) {
  let html = card_grid(48)
  b.bench(name="parse_cards_48", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_dashboard" (b : @bench.T) {
  let html = dashboard(15, 12)
  b.bench(name="parse_dashboard", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_chat_100" (b : @bench.T) {
  let html = chat_messages(100)
  b.bench(name="parse_chat_100", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_table_50x8" (b : @bench.T) {
  let html = table_layout(50, 8)
  b.bench(name="parse_table_50x8", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_form_20" (b : @bench.T) {
  let html = form_fields(20)
  b.bench(name="parse_form_20", fn() { b.keep(@html.parse_document(html)) })
}

// =============================================================================
// Large Scale Parse Benchmarks
// =============================================================================

///|
test "bench_parse_large_website_small" (b : @bench.T) {
  // ~1000 nodes
  let html = large_website(10, 5, 4)
  b.bench(name="parse_large_1k", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_large_website_medium" (b : @bench.T) {
  // ~2500 nodes
  let html = large_website(15, 10, 8)
  b.bench(name="parse_large_2k5", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_large_website_large" (b : @bench.T) {
  // ~5000 nodes
  let html = large_website(20, 20, 10)
  b.bench(name="parse_large_5k", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_scrollable_500" (b : @bench.T) {
  let html = scrollable_list(500, 64)
  b.bench(name="parse_scroll_500", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_scrollable_1000" (b : @bench.T) {
  let html = scrollable_list(1000, 64)
  b.bench(name="parse_scroll_1000", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_deep_nest_30" (b : @bench.T) {
  let html = deep_nesting(30, 5)
  b.bench(name="parse_deep_30", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_parse_deep_nest_50" (b : @bench.T) {
  let html = deep_nesting(50, 3)
  b.bench(name="parse_deep_50", fn() { b.keep(@html.parse_document(html)) })
}
