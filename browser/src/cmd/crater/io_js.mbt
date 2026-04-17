///|
extern "js" fn js_read_text_file(path : String) -> String? =
  #| (path) => {
  #|   if (typeof process === "undefined") return null;
  #|   try {
  #|     const fs = require("node:fs");
  #|     return fs.readFileSync(String(path), "utf8");
  #|   } catch (_err) {
  #|     return null;
  #|   }
  #| }

///|
extern "js" fn js_read_stdin_text() -> String? =
  #| () => {
  #|   if (typeof process === "undefined") return null;
  #|   try {
  #|     const fs = require("node:fs");
  #|     return fs.readFileSync(0, "utf8");
  #|   } catch (_err) {
  #|     return null;
  #|   }
  #| }

///|
extern "js" fn js_write_stderr(s : String) -> Unit =
  #| (s) => {
  #|   if (typeof process === "undefined") return;
  #|   process.stderr.write(String(s));
  #| }

///|
extern "js" fn js_exit(code : Int) -> Unit =
  #| (code) => {
  #|   if (typeof process === "undefined") return;
  #|   process.exit(Number(code));
  #| }

///|
extern "js" fn js_write_text_file(path : String, content : String) -> Bool =
  #| (path, content) => {
  #|   if (typeof process === "undefined") return false;
  #|   try {
  #|     const fs = require("node:fs");
  #|     fs.writeFileSync(String(path), String(content), "utf8");
  #|     return true;
  #|   } catch (_err) {
  #|     return false;
  #|   }
  #| }

///|
fn load_first_font_candidate(paths : Array[String]) -> Bytes {
  for path in paths {
    let data = js_read_binary_file(path)
    if data.length() > 100 {
      return data
    }
  }
  Bytes::new(0)
}

///|
fn system_font_face_candidates() -> Array[(Array[String], Array[String])] {
  [
    (
      [
        "/System/Library/Fonts/Supplemental/Arial.ttf", "/Library/Fonts/Arial.ttf",
      ],
      [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf", "/Library/Fonts/Arial Bold.ttf",
      ],
    ),
    (
      [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
      ],
      [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
      ],
    ),
    (["/System/Library/Fonts/SFNS.ttf"], []),
  ]
}

///|
fn load_system_font_faces() -> (Bytes, Bytes) {
  let candidates = system_font_face_candidates()
  for candidate in candidates {
    let (regular_paths, bold_paths) = candidate
    let regular = load_first_font_candidate(regular_paths)
    if regular.length() == 0 || bold_paths.is_empty() {
      continue
    }
    let bold = load_first_font_candidate(bold_paths)
    if bold.length() > 0 {
      return (regular, bold)
    }
  }
  for candidate in candidates {
    let (regular_paths, bold_paths) = candidate
    let regular = load_first_font_candidate(regular_paths)
    if regular.length() == 0 {
      continue
    }
    let bold = if bold_paths.is_empty() {
      Bytes::new(0)
    } else {
      load_first_font_candidate(bold_paths)
    }
    return (regular, bold)
  }
  (Bytes::new(0), Bytes::new(0))
}

///|
/// Read binary file as Bytes
extern "js" fn js_read_binary_file(path : String) -> Bytes =
  #| (path) => {
  #|   if (typeof process === "undefined") return new Uint8Array(0);
  #|   try {
  #|     const fs = require("node:fs");
  #|     const buf = fs.readFileSync(String(path));
  #|     return new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
  #|   } catch (_err) {
  #|     return new Uint8Array(0);
  #|   }
  #| }

///|
fn read_text_file(path : String) -> String? {
  js_read_text_file(path)
}

///|
fn read_stdin_text() -> String? {
  js_read_stdin_text()
}

///|
fn write_text_file(path : String, content : String) -> Bool {
  js_write_text_file(path, content)
}

///|
fn eprint_raw(s : String) -> Unit {
  js_write_stderr(s)
}

///|
fn eprintln(s : String) -> Unit {
  eprint_raw(s + "\n")
}

///|
fn exit_with_code(code : Int) -> Unit {
  js_exit(code)
}
