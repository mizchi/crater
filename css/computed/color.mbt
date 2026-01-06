// =============================================================================
// CSS Color Parser
// =============================================================================
//
// Parses CSS color values and resolves them to RGBA.
// Supports:
// - Named colors (148 CSS named colors)
// - Hex colors (#rgb, #rrggbb, #rgba, #rrggbbaa)
// - rgb() and rgba() functional notation
// - transparent, currentColor, inherit keywords

///|
/// Result of parsing a CSS color value
pub(all) enum CssColorValue {
  Resolved(@types.Color) // Fully resolved RGBA color
  CurrentColor // Needs parent's color to resolve
  Inherit // Inherit from parent
}

///|
pub fn CssColorValue::is_resolved(self : CssColorValue) -> Bool {
  match self {
    Resolved(_) => true
    _ => false
  }
}

///|
pub fn CssColorValue::get_color(self : CssColorValue) -> @types.Color? {
  match self {
    Resolved(c) => Some(c)
    _ => None
  }
}

///|
pub fn CssColorValue::or_default(
  self : CssColorValue,
  default : @types.Color,
) -> @types.Color {
  match self {
    Resolved(c) => c
    _ => default
  }
}

///|
pub impl Show for CssColorValue with output(self, logger) {
  match self {
    Resolved(c) => c.output(logger)
    CurrentColor => logger.write_string("currentColor")
    Inherit => logger.write_string("inherit")
  }
}

///|
/// Resolve CSS var() function for colors - extracts fallback value if present
/// This is the legacy version without context - only uses fallback values
fn resolve_color_var_fallback(value : String) -> String {
  let v = value.trim()
  if not(v.has_prefix("var(")) || not(v.has_suffix(")")) {
    return v.to_string()
  }
  // Extract content inside var(...)
  let inner = v[4:v.length() - 1].to_string() catch {
    _ => return v.to_string()
  }
  // Find the comma separating variable name from fallback
  let mut paren_depth = 0
  let mut comma_pos = -1
  for i = 0; i < inner.length(); i = i + 1 {
    let c = inner[i].to_int().unsafe_to_char()
    if c == '(' {
      paren_depth += 1
    } else if c == ')' {
      paren_depth -= 1
    } else if c == ',' && paren_depth == 0 {
      comma_pos = i
      break
    }
  }
  if comma_pos > 0 {
    // Has fallback value
    let fallback = inner[comma_pos + 1:].to_string().trim() catch {
        _ => return v.to_string()
      }
    // Recursively resolve if fallback also contains var()
    return resolve_color_var_fallback(fallback.to_string())
  }
  // No fallback, return original
  v.to_string()
}

///|
/// Resolve CSS var() function for colors with context lookup
fn resolve_color_var(value : String, ctx : ComputeContext) -> String {
  let v = value.trim().to_string()
  if not(v.has_prefix("var(")) || not(v.has_suffix(")")) {
    return v
  }
  // Extract content inside var(...)
  let inner : String = v[4:v.length() - 1].to_string() catch { _ => return v }
  // Find the comma separating variable name from fallback
  let mut paren_depth = 0
  let mut comma_pos = -1
  for i = 0; i < inner.length(); i = i + 1 {
    let c = inner[i].to_int().unsafe_to_char()
    if c == '(' {
      paren_depth += 1
    } else if c == ')' {
      paren_depth -= 1
    } else if c == ',' && paren_depth == 0 {
      comma_pos = i
      break
    }
  }
  // Extract variable name as String
  let var_name : String = if comma_pos > 0 {
    let slice = inner[:comma_pos].to_string() catch { _ => inner }
    slice.trim().to_string()
  } else {
    inner.trim().to_string()
  }
  // Look up variable in context
  match ctx.custom_properties.get(var_name) {
    Some(var_value) =>
      // Variable found - recursively resolve if it contains var()
      if var_value.contains("var(") {
        resolve_color_var(var_value, ctx)
      } else {
        var_value
      }
    None =>
      // Variable not found - use fallback if available
      if comma_pos > 0 {
        let fallback_slice = inner[comma_pos + 1:].to_string() catch {
          _ => return ""
        }
        let fallback = fallback_slice.trim().to_string()
        resolve_color_var(fallback, ctx)
      } else {
        ""
      }
  }
}

///|
/// Parse a CSS color value (legacy - uses fallback only for var())
pub fn parse_color(value : String) -> CssColorValue {
  // First resolve any var() functions
  let v = resolve_color_var_fallback(value).trim().to_lower()
  parse_color_value(v.to_string())
}

