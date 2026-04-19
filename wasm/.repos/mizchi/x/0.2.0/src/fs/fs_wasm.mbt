// WASI Preview 1 filesystem implementation

// FFI bindings

///|
fn wasi_fd_write(
  fd : Int,
  iovs_ptr : Int,
  iovs_len : Int,
  nwritten_ptr : Int,
) -> Int = "wasi_snapshot_preview1" "fd_write"

///|
fn wasi_fd_read(
  fd : Int,
  iovs_ptr : Int,
  iovs_len : Int,
  nread_ptr : Int,
) -> Int = "wasi_snapshot_preview1" "fd_read"

///|
fn wasi_fd_close(fd : Int) -> Int = "wasi_snapshot_preview1" "fd_close"

///|
fn wasi_path_open(
  fd : Int,
  dirflags : Int,
  path_ptr : Int,
  path_len : Int,
  oflags : Int,
  fs_rights_base : Int64,
  fs_rights_inheriting : Int64,
  fdflags : Int,
  fd_ptr : Int,
) -> Int = "wasi_snapshot_preview1" "path_open"

///|
fn wasi_path_unlink_file(fd : Int, path_ptr : Int, path_len : Int) -> Int = "wasi_snapshot_preview1" "path_unlink_file"

///|
fn wasi_path_create_directory(fd : Int, path_ptr : Int, path_len : Int) -> Int = "wasi_snapshot_preview1" "path_create_directory"

///|
fn wasi_path_remove_directory(fd : Int, path_ptr : Int, path_len : Int) -> Int = "wasi_snapshot_preview1" "path_remove_directory"

///|
fn wasi_fd_readdir(
  fd : Int,
  buf_ptr : Int,
  buf_len : Int,
  cookie : Int64,
  bufused_ptr : Int,
) -> Int = "wasi_snapshot_preview1" "fd_readdir"

// Memory helpers

///|
extern "wasm" fn wasm_memory_ptr(arr : FixedArray[Byte]) -> Int =
  #|(func (param i32) (result i32) local.get 0 i32.const 8 i32.add)

///|
extern "wasm" fn wasm_i32_store(ptr : Int, val : Int) -> Unit =
  #|(func (param i32) (param i32) local.get 0 local.get 1 i32.store)

///|
extern "wasm" fn wasm_i32_load(ptr : Int) -> Int =
  #|(func (param i32) (result i32) local.get 0 i32.load)

// Constants

///|
let wasi_right_fd_read : Int64 = 2L

///|
let wasi_right_fd_write : Int64 = 64L

///|
let wasi_right_fd_readdir : Int64 = 16384L

///|
let wasi_oflags_creat : Int = 1

///|
let wasi_oflags_trunc : Int = 8

///|
let wasi_oflags_directory : Int = 2

///|
let preopen_fd : Int = 3

// UTF-8 encoding helper

///|
fn string_to_utf8(s : StringView) -> FixedArray[Byte] {
  let buf : Array[Byte] = []
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      buf.push(cp.to_byte())
    } else if cp < 0x800 {
      buf.push((0xC0 | (cp >> 6)).to_byte())
      buf.push((0x80 | (cp & 0x3F)).to_byte())
    } else if cp < 0x10000 {
      buf.push((0xE0 | (cp >> 12)).to_byte())
      buf.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      buf.push((0x80 | (cp & 0x3F)).to_byte())
    } else {
      buf.push((0xF0 | (cp >> 18)).to_byte())
      buf.push((0x80 | ((cp >> 12) & 0x3F)).to_byte())
      buf.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      buf.push((0x80 | (cp & 0x3F)).to_byte())
    }
  }
  FixedArray::from_array(buf)
}

// UTF-8 decoding helper

