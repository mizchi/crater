///|
struct RuntimeImageState {
  snapshot : Bytes
  has_snapshot : Bool
  modules : Array[ModuleSource]
  with_deno_core_compat : Bool
  with_node_compat : Bool
}

///|
pub struct RuntimeImage {
  priv state : Ref[RuntimeImageState]
}

///|
fn runtime_image_from_parts(
  snapshot : Bytes,
  has_snapshot : Bool,
  modules : Array[ModuleSource],
  with_deno_core_compat : Bool,
  with_node_compat : Bool,
) -> RuntimeImage {
  RuntimeImage::{
    state: Ref::new(RuntimeImageState::{
      snapshot,
      has_snapshot,
      modules,
      with_deno_core_compat,
      with_node_compat,
    }),
  }
}

///|
pub fn runtime_image_new(snapshot : Bytes) -> RuntimeImage {
  runtime_image_from_parts(snapshot, true, Array::default(), false, false)
}

///|
pub fn RuntimeImage::load_module(
  self : RuntimeImage,
  specifier : String,
  source : String,
) -> RuntimeImage {
  self.state.val.modules.push(module_source(specifier, source))
  self
}

///|
pub fn RuntimeImage::load_modules(
  self : RuntimeImage,
  modules : Array[ModuleSource],
) -> RuntimeImage {
  for i in 0..<modules.length() {
    self.state.val.modules.push(modules[i])
  }
  self
}

///|
pub fn RuntimeImage::build_runtime(
  self : RuntimeImage,
) -> Result[Runtime, V8Error] {
  let runtime_result = if self.state.val.has_snapshot {
    runtime_new_with_snapshot(self.state.val.snapshot)
  } else {
    runtime_new()
  }
  match runtime_result {
    Ok(runtime) => {
      if self.state.val.with_deno_core_compat {
        let installed = runtime.install_deno_core_compat()
        guard installed is Ok(_) else {
          runtime.dispose()
          return Err(installed.unwrap_err())
        }
      }
      if self.state.val.with_node_compat {
        let installed = runtime.install_node_compat()
        guard installed is Ok(_) else {
          runtime.dispose()
          return Err(installed.unwrap_err())
        }
      }
      let loaded = runtime.load_modules(self.state.val.modules)
      guard loaded is Ok(_) else {
        runtime.dispose()
        return Err(loaded.unwrap_err())
      }
      Ok(runtime)
    }
    Err(err) => Err(err)
  }
}

///|
pub fn[T] RuntimeImage::with_runtime(
  self : RuntimeImage,
  f : (Runtime) -> Result[T, V8Error],
) -> Result[T, V8Error] {
  match self.build_runtime() {
    Ok(runtime) => {
      let result = f(runtime)
      runtime.dispose()
      result
    }
    Err(err) => Err(err)
  }
}