///|
/// Parse a CSS color value with context for proper var() resolution
pub fn parse_color_with_ctx(
  value : String,
  ctx : ComputeContext,
) -> CssColorValue {
  // First resolve any var() functions using context
  let resolved = if value.contains("var(") {
    resolve_color_var(value, ctx)
  } else {
    value
  }
  let v = resolved.trim().to_lower()
  parse_color_value(v.to_string())
}

///|
/// Internal function to parse color value (after var() resolution)
fn parse_color_value(v : String) -> CssColorValue {

  // Keywords
  if v == "transparent" {
    return Resolved(@types.Color::transparent())
  }
  if v == "currentcolor" {
    return CurrentColor
  }
  if v == "inherit" {
    return Inherit
  }
  // Empty value (unresolved var())
  if v == "" {
    return Resolved(@types.Color::transparent())
  }
  // Unsupported CSS functions - return transparent
  // (gradients, url(), etc. cannot be represented as solid colors)
  if v.has_prefix("linear-gradient") ||
    v.has_prefix("radial-gradient") ||
    v.has_prefix("conic-gradient") ||
    v.has_prefix("repeating-linear-gradient") ||
    v.has_prefix("repeating-radial-gradient") ||
    v.has_prefix("url(") {
    return Resolved(@types.Color::transparent())
  }

  // Hex color
  if v.has_prefix("#") {
    match parse_hex_color(v.to_string()) {
      Some(c) => return Resolved(c)
      None => ()
    }
  }

  // rgb() / rgba()
  if v.has_prefix("rgb") {
    match parse_rgb_function(v.to_string()) {
      Some(c) => return Resolved(c)
      None => ()
    }
  }

  // Named color
  match get_named_color(v.to_string()) {
    Some(c) => return Resolved(c)
    None => ()
  }

  // Default: transparent for unknown values (safer than black)
  Resolved(@types.Color::transparent())
}

