///|
/// Native TUI FFI bindings.

///|
extern "C" fn tui_enable_raw_mode() -> Int = "tui_enable_raw_mode"

///|
extern "C" fn tui_disable_raw_mode() -> Int = "tui_disable_raw_mode"

///|
extern "C" fn tui_is_raw_mode() -> Int = "tui_is_raw_mode"

///|
extern "C" fn tui_get_terminal_cols() -> Int = "tui_get_terminal_cols"

///|
extern "C" fn tui_get_terminal_rows() -> Int = "tui_get_terminal_rows"

///|
extern "C" fn tui_read_byte() -> Int = "tui_read_byte"

///|
extern "C" fn tui_is_tty() -> Int = "tui_is_tty"

///|
extern "C" fn tui_sleep_ms(ms : Int) = "tui_sleep_ms"

///|
#borrow(buf)
extern "C" fn tui_write_bytes_ffi(buf : FixedArray[Byte], len : Int) = "tui_write_bytes"

///|
extern "C" fn tui_flush() = "tui_flush"
