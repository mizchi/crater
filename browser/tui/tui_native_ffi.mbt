///|
/// Native TUI FFI bindings.

///|
extern "C" fn tui_enable_raw_mode() -> Int32 = "tui_enable_raw_mode"

///|
extern "C" fn tui_disable_raw_mode() -> Int32 = "tui_disable_raw_mode"

///|
extern "C" fn tui_is_raw_mode() -> Int32 = "tui_is_raw_mode"

///|
extern "C" fn tui_get_terminal_cols() -> Int32 = "tui_get_terminal_cols"

///|
extern "C" fn tui_get_terminal_rows() -> Int32 = "tui_get_terminal_rows"

///|
extern "C" fn tui_read_byte() -> Int32 = "tui_read_byte"

///|
extern "C" fn tui_is_tty() -> Int32 = "tui_is_tty"

///|
extern "C" fn tui_sleep_ms(ms : Int32) = "tui_sleep_ms"

///|
#borrow(buf)
extern "C" fn tui_write_bytes_ffi(buf : FixedArray[Byte], len : Int32) = "tui_write_bytes"

///|
extern "C" fn tui_flush() = "tui_flush"
