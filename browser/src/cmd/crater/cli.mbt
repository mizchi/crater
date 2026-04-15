///|
enum ArtifactMode {
  Layout
  Image
  Landmarks
} derive(Debug)

///|
pub impl Show for ArtifactMode with output(self, logger) {
  match self {
    Layout => logger.write_string("Layout")
    Image => logger.write_string("Image")
    Landmarks => logger.write_string("Landmarks")
  }
}

///|
struct Options {
  html_file : String
  stdin_html : Bool
  css_files : Array[String]
  stdin_css : Bool
  output_file : String?
  target_id : String?
  target_selector : String?
  artifact : ArtifactMode
  viewport_width : Int
  viewport_height : Int
  show_help : Bool
  error : String?
}

///|
let default_viewport_width = 1280

///|
let default_viewport_height = 720

///|
fn parse_int_simple(s : String) -> Int {
  let mut result = 0
  if s.is_empty() {
    return 0
  }
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return 0
    }
  }
  result
}

///|
fn parse_artifact_mode(value : String) -> ArtifactMode? {
  match value {
    "layout" => Some(Layout)
    "image" => Some(Image)
    "landmarks" => Some(Landmarks)
    _ => None
  }
}

///|
fn value_after_prefix(arg : String, prefix : String) -> String? {
  if arg.has_prefix(prefix) {
    Some(arg.unsafe_substring(start=prefix.length(), end=arg.length()))
  } else {
    None
  }
}

///|
fn missing_value_error(flag : String) -> String {
  "Missing value for " + flag
}

///|
fn unknown_argument_error(arg : String) -> String {
  "Unknown argument: " + arg
}

///|
fn parse_args() -> Options {
  parse_args_list(@tui.get_args())
}

///|
fn parse_args_list(args : Array[String]) -> Options {
  let mut html_file = ""
  let mut stdin_html = false
  let css_files : Array[String] = []
  let mut stdin_css = false
  let mut output_file : String? = None
  let mut target_id : String? = None
  let mut target_selector : String? = None
  let mut artifact = Landmarks
  let mut viewport_width = default_viewport_width
  let mut viewport_height = default_viewport_height
  let mut show_help = false
  let mut error : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match value_after_prefix(arg, "--html-file=") {
      Some(value) => {
        html_file = value
        i += 1
        continue
      }
      None => ()
    }
    match value_after_prefix(arg, "--css-file=") {
      Some(value) => {
        css_files.push(value)
        i += 1
        continue
      }
      None => ()
    }
    match value_after_prefix(arg, "--target-id=") {
      Some(value) => {
        target_id = Some(value)
        i += 1
        continue
      }
      None => ()
    }
    match value_after_prefix(arg, "--target-selector=") {
      Some(value) => {
        target_selector = Some(value)
        i += 1
        continue
      }
      None => ()
    }
    match value_after_prefix(arg, "--output-file=") {
      Some(value) => {
        output_file = Some(value)
        i += 1
        continue
      }
      None => ()
    }
    match value_after_prefix(arg, "--artifact=") {
      Some(value) =>
        match parse_artifact_mode(value) {
          Some(mode) => {
            artifact = mode
            i += 1
            continue
          }
          None => {
            error = Some("Unknown artifact: " + value)
            break
          }
        }
      None => ()
    }
    match value_after_prefix(arg, "--viewport-width=") {
      Some(value) => {
        viewport_width = parse_int_simple(value)
        i += 1
        continue
      }
      None => ()
    }
    match value_after_prefix(arg, "--viewport-height=") {
      Some(value) => {
        viewport_height = parse_int_simple(value)
        i += 1
        continue
      }
      None => ()
    }
    match arg {
      "-h" | "--help" => {
        show_help = true
        i += 1
      }
      "--stdin-html" => {
        stdin_html = true
        i += 1
      }
      "--stdin-css" => {
        stdin_css = true
        i += 1
      }
      "--html-file" =>
        match args.get(i + 1) {
          Some(value) => {
            html_file = value
            i += 2
          }
          None => {
            error = Some(missing_value_error("--html-file"))
            break
          }
        }
      "--css-file" =>
        match args.get(i + 1) {
          Some(value) => {
            css_files.push(value)
            i += 2
          }
          None => {
            error = Some(missing_value_error("--css-file"))
            break
          }
        }
      "--target-id" =>
        match args.get(i + 1) {
          Some(value) => {
            target_id = Some(value)
            i += 2
          }
          None => {
            error = Some(missing_value_error("--target-id"))
            break
          }
        }
      "--target-selector" =>
        match args.get(i + 1) {
          Some(value) => {
            target_selector = Some(value)
            i += 2
          }
          None => {
            error = Some(missing_value_error("--target-selector"))
            break
          }
        }
      "--output-file" =>
        match args.get(i + 1) {
          Some(value) => {
            output_file = Some(value)
            i += 2
          }
          None => {
            error = Some(missing_value_error("--output-file"))
            break
          }
        }
      "--artifact" =>
        match args.get(i + 1) {
          Some(value) =>
            match parse_artifact_mode(value) {
              Some(mode) => {
                artifact = mode
                i += 2
              }
              None => {
                error = Some("Unknown artifact: " + value)
                break
              }
            }
          None => {
            error = Some(missing_value_error("--artifact"))
            break
          }
        }
      "--viewport-width" =>
        match args.get(i + 1) {
          Some(value) => {
            viewport_width = parse_int_simple(value)
            i += 2
          }
          None => {
            error = Some(missing_value_error("--viewport-width"))
            break
          }
        }
      "--viewport-height" =>
        match args.get(i + 1) {
          Some(value) => {
            viewport_height = parse_int_simple(value)
            i += 2
          }
          None => {
            error = Some(missing_value_error("--viewport-height"))
            break
          }
        }
      _ => {
        error = Some(unknown_argument_error(arg))
        break
      }
    }
  }
  {
    html_file,
    stdin_html,
    css_files,
    stdin_css,
    output_file,
    target_id,
    target_selector,
    artifact,
    viewport_width,
    viewport_height,
    show_help,
    error,
  }
}

