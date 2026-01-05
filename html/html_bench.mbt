// =============================================================================
// HTML Parser Benchmarks
// =============================================================================
// Benchmarks for measuring HTML parsing performance

// =============================================================================
// Test Data Generators
// =============================================================================

///|
/// Generate simple HTML with N elements
fn generate_simple_html(n : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<div>")
  for i = 0; i < n; i = i + 1 {
    buf.write_string("<p>Item ")
    buf.write_string(i.to_string())
    buf.write_string("</p>")
  }
  buf.write_string("</div>")
  buf.to_string()
}

///|
/// Generate nested HTML with depth D
fn generate_nested_html(depth : Int) -> String {
  let buf = StringBuilder::new()
  for i = 0; i < depth; i = i + 1 {
    buf.write_string("<div class=\"level-")
    buf.write_string(i.to_string())
    buf.write_string("\">")
  }
  buf.write_string("Content")
  for _i = 0; _i < depth; _i = _i + 1 {
    buf.write_string("</div>")
  }
  buf.to_string()
}

///|
/// Generate HTML with many attributes
fn generate_attribute_heavy_html(n : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<div>")
  for i = 0; i < n; i = i + 1 {
    buf.write_string("<div id=\"item-")
    buf.write_string(i.to_string())
    buf.write_string("\" class=\"card flex-item\" data-index=\"")
    buf.write_string(i.to_string())
    buf.write_string("\" data-type=\"content\" aria-label=\"Item ")
    buf.write_string(i.to_string())
    buf.write_string("\" style=\"width: 100px; height: 50px;\">")
    buf.write_string("Text ")
    buf.write_string(i.to_string())
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.to_string()
}

///|
/// Generate a table with R rows and C columns
fn generate_table_html(rows : Int, cols : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<table>")
  buf.write_string("<thead><tr>")
  for c = 0; c < cols; c = c + 1 {
    buf.write_string("<th>Header ")
    buf.write_string(c.to_string())
    buf.write_string("</th>")
  }
  buf.write_string("</tr></thead>")
  buf.write_string("<tbody>")
  for r = 0; r < rows; r = r + 1 {
    buf.write_string("<tr>")
    for c = 0; c < cols; c = c + 1 {
      buf.write_string("<td>Cell ")
      buf.write_string(r.to_string())
      buf.write_string("-")
      buf.write_string(c.to_string())
      buf.write_string("</td>")
    }
    buf.write_string("</tr>")
  }
  buf.write_string("</tbody>")
  buf.write_string("</table>")
  buf.to_string()
}

///|
/// Generate a complex page layout (header, nav, main, footer)
fn generate_page_layout(sidebar_items : Int, content_sections : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><head><title>Page</title></head><body>")

  // Header
  buf.write_string("<header><nav><ul>")
  for i = 0; i < 5; i = i + 1 {
    buf.write_string("<li><a href=\"#\">Link ")
    buf.write_string(i.to_string())
    buf.write_string("</a></li>")
  }
  buf.write_string("</ul></nav></header>")

  // Main with sidebar
  buf.write_string("<main><aside>")
  for i = 0; i < sidebar_items; i = i + 1 {
    buf.write_string("<div class=\"sidebar-item\">Sidebar ")
    buf.write_string(i.to_string())
    buf.write_string("</div>")
  }
  buf.write_string("</aside><article>")
  for s = 0; s < content_sections; s = s + 1 {
    buf.write_string("<section><h2>Section ")
    buf.write_string(s.to_string())
    buf.write_string("</h2>")
    for p = 0; p < 3; p = p + 1 {
      buf.write_string("<p>Paragraph ")
      buf.write_string(p.to_string())
      buf.write_string(" with <strong>bold</strong> and <em>italic</em> text.</p>")
    }
    buf.write_string("</section>")
  }
  buf.write_string("</article></main>")

  // Footer
  buf.write_string("<footer><p>Footer content</p></footer>")
  buf.write_string("</body></html>")
  buf.to_string()
}

///|
/// Generate HTML with inline styles (CSS in style attribute)
fn generate_styled_html(n : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<div style=\"display: flex; flex-direction: column;\">")
  for i = 0; i < n; i = i + 1 {
    buf.write_string(
      "<div style=\"display: flex; justify-content: space-between; padding: 10px; margin: 5px; border: 1px solid #ccc; background-color: #f5f5f5;\">",
    )
    buf.write_string("<span style=\"font-weight: bold; color: #333;\">Label ")
    buf.write_string(i.to_string())
    buf.write_string("</span>")
    buf.write_string(
      "<span style=\"color: #666; font-size: 14px;\">Value</span>",
    )
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.to_string()
}

///|
/// Generate HTML with script and style tags (to test extraction)
fn generate_resource_heavy_html(styles : Int, scripts : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><head>")
  for i = 0; i < styles; i = i + 1 {
    buf.write_string("<style>.class")
    buf.write_string(i.to_string())
    buf.write_string(" { color: red; background: blue; margin: 10px; padding: 5px; }</style>")
  }
  buf.write_string("</head><body>")
  buf.write_string("<div>Content</div>")
  for i = 0; i < scripts; i = i + 1 {
    buf.write_string("<script>console.log('script ")
    buf.write_string(i.to_string())
    buf.write_string("');</script>")
  }
  buf.write_string("</body></html>")
  buf.to_string()
}

///|
/// Generate form HTML with various input types
fn generate_form_html(fields : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<form action=\"/submit\" method=\"post\">")
  for i = 0; i < fields; i = i + 1 {
    let field_type = match i % 5 {
      0 => "text"
      1 => "email"
      2 => "password"
      3 => "number"
      _ => "tel"
    }
    buf.write_string("<div class=\"form-group\">")
    buf.write_string("<label for=\"field-")
    buf.write_string(i.to_string())
    buf.write_string("\">Field ")
    buf.write_string(i.to_string())
    buf.write_string("</label>")
    buf.write_string("<input type=\"")
    buf.write_string(field_type)
    buf.write_string("\" id=\"field-")
    buf.write_string(i.to_string())
    buf.write_string("\" name=\"field")
    buf.write_string(i.to_string())
    buf.write_string("\" placeholder=\"Enter value\" required>")
    buf.write_string("</div>")
  }
  buf.write_string("<button type=\"submit\">Submit</button>")
  buf.write_string("</form>")
  buf.to_string()
}

