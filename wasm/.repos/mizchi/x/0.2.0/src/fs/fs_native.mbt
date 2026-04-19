///|
pub async fn read_file(path : StringView) -> &@io.Data raise IOError {
  @async_fs.read_file(path) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn write_file(
  path : StringView,
  content : &@io.Data,
  create? : Int,
) -> Unit raise IOError {
  @async_fs.write_file(path, content, create=create.unwrap_or(0o644)) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn exists(path : StringView) -> Bool {
  @async_fs.exists(path)
}

///|
pub async fn mkdir(
  path : StringView,
  permission~ : Int,
  recursive? : Bool,
) -> Unit raise IOError {
  @async_fs.mkdir(path, permission~, recursive?) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn readdir(path : StringView) -> Array[String] raise IOError {
  @async_fs.readdir(path) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn remove(path : StringView) -> Unit raise IOError {
  @async_fs.remove(path) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn rmdir(path : StringView, recursive? : Bool) -> Unit raise IOError {
  @async_fs.rmdir(path, recursive?) catch {
    err => raise IOError::IOError(err.to_string())
  }
}
