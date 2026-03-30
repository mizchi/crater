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
/// Try to find and load a system font, returns font file bytes
fn load_system_font() -> Bytes {
  // macOS system font paths (in preference order)
  let font_paths = [
    // macOS: SF Pro (closest to -apple-system)
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    // Linux fallbacks
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
  ]
  for path in font_paths {
    let data = js_read_binary_file(path)
    if data.length() > 100 {
      return data
    }
  }
  Bytes::new(0)
}

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
