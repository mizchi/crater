// =============================================================================
// HTML Patterns for Benchmarks
// =============================================================================
// Various HTML patterns to test parsing, rendering, and incremental paint

// =============================================================================
// Simple Patterns
// =============================================================================

///|
/// Simple flat list of divs
pub fn simple_flat(n : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  for i = 0; i < n; i = i + 1 {
    buf.write_string("<div style=\"height:20px;background:#")
    buf.write_string(if i % 2 == 0 { "eee" } else { "ddd" })
    buf.write_string("\">Item ")
    buf.write_string(i.to_string())
    buf.write_string("</div>")
  }
  buf.write_string("</body></html>")
  buf.to_string()
}

///|
/// Nested divs (depth-first)
pub fn nested_depth(depth : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  for i = 0; i < depth; i = i + 1 {
    buf.write_string("<div style=\"padding:5px;border:1px solid #ccc\">")
  }
  buf.write_string("Content")
  for _i = 0; _i < depth; _i = _i + 1 {
    buf.write_string("</div>")
  }
  buf.write_string("</body></html>")
  buf.to_string()
}

// =============================================================================
// Flexbox Patterns
// =============================================================================

///|
/// Flex row with N items
pub fn flex_row(n : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "<!DOCTYPE html><html><body style=\"margin:0\"><div style=\"display:flex;flex-direction:row\">",
  )
  for i = 0; i < n; i = i + 1 {
    buf.write_string("<div style=\"flex:1;height:50px;background:#")
    buf.write_string(if i % 2 == 0 { "e0e0e0" } else { "d0d0d0" })
    buf.write_string("\">")
    buf.write_string(i.to_string())
    buf.write_string("</div>")
  }
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
/// Flex column with N items
pub fn flex_column(n : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "<!DOCTYPE html><html><body style=\"margin:0\"><div style=\"display:flex;flex-direction:column\">",
  )
  for i = 0; i < n; i = i + 1 {
    buf.write_string("<div style=\"height:30px;background:#")
    buf.write_string(if i % 2 == 0 { "e0e0e0" } else { "d0d0d0" })
    buf.write_string("\">Row ")
    buf.write_string(i.to_string())
    buf.write_string("</div>")
  }
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
/// Flex wrap with many items
pub fn flex_wrap(n : Int, item_width : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "<!DOCTYPE html><html><body style=\"margin:0\"><div style=\"display:flex;flex-wrap:wrap\">",
  )
  for i = 0; i < n; i = i + 1 {
    buf.write_string("<div style=\"width:")
    buf.write_string(item_width.to_string())
    buf.write_string("px;height:50px;background:#")
    buf.write_string(if i % 2 == 0 { "e0e0e0" } else { "d0d0d0" })
    buf.write_string("\">")
    buf.write_string(i.to_string())
    buf.write_string("</div>")
  }
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
/// Nested flex containers
pub fn flex_nested(depth : Int, items_per_level : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  fn build(d : Int, is_row : Bool) -> Unit {
    if d == 0 {
      buf.write_string(
        "<div style=\"width:30px;height:20px;background:#ddd\"></div>",
      )
      return
    }
    buf.write_string("<div style=\"display:flex;flex-direction:")
    buf.write_string(if is_row { "row" } else { "column" })
    buf.write_string("\">")
    for _i = 0; _i < items_per_level; _i = _i + 1 {
      build(d - 1, not(is_row))
    }
    buf.write_string("</div>")
  }

  build(depth, true)
  buf.write_string("</body></html>")
  buf.to_string()
}

// =============================================================================
// Grid Patterns
// =============================================================================