///|
fn validate_options(options : Options) -> String? {
  match options.error {
    Some(error) => return Some(error)
    None => ()
  }
  if !options.stdin_html && options.html_file.is_empty() {
    return Some("Either --html-file or --stdin-html is required")
  }
  if options.stdin_html && !options.html_file.is_empty() {
    return Some("Choose either --html-file or --stdin-html")
  }
  if options.stdin_html && options.stdin_css {
    return Some("Cannot use --stdin-html and --stdin-css together")
  }
  match (options.target_id, options.target_selector) {
    (Some(_), Some(_)) =>
      return Some("Choose either --target-id or --target-selector")
    (None, None) =>
      return Some("Either --target-id or --target-selector is required")
    _ => ()
  }
  if options.viewport_width <= 0 {
    return Some("--viewport-width must be > 0")
  }
  if options.viewport_height <= 0 {
    return Some("--viewport-height must be > 0")
  }
  None
}

///|
fn help_text() -> String {
  let buf = StringBuilder::new()
  buf.write_string("crater - component artifact renderer\n")
  buf.write_string("\n")
  buf.write_string("Render one component artifact from HTML + CSS inputs.\n")
  buf.write_string(
    "Use this for component VRT or structural checks, not full browser navigation.\n",
  )
  buf.write_string("\n")
  buf.write_string("USAGE:\n")
  buf.write_string(
    "  crater --html-file <path> (--target-id <id> | --target-selector <selector>) [OPTIONS]\n",
  )
  buf.write_string(
    "  cat fixture.html | crater --stdin-html (--target-id <id> | --target-selector <selector>) [OPTIONS]\n",
  )
  buf.write_string("\n")
  buf.write_string("INPUT MODEL:\n")
  buf.write_string(
    "  Reads HTML from --html-file or from stdin via --stdin-html.\n",
  )
  buf.write_string(
    "  Extracts only the subtree matched by --target-id or --target-selector.\n",
  )
  buf.write_string(
    "  --target-selector picks the first matching element in document order.\n",
  )
  buf.write_string("  Applies every --css-file in the order given.\n")
  buf.write_string(
    "  Optionally appends one extra CSS payload from stdin via --stdin-css.\n",
  )
  buf.write_string("\n")
  buf.write_string("ARTIFACTS:\n")
  buf.write_string("  layout     Layout JSON for the target subtree only\n")
  buf.write_string("  image      PNG base64 JSON with width/height metadata\n")
  buf.write_string(
    "  landmarks  Accessibility landmark tree JSON for fast structural checks\n",
  )
  buf.write_string("             Default: landmarks\n")
  buf.write_string("\n")
  buf.write_string("CSS:\n")
  buf.write_string(
    "  Repeat --css-file to layer baseline CSS and component CSS.\n",
  )
  buf.write_string(
    "  CSS and viewport settings mainly affect layout and image artifacts.\n",
  )
  buf.write_string("\n")
  buf.write_string("OUTPUT CONTRACT:\n")
  buf.write_string(
    "  Every artifact is emitted as JSON schema v1 with schemaVersion/artifact/targetId fields.\n",
  )
  buf.write_string(
    "  Selector targets are normalized to the resolved DOM id in targetId.\n",
  )
  buf.write_string("\n")
  buf.write_string("OPTIONS:\n")
  buf.write_string("  -h, --help                  Show this help message\n")
  buf.write_string("  --html-file <path>          Input HTML file\n")
  buf.write_string(
    "  --stdin-html                Read HTML from stdin instead of --html-file\n",
  )
  buf.write_string(
    "  --css-file <path>           External CSS file (repeatable)\n",
  )
  buf.write_string(
    "  --stdin-css                 Read one extra CSS payload from stdin\n",
  )
  buf.write_string(
    "  --output-file <path>        Write artifact JSON to a file instead of stdout\n",
  )
  buf.write_string(
    "  --target-id <id>            DOM id of the component root\n",
  )
  buf.write_string(
    "  --target-selector <selector>  CSS selector for the first matching component root\n",
  )
  buf.write_string("  --artifact <mode>           layout | image | landmarks\n")
  buf.write_string(
    "  --viewport-width <px>       Viewport width in px (default: 1280)\n",
  )
  buf.write_string(
    "  --viewport-height <px>      Viewport height in px (default: 720)\n",
  )
  buf.write_string("\n")
  buf.write_string("EXAMPLES:\n")
  buf.write_string("  Fast structural check (default):\n")
  buf.write_string(
    "    crater --html-file fixture.html --target-id card-root\n",
  )
  buf.write_string("  Read HTML from stdin:\n")
  buf.write_string(
    "    cat fixture.html | crater --stdin-html --target-id card-root\n",
  )
  buf.write_string("  Layout snapshot with baseline + component CSS:\n")
  buf.write_string(
    "    crater --html-file fixture.html --css-file baseline.css --css-file component.css --target-id card-root --artifact layout\n",
  )
  buf.write_string("  Add one extra CSS layer from stdin:\n")
  buf.write_string(
    "    cat component.css | crater --html-file fixture.html --stdin-css --target-id card-root --artifact layout\n",
  )
  buf.write_string("  Image snapshot for pixel diff / VRT:\n")
  buf.write_string(
    "    crater --html-file fixture.html --css-file baseline.css --css-file component.css --target-id card-root --artifact image --viewport-width 960 --viewport-height 720\n",
  )
  buf.write_string("  Match a component by selector:\n")
  buf.write_string(
    "    crater --html-file fixture.html --target-selector \".card.primary\" --artifact landmarks\n",
  )
  buf.write_string("  Write output to a file:\n")
  buf.write_string(
    "    crater --html-file fixture.html --target-id card-root --output-file artifact.json\n",
  )
  buf.to_string()
}

///|
fn print_help() -> Unit {
  @tui.print_raw(help_text() + "\n")
}
