use std::any::Any;
use std::cell::RefCell;
use std::collections::{HashMap, HashSet, VecDeque};
use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::panic::{self, AssertUnwindSafe};
use std::ptr;
use std::rc::Rc;
use std::slice;
use std::sync::Once;

type MoonBitBytes = *mut u8;
type MoonBitBytesCallback = unsafe extern "C" fn(*mut c_void, MoonBitBytes) -> MoonBitBytes;

unsafe extern "C" {
    fn moonbit_make_bytes(size: i32, init: c_int) -> MoonBitBytes;
    fn moonbit_incref(obj: *mut c_void);
    fn moonbit_decref(obj: *mut c_void);
}

#[repr(C)]
struct MoonBitObjectHeader {
    rc: i32,
    meta: u32,
}

struct Runtime {
    context: v8::Global<v8::Context>,
    isolate: v8::OwnedIsolate,
    modules: Rc<RefCell<ModuleStore>>,
    ops: Rc<RefCell<OpStore>>,
    module_handles: HashMap<u64, v8::Global<v8::Module>>,
    next_module_handle: u64,
    module_evaluation_promises: HashMap<u64, u64>,
    promises: HashMap<u64, v8::Global<v8::Promise>>,
    next_promise_handle: u64,
}

#[derive(Default)]
struct ModuleStore {
    sources: HashMap<String, String>,
    modules: HashMap<String, v8::Global<v8::Module>>,
    specifiers_by_identity_hash: HashMap<i32, String>,
}

struct PendingAsyncJsonOp {
    name: String,
    payload_json: String,
    resolver: v8::Global<v8::PromiseResolver>,
}

struct CompletedSyncJsonOp {
    name: String,
    payload_json: String,
}

struct CompletedSyncBytesOp {
    name: String,
    payload: Vec<u8>,
}

#[derive(Clone, Copy)]
struct RegisteredMoonBitBytesCallback {
    callback: MoonBitBytesCallback,
    closure: *mut c_void,
}

struct PendingAsyncBytesOp {
    name: String,
    payload: Vec<u8>,
    resolver: v8::Global<v8::PromiseResolver>,
}

#[derive(Default)]
struct OpStore {
    registered_sync_json_ops: HashSet<String>,
    queued_sync_json_op_ids: VecDeque<u64>,
    completed_sync_json_ops: HashMap<u64, CompletedSyncJsonOp>,
    sync_json_callbacks: HashMap<String, RegisteredMoonBitBytesCallback>,
    sync_json_op_responses: HashMap<(String, String), VecDeque<String>>,
    next_sync_json_op_id: u64,
    registered_sync_bytes_ops: HashSet<String>,
    queued_sync_bytes_op_ids: VecDeque<u64>,
    completed_sync_bytes_ops: HashMap<u64, CompletedSyncBytesOp>,
    sync_bytes_callbacks: HashMap<String, RegisteredMoonBitBytesCallback>,
    sync_bytes_op_responses: HashMap<(String, Vec<u8>), VecDeque<Vec<u8>>>,
    next_sync_bytes_op_id: u64,
    registered_async_json_ops: HashSet<String>,
    async_json_callbacks: HashMap<String, RegisteredMoonBitBytesCallback>,
    queued_async_json_op_ids: VecDeque<u64>,
    pending_async_json_ops: HashMap<u64, PendingAsyncJsonOp>,
    next_async_json_op_id: u64,
    registered_async_bytes_ops: HashSet<String>,
    async_bytes_callbacks: HashMap<String, RegisteredMoonBitBytesCallback>,
    queued_async_bytes_op_ids: VecDeque<u64>,
    pending_async_bytes_ops: HashMap<u64, PendingAsyncBytesOp>,
    next_async_bytes_op_id: u64,
}

impl Drop for OpStore {
    fn drop(&mut self) {
        for callback in self.sync_json_callbacks.values() {
            if !callback.closure.is_null() {
                unsafe { moonbit_decref(callback.closure) };
            }
        }
        for callback in self.sync_bytes_callbacks.values() {
            if !callback.closure.is_null() {
                unsafe { moonbit_decref(callback.closure) };
            }
        }
        for callback in self.async_json_callbacks.values() {
            if !callback.closure.is_null() {
                unsafe { moonbit_decref(callback.closure) };
            }
        }
        for callback in self.async_bytes_callbacks.values() {
            if !callback.closure.is_null() {
                unsafe { moonbit_decref(callback.closure) };
            }
        }
    }
}

static INIT_V8: Once = Once::new();
const MAIN_MODULE_SPECIFIER: &str = "file:///main.mjs";
const MAIN_SCRIPT_RESOURCE_NAME: &str = "file:///main.js";
const PROMISE_STATE_PENDING: i32 = 0;
const PROMISE_STATE_FULFILLED: i32 = 1;
const PROMISE_STATE_REJECTED: i32 = 2;

struct EnteredIsolateGuard {
    isolate: *mut v8::OwnedIsolate,
}

impl EnteredIsolateGuard {
    fn new(isolate: &mut v8::OwnedIsolate) -> Self {
        unsafe {
            isolate.enter();
        }
        Self {
            isolate: isolate as *mut _,
        }
    }
}

impl Drop for EnteredIsolateGuard {
    fn drop(&mut self) {
        unsafe {
            (*self.isolate).exit();
        }
    }
}

macro_rules! entered_scope {
    ($isolate:expr, $scope:ident) => {
        let _entered_isolate = EnteredIsolateGuard::new($isolate);
        v8::scope!(let $scope, $isolate);
    };
}

fn ensure_v8() {
    INIT_V8.call_once(|| {
        let platform = v8::new_default_platform(0, false).make_shared();
        v8::V8::initialize_platform(platform);
        v8::V8::initialize();
    });
}

unsafe fn read_raw_ptr(bytes: *const u8) -> *mut c_void {
    if bytes.is_null() {
        ptr::null_mut()
    } else {
        unsafe { ptr::read_unaligned(bytes.cast::<*mut c_void>()) }
    }
}

unsafe fn write_raw_ptr(bytes: *mut u8, value: *mut c_void) {
    if !bytes.is_null() {
        unsafe { ptr::write_unaligned(bytes.cast::<*mut c_void>(), value) };
    }
}

fn clear_error(error_out: *mut u8) {
    unsafe { write_raw_ptr(error_out, ptr::null_mut()) }
}

fn set_error(error_out: *mut u8, message: &str) {
    if error_out.is_null() {
        return;
    }
    let sanitized = message.replace('\0', " ");
    let message =
        CString::new(sanitized).unwrap_or_else(|_| CString::new("V8 bridge error").unwrap());
    unsafe { write_raw_ptr(error_out, message.into_raw().cast()) }
}

fn panic_message(payload: Box<dyn Any + Send>) -> String {
    if let Some(message) = payload.downcast_ref::<&'static str>() {
        (*message).to_string()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "panic in rusty_v8 bridge".to_string()
    }
}

fn empty_bytes() -> MoonBitBytes {
    unsafe { moonbit_make_bytes(0, 0) }
}

fn copy_bytes_to_moonbit(bytes: &[u8]) -> MoonBitBytes {
    let out = unsafe { moonbit_make_bytes(bytes.len() as i32, 0) };
    if out.is_null() || bytes.is_empty() {
        return out;
    }
    unsafe { ptr::copy_nonoverlapping(bytes.as_ptr(), out, bytes.len()) };
    out
}

fn copy_string_to_moonbit(value: &str) -> MoonBitBytes {
    copy_bytes_to_moonbit(value.as_bytes())
}

unsafe fn moonbit_array_length(bytes: MoonBitBytes) -> usize {
    if bytes.is_null() {
        return 0;
    }
    let header = unsafe { (bytes as *const MoonBitObjectHeader).sub(1) };
    unsafe { ((*header).meta & ((1_u32 << 28) - 1)) as usize }
}

unsafe fn copy_bytes_from_moonbit(bytes: MoonBitBytes) -> Vec<u8> {
    let len = unsafe { moonbit_array_length(bytes) };
    if bytes.is_null() || len == 0 {
        return Vec::new();
    }
    unsafe { slice::from_raw_parts(bytes.cast::<u8>(), len) }.to_vec()
}

enum MoonBitCallbackError {
    Message(String),
    Json(String),
}

enum MoonBitCallbackEnvelope {
    Ok(Vec<u8>),
    Err(MoonBitCallbackError),
}

fn decode_moonbit_callback_envelope(bytes: Vec<u8>) -> Result<MoonBitCallbackEnvelope, String> {
    let Some((&tag, payload)) = bytes.split_first() else {
        return Err("callback returned empty response envelope".to_string());
    };
    match tag {
        0 => Ok(MoonBitCallbackEnvelope::Ok(payload.to_vec())),
        1 => String::from_utf8(payload.to_vec())
            .map(|message| MoonBitCallbackEnvelope::Err(MoonBitCallbackError::Message(message)))
            .map_err(|_| "callback rejection returned invalid utf-8".to_string()),
        2 => String::from_utf8(payload.to_vec())
            .map(|json| MoonBitCallbackEnvelope::Err(MoonBitCallbackError::Json(json)))
            .map_err(|_| "callback rejection returned invalid utf-8".to_string()),
        _ => Err("callback returned unknown response envelope".to_string()),
    }
}

fn invoke_moonbit_bytes_callback(
    callback: RegisteredMoonBitBytesCallback,
    payload: &[u8],
) -> Result<Vec<u8>, MoonBitCallbackError> {
    let input = copy_bytes_to_moonbit(payload);
    unsafe {
        if !input.is_null() {
            moonbit_incref(input.cast());
        }
        let output = (callback.callback)(callback.closure, input);
        if !input.is_null() {
            moonbit_decref(input.cast());
        }
        if output.is_null() {
            return Err(MoonBitCallbackError::Message(
                "callback returned null response".to_string(),
            ));
        }
        moonbit_incref(output.cast());
        let output_bytes = copy_bytes_from_moonbit(output);
        moonbit_decref(output.cast());
        match decode_moonbit_callback_envelope(output_bytes)
            .map_err(MoonBitCallbackError::Message)?
        {
            MoonBitCallbackEnvelope::Ok(output_bytes) => Ok(output_bytes),
            MoonBitCallbackEnvelope::Err(error) => Err(error),
        }
    }
}

fn invoke_moonbit_json_callback(
    callback: RegisteredMoonBitBytesCallback,
    payload_json: &str,
) -> Result<String, MoonBitCallbackError> {
    String::from_utf8(invoke_moonbit_bytes_callback(callback, payload_json.as_bytes())?)
        .map_err(|_| MoonBitCallbackError::Message("json callback returned invalid utf-8".to_string()))
}

fn throw_exception_message<'s>(scope: &mut v8::PinScope<'s, '_>, message: &str) {
    let exception = v8::String::new(scope, message)
        .or_else(|| v8::String::new(scope, "V8 bridge error"))
        .expect("failed to allocate exception string");
    scope.throw_exception(exception.into());
}

fn throw_exception_json<'s>(scope: &mut v8::PinScope<'s, '_>, json_text: &str) -> bool {
    let Some(reason) = parse_json_value(scope, json_text) else {
        return false;
    };
    scope.throw_exception(reason);
    true
}

fn throw_callback_error<'s>(scope: &mut v8::PinScope<'s, '_>, error: MoonBitCallbackError) {
    match error {
        MoonBitCallbackError::Message(message) => throw_exception_message(scope, &message),
        MoonBitCallbackError::Json(json) => {
            if !throw_exception_json(scope, json.as_ref()) {
                throw_exception_message(scope, "failed to parse callback rejection json");
            }
        }
    }
}

fn reject_promise_with_message<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    resolver: v8::Local<'s, v8::PromiseResolver>,
    message: &str,
) -> v8::Local<'s, v8::Promise> {
    let reason = v8::String::new(scope, message)
        .or_else(|| v8::String::new(scope, "V8 bridge error"))
        .expect("failed to allocate rejection string");
    let _ = resolver.reject(scope, reason.into());
    resolver.get_promise(scope)
}

fn reject_promise_with_json<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    resolver: v8::Local<'s, v8::PromiseResolver>,
    json_text: &str,
) -> Option<v8::Local<'s, v8::Promise>> {
    let reason = parse_json_value(scope, json_text)?;
    let _ = resolver.reject(scope, reason);
    Some(resolver.get_promise(scope))
}

fn reject_promise_with_callback_error<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    resolver: v8::Local<'s, v8::PromiseResolver>,
    error: MoonBitCallbackError,
) -> v8::Local<'s, v8::Promise> {
    match error {
        MoonBitCallbackError::Message(message) => {
            reject_promise_with_message(scope, resolver, &message)
        }
        MoonBitCallbackError::Json(json) => reject_promise_with_json(scope, resolver, json.as_ref())
            .unwrap_or_else(|| {
                reject_promise_with_message(scope, resolver, "failed to parse callback rejection json")
            }),
    }
}

fn split_specifier_prefix(specifier: &str) -> (&str, &str) {
    if let Some(scheme_end) = specifier.find("://") {
        let authority_start = scheme_end + 3;
        if let Some(path_start) = specifier[authority_start..].find('/') {
            let path_start = authority_start + path_start;
            (&specifier[..path_start], &specifier[path_start..])
        } else {
            (specifier, "")
        }
    } else {
        ("", specifier)
    }
}

fn normalize_module_path(path: &str) -> String {
    let is_absolute = path.starts_with('/');
    let mut segments: Vec<&str> = Vec::new();
    for segment in path.split('/') {
        if segment.is_empty() || segment == "." {
            continue;
        }
        if segment == ".." {
            segments.pop();
        } else {
            segments.push(segment);
        }
    }
    let joined = segments.join("/");
    if is_absolute {
        format!("/{joined}")
    } else {
        joined
    }
}