///|
/// Simple grid with rows x cols
pub fn grid_simple(rows : Int, cols : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string("<div style=\"display:grid;grid-template-columns:repeat(")
  buf.write_string(cols.to_string())
  buf.write_string(",1fr);gap:5px\">")
  for i = 0; i < rows * cols; i = i + 1 {
    buf.write_string("<div style=\"height:50px;background:#")
    buf.write_string(if i % 2 == 0 { "e0e0e0" } else { "d0d0d0" })
    buf.write_string("\">")
    buf.write_string(i.to_string())
    buf.write_string("</div>")
  }
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
/// Grid with explicit template rows and columns
pub fn grid_explicit(rows : Int, cols : Int, cell_height : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string("<div style=\"display:grid;grid-template-columns:")
  for _c = 0; _c < cols; _c = _c + 1 {
    buf.write_string("100px ")
  }
  buf.write_string(";grid-template-rows:")
  for _r = 0; _r < rows; _r = _r + 1 {
    buf.write_string(cell_height.to_string())
    buf.write_string("px ")
  }
  buf.write_string(";gap:2px\">")
  for i = 0; i < rows * cols; i = i + 1 {
    buf.write_string("<div style=\"background:#ccc\">")
    buf.write_string(i.to_string())
    buf.write_string("</div>")
  }
  buf.write_string("</div></body></html>")
  buf.to_string()
}

// =============================================================================
// Complex Patterns (Real-world like)
// =============================================================================

///|
/// Card grid (e-commerce style)
pub fn card_grid(num_cards : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string(
    "<div style=\"display:flex;flex-wrap:wrap;gap:16px;padding:16px\">",
  )
  for i = 0; i < num_cards; i = i + 1 {
    buf.write_string(
      "<div style=\"width:280px;border:1px solid #ddd;border-radius:8px;overflow:hidden\">",
    )
    // Image placeholder
    buf.write_string("<div style=\"height:160px;background:#f0f0f0\"></div>")
    // Content
    buf.write_string("<div style=\"padding:12px\">")
    buf.write_string(
      "<div style=\"height:20px;background:#333;margin-bottom:8px\"></div>",
    )
    buf.write_string(
      "<div style=\"height:40px;background:#666;margin-bottom:8px\"></div>",
    )
    // Price and button row
    buf.write_string(
      "<div style=\"display:flex;justify-content:space-between;align-items:center\">",
    )
    buf.write_string(
      "<div style=\"width:60px;height:24px;background:#e74c3c\"></div>",
    )
    buf.write_string(
      "<div style=\"width:100px;height:32px;background:#3498db;border-radius:4px\"></div>",
    )
    buf.write_string("</div>")
    buf.write_string("</div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
/// Dashboard layout with sidebar, header, and content
pub fn dashboard(sidebar_items : Int, content_cards : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string("<div style=\"display:flex;height:100vh\">")
  // Sidebar
  buf.write_string(
    "<div style=\"width:240px;background:#2c3e50;display:flex;flex-direction:column\">",
  )
  buf.write_string(
    "<div style=\"height:60px;background:#1a252f;display:flex;align-items:center;padding:0 16px\">",
  )
  buf.write_string(
    "<div style=\"width:120px;height:30px;background:#3498db\"></div>",
  )
  buf.write_string("</div>")
  for i = 0; i < sidebar_items; i = i + 1 {
    buf.write_string(
      "<div style=\"height:44px;display:flex;align-items:center;padding:0 16px;margin:4px 8px;border-radius:4px;background:",
    )
    buf.write_string(if i == 0 { "#3498db" } else { "transparent" })
    buf.write_string("\">")
    buf.write_string(
      "<div style=\"width:20px;height:20px;background:#fff;margin-right:12px\"></div>",
    )
    buf.write_string(
      "<div style=\"flex:1;height:14px;background:#ecf0f1\"></div>",
    )
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  // Main content
  buf.write_string("<div style=\"flex:1;display:flex;flex-direction:column\">")
  // Header
  buf.write_string(
    "<div style=\"height:60px;background:#fff;border-bottom:1px solid #ddd;display:flex;align-items:center;padding:0 24px;justify-content:space-between\">",
  )
  buf.write_string(
    "<div style=\"width:200px;height:36px;background:#ecf0f1;border-radius:4px\"></div>",
  )
  buf.write_string("<div style=\"display:flex;gap:16px\">")
  buf.write_string(
    "<div style=\"width:36px;height:36px;background:#ecf0f1;border-radius:50%\"></div>",
  )
  buf.write_string(
    "<div style=\"width:36px;height:36px;background:#3498db;border-radius:50%\"></div>",
  )
  buf.write_string("</div>")
  buf.write_string("</div>")
  // Content grid
  buf.write_string(
    "<div style=\"flex:1;padding:24px;background:#f5f6fa;display:grid;grid-template-columns:repeat(3,1fr);gap:16px;align-content:start\">",
  )
  for i = 0; i < content_cards; i = i + 1 {
    buf.write_string(
      "<div style=\"background:#fff;border-radius:8px;padding:16px;box-shadow:0 1px 3px rgba(0,0,0,0.1)\">",
    )
    buf.write_string(
      "<div style=\"height:20px;background:#2c3e50;margin-bottom:12px;width:60%\"></div>",
    )
    buf.write_string(
      "<div style=\"height:80px;background:#ecf0f1;margin-bottom:12px\"></div>",
    )
    buf.write_string(
      "<div style=\"display:flex;justify-content:space-between\">",
    )
    buf.write_string(
      "<div style=\"width:80px;height:16px;background:#27ae60\"></div>",
    )
    buf.write_string(
      "<div style=\"width:40px;height:16px;background:#e74c3c\"></div>",
    )
    buf.write_string("</div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.write_string("</div>")
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
/// Chat message list
pub fn chat_messages(num_messages : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string(
    "<div style=\"display:flex;flex-direction:column;padding:16px;gap:8px;max-width:600px\">",
  )
  for i = 0; i < num_messages; i = i + 1 {
    let is_sent = i % 3 != 0 // Most messages are "sent"
    buf.write_string("<div style=\"display:flex;justify-content:")
    buf.write_string(if is_sent { "flex-end" } else { "flex-start" })
    buf.write_string("\">")
    buf.write_string(
      "<div style=\"max-width:70%;padding:12px 16px;border-radius:16px;background:",
    )
    buf.write_string(if is_sent { "#3498db;color:#fff" } else { "#ecf0f1" })
    buf.write_string("\">")
    // Message content (variable height simulation)
    let height = 20 + i % 5 * 20
    buf.write_string("<div style=\"height:")
    buf.write_string(height.to_string())
    buf.write_string("px;background:")
    buf.write_string(if is_sent { "#2980b9" } else { "#bdc3c7" })
    buf.write_string("\"></div>")
    buf.write_string("</div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
/// Table with header and rows
pub fn table_layout(rows : Int, cols : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "<!DOCTYPE html><html><body style=\"margin:0;padding:16px\">",
  )
  buf.write_string("<table style=\"width:100%;border-collapse:collapse\">")
  // Header
  buf.write_string("<thead><tr>")
  for c = 0; c < cols; c = c + 1 {
    buf.write_string(
      "<th style=\"padding:12px;background:#2c3e50;color:#fff;text-align:left;border:1px solid #34495e\">",
    )
    buf.write_string("Header ")
    buf.write_string(c.to_string())
    buf.write_string("</th>")
  }
  buf.write_string("</tr></thead>")
  // Body
  buf.write_string("<tbody>")
  for r = 0; r < rows; r = r + 1 {
    buf.write_string("<tr style=\"background:")
    buf.write_string(if r % 2 == 0 { "#fff" } else { "#f9f9f9" })
    buf.write_string("\">")
    for c = 0; c < cols; c = c + 1 {
      buf.write_string("<td style=\"padding:12px;border:1px solid #ddd\">")
      buf.write_string("Cell ")
      buf.write_string(r.to_string())
      buf.write_string("-")
      buf.write_string(c.to_string())
      buf.write_string("</td>")
    }
    buf.write_string("</tr>")
  }
  buf.write_string("</tbody>")
  buf.write_string("</table></body></html>")
  buf.to_string()
}

// =============================================================================
// Large Scale Patterns
// =============================================================================

///|
/// Large web page with multiple sections (~5000 nodes)
pub fn large_website(
  sidebar_items : Int,
  sections : Int,
  cards_per_section : Int,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string("<div style=\"display:flex;min-height:100vh\">")
  // Sidebar
  buf.write_string(
    "<div style=\"width:240px;background:#1a1a2e;flex-shrink:0;padding:16px\">",
  )
  buf.write_string(
    "<div style=\"height:40px;background:#e94560;margin-bottom:24px;border-radius:4px\"></div>",
  )
  for i = 0; i < sidebar_items; i = i + 1 {
    buf.write_string(
      "<div style=\"height:36px;margin-bottom:8px;display:flex;align-items:center;padding:0 12px;border-radius:4px;background:",
    )
    buf.write_string(if i == 0 { "#e94560" } else { "#16213e" })
    buf.write_string("\">")
    buf.write_string(
      "<div style=\"width:16px;height:16px;background:#0f3460;margin-right:12px\"></div>",
    )
    buf.write_string("<div style=\"flex:1;height:12px;background:#eee\"></div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  // Main content
  buf.write_string("<div style=\"flex:1;background:#f0f0f0\">")
  // Header
  buf.write_string(
    "<div style=\"height:64px;background:#fff;border-bottom:1px solid #ddd;display:flex;align-items:center;padding:0 24px\">",
  )
  buf.write_string(
    "<div style=\"flex:1;height:36px;background:#ecf0f1;border-radius:4px\"></div>",
  )
  buf.write_string("</div>")
  // Content sections
  buf.write_string("<div style=\"padding:24px\">")
  for s = 0; s < sections; s = s + 1 {
    buf.write_string("<div style=\"margin-bottom:32px\">")
    // Section header
    buf.write_string(
      "<div style=\"display:flex;justify-content:space-between;margin-bottom:16px\">",
    )
    buf.write_string(
      "<div style=\"width:200px;height:28px;background:#2c3e50;border-radius:4px\"></div>",
    )
    buf.write_string(
      "<div style=\"width:80px;height:28px;background:#3498db;border-radius:4px\"></div>",
    )
    buf.write_string("</div>")
    // Cards grid
    buf.write_string(
      "<div style=\"display:grid;grid-template-columns:repeat(4,1fr);gap:16px\">",
    )
    for c = 0; c < cards_per_section; c = c + 1 {
      buf.write_string(
        "<div style=\"background:#fff;border-radius:8px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.1)\">",
      )
      buf.write_string("<div style=\"height:140px;background:#bdc3c7\"></div>")
      buf.write_string("<div style=\"padding:12px\">")
      buf.write_string(
        "<div style=\"height:16px;background:#2c3e50;margin-bottom:8px;width:80%\"></div>",
      )
      buf.write_string(
        "<div style=\"height:32px;background:#ecf0f1;margin-bottom:8px\"></div>",
      )
      buf.write_string(
        "<div style=\"display:flex;justify-content:space-between\">",
      )
      buf.write_string(
        "<div style=\"width:50px;height:14px;background:#e74c3c\"></div>",
      )
      buf.write_string(
        "<div style=\"width:30px;height:14px;background:#27ae60\"></div>",
      )
      buf.write_string("</div>")
      buf.write_string("</div>")
      buf.write_string("</div>")
    }
    buf.write_string("</div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.write_string("</div>")
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
/// Scrollable content with many items (for scroll benchmarks)
pub fn scrollable_list(num_items : Int, item_height : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string("<div style=\"height:100vh;overflow-y:auto\">")
  for i = 0; i < num_items; i = i + 1 {
    buf.write_string("<div style=\"height:")
    buf.write_string(item_height.to_string())
    buf.write_string(
      "px;display:flex;align-items:center;padding:0 16px;border-bottom:1px solid #eee;background:",
    )
    buf.write_string(if i % 2 == 0 { "#fff" } else { "#fafafa" })
    buf.write_string("\">")
    // Avatar
    buf.write_string(
      "<div style=\"width:40px;height:40px;background:#3498db;border-radius:50%;margin-right:12px\"></div>",
    )
    // Content
    buf.write_string("<div style=\"flex:1\">")
    buf.write_string(
      "<div style=\"height:14px;background:#2c3e50;margin-bottom:4px;width:60%\"></div>",
    )
    buf.write_string(
      "<div style=\"height:12px;background:#bdc3c7;width:80%\"></div>",
    )
    buf.write_string("</div>")
    // Actions
    buf.write_string("<div style=\"display:flex;gap:8px\">")
    buf.write_string(
      "<div style=\"width:24px;height:24px;background:#ecf0f1;border-radius:4px\"></div>",
    )
    buf.write_string(
      "<div style=\"width:24px;height:24px;background:#ecf0f1;border-radius:4px\"></div>",
    )
    buf.write_string("</div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
/// Deep nested structure (for parsing stress test)
pub fn deep_nesting(depth : Int, width : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  fn build(d : Int) -> Unit {
    if d == 0 {
      for _w = 0; _w < width; _w = _w + 1 {
        buf.write_string("<span>leaf</span>")
      }
      return
    }
    buf.write_string("<div style=\"padding:2px\">")
    build(d - 1)
    buf.write_string("</div>")
  }

  build(depth)
  buf.write_string("</body></html>")
  buf.to_string()
}

///|
/// Form with many fields
pub fn form_fields(num_fields : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "<!DOCTYPE html><html><body style=\"margin:0;padding:24px\">",
  )
  buf.write_string("<form style=\"max-width:600px\">")
  for i = 0; i < num_fields; i = i + 1 {
    buf.write_string("<div style=\"margin-bottom:16px\">")
    buf.write_string("<label style=\"display:block;margin-bottom:4px\">")
    buf.write_string(
      "<div style=\"height:14px;background:#2c3e50;width:100px\"></div>",
    )
    buf.write_string("</label>")
    buf.write_string(
      "<input type=\"text\" style=\"width:100%;height:40px;padding:0 12px;border:1px solid #ddd;border-radius:4px\">",
    )
    if i % 3 == 0 {
      buf.write_string(
        "<div style=\"height:12px;background:#e74c3c;margin-top:4px;width:200px\"></div>",
      )
    }
    buf.write_string("</div>")
  }
  buf.write_string(
    "<button type=\"submit\" style=\"width:100%;height:44px;background:#3498db;border:none;border-radius:4px;color:#fff\">Submit</button>",
  )
  buf.write_string("</form></body></html>")
  buf.to_string()
}
