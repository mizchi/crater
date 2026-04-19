///|
fn ensure_resource_runtime_open(runtime : Runtime) -> Result[Unit, V8Error] {
  if runtime.is_closed() {
    Err(V8Error::RuntimeClosed)
  } else {
    Ok(())
  }
}

///|
fn close_resource_entry(entry : RuntimeResourceEntry) -> Unit {
  match entry.on_close {
    Some(on_close) => on_close()
    None => ()
  }
}

///|
fn runtime_take_resource_entry(
  runtime : Runtime,
  rid : Int,
) -> RuntimeResourceEntry? {
  let entry = runtime.state.val.resources.entries.get(rid)
  match entry {
    Some(entry) => {
      runtime.state.val.resources.entries.remove(rid)
      Some(entry)
    }
    None => None
  }
}

///|
fn runtime_add_resource_entry(
  runtime : Runtime,
  name : String,
  on_close : (() -> Unit)?,
  is_ref : Bool,
) -> Result[Int, V8Error] {
  let open = ensure_resource_runtime_open(runtime)
  guard open is Ok(_) else { return Err(open.unwrap_err()) }
  let rid = runtime.state.val.resources.next_rid
  runtime.state.val.resources.next_rid += 1
  runtime.state.val.resources.entries.set(rid, RuntimeResourceEntry::{
    name,
    on_close,
    is_ref,
  })
  Ok(rid)
}

///|
fn runtime_resource_exists(
  runtime : Runtime,
  rid : Int,
) -> Result[Bool, V8Error] {
  let open = ensure_resource_runtime_open(runtime)
  guard open is Ok(_) else { return Err(open.unwrap_err()) }
  Ok(runtime.state.val.resources.entries.contains(rid))
}

///|
fn runtime_set_resource_ref_state(
  runtime : Runtime,
  rid : Int,
  is_ref : Bool,
) -> Result[Bool, V8Error] {
  let open = ensure_resource_runtime_open(runtime)
  guard open is Ok(_) else { return Err(open.unwrap_err()) }
  let mut changed = false
  runtime.state.val.resources.entries.update(rid, entry => {
    match entry {
      Some(entry) => {
        changed = true
        Some(RuntimeResourceEntry::{
          name: entry.name,
          on_close: entry.on_close,
          is_ref,
        })
      }
      None => None
    }
  })
  Ok(changed)
}

///|
fn runtime_resource_list_json(runtime : Runtime) -> Result[String, V8Error] {
  let listed = runtime.list_resources()
  guard listed is Ok(_) else { return Err(listed.unwrap_err()) }
  let values : Map[String, Json] = Map::new()
  listed
  .unwrap()
  .each(resource => {
    values.set(resource.rid.to_string(), Json::string(resource.name))
  })
  Ok(Json::object(values).stringify())
}

///|
fn parse_resource_rid(payload_json : String) -> Result[Int, String] {
  try @strconv.parse_int(payload_json.trim()) |> Ok catch {
    StrConvError(message) =>
      Err("invalid resource id payload: " + payload_json + " (" + message + ")")
  }
}

///|
fn runtime_close_all_resources(runtime : Runtime) -> Unit {
  let entries : Array[RuntimeResourceEntry] = []
  runtime.state.val.resources.entries.each((_rid, entry) => entries.push(entry))
  runtime.state.val.resources.entries.clear()
  entries.each(entry => close_resource_entry(entry))
}

///|
pub fn Runtime::add_resource(
  self : Runtime,
  name : String,
) -> Result[Int, V8Error] {
  runtime_add_resource_entry(self, name, None, true)
}

///|
pub fn Runtime::add_resource_with_close(
  self : Runtime,
  name : String,
  on_close : () -> Unit,
) -> Result[Int, V8Error] {
  runtime_add_resource_entry(self, name, Some(on_close), true)
}

///|
pub fn Runtime::ref_resource(
  self : Runtime,
  rid : Int,
) -> Result[Bool, V8Error] {
  runtime_set_resource_ref_state(self, rid, true)
}

///|
pub fn Runtime::unref_resource(
  self : Runtime,
  rid : Int,
) -> Result[Bool, V8Error] {
  runtime_set_resource_ref_state(self, rid, false)
}

///|
pub fn Runtime::get_resource_name(
  self : Runtime,
  rid : Int,
) -> Result[String?, V8Error] {
  let open = ensure_resource_runtime_open(self)
  guard open is Ok(_) else { return Err(open.unwrap_err()) }
  Ok(self.state.val.resources.entries.get(rid).map(entry => entry.name))
}

///|
pub fn Runtime::list_resources(
  self : Runtime,
) -> Result[Array[RuntimeResource], V8Error] {
  let open = ensure_resource_runtime_open(self)
  guard open is Ok(_) else { return Err(open.unwrap_err()) }
  let resources : Array[RuntimeResource] = []
  self.state.val.resources.entries.each((rid, entry) => {
    resources.push(RuntimeResource::{
      rid,
      name: entry.name,
      is_ref: entry.is_ref,
    })
  })
  resources.sort_by((left, right) => left.rid - right.rid)
  Ok(resources)
}

///|
pub fn Runtime::try_close_resource(
  self : Runtime,
  rid : Int,
) -> Result[Bool, V8Error] {
  let open = ensure_resource_runtime_open(self)
  guard open is Ok(_) else { return Err(open.unwrap_err()) }
  match runtime_take_resource_entry(self, rid) {
    Some(entry) => {
      close_resource_entry(entry)
      Ok(true)
    }
    None => Ok(false)
  }
}

///|
pub fn Runtime::close_resource(
  self : Runtime,
  rid : Int,
) -> Result[Unit, V8Error] {
  let closed = self.try_close_resource(rid)
  guard closed is Ok(_) else { return Err(closed.unwrap_err()) }
  if closed.unwrap() {
    Ok(())
  } else {
    Err(V8Error::NativeError("resource not found: " + rid.to_string()))
  }
}
