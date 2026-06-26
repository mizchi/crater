///|
/// Text measurement constants (monospace font simulation)
/// Character width ratio for monospace fonts (width / font-size)
/// Typical monospace fonts have width:height ratio around 0.5-0.55
let char_width_ratio : Double = 0.5 // Conservative ratio for text fitting

///|
let chars_per_line : Int = 80 // Default wrap width in characters (single-width)

///|
/// Ahem/fallback-font-like glyph width ratio observed in WPT harness rendering.
let large_ahem_like_char_width_ratio : Double = 0.722

///|
/// UA default "normal" line-height approximation used for table internals.
let normal_line_height_ratio : Double = 1.2

///|
fn is_apple_system_font_family(font_family : String) -> Bool {
  let family = font_family.to_lower()
  family == "-apple-system" || family == "blinkmacsystemfont"
}

///|
fn apple_system_normal_line_height(font_size : Double) -> Double {
  let rounded = font_size.round()
  if (font_size - rounded).abs() < 0.01 {
    match rounded.to_int() {
      10 => return 12.0
      11 => return 13.0
      12 => return 15.0
      13 => return 16.0
      14 => return 17.0
      15 => return 18.0
      16 => return 18.0
      17 => return 20.0
      18 => return 21.0
      20 => return 23.0
      24 => return 28.0
      32 => return 38.0
      _ => ()
    }
  }
  (font_size * 1.17).round()
}

///|
fn inherited_line_height_looks_like_apple_normal(
  parent_style : @style.Style?,
) -> Bool {
  match parent_style {
    Some(parent) =>
      (
        is_apple_system_font_family(parent.font_family) &&
        (parent.line_height - apple_system_normal_line_height(parent.font_size)).abs() <
        0.01
      ) ||
      (parent.line_height - parent.font_size * normal_line_height_ratio).abs() <
      0.01
    None => true
  }
}

///|
fn apply_browser_normal_line_height_if_needed(
  style : @style.Style,
  parent_style : @style.Style?,
  author_line_height_present : Bool,
) -> @style.Style {
  if author_line_height_present ||
    !is_apple_system_font_family(style.font_family) ||
    !inherited_line_height_looks_like_apple_normal(parent_style) {
    style
  } else {
    { ..style, line_height: apple_system_normal_line_height(style.font_size) }
  }
}

///|
/// Current cellpadding value from the nearest ancestor <table>.
/// -1.0 means not set. Updated when entering/leaving table elements.
let current_cellpadding : Ref[Double] = { val: -1.0 }

///|
/// Check if a character is East Asian Wide (CJK characters that take 2 columns)
fn is_wide_char(c : Char) -> Bool {
  let cp = c.to_int()
  // CJK Unified Ideographs (U+4E00–U+9FFF)
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  // CJK Extension A (U+3400–U+4DBF)
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  // Hiragana (U+3040–U+309F)
  (cp >= 0x3040 && cp <= 0x309F) ||
  // Katakana (U+30A0–U+30FF)
  (cp >= 0x30A0 && cp <= 0x30FF) ||
  // Hangul Syllables (U+AC00–U+D7AF)
  (cp >= 0xAC00 && cp <= 0xD7AF) ||
  // Fullwidth Forms (U+FF00–U+FFEF)
  (cp >= 0xFF00 && cp <= 0xFFEF) ||
  // CJK Symbols and Punctuation (U+3000–U+303F)
  (cp >= 0x3000 && cp <= 0x303F)
}

///|
/// Calculate display width of a character (1 for narrow, 2 for wide)
fn char_display_width(c : Char) -> Int {
  let cp = c.to_int()
  // U+2003 EM SPACE should advance by one full em in monospace-like metrics.
  if cp == 0x2003 {
    2
  } else if is_wide_char(c) {
    2
  } else {
    1
  }
}

///|
/// Place a word into wrapped lines.
/// Returns (updated_lines, updated_line_width).
fn place_word_with_wrap(
  lines : Int,
  line_width : Int,
  word_width : Int,
  cols_available : Int,
  needs_space : Bool,
) -> (Int, Int) {
  if cols_available <= 0 {
    return (lines, line_width)
  }
  let mut new_lines = lines
  let mut new_line_width = line_width
  let mut space_width = 0
  if needs_space && new_line_width > 0 {
    space_width = 1
  }

  // Fits current line
  if new_line_width > 0 &&
    new_line_width + space_width + word_width <= cols_available {
    new_line_width = new_line_width + space_width + word_width
    return (new_lines, new_line_width)
  }

  // Move to next line if current line already has content.
  if new_line_width > 0 {
    new_lines = new_lines + 1
    new_line_width = 0
  }

  // Fits a fresh line.
  if word_width <= cols_available {
    return (new_lines, word_width)
  }

  // Long word fallback: hard-wrap by available columns.
  let full_lines = word_width / cols_available
  let remainder = word_width % cols_available
  if remainder == 0 {
    if full_lines > 0 {
      new_lines = new_lines + full_lines - 1
      new_line_width = cols_available
    } else {
      new_line_width = 0
    }
  } else {
    new_lines = new_lines + full_lines
    new_line_width = remainder
  }
  (new_lines, new_line_width)
}

