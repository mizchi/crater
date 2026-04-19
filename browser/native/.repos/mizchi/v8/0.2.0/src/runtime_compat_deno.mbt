///|
fn deno_core_resources_op_name() -> String {
  "__mizchi_v8_deno_resources__"
}

///|
fn deno_core_close_op_name() -> String {
  "__mizchi_v8_deno_close__"
}

///|
fn deno_core_try_close_op_name() -> String {
  "__mizchi_v8_deno_try_close__"
}

///|
fn deno_core_sleep_op_name() -> String {
  "__mizchi_v8_deno_sleep__"
}

///|
fn deno_core_resource_exists_op_name() -> String {
  "__mizchi_v8_deno_resource_exists__"
}

///|
fn deno_core_sleep_resource_create_op_name() -> String {
  "__mizchi_v8_deno_sleep_resource_create__"
}

///|
fn deno_core_timeout_resource_create_op_name() -> String {
  "__mizchi_v8_deno_timeout_resource_create__"
}

///|
fn deno_core_interval_resource_create_op_name() -> String {
  "__mizchi_v8_deno_interval_resource_create__"
}

///|
fn deno_core_promise_resource_create_op_name() -> String {
  "__mizchi_v8_deno_promise_resource_create__"
}

///|
fn deno_core_ref_resource_op_name() -> String {
  "__mizchi_v8_deno_ref_resource__"
}

///|
fn deno_core_unref_resource_op_name() -> String {
  "__mizchi_v8_deno_unref_resource__"
}

///|
fn parse_deno_delay_ms(payload_json : String) -> Result[Int, String] {
  let delay = parse_resource_rid(payload_json)
  guard delay is Ok(_) else { return Err(delay.unwrap_err()) }
  if delay.unwrap() <= 0 {
    Ok(0)
  } else {
    Ok(delay.unwrap())
  }
}

///|
fn json_int(value : Int) -> String {
  Json::number(value.to_double(), repr=value.to_string()).stringify()
}

///|
fn json_bool(value : Bool) -> String {
  Json::boolean(value).stringify()
}

///|
fn add_deno_named_resource_json(
  runtime : Runtime,
  name : String,
) -> Result[String, String] {
  let rid = runtime_add_resource_entry(runtime, name, None, true)
  guard rid is Ok(_) else { return Err(rid.unwrap_err().to_string()) }
  Ok(json_int(rid.unwrap()))
}

