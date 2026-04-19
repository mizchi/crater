// WASI Preview 1 environment and process implementation

// FFI bindings

///|
fn wasi_environ_sizes_get(count_ptr : Int, buf_size_ptr : Int) -> Int = "wasi_snapshot_preview1" "environ_sizes_get"

///|
fn wasi_environ_get(environ_ptr : Int, environ_buf_ptr : Int) -> Int = "wasi_snapshot_preview1" "environ_get"

///|
fn wasi_args_sizes_get(argc_ptr : Int, argv_buf_size_ptr : Int) -> Int = "wasi_snapshot_preview1" "args_sizes_get"

///|
fn wasi_args_get(argv_ptr : Int, argv_buf_ptr : Int) -> Int = "wasi_snapshot_preview1" "args_get"

///|
fn wasi_proc_exit(code : Int) = "wasi_snapshot_preview1" "proc_exit"

// Memory helpers

///|
extern "wasm" fn sys_wasm_memory_ptr(arr : FixedArray[Byte]) -> Int =
  #|(func (param i32) (result i32) local.get 0 i32.const 8 i32.add)

///|
extern "wasm" fn sys_wasm_i32_store(ptr : Int, val : Int) -> Unit =
  #|(func (param i32) (param i32) local.get 0 local.get 1 i32.store)

///|
extern "wasm" fn sys_wasm_i32_load(ptr : Int) -> Int =
  #|(func (param i32) (result i32) local.get 0 i32.load)

// UTF-8 decoding helper

///|
fn sys_utf8_to_string(
  bytes : FixedArray[Byte],
  start : Int,
  len : Int,
) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  let end = start + len
  while i < end {
    let b0 = bytes[i].to_int()
    if b0 < 0x80 {
      buf.write_char(Int::unsafe_to_char(b0))
      i += 1
    } else if b0 < 0xE0 {
      let cp = ((b0 & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i += 2
    } else if b0 < 0xF0 {
      let cp = ((b0 & 0x0F) << 12) |
        ((bytes[i + 1].to_int() & 0x3F) << 6) |
        (bytes[i + 2].to_int() & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i += 3
    } else {
      let cp = ((b0 & 0x07) << 18) |
        ((bytes[i + 1].to_int() & 0x3F) << 12) |
        ((bytes[i + 2].to_int() & 0x3F) << 6) |
        (bytes[i + 3].to_int() & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i += 4
    }
  }
  buf.to_string()
}

// Public API

///|
pub fn get_env_var(name : String) -> String? {
  let vars = get_env_vars()
  vars.get(name)
}

///|
pub fn get_env_vars() -> Map[String, String] {
  let count_buf = FixedArray::make(4, b'\x00')
  let size_buf = FixedArray::make(4, b'\x00')
  let count_ptr = sys_wasm_memory_ptr(count_buf)
  let size_ptr = sys_wasm_memory_ptr(size_buf)
  let err = wasi_environ_sizes_get(count_ptr, size_ptr)
  if err != 0 {
    return {}
  }
  let count = sys_wasm_i32_load(count_ptr)
  let buf_size = sys_wasm_i32_load(size_ptr)
  if count == 0 {
    return {}
  }
  let ptrs = FixedArray::make(count * 4, b'\x00')
  let data = FixedArray::make(buf_size, b'\x00')
  let ptrs_ptr = sys_wasm_memory_ptr(ptrs)
  let data_ptr = sys_wasm_memory_ptr(data)
  let err2 = wasi_environ_get(ptrs_ptr, data_ptr)
  if err2 != 0 {
    return {}
  }
  let result : Map[String, String] = {}
  for i in 0..<count {
    let var_ptr = sys_wasm_i32_load(ptrs_ptr + i * 4)
    let offset = var_ptr - data_ptr
    let mut len = 0
    while offset + len < buf_size && data[offset + len] != b'\x00' {
      len += 1
    }
    // Find '=' separator in raw bytes
    let mut eq_pos = -1
    for j in 0..<len {
      if data[offset + j].to_int() == 0x3D {
        eq_pos = j
        break
      }
    }
    if eq_pos >= 0 {
      let key = sys_utf8_to_string(data, offset, eq_pos)
      let val = sys_utf8_to_string(data, offset + eq_pos + 1, len - eq_pos - 1)
      result[key] = val
    }
  }
  result
}

///|
pub fn get_cli_args() -> Array[String] {
  let argc_buf = FixedArray::make(4, b'\x00')
  let size_buf = FixedArray::make(4, b'\x00')
  let argc_ptr = sys_wasm_memory_ptr(argc_buf)
  let size_ptr = sys_wasm_memory_ptr(size_buf)
  let err = wasi_args_sizes_get(argc_ptr, size_ptr)
  if err != 0 {
    return []
  }
  let argc = sys_wasm_i32_load(argc_ptr)
  let buf_size = sys_wasm_i32_load(size_ptr)
  if argc == 0 {
    return []
  }
  let argv = FixedArray::make(argc * 4, b'\x00')
  let argv_buf = FixedArray::make(buf_size, b'\x00')
  let argv_ptr = sys_wasm_memory_ptr(argv)
  let argv_buf_ptr = sys_wasm_memory_ptr(argv_buf)
  let err2 = wasi_args_get(argv_ptr, argv_buf_ptr)
  if err2 != 0 {
    return []
  }
  let result : Array[String] = []
  for i in 0..<argc {
    let arg_ptr = sys_wasm_i32_load(argv_ptr + i * 4)
    let offset = arg_ptr - argv_buf_ptr
    let mut len = 0
    while offset + len < buf_size && argv_buf[offset + len] != b'\x00' {
      len += 1
    }
    result.push(sys_utf8_to_string(argv_buf, offset, len))
  }
  result
}

///|
pub fn set_env_var(_name : String, _value : String) -> Unit {
  abort("set_env_var is not supported on wasm target")
}

///|
pub fn unset_env_var(_name : String) -> Unit {
  abort("unset_env_var is not supported on wasm target")
}

///|
pub fn exit(code : Int) -> Unit {
  wasi_proc_exit(code)
}