///|
/// Generate HTML with malformed/edge case content (for error recovery testing)
fn generate_malformed_html(n : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<div>")
  for i = 0; i < n; i = i + 1 {
    // Mix of well-formed and malformed
    match i % 4 {
      0 => {
        // Missing closing tag
        buf.write_string("<p>Unclosed paragraph ")
        buf.write_string(i.to_string())
      }
      1 => {
        // Self-closing in wrong place
        buf.write_string("<div/>Text ")
        buf.write_string(i.to_string())
      }
      2 => {
        // Nested improperly
        buf.write_string("<b><i>Bold italic ")
        buf.write_string(i.to_string())
        buf.write_string("</b></i>")
      }
      _ => {
        // Well-formed
        buf.write_string("<span>Normal ")
        buf.write_string(i.to_string())
        buf.write_string("</span>")
      }
    }
  }
  buf.write_string("</div>")
  buf.to_string()
}

// =============================================================================
// Parse Benchmarks
// =============================================================================

///|
test "bench_parse_simple_10" (b : @bench.T) {
  let html = generate_simple_html(10)
  b.bench(name="parse_simple_10", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_simple_100" (b : @bench.T) {
  let html = generate_simple_html(100)
  b.bench(name="parse_simple_100", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_simple_500" (b : @bench.T) {
  let html = generate_simple_html(500)
  b.bench(name="parse_simple_500", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_simple_1000" (b : @bench.T) {
  let html = generate_simple_html(1000)
  b.bench(name="parse_simple_1000", fn() { b.keep(parse(html)) })
}

// =============================================================================
// Nested Structure Benchmarks
// =============================================================================

///|
test "bench_parse_nested_10" (b : @bench.T) {
  let html = generate_nested_html(10)
  b.bench(name="parse_nested_10", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_nested_50" (b : @bench.T) {
  let html = generate_nested_html(50)
  b.bench(name="parse_nested_50", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_nested_100" (b : @bench.T) {
  let html = generate_nested_html(100)
  b.bench(name="parse_nested_100", fn() { b.keep(parse(html)) })
}

// =============================================================================
// Attribute-Heavy Benchmarks
// =============================================================================

///|
test "bench_parse_attrs_50" (b : @bench.T) {
  let html = generate_attribute_heavy_html(50)
  b.bench(name="parse_attrs_50", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_attrs_200" (b : @bench.T) {
  let html = generate_attribute_heavy_html(200)
  b.bench(name="parse_attrs_200", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_attrs_500" (b : @bench.T) {
  let html = generate_attribute_heavy_html(500)
  b.bench(name="parse_attrs_500", fn() { b.keep(parse(html)) })
}

// =============================================================================
// Table Benchmarks
// =============================================================================

///|
test "bench_parse_table_10x5" (b : @bench.T) {
  let html = generate_table_html(10, 5)
  b.bench(name="parse_table_10x5", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_table_50x10" (b : @bench.T) {
  let html = generate_table_html(50, 10)
  b.bench(name="parse_table_50x10", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_table_100x20" (b : @bench.T) {
  let html = generate_table_html(100, 20)
  b.bench(name="parse_table_100x20", fn() { b.keep(parse(html)) })
}

// =============================================================================
// Page Layout Benchmarks
// =============================================================================

///|
test "bench_parse_page_small" (b : @bench.T) {
  let html = generate_page_layout(5, 3)
  b.bench(name="parse_page_small", fn() { b.keep(parse_document(html)) })
}

///|
test "bench_parse_page_medium" (b : @bench.T) {
  let html = generate_page_layout(15, 10)
  b.bench(name="parse_page_medium", fn() { b.keep(parse_document(html)) })
}

///|
test "bench_parse_page_large" (b : @bench.T) {
  let html = generate_page_layout(30, 20)
  b.bench(name="parse_page_large", fn() { b.keep(parse_document(html)) })
}

// =============================================================================
// Styled HTML Benchmarks (CSS in style attributes)
// =============================================================================

///|
test "bench_parse_styled_50" (b : @bench.T) {
  let html = generate_styled_html(50)
  b.bench(name="parse_styled_50", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_styled_200" (b : @bench.T) {
  let html = generate_styled_html(200)
  b.bench(name="parse_styled_200", fn() { b.keep(parse(html)) })
}

// =============================================================================
// Resource Extraction Benchmarks
// =============================================================================

///|
test "bench_parse_resources_10" (b : @bench.T) {
  let html = generate_resource_heavy_html(10, 10)
  b.bench(name="parse_resources_10", fn() { b.keep(parse_document(html)) })
}

///|
test "bench_parse_resources_50" (b : @bench.T) {
  let html = generate_resource_heavy_html(50, 50)
  b.bench(name="parse_resources_50", fn() { b.keep(parse_document(html)) })
}

// =============================================================================
// Form Benchmarks
// =============================================================================

///|
test "bench_parse_form_10" (b : @bench.T) {
  let html = generate_form_html(10)
  b.bench(name="parse_form_10", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_form_50" (b : @bench.T) {
  let html = generate_form_html(50)
  b.bench(name="parse_form_50", fn() { b.keep(parse(html)) })
}

// =============================================================================
// Error Recovery Benchmarks
// =============================================================================

///|
test "bench_parse_malformed_50" (b : @bench.T) {
  let html = generate_malformed_html(50)
  b.bench(name="parse_malformed_50", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_malformed_200" (b : @bench.T) {
  let html = generate_malformed_html(200)
  b.bench(name="parse_malformed_200", fn() { b.keep(parse(html)) })
}

// =============================================================================
// Fragment Parse Benchmarks
// =============================================================================

///|
test "bench_parse_fragment_simple" (b : @bench.T) {
  let html = "<p>Simple paragraph with <strong>bold</strong> text</p>"
  b.bench(name="parse_frag_simple", fn() { b.keep(parse_fragment(html)) })
}

///|
test "bench_parse_fragment_list" (b : @bench.T) {
  let buf = StringBuilder::new()
  buf.write_string("<ul>")
  for i = 0; i < 20; i = i + 1 {
    buf.write_string("<li>Item ")
    buf.write_string(i.to_string())
    buf.write_string("</li>")
  }
  buf.write_string("</ul>")
  let html = buf.to_string()
  b.bench(name="parse_frag_list", fn() { b.keep(parse_fragment(html)) })
}

// =============================================================================
// Real-World HTML Snippets
// =============================================================================

///|
fn generate_card_grid(cards : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "<div class=\"grid\" style=\"display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px;\">",
  )
  for i = 0; i < cards; i = i + 1 {
    buf.write_string("<div class=\"card\" style=\"padding: 16px; border: 1px solid #ddd; border-radius: 8px;\">")
    buf.write_string(
      "<img src=\"/img/")
    buf.write_string(i.to_string())
    buf.write_string(".jpg\" alt=\"Card image\" style=\"width: 100%; height: 150px;\">")
    buf.write_string("<h3 style=\"margin: 12px 0 8px;\">Card Title ")
    buf.write_string(i.to_string())
    buf.write_string("</h3>")
    buf.write_string("<p style=\"color: #666; font-size: 14px;\">Card description goes here.</p>")
    buf.write_string("<button style=\"padding: 8px 16px; background: #007bff; color: white; border: none; border-radius: 4px;\">Action</button>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.to_string()
}

///|
test "bench_parse_card_grid_12" (b : @bench.T) {
  let html = generate_card_grid(12)
  b.bench(name="parse_card_12", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_card_grid_48" (b : @bench.T) {
  let html = generate_card_grid(48)
  b.bench(name="parse_card_48", fn() { b.keep(parse(html)) })
}

///|
test "bench_parse_card_grid_100" (b : @bench.T) {
  let html = generate_card_grid(100)
  b.bench(name="parse_card_100", fn() { b.keep(parse(html)) })
}

// =============================================================================
// Tokenizer Only Benchmarks (measure tokenization speed)
// =============================================================================

///|
test "bench_tokenize_simple_100" (b : @bench.T) {
  let html = generate_simple_html(100)
  b.bench(name="tokenize_100", fn() {
    let tokenizer = Tokenizer::new(html)
    while true {
      match tokenizer.next_token() {
        EOF => break
        _ => ()
      }
    }
    b.keep(tokenizer)
  })
}

///|
test "bench_tokenize_attrs_100" (b : @bench.T) {
  let html = generate_attribute_heavy_html(100)
  b.bench(name="tokenize_attrs_100", fn() {
    let tokenizer = Tokenizer::new(html)
    while true {
      match tokenizer.next_token() {
        EOF => break
        _ => ()
      }
    }
    b.keep(tokenizer)
  })
}

///|
test "bench_tokenize_styled_100" (b : @bench.T) {
  let html = generate_styled_html(100)
  b.bench(name="tokenize_styled_100", fn() {
    let tokenizer = Tokenizer::new(html)
    while true {
      match tokenizer.next_token() {
        EOF => break
        _ => ()
      }
    }
    b.keep(tokenizer)
  })
}

// =============================================================================
// Large Document Benchmarks
// =============================================================================

///|
fn generate_large_document(sections : Int, paragraphs_per_section : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><head><title>Large Document</title>")
  buf.write_string("<style>body { font-family: sans-serif; }</style>")
  buf.write_string("</head><body>")
  buf.write_string("<header><h1>Large Document</h1></header>")
  buf.write_string("<main>")
  for s = 0; s < sections; s = s + 1 {
    buf.write_string("<section id=\"section-")
    buf.write_string(s.to_string())
    buf.write_string("\">")
    buf.write_string("<h2>Section ")
    buf.write_string(s.to_string())
    buf.write_string("</h2>")
    for p = 0; p < paragraphs_per_section; p = p + 1 {
      buf.write_string(
        "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.</p>",
      )
    }
    buf.write_string("</section>")
  }
  buf.write_string("</main>")
  buf.write_string("<footer><p>Footer</p></footer>")
  buf.write_string("</body></html>")
  buf.to_string()
}

///|
test "bench_parse_large_doc_10x5" (b : @bench.T) {
  let html = generate_large_document(10, 5)
  b.bench(name="parse_large_10x5", fn() { b.keep(parse_document(html)) })
}

///|
test "bench_parse_large_doc_50x10" (b : @bench.T) {
  let html = generate_large_document(50, 10)
  b.bench(name="parse_large_50x10", fn() { b.keep(parse_document(html)) })
}

///|
test "bench_parse_large_doc_100x20" (b : @bench.T) {
  let html = generate_large_document(100, 20)
  b.bench(name="parse_large_100x20", fn() { b.keep(parse_document(html)) })
}

// =============================================================================
// TreeBuilder Direct Benchmarks
// =============================================================================

///|
test "bench_treebuilder_simple_100" (b : @bench.T) {
  let html = generate_simple_html(100)
  b.bench(name="treebuilder_100", fn() {
    let tokenizer = Tokenizer::new(html)
    let builder = TreeBuilder::new(tokenizer)
    b.keep(builder.build())
  })
}

///|
test "bench_treebuilder_nested_50" (b : @bench.T) {
  let html = generate_nested_html(50)
  b.bench(name="treebuilder_nested_50", fn() {
    let tokenizer = Tokenizer::new(html)
    let builder = TreeBuilder::new(tokenizer)
    b.keep(builder.build())
  })
}

///|
test "bench_treebuilder_malformed_100" (b : @bench.T) {
  let html = generate_malformed_html(100)
  b.bench(name="treebuilder_malformed", fn() {
    let tokenizer = Tokenizer::new(html)
    let builder = TreeBuilder::new(tokenizer)
    b.keep(builder.build())
  })
}
