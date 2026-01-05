///|
/// TUI stub for WASM target (not supported)

///|
/// Read a key - not supported in WASM
pub fn read_key() -> String {
  panic()
}

///|
/// Read a line - not supported in WASM
pub fn read_line(_prompt : String) -> String {
  panic()
}

///|
/// Print string - not supported in WASM
pub fn print_raw(_s : String) -> Unit {
  ()
}

///|
/// Get command line arguments - not supported in WASM
pub fn get_args() -> Array[String] {
  []
}