fn resolve_module_specifier(referrer: &str, specifier: &str) -> String {
    if specifier.starts_with("./") || specifier.starts_with("../") {
        let (prefix, referrer_path) = split_specifier_prefix(referrer);
        let base_dir = match referrer_path.rfind('/') {
            Some(index) => &referrer_path[..index + 1],
            None => "",
        };
        let resolved_path = normalize_module_path(&format!("{base_dir}{specifier}"));
        format!("{prefix}{resolved_path}")
    } else {
        specifier.to_string()
    }
}

fn register_compiled_module<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    modules: &Rc<RefCell<ModuleStore>>,
    specifier: &str,
    module: v8::Local<'s, v8::Module>,
) {
    let identity_hash = module.get_identity_hash().get();
    let mut modules = modules.borrow_mut();
    modules
        .modules
        .insert(specifier.to_string(), v8::Global::new(scope, module));
    modules
        .specifiers_by_identity_hash
        .insert(identity_hash, specifier.to_string());
}

fn compile_module_from_source<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    specifier: &str,
    source_text: &str,
) -> Option<v8::Local<'s, v8::Module>> {
    let source = v8::String::new(scope, source_text)?;
    let resource_name = v8::String::new(scope, specifier)?;
    let origin = v8::ScriptOrigin::new(
        scope,
        resource_name.into(),
        0,
        0,
        false,
        -1,
        None,
        false,
        false,
        true,
        None,
    );
    let mut source = v8::script_compiler::Source::new(source, Some(&origin));
    v8::script_compiler::compile_module(scope, &mut source)
}

fn compile_script_from_source<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    resource_name: &str,
    source_text: &str,
) -> Option<v8::Local<'s, v8::Script>> {
    let source = v8::String::new(scope, source_text)?;
    let resource_name = v8::String::new(scope, resource_name)?;
    let origin = v8::ScriptOrigin::new(
        scope,
        resource_name.into(),
        0,
        0,
        false,
        -1,
        None,
        false,
        false,
        false,
        None,
    );
    let mut source = v8::script_compiler::Source::new(source, Some(&origin));
    v8::script_compiler::compile(
        scope,
        &mut source,
        v8::script_compiler::CompileOptions::EagerCompile,
        v8::script_compiler::NoCacheReason::NoReason,
    )
}

fn parse_json_value<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    json_text: &str,
) -> Option<v8::Local<'s, v8::Value>> {
    let json_string = v8::String::new(scope, json_text)?;
    v8::json::parse(scope, json_string)
}

fn stringify_json_value<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    value: v8::Local<'s, v8::Value>,
) -> Option<String> {
    let stringified = v8::json::stringify(scope, value)?;
    Some(stringified.to_rust_string_lossy(scope))
}

fn make_uint8_array_from_bytes<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    bytes: &[u8],
) -> Option<v8::Local<'s, v8::Uint8Array>> {
    let backing_store =
        v8::ArrayBuffer::new_backing_store_from_boxed_slice(bytes.to_vec().into_boxed_slice());
    let backing_store = backing_store.make_shared();
    let array_buffer = v8::ArrayBuffer::with_backing_store(scope, &backing_store);
    v8::Uint8Array::new(scope, array_buffer, 0, bytes.len())
}

fn copy_bytes_from_value<'s>(
    _scope: &mut v8::PinScope<'s, '_>,
    value: v8::Local<'s, v8::Value>,
) -> Result<Vec<u8>, String> {
    if let Ok(view) = v8::Local::<v8::ArrayBufferView>::try_from(value) {
        let mut dest = vec![0_u8; view.byte_length()];
        let copied = view.copy_contents(&mut dest);
        dest.truncate(copied);
        Ok(dest)
    } else if let Ok(buffer) = v8::Local::<v8::ArrayBuffer>::try_from(value) {
        let backing_store = buffer.get_backing_store();
        let mut bytes = Vec::with_capacity(backing_store.byte_length());
        for i in 0..backing_store.byte_length() {
            bytes.push(backing_store[i].get());
        }
        Ok(bytes)
    } else {
        Err("value is not an ArrayBuffer or ArrayBufferView".to_string())
    }
}

fn load_registered_module<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    modules: &Rc<RefCell<ModuleStore>>,
    specifier: &str,
) -> Result<v8::Local<'s, v8::Module>, String> {
    {
        let modules_ref = modules.borrow();
        if let Some(module) = modules_ref.modules.get(specifier) {
            return Ok(v8::Local::new(scope, module));
        }
    }

    let source_text = {
        let modules_ref = modules.borrow();
        modules_ref.sources.get(specifier).cloned()
    }
    .ok_or_else(|| format!("module not found: {specifier}"))?;

    let module = compile_module_from_source(scope, specifier, &source_text)
        .ok_or_else(|| format!("failed to compile module: {specifier}"))?;
    register_compiled_module(scope, modules, specifier, module);
    Ok(module)
}

fn instantiate_registered_module<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    modules: &Rc<RefCell<ModuleStore>>,
    specifier: &str,
) -> Result<v8::Local<'s, v8::Module>, String> {
    let module = load_registered_module(scope, modules, specifier)?;
    match module.get_status() {
        v8::ModuleStatus::Uninstantiated => {
            match module.instantiate_module(scope, registered_module_resolve_callback) {
                Some(true) => Ok(module),
                Some(false) => Err(format!(
                    "module instantiation did not complete: {specifier}"
                )),
                None => Err(format!("failed to instantiate module: {specifier}")),
            }
        }
        v8::ModuleStatus::Errored => Err(format!("module is already errored: {specifier}")),
        _ => Ok(module),
    }
}

#[allow(clippy::unnecessary_wraps)]
fn registered_module_resolve_callback<'s>(
    context: v8::Local<'s, v8::Context>,
    specifier: v8::Local<'s, v8::String>,
    _import_attributes: v8::Local<'s, v8::FixedArray>,
    referrer: v8::Local<'s, v8::Module>,
) -> Option<v8::Local<'s, v8::Module>> {
    v8::callback_scope!(unsafe scope, context);

    let specifier = specifier.to_rust_string_lossy(scope);
    let modules = match context.get_slot::<RefCell<ModuleStore>>() {
        Some(modules) => modules,
        None => {
            throw_exception_message(scope, "module registry is not initialized");
            return None;
        }
    };
    let referrer_identity_hash = referrer.get_identity_hash().get();
    let referrer_specifier = {
        let modules_ref = modules.borrow();
        modules_ref
            .specifiers_by_identity_hash
            .get(&referrer_identity_hash)
            .cloned()
    };
    let referrer_specifier = match referrer_specifier {
        Some(referrer_specifier) => referrer_specifier,
        None => {
            throw_exception_message(scope, "missing referrer metadata for module resolution");
            return None;
        }
    };
    let resolved_specifier = resolve_module_specifier(&referrer_specifier, &specifier);
    match load_registered_module(scope, &modules, &resolved_specifier) {
        Ok(module) => Some(module),
        Err(message) => {
            throw_exception_message(scope, &message);
            None
        }
    }
}

#[allow(clippy::unnecessary_wraps)]
fn registered_dynamic_import_callback<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    _host_defined_options: v8::Local<'s, v8::Data>,
    resource_name: v8::Local<'s, v8::Value>,
    specifier: v8::Local<'s, v8::String>,
    _import_attributes: v8::Local<'s, v8::FixedArray>,
) -> Option<v8::Local<'s, v8::Promise>> {
    let resolver = match v8::PromiseResolver::new(scope) {
        Some(resolver) => resolver,
        None => {
            throw_exception_message(scope, "failed to create promise resolver");
            return None;
        }
    };
    let context = scope.get_current_context();
    let modules = match context.get_slot::<RefCell<ModuleStore>>() {
        Some(modules) => modules,
        None => {
            throw_exception_message(scope, "module registry is not initialized");
            return None;
        }
    };
    let specifier = specifier.to_rust_string_lossy(scope);
    let referrer_specifier = resource_name
        .to_string(scope)
        .map(|value| value.to_rust_string_lossy(scope))
        .filter(|value| value != "undefined" && !value.is_empty())
        .unwrap_or_else(|| MAIN_MODULE_SPECIFIER.to_string());
    let resolved_specifier = resolve_module_specifier(&referrer_specifier, &specifier);

    let module = match instantiate_registered_module(scope, &modules, &resolved_specifier) {
        Ok(module) => module,
        Err(message) => return Some(reject_promise_with_message(scope, resolver, &message)),
    };

    match module.get_status() {
        v8::ModuleStatus::Evaluated => {
            let _ = resolver.resolve(scope, module.get_module_namespace());
            return Some(resolver.get_promise(scope));
        }
        v8::ModuleStatus::Errored => {
            let _ = resolver.reject(scope, module.get_exception());
            return Some(resolver.get_promise(scope));
        }
        _ => {}
    }

    let value = match module.evaluate(scope) {
        Some(value) => value,
        None => {
            return Some(reject_promise_with_message(
                scope,
                resolver,
                &format!("failed to evaluate module: {resolved_specifier}"),
            ));
        }
    };

    if !value.is_promise() {
        let _ = resolver.resolve(scope, module.get_module_namespace());
        return Some(resolver.get_promise(scope));
    }

    let promise = match v8::Local::<v8::Promise>::try_from(value) {
        Ok(promise) => promise,
        Err(_) => {
            return Some(reject_promise_with_message(
                scope,
                resolver,
                "failed to cast dynamic import evaluation promise",
            ));
        }
    };

    for _ in 0..1024 {
        match promise.state() {
            v8::PromiseState::Pending => {
                scope.perform_microtask_checkpoint();
            }
            v8::PromiseState::Fulfilled => {
                let _ = resolver.resolve(scope, module.get_module_namespace());
                return Some(resolver.get_promise(scope));
            }
            v8::PromiseState::Rejected => {
                let _ = resolver.reject(scope, promise.result(scope));
                return Some(resolver.get_promise(scope));
            }
        }
    }

    Some(reject_promise_with_message(
        scope,
        resolver,
        "dynamic import module evaluation promise is still pending after 1024 microtask checkpoints",
    ))
}

fn configure_runtime_isolate(isolate: &mut v8::OwnedIsolate) {
    isolate.set_microtasks_policy(v8::MicrotasksPolicy::Explicit);
    isolate.set_host_import_module_dynamically_callback(registered_dynamic_import_callback);
}

fn next_async_json_op_id(ops: &mut OpStore) -> u64 {
    let op_id = if ops.next_async_json_op_id == 0 {
        1
    } else {
        ops.next_async_json_op_id
    };
    ops.next_async_json_op_id = op_id.checked_add(1).unwrap_or(1);
    op_id
}

fn next_sync_json_op_id(ops: &mut OpStore) -> u64 {
    let op_id = if ops.next_sync_json_op_id == 0 {
        1
    } else {
        ops.next_sync_json_op_id
    };
    ops.next_sync_json_op_id = op_id.checked_add(1).unwrap_or(1);
    op_id
}

fn next_sync_bytes_op_id(ops: &mut OpStore) -> u64 {
    let op_id = if ops.next_sync_bytes_op_id == 0 {
        1
    } else {
        ops.next_sync_bytes_op_id
    };
    ops.next_sync_bytes_op_id = op_id.checked_add(1).unwrap_or(1);
    op_id
}

fn next_async_bytes_op_id(ops: &mut OpStore) -> u64 {
    let op_id = if ops.next_async_bytes_op_id == 0 {
        1
    } else {
        ops.next_async_bytes_op_id
    };
    ops.next_async_bytes_op_id = op_id.checked_add(1).unwrap_or(1);
    op_id
}

fn install_runtime_bindings<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    context: v8::Local<'s, v8::Context>,
) -> Result<(), String> {
    let global = context.global(scope);
    let moonbit_key = v8::String::new(scope, "MoonBit")
        .ok_or_else(|| "failed to allocate MoonBit namespace key".to_string())?;
    let moonbit_namespace = match global.get(scope, moonbit_key.into()) {
        Some(value) if value.is_object() => v8::Local::<v8::Object>::try_from(value)
            .map_err(|_| "failed to cast MoonBit namespace".to_string())?,
        _ => {
            let namespace = v8::Object::new(scope);
            match global.set(scope, moonbit_key.into(), namespace.into()) {
                Some(true) => namespace,
                _ => return Err("failed to install MoonBit namespace".to_string()),
            }
        }
    };
    let op_async_key = v8::String::new(scope, "opAsync")
        .ok_or_else(|| "failed to allocate opAsync key".to_string())?;
    let op_async_fn = v8::Function::new(scope, async_json_op_callback)
        .ok_or_else(|| "failed to allocate opAsync function".to_string())?;
    match moonbit_namespace.set(scope, op_async_key.into(), op_async_fn.into()) {
        Some(true) => {}
        _ => return Err("failed to install MoonBit.opAsync".to_string()),
    }
    let op_sync_key = v8::String::new(scope, "opSync")
        .ok_or_else(|| "failed to allocate opSync key".to_string())?;
    let op_sync_fn = v8::Function::new(scope, sync_json_op_callback)
        .ok_or_else(|| "failed to allocate opSync function".to_string())?;
    match moonbit_namespace.set(scope, op_sync_key.into(), op_sync_fn.into()) {
        Some(true) => {}
        _ => return Err("failed to install MoonBit.opSync".to_string()),
    }
    let op_sync_bytes_key = v8::String::new(scope, "opSyncBytes")
        .ok_or_else(|| "failed to allocate opSyncBytes key".to_string())?;
    let op_sync_bytes_fn = v8::Function::new(scope, sync_bytes_op_callback)
        .ok_or_else(|| "failed to allocate opSyncBytes function".to_string())?;
    match moonbit_namespace.set(scope, op_sync_bytes_key.into(), op_sync_bytes_fn.into()) {
        Some(true) => {}
        _ => return Err("failed to install MoonBit.opSyncBytes".to_string()),
    }
    let op_async_bytes_key = v8::String::new(scope, "opAsyncBytes")
        .ok_or_else(|| "failed to allocate opAsyncBytes key".to_string())?;
    let op_async_bytes_fn = v8::Function::new(scope, async_bytes_op_callback)
        .ok_or_else(|| "failed to allocate opAsyncBytes function".to_string())?;
    match moonbit_namespace.set(scope, op_async_bytes_key.into(), op_async_bytes_fn.into()) {
        Some(true) => Ok(()),
        _ => Err("failed to install MoonBit.opAsyncBytes".to_string()),
    }
}

