///|
fn load_request(options : Options) -> Result[RenderRequest, String] {
  let stdin_content = if options.stdin_html || options.stdin_css {
    match read_stdin_text() {
      Some(content) => Some(content)
      None => return Err("Failed to read stdin")
    }
  } else {
    None
  }
  let html = if options.stdin_html {
    match stdin_content {
      Some(content) => content
      None => return Err("Failed to read stdin")
    }
  } else {
    match read_text_file(options.html_file) {
      Some(content) => content
      None => return Err("Failed to read HTML file: " + options.html_file)
    }
  }
  let css : Array[String] = []
  for css_file in options.css_files {
    match read_text_file(css_file) {
      Some(content) => css.push(content)
      None => return Err("Failed to read CSS file: " + css_file)
    }
  }
  if options.stdin_css {
    match stdin_content {
      Some(content) => css.push(content)
      None => return Err("Failed to read stdin")
    }
  }
  Ok({
    html,
    css,
    target_id: options.target_id,
    target_selector: options.target_selector,
    viewport_width: options.viewport_width,
    viewport_height: options.viewport_height,
  })
}

///|
fn main {
  let options = parse_args()
  if options.show_help {
    print_help()
    return
  }
  match validate_options(options) {
    Some(error) => {
      eprintln(error)
      eprintln("")
      print_help()
      exit_with_code(1)
    }
    None => ()
  }
  // Prefer a regular/bold system font pair when available.
  match load_system_glyph_provider() {
    Some(provider) => @image.set_glyph_provider(provider)
    None => ()
  }
  match load_request(options) {
    Ok(request) =>
      match render_artifact_or_error(request, options.artifact) {
        Ok(output) =>
          match options.output_file {
            Some(path) =>
              if write_text_file(path, output) {
                ()
              } else {
                eprintln("Failed to write output file: " + path)
                exit_with_code(1)
              }
            None => @tui.print_raw(output)
          }
        Err(error) => {
          eprintln(error)
          exit_with_code(1)
        }
      }
    Err(error) => {
      eprintln(error)
      exit_with_code(1)
    }
  }
}