///|
fn utf8_to_string(bytes : FixedArray[Byte], len : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
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

// Internal WASI file open

///|
fn wasi_open(
  path : StringView,
  oflags : Int,
  rights : Int64,
) -> Int raise IOError {
  let path_bytes = string_to_utf8(path)
  let path_ptr = wasm_memory_ptr(path_bytes)
  let path_len = path_bytes.length()
  let fd_buf = FixedArray::make(4, b'\x00')
  let fd_ptr = wasm_memory_ptr(fd_buf)
  let err = wasi_path_open(
    preopen_fd, 0, path_ptr, path_len, oflags, rights, rights, 0, fd_ptr,
  )
  if err != 0 {
    raise IOError::IOError("WASI error: " + err.to_string())
  }
  wasm_i32_load(fd_ptr)
}

///|
pub fn read_file(path : StringView) -> &@io.Data raise IOError {
  let fd = wasi_open(path, 0, wasi_right_fd_read)
  let chunks : Array[FixedArray[Byte]] = []
  let buf = FixedArray::make(4096, b'\x00')
  while true {
    let iov = FixedArray::make(8, b'\x00')
    let iov_ptr = wasm_memory_ptr(iov)
    let buf_ptr = wasm_memory_ptr(buf)
    wasm_i32_store(iov_ptr, buf_ptr)
    wasm_i32_store(iov_ptr + 4, 4096)
    let nread_buf = FixedArray::make(4, b'\x00')
    let nread_ptr = wasm_memory_ptr(nread_buf)
    let err = wasi_fd_read(fd, iov_ptr, 1, nread_ptr)
    if err != 0 {
      ignore(wasi_fd_close(fd))
      raise IOError::IOError("WASI read error: " + err.to_string())
    }
    let n = wasm_i32_load(nread_ptr)
    if n == 0 {
      break
    }
    let chunk = FixedArray::make(n, b'\x00')
    for i in 0..<n {
      chunk[i] = buf[i]
    }
    chunks.push(chunk)
  }
  ignore(wasi_fd_close(fd))
  let total = chunks.fold(init=0, fn(acc, chunk) { acc + chunk.length() })
  let result = FixedArray::make(total, b'\x00')
  let mut offset = 0
  for chunk in chunks {
    for i in 0..<chunk.length() {
      result[offset + i] = chunk[i]
    }
    offset += chunk.length()
  }
  let s = utf8_to_string(result, total)
  (s : &@io.Data)
}

///|
pub fn write_file(
  path : StringView,
  content : &@io.Data,
  create? : Int,
) -> Unit raise IOError {
  ignore(create)
  let oflags = wasi_oflags_creat | wasi_oflags_trunc
  let fd = wasi_open(path, oflags, wasi_right_fd_write)
  let data = content.binary()
  let buf = data.to_fixedarray()
  let iov = FixedArray::make(8, b'\x00')
  let iov_ptr = wasm_memory_ptr(iov)
  let buf_ptr = wasm_memory_ptr(buf)
  wasm_i32_store(iov_ptr, buf_ptr)
  wasm_i32_store(iov_ptr + 4, data.length())
  let nwritten_buf = FixedArray::make(4, b'\x00')
  let nwritten_ptr = wasm_memory_ptr(nwritten_buf)
  let err = wasi_fd_write(fd, iov_ptr, 1, nwritten_ptr)
  ignore(wasi_fd_close(fd))
  if err != 0 {
    raise IOError::IOError("WASI write error: " + err.to_string())
  }
}

///|
pub fn exists(path : StringView) -> Bool {
  try {
    let fd = wasi_open(path, 0, wasi_right_fd_read)
    ignore(wasi_fd_close(fd))
    true
  } catch {
    _ => false
  }
}

///|
pub fn mkdir(
  path : StringView,
  permission~ : Int,
  recursive? : Bool,
) -> Unit raise IOError {
  ignore(permission)
  ignore(recursive)
  let path_bytes = string_to_utf8(path)
  let path_ptr = wasm_memory_ptr(path_bytes)
  let path_len = path_bytes.length()
  let err = wasi_path_create_directory(preopen_fd, path_ptr, path_len)
  if err != 0 {
    raise IOError::IOError("WASI mkdir error: " + err.to_string())
  }
}

///|
pub fn readdir(path : StringView) -> Array[String] raise IOError {
  let fd = wasi_open(
    path,
    wasi_oflags_directory,
    wasi_right_fd_readdir | wasi_right_fd_read,
  )
  let buf_size = 4096
  let buf = FixedArray::make(buf_size, b'\x00')
  let buf_ptr = wasm_memory_ptr(buf)
  let bufused_buf = FixedArray::make(4, b'\x00')
  let bufused_ptr = wasm_memory_ptr(bufused_buf)
  let err = wasi_fd_readdir(fd, buf_ptr, buf_size, 0L, bufused_ptr)
  ignore(wasi_fd_close(fd))
  if err != 0 {
    raise IOError::IOError("WASI readdir error: " + err.to_string())
  }
  let bufused = wasm_i32_load(bufused_ptr)
  let entries : Array[String] = []
  let mut offset = 0
  // dirent layout: d_next(8) + d_ino(8) + d_namlen(4) + d_type(1) = 24 bytes header
  while offset + 24 <= bufused {
    let namlen = wasm_i32_load(buf_ptr + offset + 16)
    if offset + 24 + namlen > bufused {
      break
    }
    let name_bytes = FixedArray::make(namlen, b'\x00')
    for i in 0..<namlen {
      name_bytes[i] = buf[offset + 24 + i]
    }
    let name = utf8_to_string(name_bytes, namlen)
    if name != "." && name != ".." {
      entries.push(name)
    }
    offset = offset + 24 + namlen
  }
  entries
}

///|
pub fn remove(path : StringView) -> Unit raise IOError {
  let path_bytes = string_to_utf8(path)
  let path_ptr = wasm_memory_ptr(path_bytes)
  let path_len = path_bytes.length()
  let err = wasi_path_unlink_file(preopen_fd, path_ptr, path_len)
  if err != 0 {
    raise IOError::IOError("WASI remove error: " + err.to_string())
  }
}

///|
pub fn rmdir(path : StringView, recursive? : Bool) -> Unit raise IOError {
  ignore(recursive)
  let path_bytes = string_to_utf8(path)
  let path_ptr = wasm_memory_ptr(path_bytes)
  let path_len = path_bytes.length()
  let err = wasi_path_remove_directory(preopen_fd, path_ptr, path_len)
  if err != 0 {
    raise IOError::IOError("WASI rmdir error: " + err.to_string())
  }
}