fn async_json_op_callback<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    args: v8::FunctionCallbackArguments<'s>,
    mut rv: v8::ReturnValue<'s, v8::Value>,
) {
    let resolver = match v8::PromiseResolver::new(scope) {
        Some(resolver) => resolver,
        None => {
            throw_exception_message(scope, "failed to create async op promise resolver");
            return;
        }
    };
    let promise = resolver.get_promise(scope);
    let context = scope.get_current_context();
    let ops = match context.get_slot::<RefCell<OpStore>>() {
        Some(ops) => ops,
        None => {
            rv.set(
                reject_promise_with_message(
                    scope,
                    resolver,
                    "async op registry is not initialized",
                )
                .into(),
            );
            return;
        }
    };

    if args.length() < 2 {
        rv.set(
            reject_promise_with_message(
                scope,
                resolver,
                "MoonBit.opAsync(name, payload) requires 2 arguments",
            )
            .into(),
        );
        return;
    }

    let op_name = match args.get(0).to_string(scope) {
        Some(value) => value.to_rust_string_lossy(scope),
        None => {
            rv.set(
                reject_promise_with_message(scope, resolver, "failed to stringify async op name")
                    .into(),
            );
            return;
        }
    };

    {
        let ops_ref = ops.borrow();
        if !ops_ref.registered_async_json_ops.contains(&op_name) {
            rv.set(
                reject_promise_with_message(
                    scope,
                    resolver,
                    &format!("async json op is not registered: {op_name}"),
                )
                .into(),
            );
            return;
        }
    }

    let payload_json = match stringify_json_value(scope, args.get(1)) {
        Some(payload_json) => payload_json,
        None => {
            rv.set(
                reject_promise_with_message(
                    scope,
                    resolver,
                    "async op payload must be JSON-serializable",
                )
                .into(),
            );
            return;
        }
    };

    let callback = {
        let ops_ref = ops.borrow();
        ops_ref.async_json_callbacks.get(&op_name).copied()
    };
    if let Some(callback) = callback {
        let response_json = match invoke_moonbit_json_callback(callback, payload_json.as_ref()) {
            Ok(response_json) => response_json,
            Err(error) => {
                rv.set(reject_promise_with_callback_error(scope, resolver, error).into());
                return;
            }
        };
        let value = match parse_json_value(scope, response_json.as_ref()) {
            Some(value) => value,
            None => {
                rv.set(
                    reject_promise_with_message(
                        scope,
                        resolver,
                        "failed to parse async json callback response",
                    )
                    .into(),
                );
                return;
            }
        };
        let _ = resolver.resolve(scope, value);
        rv.set(promise.into());
        return;
    }

    let mut ops_ref = ops.borrow_mut();
    let op_id = next_async_json_op_id(&mut ops_ref);
    ops_ref.queued_async_json_op_ids.push_back(op_id);
    ops_ref.pending_async_json_ops.insert(
        op_id,
        PendingAsyncJsonOp {
            name: op_name,
            payload_json,
            resolver: v8::Global::new(scope, resolver),
        },
    );
    rv.set(promise.into());
}

fn sync_json_op_callback<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    args: v8::FunctionCallbackArguments<'s>,
    mut rv: v8::ReturnValue<'s, v8::Value>,
) {
    let context = scope.get_current_context();
    let ops = match context.get_slot::<RefCell<OpStore>>() {
        Some(ops) => ops,
        None => {
            throw_exception_message(scope, "sync json op registry is not initialized");
            return;
        }
    };

    if args.length() < 2 {
        throw_exception_message(scope, "MoonBit.opSync(name, payload) requires 2 arguments");
        return;
    }

    let op_name = match args.get(0).to_string(scope) {
        Some(value) => value.to_rust_string_lossy(scope),
        None => {
            throw_exception_message(scope, "failed to stringify sync json op name");
            return;
        }
    };

    let payload_json = match stringify_json_value(scope, args.get(1)) {
        Some(payload_json) => payload_json,
        None => {
            throw_exception_message(scope, "sync op payload must be JSON-serializable");
            return;
        }
    };

    enum SyncJsonResponse {
        Callback(RegisteredMoonBitBytesCallback),
        Preloaded(String),
    }

    let response = {
        let mut ops_ref = ops.borrow_mut();
        if !ops_ref.registered_sync_json_ops.contains(&op_name) {
            drop(ops_ref);
            throw_exception_message(scope, &format!("sync json op is not registered: {op_name}"));
            return;
        }

        let op_id = next_sync_json_op_id(&mut ops_ref);
        ops_ref.queued_sync_json_op_ids.push_back(op_id);
        ops_ref.completed_sync_json_ops.insert(
            op_id,
            CompletedSyncJsonOp {
                name: op_name.clone(),
                payload_json: payload_json.clone(),
            },
        );

        if let Some(callback) = ops_ref.sync_json_callbacks.get(&op_name).copied() {
            SyncJsonResponse::Callback(callback)
        } else {
            let key = (op_name.clone(), payload_json.clone());
            match ops_ref.sync_json_op_responses.get_mut(&key) {
                Some(values) => match values.pop_front() {
                    Some(result_json) => {
                        if values.is_empty() {
                            ops_ref.sync_json_op_responses.remove(&key);
                        }
                        SyncJsonResponse::Preloaded(result_json)
                    }
                    None => {
                        drop(ops_ref);
                        throw_exception_message(
                            scope,
                            &format!("sync json op has no queued response: {op_name}"),
                        );
                        return;
                    }
                },
                None => {
                    drop(ops_ref);
                    throw_exception_message(
                        scope,
                        &format!("sync json op has no queued response: {op_name}"),
                    );
                    return;
                }
            }
        }
    };

    let response_json = match response {
        SyncJsonResponse::Callback(callback) => {
            match invoke_moonbit_json_callback(callback, payload_json.as_ref()) {
                Ok(response_json) => response_json,
                Err(error) => {
                    throw_callback_error(scope, error);
                    return;
                }
            }
        }
        SyncJsonResponse::Preloaded(response_json) => response_json,
    };

    let value = match parse_json_value(scope, response_json.as_ref()) {
        Some(value) => value,
        None => {
            throw_exception_message(scope, "failed to parse sync json op response");
            return;
        }
    };
    rv.set(value);
}

fn sync_bytes_op_callback<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    args: v8::FunctionCallbackArguments<'s>,
    mut rv: v8::ReturnValue<'s, v8::Value>,
) {
    let context = scope.get_current_context();
    let ops = match context.get_slot::<RefCell<OpStore>>() {
        Some(ops) => ops,
        None => {
            throw_exception_message(scope, "sync bytes op registry is not initialized");
            return;
        }
    };

    if args.length() < 2 {
        throw_exception_message(
            scope,
            "MoonBit.opSyncBytes(name, payload) requires 2 arguments",
        );
        return;
    }

    let op_name = match args.get(0).to_string(scope) {
        Some(value) => value.to_rust_string_lossy(scope),
        None => {
            throw_exception_message(scope, "failed to stringify sync bytes op name");
            return;
        }
    };

    let payload = match copy_bytes_from_value(scope, args.get(1)) {
        Ok(payload) => payload,
        Err(message) => {
            throw_exception_message(scope, &message);
            return;
        }
    };

    enum SyncBytesResponse {
        Callback(RegisteredMoonBitBytesCallback),
        Preloaded(Vec<u8>),
    }

    let response = {
        let mut ops_ref = ops.borrow_mut();
        if !ops_ref.registered_sync_bytes_ops.contains(&op_name) {
            drop(ops_ref);
            throw_exception_message(
                scope,
                &format!("sync bytes op is not registered: {op_name}"),
            );
            return;
        }

        let op_id = next_sync_bytes_op_id(&mut ops_ref);
        ops_ref.queued_sync_bytes_op_ids.push_back(op_id);
        ops_ref.completed_sync_bytes_ops.insert(
            op_id,
            CompletedSyncBytesOp {
                name: op_name.clone(),
                payload: payload.clone(),
            },
        );

        if let Some(callback) = ops_ref.sync_bytes_callbacks.get(&op_name).copied() {
            SyncBytesResponse::Callback(callback)
        } else {
            let key = (op_name.clone(), payload.clone());
            match ops_ref.sync_bytes_op_responses.get_mut(&key) {
                Some(values) => match values.pop_front() {
                    Some(result_bytes) => {
                        if values.is_empty() {
                            ops_ref.sync_bytes_op_responses.remove(&key);
                        }
                        SyncBytesResponse::Preloaded(result_bytes)
                    }
                    None => {
                        drop(ops_ref);
                        throw_exception_message(
                            scope,
                            &format!("sync bytes op has no queued response: {op_name}"),
                        );
                        return;
                    }
                },
                None => {
                    drop(ops_ref);
                    throw_exception_message(
                        scope,
                        &format!("sync bytes op has no queued response: {op_name}"),
                    );
                    return;
                }
            }
        }
    };

    let response = match response {
        SyncBytesResponse::Callback(callback) => match invoke_moonbit_bytes_callback(callback, &payload) {
            Ok(response) => response,
            Err(error) => {
                throw_callback_error(scope, error);
                return;
            }
        },
        SyncBytesResponse::Preloaded(response) => response,
    };

    let value = match make_uint8_array_from_bytes(scope, &response) {
        Some(value) => value,
        None => {
            throw_exception_message(scope, "failed to allocate Uint8Array");
            return;
        }
    };
    rv.set(value.into());
}

fn async_bytes_op_callback<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    args: v8::FunctionCallbackArguments<'s>,
    mut rv: v8::ReturnValue<'s, v8::Value>,
) {
    let resolver = match v8::PromiseResolver::new(scope) {
        Some(resolver) => resolver,
        None => {
            throw_exception_message(scope, "failed to create async bytes op promise resolver");
            return;
        }
    };
    let promise = resolver.get_promise(scope);
    let context = scope.get_current_context();
    let ops = match context.get_slot::<RefCell<OpStore>>() {
        Some(ops) => ops,
        None => {
            rv.set(
                reject_promise_with_message(
                    scope,
                    resolver,
                    "async bytes op registry is not initialized",
                )
                .into(),
            );
            return;
        }
    };

    if args.length() < 2 {
        rv.set(
            reject_promise_with_message(
                scope,
                resolver,
                "MoonBit.opAsyncBytes(name, payload) requires 2 arguments",
            )
            .into(),
        );
        return;
    }

    let op_name = match args.get(0).to_string(scope) {
        Some(value) => value.to_rust_string_lossy(scope),
        None => {
            rv.set(
                reject_promise_with_message(
                    scope,
                    resolver,
                    "failed to stringify async bytes op name",
                )
                .into(),
            );
            return;
        }
    };

    {
        let ops_ref = ops.borrow();
        if !ops_ref.registered_async_bytes_ops.contains(&op_name) {
            rv.set(
                reject_promise_with_message(
                    scope,
                    resolver,
                    &format!("async bytes op is not registered: {op_name}"),
                )
                .into(),
            );
            return;
        }
    }

    let payload = match copy_bytes_from_value(scope, args.get(1)) {
        Ok(payload) => payload,
        Err(message) => {
            rv.set(reject_promise_with_message(scope, resolver, &message).into());
            return;
        }
    };

    let callback = {
        let ops_ref = ops.borrow();
        ops_ref.async_bytes_callbacks.get(&op_name).copied()
    };
    if let Some(callback) = callback {
        let response = match invoke_moonbit_bytes_callback(callback, &payload) {
            Ok(response) => response,
            Err(error) => {
                rv.set(reject_promise_with_callback_error(scope, resolver, error).into());
                return;
            }
        };
        let value = match make_uint8_array_from_bytes(scope, &response) {
            Some(value) => value,
            None => {
                rv.set(
                    reject_promise_with_message(
                        scope,
                        resolver,
                        "failed to allocate async bytes callback response",
                    )
                    .into(),
                );
                return;
            }
        };
        let _ = resolver.resolve(scope, value.into());
        rv.set(promise.into());
        return;
    }

    let mut ops_ref = ops.borrow_mut();
    let op_id = next_async_bytes_op_id(&mut ops_ref);
    ops_ref.queued_async_bytes_op_ids.push_back(op_id);
    ops_ref.pending_async_bytes_ops.insert(
        op_id,
        PendingAsyncBytesOp {
            name: op_name,
            payload,
            resolver: v8::Global::new(scope, resolver),
        },
    );
    rv.set(promise.into());
}

