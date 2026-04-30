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