///|
fn install_deno_core_runtime_compat(runtime : Runtime) -> Result[Unit, V8Error] {
  let registered_resources = runtime.register_sync_json_result_callback(
    deno_core_resources_op_name(),
    _payload => {
      let resources_json = runtime_resource_list_json(runtime)
      guard resources_json is Ok(_) else {
        return Err(resources_json.unwrap_err().to_string())
      }
      Ok(resources_json.unwrap())
    },
  )
  guard registered_resources is Ok(_) else {
    return Err(registered_resources.unwrap_err())
  }
  let registered_close = runtime.register_sync_json_result_callback(
    deno_core_close_op_name(),
    payload_json => {
      let rid = parse_resource_rid(payload_json)
      guard rid is Ok(_) else { return Err(rid.unwrap_err()) }
      let closed = runtime.close_resource(rid.unwrap())
      guard closed is Ok(_) else { return Err(closed.unwrap_err().to_string()) }
      Ok("null")
    },
  )
  guard registered_close is Ok(_) else {
    return Err(registered_close.unwrap_err())
  }
  let registered_try_close = runtime.register_sync_json_result_callback(
    deno_core_try_close_op_name(),
    payload_json => {
      let rid = parse_resource_rid(payload_json)
      guard rid is Ok(_) else { return Err(rid.unwrap_err()) }
      let closed = runtime.try_close_resource(rid.unwrap())
      guard closed is Ok(_) else { return Err(closed.unwrap_err().to_string()) }
      Ok(Json::boolean(closed.unwrap()).stringify())
    },
  )
  guard registered_try_close is Ok(_) else {
    return Err(registered_try_close.unwrap_err())
  }
  let registered_sleep = runtime.register_async_json_task_result_callback(
    deno_core_sleep_op_name(),
    payload_json => {
      let delay = parse_deno_delay_ms(payload_json)
      guard delay is Ok(_) else { return Err(delay.unwrap_err()) }
      if delay.unwrap() == 0 {
        @async.pause()
      } else {
        @async.sleep(delay.unwrap())
      }
      Ok("null")
    },
  )
  guard registered_sleep is Ok(_) else {
    return Err(registered_sleep.unwrap_err())
  }
  let registered_resource_exists = runtime.register_sync_json_result_callback(
    deno_core_resource_exists_op_name(),
    payload_json => {
      let rid = parse_resource_rid(payload_json)
      guard rid is Ok(_) else { return Err(rid.unwrap_err()) }
      let exists = runtime_resource_exists(runtime, rid.unwrap())
      guard exists is Ok(_) else { return Err(exists.unwrap_err().to_string()) }
      Ok(json_bool(exists.unwrap()))
    },
  )
  guard registered_resource_exists is Ok(_) else {
    return Err(registered_resource_exists.unwrap_err())
  }
  let registered_sleep_resource = runtime.register_sync_json_result_callback(
    deno_core_sleep_resource_create_op_name(),
    _payload => add_deno_named_resource_json(runtime, "sleep"),
  )
  guard registered_sleep_resource is Ok(_) else {
    return Err(registered_sleep_resource.unwrap_err())
  }
  let registered_timeout_resource = runtime.register_sync_json_result_callback(
    deno_core_timeout_resource_create_op_name(),
    _payload => add_deno_named_resource_json(runtime, "timeout"),
  )
  guard registered_timeout_resource is Ok(_) else {
    return Err(registered_timeout_resource.unwrap_err())
  }
  let registered_interval_resource = runtime.register_sync_json_result_callback(
    deno_core_interval_resource_create_op_name(),
    _payload => add_deno_named_resource_json(runtime, "interval"),
  )
  guard registered_interval_resource is Ok(_) else {
    return Err(registered_interval_resource.unwrap_err())
  }
  let registered_promise_resource = runtime.register_sync_json_result_callback(
    deno_core_promise_resource_create_op_name(),
    _payload => add_deno_named_resource_json(runtime, "promise"),
  )
  guard registered_promise_resource is Ok(_) else {
    return Err(registered_promise_resource.unwrap_err())
  }
  let registered_ref_resource = runtime.register_sync_json_result_callback(
    deno_core_ref_resource_op_name(),
    payload_json => {
      let rid = parse_resource_rid(payload_json)
      guard rid is Ok(_) else { return Err(rid.unwrap_err()) }
      let changed = runtime.ref_resource(rid.unwrap())
      guard changed is Ok(_) else {
        return Err(changed.unwrap_err().to_string())
      }
      Ok(json_bool(changed.unwrap()))
    },
  )
  guard registered_ref_resource is Ok(_) else {
    return Err(registered_ref_resource.unwrap_err())
  }
  let registered_unref_resource = runtime.register_sync_json_result_callback(
    deno_core_unref_resource_op_name(),
    payload_json => {
      let rid = parse_resource_rid(payload_json)
      guard rid is Ok(_) else { return Err(rid.unwrap_err()) }
      let changed = runtime.unref_resource(rid.unwrap())
      guard changed is Ok(_) else {
        return Err(changed.unwrap_err().to_string())
      }
      Ok(json_bool(changed.unwrap()))
    },
  )
  guard registered_unref_resource is Ok(_) else {
    return Err(registered_unref_resource.unwrap_err())
  }
  Ok(())
}