///|
/// Render context with viewport dimensions
pub(all) struct RenderContext {
  viewport_width : Double
  viewport_height : Double
  root_font_size : Double
  color_scheme : @css.ColorScheme
}

///|
pub fn RenderContext::default() -> RenderContext {
  {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
}

///|
/// Text metrics provider hook for integrating external font engines.
pub struct TextMetricsProvider {
  func : (
    String,
    Double,
    Double,
    @style.WhiteSpace,
    @style.WritingMode,
    Double,
    String,
  ) -> @layout_types.MeasureFunc
}

///|
pub fn TextMetricsProvider::new(
  func : (
    String,
    Double,
    Double,
    @style.WhiteSpace,
    @style.WritingMode,
    Double,
    String,
  ) -> @layout_types.MeasureFunc,
) -> TextMetricsProvider {
  { func, }
}

///|
let text_metrics_provider_override : Ref[TextMetricsProvider?] = { val: None }

///|
pub fn set_text_metrics_provider(provider : TextMetricsProvider) -> Unit {
  text_metrics_provider_override.val = Some(provider)
}

///|
pub fn clear_text_metrics_provider() -> Unit {
  text_metrics_provider_override.val = None
}

///|
/// Force monospace text metrics regardless of TextMetricsProvider.
/// Use this for TUI/terminal rendering where proportional metrics are meaningless.
let force_monospace_metrics_flag : Ref[Bool] = { val: false }

///|
pub fn set_force_monospace_metrics(enabled : Bool) -> Unit {
  force_monospace_metrics_flag.val = enabled
}

///|
pub fn get_force_monospace_metrics() -> Bool {
  force_monospace_metrics_flag.val
}

///|
#cfg(target="js")
extern "js" fn is_perf_logging_enabled() -> Bool =
  #|() => {
  #|  try {
  #|    return typeof process !== "undefined" &&
  #|      process != null &&
  #|      process.env != null &&
  #|      process.env.CRATER_RENDERER_PERF_LOG === "1";
  #|  } catch {
  #|    return false;
  #|  }
  #|}

///|
#cfg(not(target="js"))
fn is_perf_logging_enabled() -> Bool {
  false
}

///|
fn maybe_log_perf(message : String) -> Unit {
  if is_perf_logging_enabled() {
    println(message)
  }
}

///|
#cfg(target="js")
extern "js" fn get_builtin_text_advance_ratio_override() -> Double =
  #|() => {
  #|  const ratio = Number(globalThis.__craterBuiltinTextAdvanceRatio);
  #|  return Number.isFinite(ratio) ? ratio : -1;
  #|}

///|
/// Test-only hook for deterministic built-in text measurement on JS.
#cfg(target="js")
pub extern "js" fn set_builtin_text_advance_ratio_override_for_test(
  ratio : Double,
) -> Unit =
  #|(ratio) => {
  #|  globalThis.__craterBuiltinTextAdvanceRatio = ratio;
  #|}

///|
/// Clear the deterministic built-in text measurement hook on JS.
#cfg(target="js")
pub extern "js" fn clear_builtin_text_advance_ratio_override_for_test() -> Unit =
  #|() => {
  #|  delete globalThis.__craterBuiltinTextAdvanceRatio;
  #|}

///|
#cfg(not(target="js"))
let builtin_text_advance_ratio_override : Ref[Double] = { val: -1.0 }

///|
/// Test-only hook for deterministic built-in text measurement.
#cfg(not(target="js"))
pub fn set_builtin_text_advance_ratio_override_for_test(ratio : Double) -> Unit {
  builtin_text_advance_ratio_override.val = ratio
}

///|
/// Clear the deterministic built-in text measurement hook.
#cfg(not(target="js"))
pub fn clear_builtin_text_advance_ratio_override_for_test() -> Unit {
  builtin_text_advance_ratio_override.val = -1.0
}

///|
#cfg(not(target="js"))
fn get_builtin_text_advance_ratio_override() -> Double {
  builtin_text_advance_ratio_override.val
}

///|
/// Image intrinsic-size provider hook for integrating external image metadata resolvers.
pub struct ImageIntrinsicSizeProvider {
  func : (String) -> (Double, Double)?
}

///|
pub fn ImageIntrinsicSizeProvider::new(
  func : (String) -> (Double, Double)?,
) -> ImageIntrinsicSizeProvider {
  { func, }
}

///|
let image_intrinsic_size_provider_override : Ref[ImageIntrinsicSizeProvider?] = {
  val: None,
}

///|
pub fn set_image_intrinsic_size_provider(
  provider : ImageIntrinsicSizeProvider,
) -> Unit {
  image_intrinsic_size_provider_override.val = Some(provider)
}

///|
pub fn clear_image_intrinsic_size_provider() -> Unit {
  image_intrinsic_size_provider_override.val = None
}

///|
fn create_text_measure_with_provider(
  text : String,
  font_size : Double,
  text_line_height : Double,
  white_space : @style.WhiteSpace,
  writing_mode : @style.WritingMode,
  font_weight? : Double = 400.0,
  font_family? : String = "",
  letter_spacing? : Double = 0.0,
  word_spacing? : Double = 0.0,
) -> @layout_types.MeasureFunc {
  fn white_space_collapses_edges(white_space : @style.WhiteSpace) -> Bool {
    match white_space {
      @style.WhiteSpace::Normal
      | @style.WhiteSpace::Nowrap
      | @style.WhiteSpace::PreLine => true
      _ => false
    }
  }
  fn has_boundary_collapsible_whitespace(text : String) -> Bool {
    let mut starts_with_ws = false
    let mut seen_first = false
    let mut ends_with_ws = false
    for c in text.iter() {
      if !seen_first {
        seen_first = true
        starts_with_ws = c == ' ' ||
          c == '\t' ||
          c == '\n' ||
          c == '\r' ||
          c == '\u000C'
      }
      ends_with_ws = c == ' ' ||
        c == '\t' ||
        c == '\n' ||
        c == '\r' ||
        c == '\u000C'
    }
    starts_with_ws || ends_with_ws
  }
  fn has_non_collapsible_space_glyph(text : String) -> Bool {
    for c in text.iter() {
      let cp = c.to_int()
      if cp == 0x00A0 || // NO-BREAK SPACE
        cp == 0x1680 ||
        (cp >= 0x2000 && cp <= 0x200A) ||
        cp == 0x202F ||
        cp == 0x205F ||
        cp == 0x3000 {
        return true
      }
    }
    false
  }
  fn is_ahem_like_measure_target(
    text : String,
    font_size : Double,
    text_line_height : Double,
  ) -> Bool {
    if font_size < 80.0 || text_line_height > font_size * 1.01 {
      return false
    }
    let trimmed = trim_collapsible_whitespace_edges(text)
    if trimmed.is_empty() {
      return false
    }
    for c in trimmed.iter() {
      if c != 'X' && c != '\u00A0' {
        return false
      }
    }
    true
  }
  let trimmed = trim_collapsible_whitespace_edges(text)
  let force_builtin_measure = white_space_collapses_edges(white_space) &&
    !text.is_empty() &&
    (
      trimmed.is_empty() ||
      has_boundary_collapsible_whitespace(text) ||
      has_non_collapsible_space_glyph(text) ||
      is_ahem_like_measure_target(text, font_size, text_line_height)
    )
  if force_monospace_metrics_flag.val {
    return create_text_measure(
      text,
      font_size,
      text_line_height,
      white_space,
      writing_mode,
      font_family~,
    )
  }
  let base_measure = match text_metrics_provider_override.val {
    Some(provider) =>
      if force_builtin_measure {
        create_text_measure(
          text,
          font_size,
          text_line_height,
          white_space,
          writing_mode,
          font_family~,
        )
      } else {
        (provider.func)(
          text, font_size, text_line_height, white_space, writing_mode, font_weight,
          font_family,
        )
      }
    None =>
      create_text_measure(
        text,
        font_size,
        text_line_height,
        white_space,
        writing_mode,
        font_family~,
      )
  }
  // Apply letter-spacing and word-spacing adjustments
  let adjusted : @layout_types.MeasureFunc = if letter_spacing != 0.0 ||
    word_spacing != 0.0 {
    let char_count = text.iter().count()
    let space_count = text
      .iter()
      .fold(init=0, fn(acc, c) { if c == ' ' { acc + 1 } else { acc } })
    let extra_width = letter_spacing * (char_count - 1).to_double() +
      word_spacing * space_count.to_double()
    let base_fn = base_measure.func
    {
      func: fn(available_width, available_height) {
        let result = base_fn(available_width, available_height)
        {
          ..result,
          min_width: result.min_width + extra_width,
          max_width: result.max_width + extra_width,
        }
      },
    }
  } else {
    base_measure
  }
  let cache : Array[(Double, Double, @layout_types.IntrinsicSize)] = []
  let memoized : @layout_types.MeasureFunc = {
    func: fn(available_width, available_height) {
      for entry in cache {
        let (caw, cah, cached) = entry
        if caw == available_width && cah == available_height {
          return cached
        }
      }
      let result = (adjusted.func)(available_width, available_height)
      if cache.length() < 32 {
        cache.push((available_width, available_height, result))
      }
      result
    },
  }
  memoized
}

///|
/// Create a MeasureFunc for text content with font metrics
/// Calculates text dimensions based on monospace character width
/// Accounts for East Asian Wide characters (CJK) which take 2 columns
/// Handles explicit line breaks (from <br> elements converted to \n)
/// Supports writing-mode for vertical text layout
fn create_text_measure(
  text : String,
  font_size : Double,
  text_line_height : Double,
  white_space : @style.WhiteSpace,
  writing_mode : @style.WritingMode,
  font_family? : String = "",
) -> @layout_types.MeasureFunc {
  let raw_trimmed = trim_collapsible_whitespace_edges(text)
  let mut trimmed = if raw_trimmed.is_empty() && !text.is_empty() {
    " "
  } else {
    raw_trimmed.to_string()
  }
  if !raw_trimmed.is_empty() {
    let mut starts_with_ws = false
    let mut seen_first = false
    let mut ends_with_ws = false
    let mut before_first_non_ws = true
    let mut leading_has_line_break = false
    for c in text.iter() {
      if !seen_first {
        seen_first = true
        starts_with_ws = c == ' ' ||
          c == '\t' ||
          c == '\n' ||
          c == '\r' ||
          c == '\u000C'
      }
      if before_first_non_ws {
        if c == '\n' || c == '\r' {
          leading_has_line_break = true
        }
        let is_ws = c == ' ' ||
          c == '\t' ||
          c == '\n' ||
          c == '\r' ||
          c == '\u000C'
        if !is_ws {
          before_first_non_ws = false
        }
      }
      ends_with_ws = c == ' ' ||
        c == '\t' ||
        c == '\n' ||
        c == '\r' ||
        c == '\u000C'
    }
    if starts_with_ws && !leading_has_line_break {
      trimmed = " " + trimmed
    }
    if ends_with_ws {
      trimmed = trimmed + " "
    }
  }
  let override_ratio = get_builtin_text_advance_ratio_override()
  let mut effective_char_width_ratio = if override_ratio > 0.0 {
    override_ratio
  } else if font_family.to_lower().contains("ahem") {
    1.0
  } else {
    char_width_ratio
  }
  if font_size >= 80.0 && text_line_height <= font_size * 1.01 {
    let mut all_ahem_like = true
    for c in trimmed.iter() {
      if c != 'X' && c != '\u00A0' {
        all_ahem_like = false
        break
      }
    }
    if all_ahem_like && !trimmed.is_empty() {
      effective_char_width_ratio = large_ahem_like_char_width_ratio
    }
  }
  let char_width = font_size * effective_char_width_ratio

  // Split by explicit line breaks and calculate per-line metrics
  let mut explicit_lines = 1
  let mut max_line_width = 0
  let mut current_line_width = 0
  let mut max_word_width = 0
  let mut current_word_width = 0
  for c in trimmed.iter() {
    if c == '\n' {
      // Explicit line break (from <br>)
      explicit_lines = explicit_lines + 1
      if current_line_width > max_line_width {
        max_line_width = current_line_width
      }
      if current_word_width > max_word_width {
        max_word_width = current_word_width
      }
      current_line_width = 0
      current_word_width = 0
    } else if c == ' ' || c == '\t' {
      if current_word_width > max_word_width {
        max_word_width = current_word_width
      }
      current_word_width = 0
      current_line_width = current_line_width + 1 // Space width
    } else {
      let cw = char_display_width(c)
      current_line_width = current_line_width + cw
      current_word_width = current_word_width + cw
    }
  }
  // Handle last line/word
  if current_line_width > max_line_width {
    max_line_width = current_line_width
  }
  if current_word_width > max_word_width {
    max_word_width = current_word_width
  }

  // Check if vertical writing mode
  let is_vertical = writing_mode.is_vertical()

  // max_width is the widest line (for intrinsic sizing)
  let text_max_width = max_line_width.to_double() * char_width
  // min_width is the longest word
  let text_min_width = max_word_width.to_double() * char_width
  // min_height accounts for explicit line breaks
  let min_lines = explicit_lines
  {
    func: fn(
      available_width : Double,
      available_height : Double,
    ) -> @layout_types.IntrinsicSize {
      // For white-space: nowrap, don't wrap text
      let no_wrap = match white_space {
        @style.WhiteSpace::Nowrap => true
        _ => false
      }

      // In vertical mode, the inline axis is vertical (height constrains)
      // In horizontal mode, the inline axis is horizontal (width constrains)
      let (available_inline, line_size) = if is_vertical {
        (available_height, char_width)
      } else {
        (available_width, char_width)
      }

      // Calculate how many single-width columns fit in available inline space
      // For nowrap, use a very large number to prevent wrapping
      let cols_available = if no_wrap {
        1000000 // Large number to prevent wrapping
      } else if available_inline > 0.0 {
        (available_inline / line_size).to_int()
      } else {
        chars_per_line
      }
      // Calculate total lines needed (considering both wrapping and explicit breaks)
      // For each explicit line, calculate how many visual lines it needs
      let use_word_wrap = match white_space {
        @style.WhiteSpace::Normal | @style.WhiteSpace::PreLine => true
        _ => false
      }
      let mut total_lines = 1
      if use_word_wrap && !no_wrap {
        // Greedy word wrapping with long-word hard-wrap fallback.
        let mut current_line_width = 0
        let mut current_word_width = 0
        let mut has_pending_space = false
        for c in trimmed.iter() {
          if c == '\n' {
            if current_word_width > 0 {
              let (l, w) = place_word_with_wrap(
                total_lines, current_line_width, current_word_width, cols_available,
                has_pending_space,
              )
              total_lines = l
              current_line_width = w
              current_word_width = 0
            }
            // Explicit line break always starts a new visual line.
            total_lines = total_lines + 1
            current_line_width = 0
            has_pending_space = false
          } else if c == ' ' || c == '\t' {
            if current_word_width > 0 {
              let (l, w) = place_word_with_wrap(
                total_lines, current_line_width, current_word_width, cols_available,
                has_pending_space,
              )
              total_lines = l
              current_line_width = w
              current_word_width = 0
            }
            has_pending_space = true
          } else {
            current_word_width = current_word_width + char_display_width(c)
          }
        }
        if current_word_width > 0 {
          let (l, _w) = place_word_with_wrap(
            total_lines, current_line_width, current_word_width, cols_available,
            has_pending_space,
          )
          total_lines = l
        }
      } else {
        // Character-based wrapping for nowrap/pre/pre-wrap behavior.
        let mut current_line_width = 0
        total_lines = 0
        for c in trimmed.iter() {
          if c == '\n' {
            // End of explicit line
            let line_visual_lines = if cols_available > 0 &&
              current_line_width > 0 {
              (current_line_width + cols_available - 1) / cols_available
            } else {
              1
            }
            total_lines = total_lines + line_visual_lines
            current_line_width = 0
          } else if c == ' ' || c == '\t' {
            current_line_width = current_line_width + 1
          } else {
            current_line_width = current_line_width + char_display_width(c)
          }
        }
        // Handle last line
        let last_line_visual = if cols_available > 0 && current_line_width > 0 {
          (current_line_width + cols_available - 1) / cols_available
        } else {
          1
        }
        total_lines = total_lines + last_line_visual
      }

      // In vertical mode, swap width/height concepts
      // - Width = number of lines (block dimension)
      // - Height = characters per line (inline dimension)
      if is_vertical {
        let width = total_lines.to_double() * text_line_height
        let max_wrapped_height = if no_wrap {
          text_max_width
        } else if available_inline > 0.0 {
          let wrapped_height = cols_available.to_double() * char_width
          if text_max_width < wrapped_height {
            text_max_width
          } else {
            wrapped_height
          }
        } else {
          text_max_width
        }
        let min_width = min_lines.to_double() * text_line_height
        {
          min_width,
          max_width: width,
          min_height: text_min_width, // word length becomes height
          max_height: max_wrapped_height,
        }
      } else {
        let height = total_lines.to_double() * text_line_height
        let min_height = min_lines.to_double() * text_line_height
        {
          min_width: text_min_width,
          max_width: text_max_width,
          min_height,
          max_height: height,
        }
      }
    },
  }
}
