///|
pub struct ModuleSource {
  specifier : String
  source : String
}

///|
pub fn module_source(specifier : String, source : String) -> ModuleSource {
  ModuleSource::{ specifier, source }
}

///|
pub fn Runtime::load_modules(
  self : Runtime,
  modules : Array[ModuleSource],
) -> Result[Unit, V8Error] {
  for i in 0..<modules.length() {
    let source = modules[i]
    let loaded = self.load_module(source.specifier, source.source)
    guard loaded is Ok(_) else { return Err(loaded.unwrap_err()) }
  }
  Ok(())
}

///|
struct RuntimeBuilderState {
  mut snapshot : Bytes
  mut has_snapshot : Bool
  snapshot_sources : Array[String]
  modules : Array[ModuleSource]
  mut with_deno_core_compat : Bool
  mut with_node_compat : Bool
}

///|
pub struct RuntimeBuilder {
  priv state : Ref[RuntimeBuilderState]
}

///|
pub fn runtime_builder_new() -> RuntimeBuilder {
  RuntimeBuilder::{
    state: Ref::new(RuntimeBuilderState::{
      snapshot: Bytes::default(),
      has_snapshot: false,
      snapshot_sources: Array::default(),
      modules: Array::default(),
      with_deno_core_compat: false,
      with_node_compat: false,
    }),
  }
}

///|
pub fn RuntimeBuilder::with_snapshot(
  self : RuntimeBuilder,
  snapshot : Bytes,
) -> RuntimeBuilder {
  self.state.val.snapshot = snapshot
  self.state.val.has_snapshot = true
  self
}

///|
pub fn RuntimeBuilder::eval_snapshot(
  self : RuntimeBuilder,
  source : String,
) -> RuntimeBuilder {
  self.state.val.snapshot_sources.push(source)
  self
}

///|
pub fn RuntimeBuilder::with_snapshot_builder(
  self : RuntimeBuilder,
  snapshot_builder : SnapshotBuilder,
) -> RuntimeBuilder {
  if snapshot_builder.state.val.has_snapshot {
    self.state.val.snapshot = snapshot_builder.state.val.snapshot
    self.state.val.has_snapshot = true
  }
  for i in 0..<snapshot_builder.state.val.sources.length() {
    self.state.val.snapshot_sources.push(snapshot_builder.state.val.sources[i])
  }
  self
}

///|
pub fn RuntimeBuilder::load_module(
  self : RuntimeBuilder,
  specifier : String,
  source : String,
) -> RuntimeBuilder {
  self.state.val.modules.push(module_source(specifier, source))
  self
}

///|
pub fn RuntimeBuilder::load_modules(
  self : RuntimeBuilder,
  modules : Array[ModuleSource],
) -> RuntimeBuilder {
  for i in 0..<modules.length() {
    self.state.val.modules.push(modules[i])
  }
  self
}

///|
pub fn RuntimeBuilder::build_image(
  self : RuntimeBuilder,
) -> Result[RuntimeImage, V8Error] {
  let image = if self.state.val.has_snapshot ||
    !self.state.val.snapshot_sources.is_empty() {
    let snapshot_result = build_snapshot_from_parts(
      self.state.val.snapshot,
      self.state.val.has_snapshot,
      self.state.val.snapshot_sources,
    )
    guard snapshot_result is Ok(_) else {
      return Err(snapshot_result.unwrap_err())
    }
    runtime_image_from_parts(
      snapshot_result.unwrap(),
      true,
      Array::default(),
      self.state.val.with_deno_core_compat,
      self.state.val.with_node_compat,
    )
  } else {
    runtime_image_from_parts(
      Bytes::default(),
      false,
      Array::default(),
      self.state.val.with_deno_core_compat,
      self.state.val.with_node_compat,
    )
  }
  Ok(image.load_modules(self.state.val.modules))
}

///|
pub fn RuntimeBuilder::build(self : RuntimeBuilder) -> Result[Runtime, V8Error] {
  match self.build_image() {
    Ok(image) => image.build_runtime()
    Err(err) => Err(err)
  }
}

///|
pub fn[T] RuntimeBuilder::with_runtime(
  self : RuntimeBuilder,
  f : (Runtime) -> Result[T, V8Error],
) -> Result[T, V8Error] {
  match self.build() {
    Ok(runtime) => {
      let result = f(runtime)
      runtime.dispose()
      result
    }
    Err(err) => Err(err)
  }
}
