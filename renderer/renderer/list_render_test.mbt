///|
// List renderer regressions.

///|
test "list_items_in_flex_columns_keep_available_line_width" {
  let html =
    #|<!DOCTYPE html><html><head><style>
    #|body { margin: 20px; background: #fff; font-family: Arial, sans-serif; font-size: 14px; color: #333; }
    #|h2 { font-size: 18px; margin: 0 0 8px; }
    #|ul, ol { margin: 0 0 16px; padding-left: 24px; }
    #|li { margin-bottom: 4px; line-height: 1.5; }
    #|.two-col { display: flex; gap: 40px; }
    #|.two-col > div { flex: 1; }
    #|</style></head><body>
    #|  <div class="two-col">
    #|    <div>
    #|      <h2>Features</h2>
    #|      <ul>
    #|        <li>Fast rendering engine</li>
    #|        <li>CSS Flexbox support</li>
    #|      </ul>
    #|    </div>
    #|    <div>
    #|      <h2>Steps</h2>
    #|      <ol>
    #|        <li>Install dependencies</li>
    #|      </ol>
    #|    </div>
    #|  </div>
    #|</body></html>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let two_col = layout.children[0]
  let left_col = two_col.children[0]
  let ul = left_col.children[1]
  let first_li = ul.children[0]
  let first_text = first_li.children[0]

  inspect(
    two_col.width,
    content=(
      #|760
    ),
  )
  guard first_li.height <= 25.0 else {
    fail("short list item should not wrap in a flex column")
  }
  guard first_text.width >= 130.0 else {
    fail("list item text should receive the column content width")
  }
}
