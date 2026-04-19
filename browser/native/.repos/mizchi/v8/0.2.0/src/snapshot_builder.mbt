///|
fn build_snapshot_from_parts(
  snapshot : Bytes,
  has_snapshot : Bool,
  sources : Array[String],
) -> Result[Bytes, V8Error] {
  if has_snapshot {
    let mut current = snapshot
    for i in 0..<sources.length() {
      let next = snapshot_extend(current, sources[i])
      guard next is Ok(_) else { return Err(next.unwrap_err()) }
      current = next.unwrap()
    }
    Ok(current)
  } else if sources.is_empty() {
    snapshot_create("")
  } else {
    let first = snapshot_create(sources[0])
    guard first is Ok(_) else { return Err(first.unwrap_err()) }
    let mut current = first.unwrap()
    for i in 1..<sources.length() {
      let next = snapshot_extend(current, sources[i])
      guard next is Ok(_) else { return Err(next.unwrap_err()) }
      current = next.unwrap()
    }
    Ok(current)
  }
}

///|
struct SnapshotBuilderState {
  mut snapshot : Bytes
  mut has_snapshot : Bool
  sources : Array[String]
  mut with_deno_core_compat : Bool
  mut with_node_compat : Bool
}

///|
pub struct SnapshotBuilder {
  priv state : Ref[SnapshotBuilderState]
}

///|
pub fn snapshot_builder_new() -> SnapshotBuilder {
  SnapshotBuilder::{
    state: Ref::new(SnapshotBuilderState::{
      snapshot: Bytes::default(),
      has_snapshot: false,
      sources: Array::default(),
      with_deno_core_compat: false,
      with_node_compat: false,
    }),
  }
}

///|
pub fn SnapshotBuilder::with_snapshot(
  self : SnapshotBuilder,
  snapshot : Bytes,
) -> SnapshotBuilder {
  self.state.val.snapshot = snapshot
  self.state.val.has_snapshot = true
  self
}

///|
pub fn SnapshotBuilder::eval(
  self : SnapshotBuilder,
  source : String,
) -> SnapshotBuilder {
  self.state.val.sources.push(source)
  self
}

///|
pub fn SnapshotBuilder::build(self : SnapshotBuilder) -> Result[Bytes, V8Error] {
  build_snapshot_from_parts(
    self.state.val.snapshot,
    self.state.val.has_snapshot,
    self.state.val.sources,
  )
}

///|
pub fn SnapshotBuilder::build_image(
  self : SnapshotBuilder,
) -> Result[RuntimeImage, V8Error] {
  match self.build() {
    Ok(snapshot) =>
      Ok(
        runtime_image_from_parts(
          snapshot,
          true,
          Array::default(),
          self.state.val.with_deno_core_compat,
          self.state.val.with_node_compat,
        ),
      )
    Err(err) => Err(err)
  }
}

///|
pub fn SnapshotBuilder::build_runtime(
  self : SnapshotBuilder,
) -> Result[Runtime, V8Error] {
  match self.build_image() {
    Ok(image) => image.build_runtime()
    Err(err) => Err(err)
  }
}

///|
pub fn[T] SnapshotBuilder::with_runtime(
  self : SnapshotBuilder,
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