fn create_runtime_handle(mut isolate: v8::OwnedIsolate) -> u64 {
    configure_runtime_isolate(&mut isolate);
    let modules = Rc::new(RefCell::new(ModuleStore::default()));
    let ops = Rc::new(RefCell::new(OpStore::default()));
    let context = {
        v8::scope!(let scope, &mut isolate);
        let context = v8::Context::new(scope, Default::default());
        context.set_slot(modules.clone());
        context.set_slot(ops.clone());
        {
            let context_scope = &mut v8::ContextScope::new(scope, context);
            install_runtime_bindings(context_scope, context)
                .expect("failed to install runtime bindings");
        }
        v8::Global::new(scope, context)
    };
    unsafe {
        isolate.exit();
    }
    let runtime = Box::new(Runtime {
        context,
        isolate,
        modules,
        ops,
        module_handles: HashMap::new(),
        next_module_handle: 1,
        module_evaluation_promises: HashMap::new(),
        promises: HashMap::new(),
        next_promise_handle: 1,
    });
    Box::into_raw(runtime) as usize as u64
}

fn store_module_handle<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    module_handles: &mut HashMap<u64, v8::Global<v8::Module>>,
    next_module_handle: &mut u64,
    module: v8::Local<'s, v8::Module>,
) -> u64 {
    let module_handle = *next_module_handle;
    *next_module_handle = next_module_handle.checked_add(1).unwrap_or(1);
    module_handles.insert(module_handle, v8::Global::new(scope, module));
    module_handle
}

fn load_module_namespace_object<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    module_handles: &HashMap<u64, v8::Global<v8::Module>>,
    module_handle: u64,
) -> Result<v8::Local<'s, v8::Object>, String> {
    let module_global = module_handles
        .get(&module_handle)
        .ok_or_else(|| "module handle is closed".to_string())?;
    let module = v8::Local::new(scope, module_global);
    v8::Local::<v8::Object>::try_from(module.get_module_namespace())
        .map_err(|_| "failed to cast module namespace".to_string())
}

fn load_module_export_value<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    namespace: v8::Local<'s, v8::Object>,
    export_name: &str,
) -> Result<v8::Local<'s, v8::Value>, String> {
    let export_name = v8::String::new(scope, export_name)
        .ok_or_else(|| "failed to allocate export name".to_string())?;
    namespace
        .get(scope, export_name.into())
        .ok_or_else(|| "failed to read module export".to_string())
}

fn encode_promise_state(state: v8::PromiseState) -> i32 {
    match state {
        v8::PromiseState::Pending => PROMISE_STATE_PENDING,
        v8::PromiseState::Fulfilled => PROMISE_STATE_FULFILLED,
        v8::PromiseState::Rejected => PROMISE_STATE_REJECTED,
    }
}

fn eval_promise_from_source(
    runtime: &mut Runtime,
    resource_name: &str,
    source: &str,
    error_out: *mut u8,
) -> u64 {
    let Runtime {
        context,
        isolate,
        promises,
        next_promise_handle,
        ..
    } = runtime;
    entered_scope!(isolate, scope);
    let context = v8::Local::new(scope, &*context);
    let context_scope = &mut v8::ContextScope::new(scope, context);
    let mut try_catch = v8::TryCatch::new(context_scope);
    let mut try_catch = {
        let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
        try_catch_pinned.init()
    };
    let try_catch = &mut try_catch;
    macro_rules! format_exception {
        ($try_catch:expr) => {{
            let exception = $try_catch
                .stack_trace()
                .or_else(|| $try_catch.exception())
                .map(|value| value.to_rust_string_lossy($try_catch))
                .unwrap_or_else(|| "V8 exception".to_string());

            if let Some(message) = $try_catch.message() {
                let line = message.get_line_number($try_catch).unwrap_or_default();
                if line > 0 {
                    format!("line {}: {}", line, exception)
                } else {
                    exception
                }
            } else {
                exception
            }
        }};
    }

    let script = match compile_script_from_source(try_catch, resource_name, source) {
        Some(script) => script,
        None => {
            set_error(error_out, &format_exception!(try_catch));
            return 0;
        }
    };

    let value = match script.run(try_catch) {
        Some(value) => value,
        None => {
            set_error(error_out, &format_exception!(try_catch));
            return 0;
        }
    };

    if !value.is_promise() {
        set_error(error_out, "script result is not a promise");
        return 0;
    }

    let promise = match v8::Local::<v8::Promise>::try_from(value) {
        Ok(promise) => promise,
        Err(_) => {
            set_error(error_out, "failed to cast promise result");
            return 0;
        }
    };

    store_promise_handle(try_catch, promises, next_promise_handle, promise)
}

fn store_promise_handle<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    promises: &mut HashMap<u64, v8::Global<v8::Promise>>,
    next_promise_handle: &mut u64,
    promise: v8::Local<'s, v8::Promise>,
) -> u64 {
    let promise_handle = *next_promise_handle;
    *next_promise_handle = next_promise_handle.checked_add(1).unwrap_or(1);
    promises.insert(promise_handle, v8::Global::new(scope, promise));
    promise_handle
}

fn load_promise_local<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    promises: &HashMap<u64, v8::Global<v8::Promise>>,
    promise_handle: u64,
) -> Result<v8::Local<'s, v8::Promise>, String> {
    let promise_global = promises
        .get(&promise_handle)
        .ok_or_else(|| "promise handle is closed".to_string())?;
    Ok(v8::Local::new(scope, promise_global))
}

fn load_fulfilled_promise_value<'s>(
    scope: &mut v8::PinScope<'s, '_>,
    promise: v8::Local<'s, v8::Promise>,
) -> Result<v8::Local<'s, v8::Value>, String> {
    match promise.state() {
        v8::PromiseState::Pending => Err("promise is still pending".to_string()),
        v8::PromiseState::Fulfilled => Ok(promise.result(scope)),
        v8::PromiseState::Rejected => {
            let reason = promise.result(scope);
            let reason = reason
                .to_string(scope)
                .map(|value| value.to_rust_string_lossy(scope))
                .unwrap_or_else(|| "Promise rejected".to_string());
            Err(reason)
        }
    }
}

fn eval_module_handle_from_source(
    runtime: &mut Runtime,
    specifier: &str,
    source: &str,
    error_out: *mut u8,
) -> u64 {
    let Runtime {
        context,
        isolate,
        modules,
        module_handles,
        next_module_handle,
        ..
    } = runtime;
    entered_scope!(isolate, scope);
    let context = v8::Local::new(scope, &*context);
    let context_scope = &mut v8::ContextScope::new(scope, context);
    let mut try_catch = v8::TryCatch::new(context_scope);
    let mut try_catch = {
        let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
        try_catch_pinned.init()
    };
    let try_catch = &mut try_catch;
    macro_rules! format_exception {
        ($try_catch:expr) => {{
            let exception = $try_catch
                .stack_trace()
                .or_else(|| $try_catch.exception())
                .map(|value| value.to_rust_string_lossy($try_catch))
                .unwrap_or_else(|| "V8 exception".to_string());

            if let Some(message) = $try_catch.message() {
                let line = message.get_line_number($try_catch).unwrap_or_default();
                if line > 0 {
                    format!("line {}: {}", line, exception)
                } else {
                    exception
                }
            } else {
                exception
            }
        }};
    }

    let module = match compile_module_from_source(try_catch, specifier, source) {
        Some(module) => module,
        None => {
            set_error(error_out, &format_exception!(try_catch));
            return 0;
        }
    };
    register_compiled_module(try_catch, modules, specifier, module);

    match module.instantiate_module(try_catch, registered_module_resolve_callback) {
        Some(true) => {}
        Some(false) => {
            set_error(error_out, "module instantiation did not complete");
            return 0;
        }
        None => {
            set_error(error_out, &format_exception!(try_catch));
            return 0;
        }
    }

    let value = match module.evaluate(try_catch) {
        Some(value) => value,
        None => {
            set_error(error_out, &format_exception!(try_catch));
            return 0;
        }
    };

    if !value.is_promise() {
        return store_module_handle(try_catch, module_handles, next_module_handle, module);
    }

    let promise = match v8::Local::<v8::Promise>::try_from(value) {
        Ok(promise) => promise,
        Err(_) => {
            set_error(error_out, "failed to cast module evaluation promise");
            return 0;
        }
    };

    for _ in 0..1024 {
        match promise.state() {
            v8::PromiseState::Pending => {
                try_catch.perform_microtask_checkpoint();
            }
            v8::PromiseState::Fulfilled => {
                return store_module_handle(try_catch, module_handles, next_module_handle, module);
            }
            v8::PromiseState::Rejected => {
                let reason = promise.result(try_catch);
                let reason = reason
                    .to_string(try_catch)
                    .map(|value| value.to_rust_string_lossy(try_catch))
                    .unwrap_or_else(|| "Module evaluation rejected".to_string());
                set_error(error_out, &reason);
                return 0;
            }
        }
    }

    set_error(
        error_out,
        "module evaluation promise is still pending after 1024 microtask checkpoints",
    );
    0
}

fn eval_module_handle_async_from_source(
    runtime: &mut Runtime,
    specifier: &str,
    source: &str,
    error_out: *mut u8,
) -> u64 {
    let Runtime {
        context,
        isolate,
        modules,
        module_handles,
        next_module_handle,
        module_evaluation_promises,
        promises,
        next_promise_handle,
        ..
    } = runtime;
    entered_scope!(isolate, scope);
    let context = v8::Local::new(scope, &*context);
    let context_scope = &mut v8::ContextScope::new(scope, context);
    let mut try_catch = v8::TryCatch::new(context_scope);
    let mut try_catch = {
        let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
        try_catch_pinned.init()
    };
    let try_catch = &mut try_catch;
    macro_rules! format_exception {
        ($try_catch:expr) => {{
            let exception = $try_catch
                .stack_trace()
                .or_else(|| $try_catch.exception())
                .map(|value| value.to_rust_string_lossy($try_catch))
                .unwrap_or_else(|| "V8 exception".to_string());

            if let Some(message) = $try_catch.message() {
                let line = message.get_line_number($try_catch).unwrap_or_default();
                if line > 0 {
                    format!("line {}: {}", line, exception)
                } else {
                    exception
                }
            } else {
                exception
            }
        }};
    }

    let module = match compile_module_from_source(try_catch, specifier, source) {
        Some(module) => module,
        None => {
            set_error(error_out, &format_exception!(try_catch));
            return 0;
        }
    };
    register_compiled_module(try_catch, modules, specifier, module);

    match module.instantiate_module(try_catch, registered_module_resolve_callback) {
        Some(true) => {}
        Some(false) => {
            set_error(error_out, "module instantiation did not complete");
            return 0;
        }
        None => {
            set_error(error_out, &format_exception!(try_catch));
            return 0;
        }
    }

    let is_graph_async = module.is_graph_async();
    let value = match module.evaluate(try_catch) {
        Some(value) => value,
        None => {
            set_error(error_out, &format_exception!(try_catch));
            return 0;
        }
    };

    if !is_graph_async {
        return store_module_handle(try_catch, module_handles, next_module_handle, module);
    }

    if !value.is_promise() {
        set_error(
            error_out,
            "async module evaluation did not return a promise",
        );
        return 0;
    }

    let promise = match v8::Local::<v8::Promise>::try_from(value) {
        Ok(promise) => promise,
        Err(_) => {
            set_error(error_out, "failed to cast module evaluation promise");
            return 0;
        }
    };

    let promise_handle = store_promise_handle(try_catch, promises, next_promise_handle, promise);
    let module_handle = store_module_handle(try_catch, module_handles, next_module_handle, module);
    module_evaluation_promises.insert(module_handle, promise_handle);
    module_handle
}

fn startup_data_from_bytes(snapshot: &[u8]) -> Result<v8::StartupData, String> {
    if snapshot.len() < 64 {
        return Err("snapshot buffer is too small".to_string());
    }
    let startup_data = v8::StartupData::from(snapshot.to_vec());
    if startup_data.is_valid() {
        Ok(startup_data)
    } else {
        Err("snapshot is invalid for current V8 instance".to_string())
    }
}

fn create_snapshot_blob(
    source: &str,
    existing_snapshot: Option<v8::StartupData>,
) -> Result<MoonBitBytes, String> {
    ensure_v8();
    let mut snapshot_creator = match existing_snapshot {
        Some(existing_snapshot) => {
            v8::Isolate::snapshot_creator_from_existing_snapshot(existing_snapshot, None, None)
        }
        None => v8::Isolate::snapshot_creator(None, None),
    };
    snapshot_creator.set_microtasks_policy(v8::MicrotasksPolicy::Explicit);

    {
        v8::scope!(let scope, &mut snapshot_creator);
        let context = v8::Context::new(scope, Default::default());
        let context_scope = &mut v8::ContextScope::new(scope, context);
        {
            let mut try_catch = v8::TryCatch::new(context_scope);
            let mut try_catch = {
                let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
                try_catch_pinned.init()
            };
            let try_catch = &mut try_catch;
            macro_rules! format_exception {
                ($try_catch:expr) => {{
                    let exception = $try_catch
                        .stack_trace()
                        .or_else(|| $try_catch.exception())
                        .map(|value| value.to_rust_string_lossy($try_catch))
                        .unwrap_or_else(|| "V8 exception".to_string());

                    if let Some(message) = $try_catch.message() {
                        let line = message.get_line_number($try_catch).unwrap_or_default();
                        if line > 0 {
                            format!("line {}: {}", line, exception)
                        } else {
                            exception
                        }
                    } else {
                        exception
                    }
                }};
            }

            let source = match v8::String::new(try_catch, source) {
                Some(source) => source,
                None => return Err("failed to allocate V8 source string".to_string()),
            };
            let script = match v8::Script::compile(try_catch, source, None) {
                Some(script) => script,
                None => return Err(format_exception!(try_catch)),
            };
            if script.run(try_catch).is_none() {
                return Err(format_exception!(try_catch));
            }
        }
        context_scope.set_default_context(context);
    }

    let blob = snapshot_creator
        .create_blob(v8::FunctionCodeHandling::Clear)
        .ok_or_else(|| "failed to create snapshot blob".to_string())?;
    Ok(copy_bytes_to_moonbit(&blob))
}

