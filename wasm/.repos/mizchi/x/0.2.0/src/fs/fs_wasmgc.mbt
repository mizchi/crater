///|
pub fn read_file(_path : StringView) -> &@io.Data raise IOError {
  raise IOError::IOError("read_file is not supported on wasm target")
}

///|
pub fn write_file(
  _path : StringView,
  _content : &@io.Data,
  create? : Int,
) -> Unit raise IOError {
  ignore(create)
  raise IOError::IOError("write_file is not supported on wasm target")
}

///|
pub fn exists(_path : StringView) -> Bool {
  false
}

///|
pub fn mkdir(
  _path : StringView,
  permission~ : Int,
  recursive? : Bool,
) -> Unit raise IOError {
  ignore(permission)
  ignore(recursive)
  raise IOError::IOError("mkdir is not supported on wasm target")
}

///|
pub fn readdir(_path : StringView) -> Array[String] raise IOError {
  raise IOError::IOError("readdir is not supported on wasm target")
}

///|
pub fn remove(_path : StringView) -> Unit raise IOError {
  raise IOError::IOError("remove is not supported on wasm target")
}

///|
pub fn rmdir(_path : StringView, recursive? : Bool) -> Unit raise IOError {
  ignore(recursive)
  raise IOError::IOError("rmdir is not supported on wasm target")
}