///|
fn char_at(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn hex_digit(c : Char) -> Int {
  let code = c.to_int()
  if code >= '0'.to_int() && code <= '9'.to_int() {
    code - '0'.to_int()
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    code - 'a'.to_int() + 10
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    code - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
/// Parse hex color (#rgb, #rrggbb, #rgba, #rrggbbaa)
fn parse_hex_color(value : String) -> @types.Color? {
  if value.length() < 2 {
    return None
  }
  // Skip the '#' prefix
  let len = value.length() - 1
  fn hex1(idx : Int) -> Int {
    let d = hex_digit(char_at(value, idx))
    d * 16 + d
  }

  fn hex2(idx1 : Int, idx2 : Int) -> Int {
    hex_digit(char_at(value, idx1)) * 16 + hex_digit(char_at(value, idx2))
  }

  match len {
    3 => {
      // #rgb
      let r = hex1(1)
      let g = hex1(2)
      let b = hex1(3)
      Some(@types.Color::rgb(r, g, b))
    }
    4 => {
      // #rgba
      let r = hex1(1)
      let g = hex1(2)
      let b = hex1(3)
      let a = hex1(4).to_double() / 255.0
      Some(@types.Color::rgba(r, g, b, a))
    }
    6 => {
      // #rrggbb
      let r = hex2(1, 2)
      let g = hex2(3, 4)
      let b = hex2(5, 6)
      Some(@types.Color::rgb(r, g, b))
    }
    8 => {
      // #rrggbbaa
      let r = hex2(1, 2)
      let g = hex2(3, 4)
      let b = hex2(5, 6)
      let a = hex2(7, 8).to_double() / 255.0
      Some(@types.Color::rgba(r, g, b, a))
    }
    _ => None
  }
}

///|
/// Find first index of character in string
fn find_char(s : String, c : Char) -> Int {
  for i = 0; i < s.length(); i = i + 1 {
    if char_at(s, i) == c {
      return i
    }
  }
  -1
}

///|
/// Find last index of character in string
fn find_char_last(s : String, c : Char) -> Int {
  let mut last = -1
  for i = 0; i < s.length(); i = i + 1 {
    if char_at(s, i) == c {
      last = i
    }
  }
  last
}

///|
/// Extract substring
fn substr(s : String, start : Int, end : Int) -> String {
  let sb = StringBuilder::new()
  for i = start; i < end && i < s.length(); i = i + 1 {
    sb.write_char(char_at(s, i))
  }
  sb.to_string()
}

///|
/// Parse rgb() or rgba() function
fn parse_rgb_function(value : String) -> @types.Color? {
  // Extract content between parentheses
  let start = find_char(value, '(')
  let end = find_char_last(value, ')')
  if start < 0 || end < 0 || end <= start {
    return None
  }
  let content = substr(value, start + 1, end).trim()

  // Split by comma or space
  let parts = split_color_args(content.to_string())
  if parts.length() < 3 {
    return None
  }
  let r = parse_color_component(parts[0], false)
  let g = parse_color_component(parts[1], false)
  let b = parse_color_component(parts[2], false)
  let a = if parts.length() >= 4 {
    parse_color_component(parts[3], true)
  } else {
    1.0
  }
  Some(@types.Color::rgba(r.to_int(), g.to_int(), b.to_int(), a))
}

///|
/// Split color function arguments (handles comma and space separation)
fn split_color_args(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == ',' || c == '/' || c == ' ' {
      let part = current.to_string().trim()
      if part.length() > 0 {
        result.push(part.to_string())
      }
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  let part = current.to_string().trim()
  if part.length() > 0 {
    result.push(part.to_string())
  }
  result
}

///|
/// Parse a color component (0-255 or 0%-100%, or 0-1 for alpha)
fn parse_color_component(s : String, is_alpha : Bool) -> Double {
  let v = s.trim().to_string()
  if v.has_suffix("%") {
    let num_str = substr(v, 0, v.length() - 1)
    let n = @strconv.parse_double(num_str) catch { _ => 0.0 }
    if is_alpha {
      n / 100.0
    } else {
      n * 255.0 / 100.0
    }
  } else {
    let n = @strconv.parse_double(v) catch { _ => 0.0 }
    if is_alpha {
      // Alpha can be 0-1 or 0-100%
      if n > 1.0 {
        n / 255.0
      } else {
        n
      }
    } else {
      n
    }
  }
}

///|
/// Get a named CSS color (148 colors)
fn get_named_color(name : String) -> @types.Color? {
  // CSS Named Colors (Level 4) - all 148 colors
  match name {
    "aliceblue" => Some(@types.Color::rgb(240, 248, 255))
    "antiquewhite" => Some(@types.Color::rgb(250, 235, 215))
    "aqua" => Some(@types.Color::rgb(0, 255, 255))
    "aquamarine" => Some(@types.Color::rgb(127, 255, 212))
    "azure" => Some(@types.Color::rgb(240, 255, 255))
    "beige" => Some(@types.Color::rgb(245, 245, 220))
    "bisque" => Some(@types.Color::rgb(255, 228, 196))
    "black" => Some(@types.Color::rgb(0, 0, 0))
    "blanchedalmond" => Some(@types.Color::rgb(255, 235, 205))
    "blue" => Some(@types.Color::rgb(0, 0, 255))
    "blueviolet" => Some(@types.Color::rgb(138, 43, 226))
    "brown" => Some(@types.Color::rgb(165, 42, 42))
    "burlywood" => Some(@types.Color::rgb(222, 184, 135))
    "cadetblue" => Some(@types.Color::rgb(95, 158, 160))
    "chartreuse" => Some(@types.Color::rgb(127, 255, 0))
    "chocolate" => Some(@types.Color::rgb(210, 105, 30))
    "coral" => Some(@types.Color::rgb(255, 127, 80))
    "cornflowerblue" => Some(@types.Color::rgb(100, 149, 237))
    "cornsilk" => Some(@types.Color::rgb(255, 248, 220))
    "crimson" => Some(@types.Color::rgb(220, 20, 60))
    "cyan" => Some(@types.Color::rgb(0, 255, 255))
    "darkblue" => Some(@types.Color::rgb(0, 0, 139))
    "darkcyan" => Some(@types.Color::rgb(0, 139, 139))
    "darkgoldenrod" => Some(@types.Color::rgb(184, 134, 11))
    "darkgray" => Some(@types.Color::rgb(169, 169, 169))
    "darkgreen" => Some(@types.Color::rgb(0, 100, 0))
    "darkgrey" => Some(@types.Color::rgb(169, 169, 169))
    "darkkhaki" => Some(@types.Color::rgb(189, 183, 107))
    "darkmagenta" => Some(@types.Color::rgb(139, 0, 139))
    "darkolivegreen" => Some(@types.Color::rgb(85, 107, 47))
    "darkorange" => Some(@types.Color::rgb(255, 140, 0))
    "darkorchid" => Some(@types.Color::rgb(153, 50, 204))
    "darkred" => Some(@types.Color::rgb(139, 0, 0))
    "darksalmon" => Some(@types.Color::rgb(233, 150, 122))
    "darkseagreen" => Some(@types.Color::rgb(143, 188, 143))
    "darkslateblue" => Some(@types.Color::rgb(72, 61, 139))
    "darkslategray" => Some(@types.Color::rgb(47, 79, 79))
    "darkslategrey" => Some(@types.Color::rgb(47, 79, 79))
    "darkturquoise" => Some(@types.Color::rgb(0, 206, 209))
    "darkviolet" => Some(@types.Color::rgb(148, 0, 211))
    "deeppink" => Some(@types.Color::rgb(255, 20, 147))
    "deepskyblue" => Some(@types.Color::rgb(0, 191, 255))
    "dimgray" => Some(@types.Color::rgb(105, 105, 105))
    "dimgrey" => Some(@types.Color::rgb(105, 105, 105))
    "dodgerblue" => Some(@types.Color::rgb(30, 144, 255))
    "firebrick" => Some(@types.Color::rgb(178, 34, 34))
    "floralwhite" => Some(@types.Color::rgb(255, 250, 240))
    "forestgreen" => Some(@types.Color::rgb(34, 139, 34))
    "fuchsia" => Some(@types.Color::rgb(255, 0, 255))
    "gainsboro" => Some(@types.Color::rgb(220, 220, 220))
    "ghostwhite" => Some(@types.Color::rgb(248, 248, 255))
    "gold" => Some(@types.Color::rgb(255, 215, 0))
    "goldenrod" => Some(@types.Color::rgb(218, 165, 32))
    "gray" => Some(@types.Color::rgb(128, 128, 128))
    "green" => Some(@types.Color::rgb(0, 128, 0))
    "greenyellow" => Some(@types.Color::rgb(173, 255, 47))
    "grey" => Some(@types.Color::rgb(128, 128, 128))
    "honeydew" => Some(@types.Color::rgb(240, 255, 240))
    "hotpink" => Some(@types.Color::rgb(255, 105, 180))
    "indianred" => Some(@types.Color::rgb(205, 92, 92))
    "indigo" => Some(@types.Color::rgb(75, 0, 130))
    "ivory" => Some(@types.Color::rgb(255, 255, 240))
    "khaki" => Some(@types.Color::rgb(240, 230, 140))
    "lavender" => Some(@types.Color::rgb(230, 230, 250))
    "lavenderblush" => Some(@types.Color::rgb(255, 240, 245))
    "lawngreen" => Some(@types.Color::rgb(124, 252, 0))
    "lemonchiffon" => Some(@types.Color::rgb(255, 250, 205))
    "lightblue" => Some(@types.Color::rgb(173, 216, 230))
    "lightcoral" => Some(@types.Color::rgb(240, 128, 128))
    "lightcyan" => Some(@types.Color::rgb(224, 255, 255))
    "lightgoldenrodyellow" => Some(@types.Color::rgb(250, 250, 210))
    "lightgray" => Some(@types.Color::rgb(211, 211, 211))
    "lightgreen" => Some(@types.Color::rgb(144, 238, 144))
    "lightgrey" => Some(@types.Color::rgb(211, 211, 211))
    "lightpink" => Some(@types.Color::rgb(255, 182, 193))
    "lightsalmon" => Some(@types.Color::rgb(255, 160, 122))
    "lightseagreen" => Some(@types.Color::rgb(32, 178, 170))
    "lightskyblue" => Some(@types.Color::rgb(135, 206, 250))
    "lightslategray" => Some(@types.Color::rgb(119, 136, 153))
    "lightslategrey" => Some(@types.Color::rgb(119, 136, 153))
    "lightsteelblue" => Some(@types.Color::rgb(176, 196, 222))
    "lightyellow" => Some(@types.Color::rgb(255, 255, 224))
    "lime" => Some(@types.Color::rgb(0, 255, 0))
    "limegreen" => Some(@types.Color::rgb(50, 205, 50))
    "linen" => Some(@types.Color::rgb(250, 240, 230))
    "magenta" => Some(@types.Color::rgb(255, 0, 255))
    "maroon" => Some(@types.Color::rgb(128, 0, 0))
    "mediumaquamarine" => Some(@types.Color::rgb(102, 205, 170))
    "mediumblue" => Some(@types.Color::rgb(0, 0, 205))
    "mediumorchid" => Some(@types.Color::rgb(186, 85, 211))
    "mediumpurple" => Some(@types.Color::rgb(147, 112, 219))
    "mediumseagreen" => Some(@types.Color::rgb(60, 179, 113))
    "mediumslateblue" => Some(@types.Color::rgb(123, 104, 238))
    "mediumspringgreen" => Some(@types.Color::rgb(0, 250, 154))
    "mediumturquoise" => Some(@types.Color::rgb(72, 209, 204))
    "mediumvioletred" => Some(@types.Color::rgb(199, 21, 133))
    "midnightblue" => Some(@types.Color::rgb(25, 25, 112))
    "mintcream" => Some(@types.Color::rgb(245, 255, 250))
    "mistyrose" => Some(@types.Color::rgb(255, 228, 225))
    "moccasin" => Some(@types.Color::rgb(255, 228, 181))
    "navajowhite" => Some(@types.Color::rgb(255, 222, 173))
    "navy" => Some(@types.Color::rgb(0, 0, 128))
    "oldlace" => Some(@types.Color::rgb(253, 245, 230))
    "olive" => Some(@types.Color::rgb(128, 128, 0))
    "olivedrab" => Some(@types.Color::rgb(107, 142, 35))
    "orange" => Some(@types.Color::rgb(255, 165, 0))
    "orangered" => Some(@types.Color::rgb(255, 69, 0))
    "orchid" => Some(@types.Color::rgb(218, 112, 214))
    "palegoldenrod" => Some(@types.Color::rgb(238, 232, 170))
    "palegreen" => Some(@types.Color::rgb(152, 251, 152))
    "paleturquoise" => Some(@types.Color::rgb(175, 238, 238))
    "palevioletred" => Some(@types.Color::rgb(219, 112, 147))
    "papayawhip" => Some(@types.Color::rgb(255, 239, 213))
    "peachpuff" => Some(@types.Color::rgb(255, 218, 185))
    "peru" => Some(@types.Color::rgb(205, 133, 63))
    "pink" => Some(@types.Color::rgb(255, 192, 203))
    "plum" => Some(@types.Color::rgb(221, 160, 221))
    "powderblue" => Some(@types.Color::rgb(176, 224, 230))
    "purple" => Some(@types.Color::rgb(128, 0, 128))
    "rebeccapurple" => Some(@types.Color::rgb(102, 51, 153))
    "red" => Some(@types.Color::rgb(255, 0, 0))
    "rosybrown" => Some(@types.Color::rgb(188, 143, 143))
    "royalblue" => Some(@types.Color::rgb(65, 105, 225))
    "saddlebrown" => Some(@types.Color::rgb(139, 69, 19))
    "salmon" => Some(@types.Color::rgb(250, 128, 114))
    "sandybrown" => Some(@types.Color::rgb(244, 164, 96))
    "seagreen" => Some(@types.Color::rgb(46, 139, 87))
    "seashell" => Some(@types.Color::rgb(255, 245, 238))
    "sienna" => Some(@types.Color::rgb(160, 82, 45))
    "silver" => Some(@types.Color::rgb(192, 192, 192))
    "skyblue" => Some(@types.Color::rgb(135, 206, 235))
    "slateblue" => Some(@types.Color::rgb(106, 90, 205))
    "slategray" => Some(@types.Color::rgb(112, 128, 144))
    "slategrey" => Some(@types.Color::rgb(112, 128, 144))
    "snow" => Some(@types.Color::rgb(255, 250, 250))
    "springgreen" => Some(@types.Color::rgb(0, 255, 127))
    "steelblue" => Some(@types.Color::rgb(70, 130, 180))
    "tan" => Some(@types.Color::rgb(210, 180, 140))
    "teal" => Some(@types.Color::rgb(0, 128, 128))
    "thistle" => Some(@types.Color::rgb(216, 191, 216))
    "tomato" => Some(@types.Color::rgb(255, 99, 71))
    "turquoise" => Some(@types.Color::rgb(64, 224, 208))
    "violet" => Some(@types.Color::rgb(238, 130, 238))
    "wheat" => Some(@types.Color::rgb(245, 222, 179))
    "white" => Some(@types.Color::rgb(255, 255, 255))
    "whitesmoke" => Some(@types.Color::rgb(245, 245, 245))
    "yellow" => Some(@types.Color::rgb(255, 255, 0))
    "yellowgreen" => Some(@types.Color::rgb(154, 205, 50))
    _ => None
  }
}

///|
/// Resolve currentColor using parent's color
pub fn resolve_current_color(
  value : CssColorValue,
  parent_color : @types.Color,
) -> @types.Color {
  match value {
    Resolved(c) => c
    CurrentColor => parent_color
    Inherit => parent_color
  }
}

///|
/// Default color for text (black)
pub fn default_color() -> @types.Color {
  @types.Color::black()
}

///|
/// Default color for background (transparent)
pub fn default_background_color() -> @types.Color {
  @types.Color::transparent()
}