#[no_mangle]
pub extern "C" fn moonbit_ptr_sizeof() -> i32 {
    std::mem::size_of::<*mut c_void>() as i32
}

#[no_mangle]
pub extern "C" fn moonbit_ptr_is_null(bytes: *const u8) -> bool {
    unsafe { read_raw_ptr(bytes).is_null() }
}

#[no_mangle]
pub extern "C" fn moonbit_ptr_clear(bytes: *mut u8) {
    unsafe { write_raw_ptr(bytes, ptr::null_mut()) }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_error_delete_ptr(bytes: *const u8) {
    let ptr = unsafe { read_raw_ptr(bytes) }.cast::<c_char>();
    if ptr.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(ptr));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_error_message_bytes(bytes: *const u8) -> MoonBitBytes {
    let ptr = unsafe { read_raw_ptr(bytes) }.cast::<c_char>();
    if ptr.is_null() {
        return empty_bytes();
    }
    let message = unsafe { CStr::from_ptr(ptr) };
    copy_bytes_to_moonbit(message.to_bytes())
}

#[no_mangle]
pub extern "C" fn moonbit_v8_version_bytes() -> MoonBitBytes {
    match panic::catch_unwind(AssertUnwindSafe(|| {
        copy_string_to_moonbit(v8::V8::get_version())
    })) {
        Ok(bytes) => bytes,
        Err(_) => empty_bytes(),
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_new(error_out: *mut u8) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        ensure_v8();
        create_runtime_handle(v8::Isolate::new(v8::CreateParams::default()))
    }));

    match result {
        Ok(handle) => handle,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_new_with_snapshot(
    snapshot: *const u8,
    snapshot_len: i32,
    error_out: *mut u8,
) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        ensure_v8();
        if snapshot.is_null() || snapshot_len < 0 {
            set_error(error_out, "snapshot buffer is invalid");
            return 0;
        }
        let snapshot = unsafe { slice::from_raw_parts(snapshot, snapshot_len as usize) };
        let startup_data = match startup_data_from_bytes(snapshot) {
            Ok(startup_data) => startup_data,
            Err(message) => {
                set_error(error_out, &message);
                return 0;
            }
        };
        let params = v8::Isolate::create_params().snapshot_blob(startup_data);
        create_runtime_handle(v8::Isolate::new(params))
    }));

    match result {
        Ok(handle) => handle,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_snapshot_create(
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);
        match create_snapshot_blob(source.as_ref(), None) {
            Ok(snapshot) => snapshot,
            Err(message) => {
                set_error(error_out, &message);
                empty_bytes()
            }
        }
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_snapshot_extend(
    snapshot: *const u8,
    snapshot_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if snapshot.is_null() || snapshot_len < 0 {
            set_error(error_out, "snapshot buffer is invalid");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }
        let snapshot = unsafe { slice::from_raw_parts(snapshot, snapshot_len as usize) };
        let startup_data = match startup_data_from_bytes(snapshot) {
            Ok(startup_data) => startup_data,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);
        match create_snapshot_blob(source.as_ref(), Some(startup_data)) {
            Ok(snapshot) => snapshot,
            Err(message) => {
                set_error(error_out, &message);
                empty_bytes()
            }
        }
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_delete(handle: u64) {
    if handle == 0 {
        return;
    }

    let runtime = handle as usize as *mut Runtime;
    let _ = panic::catch_unwind(AssertUnwindSafe(|| unsafe {
        (*runtime).isolate.enter();
        drop(Box::from_raw(runtime));
    }));
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_load_module(
    handle: u64,
    specifier: *const u8,
    specifier_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if specifier.is_null() || specifier_len < 0 {
            set_error(error_out, "module specifier buffer is invalid");
            return;
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "module source buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let specifier = unsafe { slice::from_raw_parts(specifier, specifier_len as usize) };
        let specifier = String::from_utf8_lossy(specifier).to_string();
        if specifier.is_empty() {
            set_error(error_out, "module specifier must not be empty");
            return;
        }

        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source).to_string();

        let mut modules = runtime.modules.borrow_mut();
        modules.sources.insert(specifier.clone(), source);
        modules.modules.remove(&specifier);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_register_sync_json_op(
    handle: u64,
    name: *const u8,
    name_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "op name buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name).to_string();
        if name.is_empty() {
            set_error(error_out, "op name must not be empty");
            return;
        }

        runtime
            .ops
            .borrow_mut()
            .registered_sync_json_ops
            .insert(name);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_push_sync_json_op_response(
    handle: u64,
    name: *const u8,
    name_len: i32,
    payload_json: *const u8,
    payload_json_len: i32,
    result_json: *const u8,
    result_json_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "op name buffer is invalid");
            return;
        }
        if payload_json.is_null() || payload_json_len < 0 {
            set_error(error_out, "payload json buffer is invalid");
            return;
        }
        if result_json.is_null() || result_json_len < 0 {
            set_error(error_out, "result json buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name).to_string();
        if name.is_empty() {
            set_error(error_out, "op name must not be empty");
            return;
        }
        let payload_json =
            unsafe { slice::from_raw_parts(payload_json, payload_json_len as usize) };
        let payload_json = String::from_utf8_lossy(payload_json).to_string();
        let result_json = unsafe { slice::from_raw_parts(result_json, result_json_len as usize) };
        let result_json = String::from_utf8_lossy(result_json).to_string();

        let key = (name, payload_json);
        let mut ops = runtime.ops.borrow_mut();
        ops.sync_json_op_responses
            .entry(key)
            .or_default()
            .push_back(result_json);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_register_sync_json_callback(
    handle: u64,
    name: *const u8,
    name_len: i32,
    callback: MoonBitBytesCallback,
    closure: *mut c_void,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "op name buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name).to_string();
        if name.is_empty() {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "op name must not be empty");
            return;
        }

        let mut ops = runtime.ops.borrow_mut();
        if let Some(previous) = ops.sync_json_callbacks.insert(
            name.clone(),
            RegisteredMoonBitBytesCallback { callback, closure },
        ) {
            if !previous.closure.is_null() {
                unsafe { moonbit_decref(previous.closure) };
            }
        }
        ops.registered_sync_json_ops.insert(name);
    }));

    if let Err(payload) = result {
        if !closure.is_null() {
            unsafe { moonbit_decref(closure) };
        }
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_take_sync_json_op(handle: u64, error_out: *mut u8) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        runtime
            .ops
            .borrow_mut()
            .queued_sync_json_op_ids
            .pop_front()
            .unwrap_or(0)
    }));

    match result {
        Ok(op_id) => op_id,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_sync_json_op_name(
    handle: u64,
    op_id: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if op_id == 0 {
            set_error(error_out, "sync json op id is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let ops = runtime.ops.borrow();
        let op = match ops.completed_sync_json_ops.get(&op_id) {
            Some(op) => op,
            None => {
                set_error(error_out, "sync json op is closed");
                return empty_bytes();
            }
        };
        copy_string_to_moonbit(&op.name)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_sync_json_op_payload_json(
    handle: u64,
    op_id: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if op_id == 0 {
            set_error(error_out, "sync json op id is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let ops = runtime.ops.borrow();
        let op = match ops.completed_sync_json_ops.get(&op_id) {
            Some(op) => op,
            None => {
                set_error(error_out, "sync json op is closed");
                return empty_bytes();
            }
        };
        copy_string_to_moonbit(&op.payload_json)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_sync_json_op_delete(handle: u64, op_id: u64) {
    if handle == 0 || op_id == 0 {
        return;
    }

    let _ = panic::catch_unwind(AssertUnwindSafe(|| {
        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        runtime
            .ops
            .borrow_mut()
            .completed_sync_json_ops
            .remove(&op_id);
    }));
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_register_sync_bytes_op(
    handle: u64,
    name: *const u8,
    name_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "op name buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name).to_string();
        if name.is_empty() {
            set_error(error_out, "op name must not be empty");
            return;
        }

        runtime
            .ops
            .borrow_mut()
            .registered_sync_bytes_ops
            .insert(name);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_push_sync_bytes_op_response(
    handle: u64,
    name: *const u8,
    name_len: i32,
    payload: *const u8,
    payload_len: i32,
    result_bytes: *const u8,
    result_bytes_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "op name buffer is invalid");
            return;
        }
        if payload.is_null() || payload_len < 0 {
            set_error(error_out, "payload bytes buffer is invalid");
            return;
        }
        if result_bytes.is_null() || result_bytes_len < 0 {
            set_error(error_out, "result bytes buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name).to_string();
        if name.is_empty() {
            set_error(error_out, "op name must not be empty");
            return;
        }
        let payload = unsafe { slice::from_raw_parts(payload, payload_len as usize) }.to_vec();
        let result_bytes =
            unsafe { slice::from_raw_parts(result_bytes, result_bytes_len as usize) }.to_vec();

        let key = (name, payload);
        let mut ops = runtime.ops.borrow_mut();
        ops.sync_bytes_op_responses
            .entry(key)
            .or_default()
            .push_back(result_bytes);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_register_sync_bytes_callback(
    handle: u64,
    name: *const u8,
    name_len: i32,
    callback: MoonBitBytesCallback,
    closure: *mut c_void,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "op name buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name).to_string();
        if name.is_empty() {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "op name must not be empty");
            return;
        }

        let mut ops = runtime.ops.borrow_mut();
        if let Some(previous) = ops.sync_bytes_callbacks.insert(
            name.clone(),
            RegisteredMoonBitBytesCallback { callback, closure },
        ) {
            if !previous.closure.is_null() {
                unsafe { moonbit_decref(previous.closure) };
            }
        }
        ops.registered_sync_bytes_ops.insert(name);
    }));

    if let Err(payload) = result {
        if !closure.is_null() {
            unsafe { moonbit_decref(closure) };
        }
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_take_sync_bytes_op(handle: u64, error_out: *mut u8) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        runtime
            .ops
            .borrow_mut()
            .queued_sync_bytes_op_ids
            .pop_front()
            .unwrap_or(0)
    }));

    match result {
        Ok(op_id) => op_id,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_sync_bytes_op_name(
    handle: u64,
    op_id: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if op_id == 0 {
            set_error(error_out, "sync bytes op id is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let ops = runtime.ops.borrow();
        let op = match ops.completed_sync_bytes_ops.get(&op_id) {
            Some(op) => op,
            None => {
                set_error(error_out, "sync bytes op is closed");
                return empty_bytes();
            }
        };
        copy_string_to_moonbit(&op.name)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_sync_bytes_op_payload(
    handle: u64,
    op_id: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if op_id == 0 {
            set_error(error_out, "sync bytes op id is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let ops = runtime.ops.borrow();
        let op = match ops.completed_sync_bytes_ops.get(&op_id) {
            Some(op) => op,
            None => {
                set_error(error_out, "sync bytes op is closed");
                return empty_bytes();
            }
        };
        copy_bytes_to_moonbit(&op.payload)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_sync_bytes_op_delete(handle: u64, op_id: u64) {
    if handle == 0 || op_id == 0 {
        return;
    }

    let _ = panic::catch_unwind(AssertUnwindSafe(|| {
        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        runtime
            .ops
            .borrow_mut()
            .completed_sync_bytes_ops
            .remove(&op_id);
    }));
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_register_async_json_op(
    handle: u64,
    name: *const u8,
    name_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "op name buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name).to_string();
        if name.is_empty() {
            set_error(error_out, "op name must not be empty");
            return;
        }

        runtime
            .ops
            .borrow_mut()
            .registered_async_json_ops
            .insert(name);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_register_async_json_callback(
    handle: u64,
    name: *const u8,
    name_len: i32,
    callback: MoonBitBytesCallback,
    closure: *mut c_void,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "op name buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name).to_string();
        if name.is_empty() {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "op name must not be empty");
            return;
        }

        let mut ops = runtime.ops.borrow_mut();
        if let Some(previous) = ops.async_json_callbacks.insert(
            name.clone(),
            RegisteredMoonBitBytesCallback { callback, closure },
        ) {
            if !previous.closure.is_null() {
                unsafe { moonbit_decref(previous.closure) };
            }
        }
        ops.registered_async_json_ops.insert(name);
    }));

    if let Err(payload) = result {
        if !closure.is_null() {
            unsafe { moonbit_decref(closure) };
        }
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_take_async_json_op(handle: u64, error_out: *mut u8) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        runtime
            .ops
            .borrow_mut()
            .queued_async_json_op_ids
            .pop_front()
            .unwrap_or(0)
    }));

    match result {
        Ok(op_id) => op_id,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_async_json_op_name(
    handle: u64,
    op_id: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if op_id == 0 {
            set_error(error_out, "async json op id is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let ops = runtime.ops.borrow();
        let op = match ops.pending_async_json_ops.get(&op_id) {
            Some(op) => op,
            None => {
                set_error(error_out, "async json op is closed");
                return empty_bytes();
            }
        };
        copy_string_to_moonbit(&op.name)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_async_json_op_payload_json(
    handle: u64,
    op_id: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if op_id == 0 {
            set_error(error_out, "async json op id is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let ops = runtime.ops.borrow();
        let op = match ops.pending_async_json_ops.get(&op_id) {
            Some(op) => op,
            None => {
                set_error(error_out, "async json op is closed");
                return empty_bytes();
            }
        };
        copy_string_to_moonbit(&op.payload_json)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_resolve_async_json_op(
    handle: u64,
    op_id: u64,
    result_json: *const u8,
    result_json_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if op_id == 0 {
            set_error(error_out, "async json op id is invalid");
            return;
        }
        if result_json.is_null() || result_json_len < 0 {
            set_error(error_out, "result json buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let result_json = unsafe { slice::from_raw_parts(result_json, result_json_len as usize) };
        let result_json = String::from_utf8_lossy(result_json).to_string();

        let Runtime {
            context,
            isolate,
            ops,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let value = match parse_json_value(try_catch, result_json.as_ref()) {
            Some(value) => value,
            None => {
                set_error(error_out, "failed to parse async json op result");
                return;
            }
        };

        let resolver = {
            let ops_ref = ops.borrow();
            match ops_ref.pending_async_json_ops.get(&op_id) {
                Some(op) => op.resolver.clone(),
                None => {
                    set_error(error_out, "async json op is closed");
                    return;
                }
            }
        };

        let resolver = v8::Local::new(try_catch, &resolver);
        let _ = resolver.resolve(try_catch, value);
        ops.borrow_mut().pending_async_json_ops.remove(&op_id);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_reject_async_json_op(
    handle: u64,
    op_id: u64,
    message: *const u8,
    message_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if op_id == 0 {
            set_error(error_out, "async json op id is invalid");
            return;
        }
        if message.is_null() || message_len < 0 {
            set_error(error_out, "rejection message buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let message = unsafe { slice::from_raw_parts(message, message_len as usize) };
        let message = String::from_utf8_lossy(message).to_string();

        let Runtime {
            context,
            isolate,
            ops,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let resolver = {
            let ops_ref = ops.borrow();
            match ops_ref.pending_async_json_ops.get(&op_id) {
                Some(op) => op.resolver.clone(),
                None => {
                    set_error(error_out, "async json op is closed");
                    return;
                }
            }
        };

        let resolver = v8::Local::new(try_catch, &resolver);
        let reason = match v8::String::new(try_catch, message.as_ref()) {
            Some(reason) => reason,
            None => {
                set_error(error_out, "failed to allocate rejection message");
                return;
            }
        };
        let _ = resolver.reject(try_catch, reason.into());
        ops.borrow_mut().pending_async_json_ops.remove(&op_id);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_reject_async_json_op_with_json(
    handle: u64,
    op_id: u64,
    error_json: *const u8,
    error_json_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if op_id == 0 {
            set_error(error_out, "async json op id is invalid");
            return;
        }
        if error_json.is_null() || error_json_len < 0 {
            set_error(error_out, "rejection json buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let error_json = unsafe { slice::from_raw_parts(error_json, error_json_len as usize) };
        let error_json = String::from_utf8_lossy(error_json).to_string();

        let Runtime {
            context,
            isolate,
            ops,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let resolver = {
            let ops_ref = ops.borrow();
            match ops_ref.pending_async_json_ops.get(&op_id) {
                Some(op) => op.resolver.clone(),
                None => {
                    set_error(error_out, "async json op is closed");
                    return;
                }
            }
        };

        let reason = match parse_json_value(try_catch, error_json.as_ref()) {
            Some(reason) => reason,
            None => {
                set_error(error_out, "failed to parse rejection json");
                return;
            }
        };
        let resolver = v8::Local::new(try_catch, &resolver);
        let _ = resolver.reject(try_catch, reason);
        ops.borrow_mut().pending_async_json_ops.remove(&op_id);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_register_async_bytes_op(
    handle: u64,
    name: *const u8,
    name_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "op name buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name).to_string();
        if name.is_empty() {
            set_error(error_out, "op name must not be empty");
            return;
        }

        runtime
            .ops
            .borrow_mut()
            .registered_async_bytes_ops
            .insert(name);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_register_async_bytes_callback(
    handle: u64,
    name: *const u8,
    name_len: i32,
    callback: MoonBitBytesCallback,
    closure: *mut c_void,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "op name buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name).to_string();
        if name.is_empty() {
            if !closure.is_null() {
                unsafe { moonbit_decref(closure) };
            }
            set_error(error_out, "op name must not be empty");
            return;
        }

        let mut ops = runtime.ops.borrow_mut();
        if let Some(previous) = ops.async_bytes_callbacks.insert(
            name.clone(),
            RegisteredMoonBitBytesCallback { callback, closure },
        ) {
            if !previous.closure.is_null() {
                unsafe { moonbit_decref(previous.closure) };
            }
        }
        ops.registered_async_bytes_ops.insert(name);
    }));

    if let Err(payload) = result {
        if !closure.is_null() {
            unsafe { moonbit_decref(closure) };
        }
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_take_async_bytes_op(handle: u64, error_out: *mut u8) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        runtime
            .ops
            .borrow_mut()
            .queued_async_bytes_op_ids
            .pop_front()
            .unwrap_or(0)
    }));

    match result {
        Ok(op_id) => op_id,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_async_bytes_op_name(
    handle: u64,
    op_id: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if op_id == 0 {
            set_error(error_out, "async bytes op id is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let ops = runtime.ops.borrow();
        let op = match ops.pending_async_bytes_ops.get(&op_id) {
            Some(op) => op,
            None => {
                set_error(error_out, "async bytes op is closed");
                return empty_bytes();
            }
        };
        copy_string_to_moonbit(&op.name)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_async_bytes_op_payload(
    handle: u64,
    op_id: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if op_id == 0 {
            set_error(error_out, "async bytes op id is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let ops = runtime.ops.borrow();
        let op = match ops.pending_async_bytes_ops.get(&op_id) {
            Some(op) => op,
            None => {
                set_error(error_out, "async bytes op is closed");
                return empty_bytes();
            }
        };
        copy_bytes_to_moonbit(&op.payload)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_resolve_async_bytes_op(
    handle: u64,
    op_id: u64,
    result_bytes: *const u8,
    result_bytes_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if op_id == 0 {
            set_error(error_out, "async bytes op id is invalid");
            return;
        }
        if result_bytes.is_null() || result_bytes_len < 0 {
            set_error(error_out, "result bytes buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let result_bytes =
            unsafe { slice::from_raw_parts(result_bytes, result_bytes_len as usize) };

        let Runtime {
            context,
            isolate,
            ops,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let value = match make_uint8_array_from_bytes(try_catch, result_bytes) {
            Some(value) => value,
            None => {
                set_error(error_out, "failed to allocate Uint8Array");
                return;
            }
        };

        let resolver = {
            let ops_ref = ops.borrow();
            match ops_ref.pending_async_bytes_ops.get(&op_id) {
                Some(op) => op.resolver.clone(),
                None => {
                    set_error(error_out, "async bytes op is closed");
                    return;
                }
            }
        };

        let resolver = v8::Local::new(try_catch, &resolver);
        let _ = resolver.resolve(try_catch, value.into());
        ops.borrow_mut().pending_async_bytes_ops.remove(&op_id);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_reject_async_bytes_op(
    handle: u64,
    op_id: u64,
    message: *const u8,
    message_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if op_id == 0 {
            set_error(error_out, "async bytes op id is invalid");
            return;
        }
        if message.is_null() || message_len < 0 {
            set_error(error_out, "rejection message buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let message = unsafe { slice::from_raw_parts(message, message_len as usize) };
        let message = String::from_utf8_lossy(message).to_string();

        let Runtime {
            context,
            isolate,
            ops,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let resolver = {
            let ops_ref = ops.borrow();
            match ops_ref.pending_async_bytes_ops.get(&op_id) {
                Some(op) => op.resolver.clone(),
                None => {
                    set_error(error_out, "async bytes op is closed");
                    return;
                }
            }
        };

        let resolver = v8::Local::new(try_catch, &resolver);
        let reason = match v8::String::new(try_catch, message.as_ref()) {
            Some(reason) => reason,
            None => {
                set_error(error_out, "failed to allocate rejection message");
                return;
            }
        };
        let _ = resolver.reject(try_catch, reason.into());
        ops.borrow_mut().pending_async_bytes_ops.remove(&op_id);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_reject_async_bytes_op_with_json(
    handle: u64,
    op_id: u64,
    error_json: *const u8,
    error_json_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if op_id == 0 {
            set_error(error_out, "async bytes op id is invalid");
            return;
        }
        if error_json.is_null() || error_json_len < 0 {
            set_error(error_out, "rejection json buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let error_json = unsafe { slice::from_raw_parts(error_json, error_json_len as usize) };
        let error_json = String::from_utf8_lossy(error_json).to_string();

        let Runtime {
            context,
            isolate,
            ops,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let resolver = {
            let ops_ref = ops.borrow();
            match ops_ref.pending_async_bytes_ops.get(&op_id) {
                Some(op) => op.resolver.clone(),
                None => {
                    set_error(error_out, "async bytes op is closed");
                    return;
                }
            }
        };

        let reason = match parse_json_value(try_catch, error_json.as_ref()) {
            Some(reason) => reason,
            None => {
                set_error(error_out, "failed to parse rejection json");
                return;
            }
        };
        let resolver = v8::Local::new(try_catch, &resolver);
        let _ = resolver.reject(try_catch, reason);
        ops.borrow_mut().pending_async_bytes_ops.remove(&op_id);
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_set_global_json(
    handle: u64,
    name: *const u8,
    name_len: i32,
    json: *const u8,
    json_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "global name buffer is invalid");
            return;
        }
        if json.is_null() || json_len < 0 {
            set_error(error_out, "json buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name);
        if name.is_empty() {
            set_error(error_out, "global name must not be empty");
            return;
        }
        let json = unsafe { slice::from_raw_parts(json, json_len as usize) };
        let json = String::from_utf8_lossy(json);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let name = match v8::String::new(try_catch, name.as_ref()) {
            Some(name) => name,
            None => {
                set_error(error_out, "failed to allocate global name");
                return;
            }
        };
        let value = match parse_json_value(try_catch, json.as_ref()) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return;
            }
        };

        let global = context.global(try_catch);
        match global.set(try_catch, name.into(), value) {
            Some(true) => {}
            Some(false) => set_error(error_out, "failed to set global value"),
            None => set_error(error_out, &format_exception!(try_catch)),
        }
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_get_global_json(
    handle: u64,
    name: *const u8,
    name_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "global name buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name);
        if name.is_empty() {
            set_error(error_out, "global name must not be empty");
            return empty_bytes();
        }

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let name = match v8::String::new(try_catch, name.as_ref()) {
            Some(name) => name,
            None => {
                set_error(error_out, "failed to allocate global name");
                return empty_bytes();
            }
        };

        let global = context.global(try_catch);
        let value = match global.get(try_catch, name.into()) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };
        let json = match stringify_json_value(try_catch, value) {
            Some(json) => json,
            None => {
                set_error(error_out, "global value is not JSON-serializable");
                return empty_bytes();
            }
        };
        copy_string_to_moonbit(&json)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_set_global_bytes(
    handle: u64,
    name: *const u8,
    name_len: i32,
    bytes: *const u8,
    bytes_len: i32,
    error_out: *mut u8,
) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "global name buffer is invalid");
            return;
        }
        if bytes.is_null() || bytes_len < 0 {
            set_error(error_out, "bytes buffer is invalid");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name);
        if name.is_empty() {
            set_error(error_out, "global name must not be empty");
            return;
        }
        let bytes = unsafe { slice::from_raw_parts(bytes, bytes_len as usize) };

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let name = match v8::String::new(try_catch, name.as_ref()) {
            Some(name) => name,
            None => {
                set_error(error_out, "failed to allocate global name");
                return;
            }
        };
        let value = match make_uint8_array_from_bytes(try_catch, bytes) {
            Some(value) => value,
            None => {
                set_error(error_out, "failed to allocate Uint8Array");
                return;
            }
        };

        let global = context.global(try_catch);
        match global.set(try_catch, name.into(), value.into()) {
            Some(true) => {}
            Some(false) => set_error(error_out, "failed to set global bytes"),
            None => set_error(error_out, &format_exception!(try_catch)),
        }
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_get_global_bytes(
    handle: u64,
    name: *const u8,
    name_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "global name buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name);
        if name.is_empty() {
            set_error(error_out, "global name must not be empty");
            return empty_bytes();
        }

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let name = match v8::String::new(try_catch, name.as_ref()) {
            Some(name) => name,
            None => {
                set_error(error_out, "failed to allocate global name");
                return empty_bytes();
            }
        };

        let global = context.global(try_catch);
        let value = match global.get(try_catch, name.into()) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };
        let bytes = match copy_bytes_from_value(try_catch, value) {
            Ok(bytes) => bytes,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        copy_bytes_to_moonbit(&bytes)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_call_global_bytes(
    handle: u64,
    name: *const u8,
    name_len: i32,
    bytes: *const u8,
    bytes_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "global name buffer is invalid");
            return empty_bytes();
        }
        if bytes.is_null() || bytes_len < 0 {
            set_error(error_out, "bytes buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name);
        if name.is_empty() {
            set_error(error_out, "global name must not be empty");
            return empty_bytes();
        }
        let bytes = unsafe { slice::from_raw_parts(bytes, bytes_len as usize) };

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let name = match v8::String::new(try_catch, name.as_ref()) {
            Some(name) => name,
            None => {
                set_error(error_out, "failed to allocate global name");
                return empty_bytes();
            }
        };
        let arg = match make_uint8_array_from_bytes(try_catch, bytes) {
            Some(arg) => arg,
            None => {
                set_error(error_out, "failed to allocate Uint8Array");
                return empty_bytes();
            }
        };

        let global = context.global(try_catch);
        let value = match global.get(try_catch, name.into()) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };
        let func = match v8::Local::<v8::Function>::try_from(value) {
            Ok(func) => func,
            Err(_) => {
                set_error(error_out, "global value is not a function");
                return empty_bytes();
            }
        };

        let argv = [arg.into()];
        let value = match func.call(try_catch, global.into(), &argv) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let bytes = match copy_bytes_from_value(try_catch, value) {
                Ok(bytes) => bytes,
                Err(message) => {
                    set_error(error_out, &message);
                    return empty_bytes();
                }
            };
            return copy_bytes_to_moonbit(&bytes);
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast function result promise");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let bytes = match copy_bytes_from_value(try_catch, value) {
                        Ok(bytes) => bytes,
                        Err(message) => {
                            set_error(error_out, &message);
                            return empty_bytes();
                        }
                    };
                    return copy_bytes_to_moonbit(&bytes);
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Function call rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "function result promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_call_global_json(
    handle: u64,
    name: *const u8,
    name_len: i32,
    args_json: *const u8,
    args_json_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if name.is_null() || name_len < 0 {
            set_error(error_out, "global name buffer is invalid");
            return empty_bytes();
        }
        if args_json.is_null() || args_json_len < 0 {
            set_error(error_out, "args json buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let name = unsafe { slice::from_raw_parts(name, name_len as usize) };
        let name = String::from_utf8_lossy(name);
        if name.is_empty() {
            set_error(error_out, "global name must not be empty");
            return empty_bytes();
        }
        let args_json = unsafe { slice::from_raw_parts(args_json, args_json_len as usize) };
        let args_json = String::from_utf8_lossy(args_json);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let name = match v8::String::new(try_catch, name.as_ref()) {
            Some(name) => name,
            None => {
                set_error(error_out, "failed to allocate global name");
                return empty_bytes();
            }
        };
        let args_value = match parse_json_value(try_catch, args_json.as_ref()) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };
        let args_array = match v8::Local::<v8::Array>::try_from(args_value) {
            Ok(args_array) => args_array,
            Err(_) => {
                set_error(
                    error_out,
                    "call_global_json expects args_json to decode to an array",
                );
                return empty_bytes();
            }
        };

        let global = context.global(try_catch);
        let value = match global.get(try_catch, name.into()) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };
        let func = match v8::Local::<v8::Function>::try_from(value) {
            Ok(func) => func,
            Err(_) => {
                set_error(error_out, "global value is not a function");
                return empty_bytes();
            }
        };

        let mut argv: Vec<v8::Local<v8::Value>> = Vec::with_capacity(args_array.length() as usize);
        for i in 0..args_array.length() {
            let value = match args_array.get_index(try_catch, i) {
                Some(value) => value,
                None => {
                    set_error(error_out, &format!("missing argument at index {i}"));
                    return empty_bytes();
                }
            };
            argv.push(value);
        }

        let value = match func.call(try_catch, global.into(), argv.as_slice()) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let json = match stringify_json_value(try_catch, value) {
                Some(json) => json,
                None => {
                    set_error(error_out, "function result is not JSON-serializable");
                    return empty_bytes();
                }
            };
            return copy_string_to_moonbit(&json);
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast function result promise");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let json = match stringify_json_value(try_catch, value) {
                        Some(json) => json,
                        None => {
                            set_error(
                                error_out,
                                "fulfilled function result is not JSON-serializable",
                            );
                            return empty_bytes();
                        }
                    };
                    return copy_string_to_moonbit(&json);
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Function call rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "function result promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, MAIN_SCRIPT_RESOURCE_NAME, source.as_ref())
            {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        let value = match value.to_string(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch))
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_json(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, MAIN_SCRIPT_RESOURCE_NAME, source.as_ref())
            {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        let json = match stringify_json_value(try_catch, value) {
            Some(json) => json,
            None => {
                set_error(error_out, "failed to stringify script result to json");
                return empty_bytes();
            }
        };

        copy_string_to_moonbit(&json)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_bytes(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, MAIN_SCRIPT_RESOURCE_NAME, source.as_ref())
            {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        let bytes = match copy_bytes_from_value(try_catch, value) {
            Ok(bytes) => bytes,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };

        copy_bytes_to_moonbit(&bytes)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_promise(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        eval_promise_from_source(
            runtime,
            MAIN_SCRIPT_RESOURCE_NAME,
            source.as_ref(),
            error_out,
        )
    }));

    match result {
        Ok(promise_handle) => promise_handle,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_with_name(
    handle: u64,
    resource_name: *const u8,
    resource_name_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if resource_name.is_null() || resource_name_len < 0 {
            set_error(error_out, "resource name buffer is invalid");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let resource_name =
            unsafe { slice::from_raw_parts(resource_name, resource_name_len as usize) };
        let resource_name = String::from_utf8_lossy(resource_name);
        if resource_name.is_empty() {
            set_error(error_out, "resource name must not be empty");
            return empty_bytes();
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, resource_name.as_ref(), source.as_ref()) {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        let value = match value.to_string(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch))
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_json_with_name(
    handle: u64,
    resource_name: *const u8,
    resource_name_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if resource_name.is_null() || resource_name_len < 0 {
            set_error(error_out, "resource name buffer is invalid");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let resource_name =
            unsafe { slice::from_raw_parts(resource_name, resource_name_len as usize) };
        let resource_name = String::from_utf8_lossy(resource_name);
        if resource_name.is_empty() {
            set_error(error_out, "resource name must not be empty");
            return empty_bytes();
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, resource_name.as_ref(), source.as_ref()) {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        let json = match stringify_json_value(try_catch, value) {
            Some(json) => json,
            None => {
                set_error(error_out, "failed to stringify script result to json");
                return empty_bytes();
            }
        };

        copy_string_to_moonbit(&json)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_bytes_with_name(
    handle: u64,
    resource_name: *const u8,
    resource_name_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if resource_name.is_null() || resource_name_len < 0 {
            set_error(error_out, "resource name buffer is invalid");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let resource_name =
            unsafe { slice::from_raw_parts(resource_name, resource_name_len as usize) };
        let resource_name = String::from_utf8_lossy(resource_name);
        if resource_name.is_empty() {
            set_error(error_out, "resource name must not be empty");
            return empty_bytes();
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, resource_name.as_ref(), source.as_ref()) {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        let bytes = match copy_bytes_from_value(try_catch, value) {
            Ok(bytes) => bytes,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };

        copy_bytes_to_moonbit(&bytes)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_promise_with_name(
    handle: u64,
    resource_name: *const u8,
    resource_name_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }
        if resource_name.is_null() || resource_name_len < 0 {
            set_error(error_out, "resource name buffer is invalid");
            return 0;
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let resource_name =
            unsafe { slice::from_raw_parts(resource_name, resource_name_len as usize) };
        let resource_name = String::from_utf8_lossy(resource_name);
        if resource_name.is_empty() {
            set_error(error_out, "resource name must not be empty");
            return 0;
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        eval_promise_from_source(runtime, resource_name.as_ref(), source.as_ref(), error_out)
    }));

    match result {
        Ok(promise_handle) => promise_handle,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_perform_microtask_checkpoint(handle: u64, error_out: *mut u8) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let scope = &mut v8::ContextScope::new(scope, context);
        scope.perform_microtask_checkpoint();
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_promise_state(
    handle: u64,
    promise_handle: u64,
    error_out: *mut u8,
) -> i32 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return PROMISE_STATE_PENDING;
        }
        if promise_handle == 0 {
            set_error(error_out, "promise handle is null");
            return PROMISE_STATE_PENDING;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let Runtime {
            context,
            isolate,
            promises,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let promise_global = match promises.get(&promise_handle) {
            Some(promise) => promise,
            None => {
                set_error(error_out, "promise handle is closed");
                return PROMISE_STATE_PENDING;
            }
        };
        let promise = v8::Local::new(context_scope, promise_global);
        encode_promise_state(promise.state())
    }));

    match result {
        Ok(state) => state,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            PROMISE_STATE_PENDING
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_promise_result(
    handle: u64,
    promise_handle: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if promise_handle == 0 {
            set_error(error_out, "promise handle is null");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let Runtime {
            context,
            isolate,
            promises,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        let promise = match load_promise_local(try_catch, promises, promise_handle) {
            Ok(promise) => promise,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let value = match load_fulfilled_promise_value(try_catch, promise) {
            Ok(value) => value,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let value = match value.to_string(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, "failed to stringify fulfilled promise value");
                return empty_bytes();
            }
        };
        copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch))
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_promise_result_json(
    handle: u64,
    promise_handle: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if promise_handle == 0 {
            set_error(error_out, "promise handle is null");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let Runtime {
            context,
            isolate,
            promises,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let promise = match load_promise_local(try_catch, promises, promise_handle) {
            Ok(promise) => promise,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let value = match load_fulfilled_promise_value(try_catch, promise) {
            Ok(value) => value,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let json = match stringify_json_value(try_catch, value) {
            Some(json) => json,
            None => {
                set_error(
                    error_out,
                    "failed to stringify fulfilled promise value to json",
                );
                return empty_bytes();
            }
        };
        copy_string_to_moonbit(&json)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_promise_result_bytes(
    handle: u64,
    promise_handle: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if promise_handle == 0 {
            set_error(error_out, "promise handle is null");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let Runtime {
            context,
            isolate,
            promises,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let promise = match load_promise_local(try_catch, promises, promise_handle) {
            Ok(promise) => promise,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let value = match load_fulfilled_promise_value(try_catch, promise) {
            Ok(value) => value,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let bytes = match copy_bytes_from_value(try_catch, value) {
            Ok(bytes) => bytes,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        copy_bytes_to_moonbit(&bytes)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_promise_delete(handle: u64, promise_handle: u64) {
    if handle == 0 || promise_handle == 0 {
        return;
    }

    let _ = panic::catch_unwind(AssertUnwindSafe(|| {
        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        runtime.promises.remove(&promise_handle);
    }));
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_async(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, MAIN_SCRIPT_RESOURCE_NAME, source.as_ref())
            {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let value = match value.to_string(try_catch) {
                Some(value) => value,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };
            return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast promise result");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let value = match value.to_string(try_catch) {
                        Some(value) => value,
                        None => {
                            set_error(error_out, "failed to stringify fulfilled promise value");
                            return empty_bytes();
                        }
                    };
                    return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Promise rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_async_json(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, MAIN_SCRIPT_RESOURCE_NAME, source.as_ref())
            {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let json = match stringify_json_value(try_catch, value) {
                Some(json) => json,
                None => {
                    set_error(error_out, "failed to stringify script result to json");
                    return empty_bytes();
                }
            };
            return copy_string_to_moonbit(&json);
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast promise result");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let json = match stringify_json_value(try_catch, value) {
                        Some(json) => json,
                        None => {
                            set_error(
                                error_out,
                                "failed to stringify fulfilled promise value to json",
                            );
                            return empty_bytes();
                        }
                    };
                    return copy_string_to_moonbit(&json);
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Promise rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_async_bytes(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, MAIN_SCRIPT_RESOURCE_NAME, source.as_ref())
            {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let bytes = match copy_bytes_from_value(try_catch, value) {
                Ok(bytes) => bytes,
                Err(message) => {
                    set_error(error_out, &message);
                    return empty_bytes();
                }
            };
            return copy_bytes_to_moonbit(&bytes);
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast promise result");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let bytes = match copy_bytes_from_value(try_catch, value) {
                        Ok(bytes) => bytes,
                        Err(message) => {
                            set_error(error_out, &message);
                            return empty_bytes();
                        }
                    };
                    return copy_bytes_to_moonbit(&bytes);
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Promise rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_async_with_name(
    handle: u64,
    resource_name: *const u8,
    resource_name_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if resource_name.is_null() || resource_name_len < 0 {
            set_error(error_out, "resource name buffer is invalid");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let resource_name =
            unsafe { slice::from_raw_parts(resource_name, resource_name_len as usize) };
        let resource_name = String::from_utf8_lossy(resource_name);
        if resource_name.is_empty() {
            set_error(error_out, "resource name must not be empty");
            return empty_bytes();
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, resource_name.as_ref(), source.as_ref()) {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let value = match value.to_string(try_catch) {
                Some(value) => value,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };
            return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast promise result");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let value = match value.to_string(try_catch) {
                        Some(value) => value,
                        None => {
                            set_error(error_out, "failed to stringify fulfilled promise value");
                            return empty_bytes();
                        }
                    };
                    return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Promise rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_async_json_with_name(
    handle: u64,
    resource_name: *const u8,
    resource_name_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if resource_name.is_null() || resource_name_len < 0 {
            set_error(error_out, "resource name buffer is invalid");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let resource_name =
            unsafe { slice::from_raw_parts(resource_name, resource_name_len as usize) };
        let resource_name = String::from_utf8_lossy(resource_name);
        if resource_name.is_empty() {
            set_error(error_out, "resource name must not be empty");
            return empty_bytes();
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, resource_name.as_ref(), source.as_ref()) {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let json = match stringify_json_value(try_catch, value) {
                Some(json) => json,
                None => {
                    set_error(error_out, "failed to stringify script result to json");
                    return empty_bytes();
                }
            };
            return copy_string_to_moonbit(&json);
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast promise result");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let json = match stringify_json_value(try_catch, value) {
                        Some(json) => json,
                        None => {
                            set_error(
                                error_out,
                                "failed to stringify fulfilled promise value to json",
                            );
                            return empty_bytes();
                        }
                    };
                    return copy_string_to_moonbit(&json);
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Promise rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_async_bytes_with_name(
    handle: u64,
    resource_name: *const u8,
    resource_name_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if resource_name.is_null() || resource_name_len < 0 {
            set_error(error_out, "resource name buffer is invalid");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let resource_name =
            unsafe { slice::from_raw_parts(resource_name, resource_name_len as usize) };
        let resource_name = String::from_utf8_lossy(resource_name);
        if resource_name.is_empty() {
            set_error(error_out, "resource name must not be empty");
            return empty_bytes();
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let script =
            match compile_script_from_source(try_catch, resource_name.as_ref(), source.as_ref()) {
                Some(script) => script,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let bytes = match copy_bytes_from_value(try_catch, value) {
                Ok(bytes) => bytes,
                Err(message) => {
                    set_error(error_out, &message);
                    return empty_bytes();
                }
            };
            return copy_bytes_to_moonbit(&bytes);
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast promise result");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let bytes = match copy_bytes_from_value(try_catch, value) {
                        Ok(bytes) => bytes,
                        Err(message) => {
                            set_error(error_out, &message);
                            return empty_bytes();
                        }
                    };
                    return copy_bytes_to_moonbit(&bytes);
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Promise rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_module(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let module =
            match compile_module_from_source(try_catch, MAIN_MODULE_SPECIFIER, source.as_ref()) {
                Some(module) => module,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };
        register_compiled_module(try_catch, &runtime.modules, MAIN_MODULE_SPECIFIER, module);

        match module.instantiate_module(try_catch, registered_module_resolve_callback) {
            Some(true) => {}
            Some(false) => {
                set_error(error_out, "module instantiation did not complete");
                return empty_bytes();
            }
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        }

        let value = match module.evaluate(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let value = match value.to_string(try_catch) {
                Some(value) => value,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };
            return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast module evaluation promise");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let value = match value.to_string(try_catch) {
                        Some(value) => value,
                        None => {
                            set_error(error_out, "failed to stringify fulfilled module value");
                            return empty_bytes();
                        }
                    };
                    return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Module evaluation rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "module evaluation promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_module_handle(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        eval_module_handle_from_source(runtime, MAIN_MODULE_SPECIFIER, source.as_ref(), error_out)
    }));

    match result {
        Ok(module_handle) => module_handle,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_module_with_specifier(
    handle: u64,
    specifier: *const u8,
    specifier_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if specifier.is_null() || specifier_len < 0 {
            set_error(error_out, "module specifier buffer is invalid");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let specifier = unsafe { slice::from_raw_parts(specifier, specifier_len as usize) };
        let specifier = String::from_utf8_lossy(specifier);
        if specifier.is_empty() {
            set_error(error_out, "module specifier must not be empty");
            return empty_bytes();
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        entered_scope!(&mut runtime.isolate, scope);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let module =
            match compile_module_from_source(try_catch, specifier.as_ref(), source.as_ref()) {
                Some(module) => module,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };
        register_compiled_module(try_catch, &runtime.modules, specifier.as_ref(), module);

        match module.instantiate_module(try_catch, registered_module_resolve_callback) {
            Some(true) => {}
            Some(false) => {
                set_error(error_out, "module instantiation did not complete");
                return empty_bytes();
            }
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        }

        let value = match module.evaluate(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let value = match value.to_string(try_catch) {
                Some(value) => value,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };
            return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast module evaluation promise");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let value = match value.to_string(try_catch) {
                        Some(value) => value,
                        None => {
                            set_error(error_out, "failed to stringify fulfilled module value");
                            return empty_bytes();
                        }
                    };
                    return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Module evaluation rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "module evaluation promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_module_handle_with_specifier(
    handle: u64,
    specifier: *const u8,
    specifier_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }
        if specifier.is_null() || specifier_len < 0 {
            set_error(error_out, "module specifier buffer is invalid");
            return 0;
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let specifier = unsafe { slice::from_raw_parts(specifier, specifier_len as usize) };
        let specifier = String::from_utf8_lossy(specifier);
        if specifier.is_empty() {
            set_error(error_out, "module specifier must not be empty");
            return 0;
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        eval_module_handle_from_source(runtime, specifier.as_ref(), source.as_ref(), error_out)
    }));

    match result {
        Ok(module_handle) => module_handle,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_module_handle_async(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        eval_module_handle_async_from_source(
            runtime,
            MAIN_MODULE_SPECIFIER,
            source.as_ref(),
            error_out,
        )
    }));

    match result {
        Ok(module_handle) => module_handle,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_module_handle_async_with_specifier(
    handle: u64,
    specifier: *const u8,
    specifier_len: i32,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }
        if specifier.is_null() || specifier_len < 0 {
            set_error(error_out, "module specifier buffer is invalid");
            return 0;
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let specifier = unsafe { slice::from_raw_parts(specifier, specifier_len as usize) };
        let specifier = String::from_utf8_lossy(specifier);
        if specifier.is_empty() {
            set_error(error_out, "module specifier must not be empty");
            return 0;
        }
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        eval_module_handle_async_from_source(
            runtime,
            specifier.as_ref(),
            source.as_ref(),
            error_out,
        )
    }));

    match result {
        Ok(module_handle) => module_handle,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_module_evaluation_promise(
    handle: u64,
    module_handle: u64,
    error_out: *mut u8,
) -> u64 {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return 0;
        }
        if module_handle == 0 {
            set_error(error_out, "module handle is null");
            return 0;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        runtime
            .module_evaluation_promises
            .get(&module_handle)
            .copied()
            .unwrap_or(0)
    }));

    match result {
        Ok(promise_handle) => promise_handle,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_module_get_export_json(
    handle: u64,
    module_handle: u64,
    export_name: *const u8,
    export_name_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if module_handle == 0 {
            set_error(error_out, "module handle is null");
            return empty_bytes();
        }
        if export_name.is_null() || export_name_len < 0 {
            set_error(error_out, "export name buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let export_name = unsafe { slice::from_raw_parts(export_name, export_name_len as usize) };
        let export_name = String::from_utf8_lossy(export_name);
        if export_name.is_empty() {
            set_error(error_out, "export name must not be empty");
            return empty_bytes();
        }

        let Runtime {
            context,
            isolate,
            module_handles,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let namespace = match load_module_namespace_object(try_catch, module_handles, module_handle)
        {
            Ok(namespace) => namespace,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let value = match load_module_export_value(try_catch, namespace, export_name.as_ref()) {
            Ok(value) => value,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let json = match stringify_json_value(try_catch, value) {
            Some(json) => json,
            None => {
                set_error(error_out, "failed to stringify module export to json");
                return empty_bytes();
            }
        };
        copy_string_to_moonbit(&json)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_module_export_names(
    handle: u64,
    module_handle: u64,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if module_handle == 0 {
            set_error(error_out, "module handle is null");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };

        let Runtime {
            context,
            isolate,
            module_handles,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let namespace = match load_module_namespace_object(try_catch, module_handles, module_handle)
        {
            Ok(namespace) => namespace,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let property_names = match namespace.get_own_property_names(try_catch, Default::default()) {
            Some(property_names) => property_names,
            None => {
                set_error(error_out, "failed to enumerate module export names");
                return empty_bytes();
            }
        };
        let mut names: Vec<String> = Vec::with_capacity(property_names.length() as usize);
        for i in 0..property_names.length() {
            let value = match property_names.get_index(try_catch, i) {
                Some(value) => value,
                None => {
                    set_error(error_out, &format!("missing export name at index {i}"));
                    return empty_bytes();
                }
            };
            let value = match value.to_string(try_catch) {
                Some(value) => value,
                None => {
                    set_error(
                        error_out,
                        &format!("failed to stringify export name at index {i}"),
                    );
                    return empty_bytes();
                }
            };
            names.push(value.to_rust_string_lossy(try_catch));
        }
        copy_string_to_moonbit(&names.join("\n"))
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_module_get_export_bytes(
    handle: u64,
    module_handle: u64,
    export_name: *const u8,
    export_name_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if module_handle == 0 {
            set_error(error_out, "module handle is null");
            return empty_bytes();
        }
        if export_name.is_null() || export_name_len < 0 {
            set_error(error_out, "export name buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let export_name = unsafe { slice::from_raw_parts(export_name, export_name_len as usize) };
        let export_name = String::from_utf8_lossy(export_name);
        if export_name.is_empty() {
            set_error(error_out, "export name must not be empty");
            return empty_bytes();
        }

        let Runtime {
            context,
            isolate,
            module_handles,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;

        let namespace = match load_module_namespace_object(try_catch, module_handles, module_handle)
        {
            Ok(namespace) => namespace,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let value = match load_module_export_value(try_catch, namespace, export_name.as_ref()) {
            Ok(value) => value,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let bytes = match copy_bytes_from_value(try_catch, value) {
            Ok(bytes) => bytes,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        copy_bytes_to_moonbit(&bytes)
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_module_call_export_json(
    handle: u64,
    module_handle: u64,
    export_name: *const u8,
    export_name_len: i32,
    args_json: *const u8,
    args_json_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if module_handle == 0 {
            set_error(error_out, "module handle is null");
            return empty_bytes();
        }
        if export_name.is_null() || export_name_len < 0 {
            set_error(error_out, "export name buffer is invalid");
            return empty_bytes();
        }
        if args_json.is_null() || args_json_len < 0 {
            set_error(error_out, "args json buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let export_name = unsafe { slice::from_raw_parts(export_name, export_name_len as usize) };
        let export_name = String::from_utf8_lossy(export_name);
        if export_name.is_empty() {
            set_error(error_out, "export name must not be empty");
            return empty_bytes();
        }
        let args_json = unsafe { slice::from_raw_parts(args_json, args_json_len as usize) };
        let args_json = String::from_utf8_lossy(args_json);

        let Runtime {
            context,
            isolate,
            module_handles,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let namespace = match load_module_namespace_object(try_catch, module_handles, module_handle)
        {
            Ok(namespace) => namespace,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let value = match load_module_export_value(try_catch, namespace, export_name.as_ref()) {
            Ok(value) => value,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let func = match v8::Local::<v8::Function>::try_from(value) {
            Ok(func) => func,
            Err(_) => {
                set_error(error_out, "module export is not a function");
                return empty_bytes();
            }
        };
        let args_value = match parse_json_value(try_catch, args_json.as_ref()) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };
        let args_array = match v8::Local::<v8::Array>::try_from(args_value) {
            Ok(args_array) => args_array,
            Err(_) => {
                set_error(
                    error_out,
                    "call_export_json expects args_json to decode to an array",
                );
                return empty_bytes();
            }
        };

        let mut argv: Vec<v8::Local<v8::Value>> = Vec::with_capacity(args_array.length() as usize);
        for i in 0..args_array.length() {
            let value = match args_array.get_index(try_catch, i) {
                Some(value) => value,
                None => {
                    set_error(error_out, &format!("missing argument at index {i}"));
                    return empty_bytes();
                }
            };
            argv.push(value);
        }

        let value = match func.call(try_catch, namespace.into(), argv.as_slice()) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let json = match stringify_json_value(try_catch, value) {
                Some(json) => json,
                None => {
                    set_error(error_out, "failed to stringify function result");
                    return empty_bytes();
                }
            };
            return copy_string_to_moonbit(&json);
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast function result promise");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let json = match stringify_json_value(try_catch, value) {
                        Some(json) => json,
                        None => {
                            set_error(error_out, "failed to stringify function result");
                            return empty_bytes();
                        }
                    };
                    return copy_string_to_moonbit(&json);
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Function call rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "function result promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_module_call_export_bytes(
    handle: u64,
    module_handle: u64,
    export_name: *const u8,
    export_name_len: i32,
    bytes: *const u8,
    bytes_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if module_handle == 0 {
            set_error(error_out, "module handle is null");
            return empty_bytes();
        }
        if export_name.is_null() || export_name_len < 0 {
            set_error(error_out, "export name buffer is invalid");
            return empty_bytes();
        }
        if bytes.is_null() || bytes_len < 0 {
            set_error(error_out, "bytes buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let export_name = unsafe { slice::from_raw_parts(export_name, export_name_len as usize) };
        let export_name = String::from_utf8_lossy(export_name);
        if export_name.is_empty() {
            set_error(error_out, "export name must not be empty");
            return empty_bytes();
        }
        let bytes = unsafe { slice::from_raw_parts(bytes, bytes_len as usize) };

        let Runtime {
            context,
            isolate,
            module_handles,
            ..
        } = runtime;
        entered_scope!(isolate, scope);
        let context = v8::Local::new(scope, &*context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let namespace = match load_module_namespace_object(try_catch, module_handles, module_handle)
        {
            Ok(namespace) => namespace,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let value = match load_module_export_value(try_catch, namespace, export_name.as_ref()) {
            Ok(value) => value,
            Err(message) => {
                set_error(error_out, &message);
                return empty_bytes();
            }
        };
        let func = match v8::Local::<v8::Function>::try_from(value) {
            Ok(func) => func,
            Err(_) => {
                set_error(error_out, "module export is not a function");
                return empty_bytes();
            }
        };
        let arg = match make_uint8_array_from_bytes(try_catch, bytes) {
            Some(arg) => arg,
            None => {
                set_error(error_out, "failed to allocate Uint8Array");
                return empty_bytes();
            }
        };

        let argv = [arg.into()];
        let value = match func.call(try_catch, namespace.into(), &argv) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let bytes = match copy_bytes_from_value(try_catch, value) {
                Ok(bytes) => bytes,
                Err(message) => {
                    set_error(error_out, &message);
                    return empty_bytes();
                }
            };
            return copy_bytes_to_moonbit(&bytes);
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast function result promise");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let bytes = match copy_bytes_from_value(try_catch, value) {
                        Ok(bytes) => bytes,
                        Err(message) => {
                            set_error(error_out, &message);
                            return empty_bytes();
                        }
                    };
                    return copy_bytes_to_moonbit(&bytes);
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Function call rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "function result promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_module_delete(handle: u64, module_handle: u64) {
    if handle == 0 || module_handle == 0 {
        return;
    }

    let _ = panic::catch_unwind(AssertUnwindSafe(|| {
        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        runtime.module_handles.remove(&module_handle);
        runtime.module_evaluation_promises.remove(&module_handle);
    }));
}
