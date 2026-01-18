///|
/// ProgressBar - Progress indicator components

///|
/// Progress bar style
pub(all) enum ProgressStyle {
  Bar        // [████████░░░░] 80%
  Dots       // ●●●●●●●●○○○○
  Blocks     // ▓▓▓▓▓▓▓▓░░░░
  Spinner    // ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏
}

///|
/// Progress bar characters for different styles
fn get_progress_chars(style : ProgressStyle) -> (String, String) {
  match style {
    ProgressStyle::Bar => ("█", "░")
    ProgressStyle::Dots => ("●", "○")
    ProgressStyle::Blocks => ("▓", "░")
    ProgressStyle::Spinner => ("█", "░") // Spinner uses animation, not fill
  }
}

///|
/// Spinner frames for animation
let spinner_frames : Array[String] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

///|
/// Get spinner frame for animation
pub fn get_spinner_frame(tick : Int) -> String {
  let idx = tick % spinner_frames.length()
  spinner_frames[idx]
}

///|
/// Build progress bar string
/// ratio: 0.0 to 1.0
/// width: total width in characters
pub fn build_progress_bar(
  ratio : Double,
  width : Int,
  style? : ProgressStyle = ProgressStyle::Bar,
  show_percent? : Bool = true
) -> String {
  let clamped = if ratio < 0.0 {
    0.0
  } else if ratio > 1.0 {
    1.0
  } else {
    ratio
  }
  let percent_str = if show_percent {
    let pct = (clamped * 100.0).to_int()
    " " + pct.to_string() + "%"
  } else {
    ""
  }
  let bar_width = width - 2 - percent_str.length() // -2 for brackets
  if bar_width <= 0 {
    return percent_str.trim().to_string()
  }
  let filled = (bar_width.to_double() * clamped).to_int()
  let empty = bar_width - filled
  let (fill_char, empty_char) = get_progress_chars(style)
  "[" + fill_char.repeat(filled) + empty_char.repeat(empty) + "]" + percent_str
}

///|
/// Progress bar component
pub fn progress_bar(
  ratio : Double,
  width : Int,
  style? : ProgressStyle = ProgressStyle::Bar,
  show_percent? : Bool = true,
  fg? : @tui.Color = @tui.Color::white(),
  fill_fg? : @tui.Color = @tui.Color::cyan()
) -> @tui.Component {
  // Build the bar text
  let bar_text = build_progress_bar(ratio, width, style~, show_percent~)
  // For now, return as single styled text
  // Future: could split into colored segments
  text(bar_text, fg=if ratio > 0.0 { fill_fg } else { fg })
}

///|
/// Spinner component (use with ticker for animation)
pub fn spinner(
  tick : Int,
  label? : String = "",
  fg? : @tui.Color = @tui.Color::cyan()
) -> @tui.Component {
  let frame = get_spinner_frame(tick)
  if label.length() > 0 {
    row([text(frame + " ", fg~), text(label)])
  } else {
    text(frame, fg~)
  }
}

///|
/// Loading indicator with dots animation
pub fn loading_dots(
  tick : Int,
  label? : String = "Loading",
  fg? : @tui.Color = @tui.Color::white()
) -> @tui.Component {
  let dots = match tick % 4 {
    0 => ""
    1 => "."
    2 => ".."
    _ => "..."
  }
  text(label + dots, fg~)
}

///|
/// Simple percentage text
pub fn percent_text(
  ratio : Double,
  fg? : @tui.Color = @tui.Color::white()
) -> @tui.Component {
  let clamped = if ratio < 0.0 {
    0.0
  } else if ratio > 1.0 {
    1.0
  } else {
    ratio
  }
  let pct = (clamped * 100.0).to_int()
  text(pct.to_string() + "%", fg~)
}

///|
/// Fraction text (e.g., "5/10")
pub fn fraction_text(
  current : Int,
  total : Int,
  fg? : @tui.Color = @tui.Color::white()
) -> @tui.Component {
  text(current.to_string() + "/" + total.to_string(), fg~)
}