///|
fn deno_core_compat_source() -> String {
  "(function(){ " +
  "const root = globalThis; " +
  "const deno = root.Deno ?? (root.Deno = {}); " +
  "const toDelay = function(value){ const number = Number(value ?? 0); if (!Number.isFinite(number) || number <= 0) return 0; return Math.trunc(number); }; " +
  "const encode = typeof TextEncoder === 'function' ? function(value){ return new TextEncoder().encode(String(value)); } : function(value){ const text = String(value); const out = new Uint8Array(text.length); for (let i = 0; i < text.length; i += 1) out[i] = text.charCodeAt(i) & 255; return out; }; " +
  "const asBytes = function(value){ if (value instanceof Uint8Array) return value; if (ArrayBuffer.isView(value)) return new Uint8Array(value.buffer, value.byteOffset, value.byteLength); if (value instanceof ArrayBuffer) return new Uint8Array(value); return new Uint8Array(0); }; " +
  "const decode = typeof TextDecoder === 'function' ? function(value){ return new TextDecoder().decode(asBytes(value)); } : function(value){ const bytes = asBytes(value); let out = ''; for (let i = 0; i < bytes.length; i += 1) out += String.fromCharCode(bytes[i]); return out; }; " +
  "if (!Array.isArray(deno.args)) deno.args = []; " +
  "if (typeof deno.build !== 'object' || deno.build === null) deno.build = { arch: 'unknown', os: 'unknown', vendor: 'unknown', target: 'unknown' }; " +
  "if (typeof deno.version !== 'object' || deno.version === null) deno.version = { deno: '0.0.0-mizchi-v8', v8: '" +
  version() +
  "', typescript: 'unknown' }; " +
  "if (typeof deno.pid !== 'number') deno.pid = 0; " +
  "if (typeof deno.ppid !== 'number') deno.ppid = 0; " +
  "if (typeof deno.noColor !== 'boolean') deno.noColor = false; " +
  "if (typeof deno.exitCode !== 'number') deno.exitCode = 0; " +
  "if (typeof deno.cwd !== 'function') deno.cwd = function(){ return '/'; }; " +
  "if (typeof deno.execPath !== 'function') deno.execPath = function(){ return '/mizchi-v8/deno'; }; " +
  "if (typeof deno.inspect !== 'function') deno.inspect = function(value, _options){ try { const inspected = JSON.stringify(value); return inspected === undefined ? String(value) : inspected; } catch (_) { return String(value); } }; " +
  "const core = deno.core ?? (deno.core = {}); " +
  "if (typeof core.opSync !== 'function') core.opSync = function(name, payload){ return MoonBit.opSync(name, payload); }; " +
  "const promiseRidKey = '__mizchi_v8_resource_rid__'; " +
  "const createManagedResource = function(kind){ switch (kind) { case 'sleep': return MoonBit.opSync('" +
  deno_core_sleep_resource_create_op_name() +
  "', null); case 'timeout': return MoonBit.opSync('" +
  deno_core_timeout_resource_create_op_name() +
  "', null); case 'interval': return MoonBit.opSync('" +
  deno_core_interval_resource_create_op_name() +
  "', null); default: return MoonBit.opSync('" +
  deno_core_promise_resource_create_op_name() +
  "', null); } }; " +
  "const getPromiseRid = function(promise){ if ((typeof promise !== 'object' && typeof promise !== 'function') || promise === null) return undefined; const rid = promise[promiseRidKey]; return typeof rid === 'number' && Number.isFinite(rid) ? rid : undefined; }; " +
  "const attachPromiseRid = function(promise, rid){ if ((typeof promise !== 'object' && typeof promise !== 'function') || promise === null) return promise; try { Object.defineProperty(promise, promiseRidKey, { value: rid, writable: true, configurable: true }); } catch (_) { promise[promiseRidKey] = rid; } Promise.resolve(promise).finally(function(){ core.tryClose(rid); }); return promise; }; " +
  "const ensurePromiseResource = function(promise, kind){ const existing = getPromiseRid(promise); if (existing !== undefined) return existing; const rid = createManagedResource(kind); attachPromiseRid(promise, rid); return rid; }; " +
  "const setPromiseRefState = function(promise, isRef){ const rid = ensurePromiseResource(promise, 'promise'); MoonBit.opSync(isRef ? '" +
  deno_core_ref_resource_op_name() +
  "' : '" +
  deno_core_unref_resource_op_name() +
  "', rid); return promise; }; " +
  "const timers = root.__mizchi_v8_timers ?? (root.__mizchi_v8_timers = new Map()); " +
  "const resourceExists = function(rid){ return MoonBit.opSync('" +
  deno_core_resource_exists_op_name() +
  "', rid); }; " +
  "const closeResourceByRid = function(rid, throwOnMissing){ const id = Number(rid); timers.delete(id); if (throwOnMissing) { MoonBit.opSync('" +
  deno_core_close_op_name() +
  "', id); return; } return MoonBit.opSync('" +
  deno_core_try_close_op_name() +
  "', id); }; " +
  "const scheduleTimer = function(id){ const timer = timers.get(id); if (!timer) return; MoonBit.opAsync('" +
  deno_core_sleep_op_name() +
  "', timer.delay).then(function(){ const current = timers.get(id); if (!current) return; if (!resourceExists(id)) { timers.delete(id); return; } try { current.callback(...current.args); } finally { if (!current.repeat) { core.tryClose(id); return; } if (timers.has(id) && resourceExists(id)) scheduleTimer(id); } }); }; " +
  "if (typeof core.opAsync !== 'function') core.opAsync = function(name, payload){ return attachPromiseRid(MoonBit.opAsync(name, payload), createManagedResource('promise')); }; " +
  "if (typeof core.opSyncBytes !== 'function') core.opSyncBytes = function(name, payload){ return MoonBit.opSyncBytes(name, payload); }; " +
  "if (typeof core.opAsyncBytes !== 'function') core.opAsyncBytes = function(name, payload){ return attachPromiseRid(MoonBit.opAsyncBytes(name, payload), createManagedResource('promise')); }; " +
  "if (typeof core.encode !== 'function') core.encode = encode; " +
  "if (typeof core.decode !== 'function') core.decode = decode; " +
  "if (typeof core.resources !== 'function') core.resources = function(){ return MoonBit.opSync('" +
  deno_core_resources_op_name() +
  "', null); }; " +
  "if (typeof core.close !== 'function') core.close = function(rid){ closeResourceByRid(rid, true); }; " +
  "if (typeof core.tryClose !== 'function') core.tryClose = function(rid){ return closeResourceByRid(rid, false); }; " +
  "if (typeof deno.sleep !== 'function') deno.sleep = function(delay){ const rid = createManagedResource('sleep'); return attachPromiseRid(MoonBit.opAsync('" +
  deno_core_sleep_op_name() +
  "', toDelay(delay)).then(function(){ return undefined; }), rid); }; " +
  "if (typeof root.setTimeout !== 'function') root.setTimeout = function(callback, delay, ...args){ const id = createManagedResource('timeout'); timers.set(id, { callback, args, delay: toDelay(delay), repeat: false }); scheduleTimer(id); return id; }; " +
  "if (typeof root.clearTimeout !== 'function') root.clearTimeout = function(id){ closeResourceByRid(id, false); }; " +
  "if (typeof root.setInterval !== 'function') root.setInterval = function(callback, delay, ...args){ const id = createManagedResource('interval'); timers.set(id, { callback, args, delay: toDelay(delay), repeat: true }); scheduleTimer(id); return id; }; " +
  "if (typeof root.clearInterval !== 'function') root.clearInterval = function(id){ closeResourceByRid(id, false); }; " +
  "if (typeof core.refOpPromise !== 'function') core.refOpPromise = function(promise){ return setPromiseRefState(promise, true); }; " +
  "if (typeof core.unrefOpPromise !== 'function') core.unrefOpPromise = function(promise){ return setPromiseRefState(promise, false); }; " +
  "if (typeof core.print !== 'function') core.print = function(message, is_err){ if (typeof console !== 'object' || console === null) return; const text = String(message); if (is_err && typeof console.error === 'function') { console.error(text); return; } if (typeof console.log === 'function') console.log(text); }; " +
  "if (typeof core.ops !== 'object' || core.ops === null) core.ops = new Proxy({}, { get(_target, key) { return typeof key === 'string' ? key : undefined; } }); " +
  "if (typeof core.opsBytes !== 'object' || core.opsBytes === null) core.opsBytes = new Proxy({}, { get(_target, key) { return typeof key === 'string' ? key : undefined; } }); " +
  "return 'ok'; " +
  "})()"
}

///|
pub fn Runtime::install_deno_core_compat(
  self : Runtime,
) -> Result[Unit, V8Error] {
  if runtime_has_deno_core_compat(self) {
    Ok(())
  } else {
    let registered = install_deno_core_runtime_compat(self)
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let installed = install_compat_source(
      self,
      "file:///compat/deno_core.js",
      deno_core_compat_source(),
    )
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    runtime_mark_deno_core_compat(self)
    Ok(())
  }
}

///|
pub fn RuntimeBuilder::with_deno_core_compat(
  self : RuntimeBuilder,
) -> RuntimeBuilder {
  self.state.val.with_deno_core_compat = true
  apply_runtime_builder_compat(self, deno_core_compat_source())
}

///|
pub fn SnapshotBuilder::with_deno_core_compat(
  self : SnapshotBuilder,
) -> SnapshotBuilder {
  self.state.val.with_deno_core_compat = true
  apply_snapshot_builder_compat(self, deno_core_compat_source())
}
