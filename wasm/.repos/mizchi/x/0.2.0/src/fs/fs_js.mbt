///|
#external
priv type JsPromise[T]

///|
fn[T, U] JsPromise::cast(self : JsPromise[T]) -> @js_async.Promise[U] = "%identity"

///|
extern "js" fn js_read_file(path : String) -> JsPromise[String] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   return await fs.readFile(path, 'utf-8');
  #| }

///|
extern "js" fn js_write_file(
  path : String,
  content : String,
) -> JsPromise[Unit] =
  #| async (path, content) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.writeFile(path, content, 'utf-8');
  #| }

///|
extern "js" fn js_exists(path : String) -> JsPromise[Bool] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   try { await fs.access(path); return true; }
  #|   catch { return false; }
  #| }

///|
extern "js" fn js_mkdir(path : String, recursive : Bool) -> JsPromise[Unit] =
  #| async (path, recursive) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.mkdir(path, { recursive });
  #| }

///|
extern "js" fn js_readdir(path : String) -> JsPromise[Array[String]] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   return await fs.readdir(path);
  #| }

///|
extern "js" fn js_remove(path : String) -> JsPromise[Unit] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.rm(path, { force: true });
  #| }

///|
extern "js" fn js_rmdir(path : String, recursive : Bool) -> JsPromise[Unit] =
  #| async (path, recursive) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.rm(path, { recursive, force: true });
  #| }

///|
async fn[T] run_js_promise(promise : JsPromise[T]) -> T raise IOError {
  @js_async.run_promise(fn(_signal) { promise.cast() }) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn read_file(path : StringView) -> &@io.Data raise IOError {
  let s : String = run_js_promise(js_read_file(path.to_string()))
  s
}

///|
pub async fn write_file(
  path : StringView,
  content : &@io.Data,
  create? : Int,
) -> Unit raise IOError {
  ignore(create)
  let text = content.text() catch {
    err => raise IOError::IOError(err.to_string())
  }
  run_js_promise(js_write_file(path.to_string(), text))
}

///|
pub async fn exists(path : StringView) -> Bool {
  run_js_promise(js_exists(path.to_string())) catch {
    _ => false
  }
}

///|
pub async fn mkdir(
  path : StringView,
  permission~ : Int,
  recursive? : Bool,
) -> Unit raise IOError {
  ignore(permission)
  run_js_promise(js_mkdir(path.to_string(), recursive.unwrap_or(false)))
}

///|
pub async fn readdir(path : StringView) -> Array[String] raise IOError {
  run_js_promise(js_readdir(path.to_string()))
}

///|
pub async fn remove(path : StringView) -> Unit raise IOError {
  run_js_promise(js_remove(path.to_string()))
}

///|
pub async fn rmdir(path : StringView, recursive? : Bool) -> Unit raise IOError {
  run_js_promise(js_rmdir(path.to_string(), recursive.unwrap_or(false)))
}
