///|
/// Script info extracted from HTML
priv struct ScriptInfo {
  /// Inline script source (empty if external)
  source : String
  /// External script URL (empty if inline)
  src : String
  /// Whether script is async
  is_async : Bool
  /// Whether script is deferred
  is_defer : Bool
  /// Script type attribute (empty for default JavaScript)
  script_type : String
}

///|
/// Check if a script type is executable as JavaScript
fn is_executable_script_type(script_type : String) -> Bool {
  // Empty type or module/javascript types are executable
  if script_type.length() == 0 {
    return true
  }
  let lower = script_type.to_lower()
  // Standard JavaScript MIME types
  lower == "text/javascript" ||
  lower == "application/javascript" ||
  lower == "module"
}

///|
/// Extract script tags from HTML
fn extract_scripts(html : String) -> Array[ScriptInfo] {
  let scripts : Array[ScriptInfo] = []
  let len = html.length()
  let mut i = 0
  while i < len {
    // Look for <script
    if i + 7 < len &&
      char_at(html, i) == '<' &&
      (char_at(html, i + 1) == 's' || char_at(html, i + 1) == 'S') &&
      (char_at(html, i + 2) == 'c' || char_at(html, i + 2) == 'C') &&
      (char_at(html, i + 3) == 'r' || char_at(html, i + 3) == 'R') &&
      (char_at(html, i + 4) == 'i' || char_at(html, i + 4) == 'I') &&
      (char_at(html, i + 5) == 'p' || char_at(html, i + 5) == 'P') &&
      (char_at(html, i + 6) == 't' || char_at(html, i + 6) == 'T') &&
      (
        char_at(html, i + 7) == ' ' ||
        char_at(html, i + 7) == '>' ||
        char_at(html, i + 7) == '\t' ||
        char_at(html, i + 7) == '\n'
      ) {
      // Parse script tag attributes
      let mut j = i + 7
      let mut src = ""
      let mut script_type = ""
      let mut is_async = false
      let mut is_defer = false
      // Find end of opening tag
      while j < len && char_at(html, j) != '>' {
        // Check for src="..."
        if j + 5 < len &&
          (char_at(html, j) == 's' || char_at(html, j) == 'S') &&
          (char_at(html, j + 1) == 'r' || char_at(html, j + 1) == 'R') &&
          (char_at(html, j + 2) == 'c' || char_at(html, j + 2) == 'C') &&
          char_at(html, j + 3) == '=' {
          let quote = char_at(html, j + 4)
          if quote == '"' || quote == '\'' {
            let mut k = j + 5
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            src = html.unsafe_substring(start=j + 5, end=k)
            j = k
          }
        }
        // Check for type="..."
        if j + 6 < len &&
          (char_at(html, j) == 't' || char_at(html, j) == 'T') &&
          (char_at(html, j + 1) == 'y' || char_at(html, j + 1) == 'Y') &&
          (char_at(html, j + 2) == 'p' || char_at(html, j + 2) == 'P') &&
          (char_at(html, j + 3) == 'e' || char_at(html, j + 3) == 'E') &&
          char_at(html, j + 4) == '=' {
          let quote = char_at(html, j + 5)
          if quote == '"' || quote == '\'' {
            let mut k = j + 6
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            script_type = html.unsafe_substring(start=j + 6, end=k)
            j = k
          }
        }
        // Check for async
        if j + 5 < len &&
          (char_at(html, j) == 'a' || char_at(html, j) == 'A') &&
          (char_at(html, j + 1) == 's' || char_at(html, j + 1) == 'S') &&
          (char_at(html, j + 2) == 'y' || char_at(html, j + 2) == 'Y') &&
          (char_at(html, j + 3) == 'n' || char_at(html, j + 3) == 'N') &&
          (char_at(html, j + 4) == 'c' || char_at(html, j + 4) == 'C') {
          is_async = true
        }
        // Check for defer
        if j + 5 < len &&
          (char_at(html, j) == 'd' || char_at(html, j) == 'D') &&
          (char_at(html, j + 1) == 'e' || char_at(html, j + 1) == 'E') &&
          (char_at(html, j + 2) == 'f' || char_at(html, j + 2) == 'F') &&
          (char_at(html, j + 3) == 'e' || char_at(html, j + 3) == 'E') &&
          (char_at(html, j + 4) == 'r' || char_at(html, j + 4) == 'R') {
          is_defer = true
        }
        j = j + 1
      }
      // Extract inline script content if no src
      let mut source = ""
      if src.length() == 0 && j < len && char_at(html, j) == '>' {
        let content_start = j + 1
        // Find </script>
        let mut content_end = content_start
        while content_end + 8 < len {
          if char_at(html, content_end) == '<' &&
            char_at(html, content_end + 1) == '/' &&
            (
              char_at(html, content_end + 2) == 's' ||
              char_at(html, content_end + 2) == 'S'
            ) &&
            (
              char_at(html, content_end + 3) == 'c' ||
              char_at(html, content_end + 3) == 'C'
            ) &&
            (
              char_at(html, content_end + 4) == 'r' ||
              char_at(html, content_end + 4) == 'R'
            ) &&
            (
              char_at(html, content_end + 5) == 'i' ||
              char_at(html, content_end + 5) == 'I'
            ) &&
            (
              char_at(html, content_end + 6) == 'p' ||
              char_at(html, content_end + 6) == 'P'
            ) &&
            (
              char_at(html, content_end + 7) == 't' ||
              char_at(html, content_end + 7) == 'T'
            ) {
            break
          }
          content_end = content_end + 1
        }
        source = html
          .unsafe_substring(start=content_start, end=content_end)
          .trim()
          .to_string()
        i = content_end
      }
      // Add script info if we have source or src
      if source.length() > 0 || src.length() > 0 {
        scripts.push({ source, src, is_async, is_defer, script_type })
      }
    }
    i = i + 1
  }
  scripts
}
