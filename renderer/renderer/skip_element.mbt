///|
// Non-visual and unsupported element skip policy.

///|
/// Check if element should be skipped during rendering
fn should_skip_element(tag : String) -> Bool {
  match tag {
    // Script and style elements
    "script"
    | "noscript"
    | "style"
    // Metadata elements (shouldn't appear in body, but handle invalid HTML)
    | "head"
    | "meta"
    | "link"
    | "title"
    | "base"
    // Template and embedded content
    | "template"
    | "applet"
    | "track"
    | "param"
    // math is not yet supported
    | "math"
    // Other non-visual elements
    | "map"
    | "area" => true
    _ => false
  }
}
