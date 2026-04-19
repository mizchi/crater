///|
fn node_compat_source() -> String {
  "(function(){ " +
  "const root = globalThis; " +
  "const enqueue = typeof queueMicrotask === 'function' ? queueMicrotask : function(fn){ Promise.resolve().then(fn); }; " +
  "root.global = root; " +
  "const process = root.process ?? (root.process = {}); " +
  "if (!Array.isArray(process.argv)) process.argv = []; " +
  "if (typeof process.env !== 'object' || process.env === null) process.env = {}; " +
  "if (typeof process.cwd !== 'function') process.cwd = function(){ return '/'; }; " +
  "if (typeof process.nextTick !== 'function') process.nextTick = function(cb, ...args){ enqueue(function(){ cb(...args); }); }; " +
  "if (typeof process.version !== 'string') process.version = 'v0.0.0-mizchi-v8'; " +
  "if (typeof process.platform !== 'string') process.platform = 'unknown'; " +
  "if (typeof process.arch !== 'string') process.arch = 'unknown'; " +
  "if (typeof process.versions !== 'object' || process.versions === null) process.versions = {}; " +
  "if (typeof process.versions.node !== 'string') process.versions.node = '0.0.0-mizchi-v8'; " +
  "if (typeof process.versions.v8 !== 'string') process.versions.v8 = '" +
  version() +
  "'; " +
  "if (typeof root.setImmediate !== 'function') root.setImmediate = function(cb, ...args){ enqueue(function(){ cb(...args); }); return 0; }; " +
  "if (typeof root.clearImmediate !== 'function') root.clearImmediate = function(_id){}; " +
  "if (typeof root.Buffer !== 'function') { " +
  "class Buffer extends Uint8Array { " +
  "static from(input){ " +
  "if (typeof input === 'string') { const buf = new Buffer(input.length); for (let i = 0; i < input.length; i += 1) buf[i] = input.charCodeAt(i) & 255; return buf; } " +
  "if (Array.isArray(input)) return new Buffer(input); " +
  "if (input instanceof ArrayBuffer) return new Buffer(new Uint8Array(input)); " +
  "if (ArrayBuffer.isView(input)) return new Buffer(new Uint8Array(input.buffer, input.byteOffset, input.byteLength)); " +
  "throw new TypeError('Buffer.from unsupported input'); " +
  "} " +
  "static alloc(size){ return new Buffer(size); } " +
  "static concat(list){ let total = 0; for (const item of list) total += Buffer.from(item).length; const out = new Buffer(total); let offset = 0; for (const item of list) { const next = Buffer.from(item); out.set(next, offset); offset += next.length; } return out; } " +
  "static byteLength(input){ return Buffer.from(input).length; } " +
  "static isBuffer(value){ return value instanceof Buffer; } " +
  "toString(_encoding){ let out = ''; for (let i = 0; i < this.length; i += 1) out += String.fromCharCode(this[i]); return out; } " +
  "} " +
  "root.Buffer = Buffer; " +
  "} " +
  "return 'ok'; " +
  "})()"
}

///|
pub fn Runtime::install_node_compat(self : Runtime) -> Result[Unit, V8Error] {
  if runtime_has_node_compat(self) {
    Ok(())
  } else {
    let installed = install_compat_source(
      self,
      "file:///compat/node.js",
      node_compat_source(),
    )
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    runtime_mark_node_compat(self)
    Ok(())
  }
}

///|
pub fn RuntimeBuilder::with_node_compat(
  self : RuntimeBuilder,
) -> RuntimeBuilder {
  self.state.val.with_node_compat = true
  apply_runtime_builder_compat(self, node_compat_source())
}

///|
pub fn SnapshotBuilder::with_node_compat(
  self : SnapshotBuilder,
) -> SnapshotBuilder {
  self.state.val.with_node_compat = true
  apply_snapshot_builder_compat(self, node_compat_source())
}
