///|
/// FFI: Evaluate expression and return a fully serialized BiDi response (fast path)
extern "js" fn js_evaluate_expression_fast(
  id : Int,
  expression : String,
  user_activation : Bool,
  realm_id : String,
  ctx_id : String,
) -> String =
  #| (id, expression, userActivation, realmId, ctxId) => {
  #|   const isActive = !!userActivation;
  #|   globalThis.__bidiUserActivation = isActive;
  #|   globalThis.__bidiCurrentContext = ctxId;
  #|   if (!globalThis.__bidiProxyInstances) globalThis.__bidiProxyInstances = new WeakSet();
  #|   if (!globalThis.__bidiNativeProxy && typeof globalThis.Proxy === "function") {
  #|     const NativeProxy = globalThis.Proxy;
  #|     const tracked = globalThis.__bidiProxyInstances;
  #|     function TrackedProxy(target, handler) {
  #|       const proxied = new NativeProxy(target, handler);
  #|       tracked.add(proxied);
  #|       return proxied;
  #|     }
  #|     TrackedProxy.revocable = function(target, handler) {
  #|       const revocable = NativeProxy.revocable(target, handler);
  #|       tracked.add(revocable.proxy);
  #|       return revocable;
  #|     };
  #|     globalThis.__bidiNativeProxy = NativeProxy;
  #|     globalThis.Proxy = TrackedProxy;
  #|   }
  #|   if (!globalThis.navigator) globalThis.navigator = {};
  #|   globalThis.navigator.userActivation = {
  #|     isActive,
  #|     hasBeenActive: isActive
  #|   };
  #|   if (globalThis.document) {
  #|     globalThis.document.execCommand = function(command) {
  #|       const cmd = String(command || '').toLowerCase();
  #|       if (cmd === 'selectall') return true;
  #|       if (cmd === 'copy') return !!globalThis.__bidiUserActivation;
  #|       return false;
  #|     };
  #|   }
  #|   if (globalThis.document && typeof globalThis.__bidiEnsureDocumentRange === "function") {
  #|     globalThis.__bidiEnsureDocumentRange(globalThis.document);
  #|     if (globalThis.window && typeof globalThis.window === "object") {
  #|       globalThis.window.document = globalThis.document;
  #|     }
  #|   }
  #|
  #|   function getNodeSharedId(node) {
  #|     const sharedIds = globalThis.__bidiNodeSharedIds || (globalThis.__bidiNodeSharedIds = new WeakMap());
  #|     const nodeStore = globalThis.__bidiSharedNodeStore || (globalThis.__bidiSharedNodeStore = new Map());
  #|     if (typeof globalThis.__bidiNextNodeSharedId !== "number") {
  #|       globalThis.__bidiNextNodeSharedId = 1;
  #|     }
  #|     let sharedId = sharedIds.get(node);
  #|     if (!sharedId) {
  #|       sharedId = `node-${globalThis.__bidiNextNodeSharedId++}`;
  #|       sharedIds.set(node, sharedId);
  #|     }
  #|     nodeStore.set(sharedId, node);
  #|     return sharedId;
  #|   }
  #|
  #|   function getNodeAttributes(node) {
  #|     const attrs = {};
  #|     if (!node || typeof node !== "object") return attrs;
  #|     if (node._attrs && typeof node._attrs === "object") {
  #|       for (const [k, v] of Object.entries(node._attrs)) attrs[k] = String(v);
  #|       return attrs;
  #|     }
  #|     if (node.attributes && typeof node.attributes.length === "number") {
  #|       for (const attr of Array.from(node.attributes)) {
  #|         if (attr && typeof attr.name === "string") attrs[attr.name] = String(attr.value ?? "");
  #|       }
  #|     }
  #|     return attrs;
  #|   }
  #|
  #|   function toBidiNodeValue(node) {
  #|     const childNodes = Array.isArray(node._children)
  #|       ? node._children
  #|       : (Array.isArray(node.childNodes) ? node.childNodes : []);
  #|     const nodeType = typeof node.nodeType === "number" ? node.nodeType : 1;
  #|     const localName = node.localName || node._tagName || (node.tagName ? String(node.tagName).toLowerCase() : "");
  #|     const namespaceURI = node.namespaceURI || "http://www.w3.org/1999/xhtml";
  #|     const shadowRoot = node.shadowRoot
  #|       ? { type: "node", sharedId: getNodeSharedId(node.shadowRoot) }
  #|       : null;
  #|     return {
  #|       type: "node",
  #|       sharedId: getNodeSharedId(node),
  #|       value: {
  #|         nodeType,
  #|         localName: String(localName),
  #|         namespaceURI: String(namespaceURI),
  #|         childNodeCount: childNodes.length,
  #|         children: [],
  #|         attributes: getNodeAttributes(node),
  #|         shadowRoot
  #|       }
  #|     };
  #|   }
  #|
  #|   const internalIds = new WeakMap();
  #|   const referenceCounts = new WeakMap();
  #|   let nextInternalId = 1;
  #|   const trackReference = (obj) => {
  #|     const prev = referenceCounts.get(obj) || 0;
  #|     referenceCounts.set(obj, prev + 1);
  #|   };
  #|   const collectReferences = (value, seen = new WeakSet()) => {
  #|     if (!value || typeof value !== "object") return;
  #|     if (typeof value.nodeType === "number") {
  #|       trackReference(value);
  #|       return;
  #|     }
  #|     if (
  #|       value instanceof Date ||
  #|       value instanceof RegExp ||
  #|       value instanceof Error ||
  #|       value instanceof Promise ||
  #|       value instanceof WeakMap ||
  #|       value instanceof WeakSet ||
  #|       value instanceof ArrayBuffer ||
  #|       ArrayBuffer.isView(value)
  #|     ) {
  #|       return;
  #|     }
  #|     if (globalThis.__bidiProxyInstances && globalThis.__bidiProxyInstances.has(value)) return;
  #|     const isContainer =
  #|       Array.isArray(value) ||
  #|       value instanceof Map ||
  #|       value instanceof Set ||
  #|       value.constructor === Object;
  #|     if (!isContainer) return;
  #|     trackReference(value);
  #|     if (seen.has(value)) return;
  #|     seen.add(value);
  #|     if (Array.isArray(value)) {
  #|       for (const item of value) collectReferences(item, seen);
  #|       return;
  #|     }
  #|     if (value instanceof Map) {
  #|       for (const [k, v] of value) {
  #|         if (typeof k !== "string") collectReferences(k, seen);
  #|         collectReferences(v, seen);
  #|       }
  #|       return;
  #|     }
  #|     if (value instanceof Set) {
  #|       for (const item of value) collectReferences(item, seen);
  #|       return;
  #|     }
  #|     for (const entryValue of Object.values(value)) {
  #|       collectReferences(entryValue, seen);
  #|     }
  #|   };
  #|   const withInternalId = (originalValue, serialized) => {
  #|     if (!serialized || typeof serialized !== "object") return serialized;
  #|     if (!originalValue || (typeof originalValue !== "object" && typeof originalValue !== "function")) {
  #|       return serialized;
  #|     }
  #|     const serializedType = serialized.type;
  #|     if (serializedType !== "array" && serializedType !== "map" && serializedType !== "set" && serializedType !== "object" && serializedType !== "node") {
  #|       return serialized;
  #|     }
  #|     const count = referenceCounts.get(originalValue) || 0;
  #|     if (count <= 1) return serialized;
  #|     let internalId = internalIds.get(originalValue);
  #|     if (!internalId) {
  #|       internalId = `internal-${nextInternalId++}`;
  #|       internalIds.set(originalValue, internalId);
  #|     }
  #|     if (serialized.internalId) return serialized;
  #|     return { ...serialized, internalId };
  #|   };
  #|
  #|   function toBidiValue(value) {
  #|     if (value === undefined) return { type: "undefined" };
  #|     if (value === null) return { type: "null" };
  #|     const type = typeof value;
  #|     if (type === "boolean") return { type: "boolean", value };
  #|     if (type === "number") {
  #|       if (Number.isNaN(value)) return { type: "number", value: "NaN" };
  #|       if (!Number.isFinite(value)) return { type: "number", value: value > 0 ? "Infinity" : "-Infinity" };
  #|       if (Object.is(value, -0)) return { type: "number", value: "-0" };
  #|       return { type: "number", value };
  #|     }
  #|     if (type === "string") return { type: "string", value };
  #|     if (type === "bigint") return { type: "bigint", value: String(value) };
  #|     if (type === "symbol") return { type: "symbol" };
  #|     if (type === "function") return { type: "function" };
  #|     const objectTag = type === "object" ? Object.prototype.toString.call(value) : "";
  #|     if (objectTag === "[object Generator]" || objectTag === "[object AsyncGenerator]") {
  #|       return { type: "generator" };
  #|     }
  #|     if (globalThis.__bidiProxyInstances && globalThis.__bidiProxyInstances.has(value)) {
  #|       return { type: "proxy" };
  #|     }
  #|     if (value && type === "object" && typeof value.__bidiContextId === "string") {
  #|       return { type: "window", value: { context: String(value.__bidiContextId) } };
  #|     }
  #|     if (value === globalThis || value === globalThis.window) {
  #|       return {
  #|         type: "window",
  #|         value: { context: String(globalThis.__bidiCurrentContext || "default-context") }
  #|       };
  #|     }
  #|     if (value && type === "object" && typeof value.nodeType === "number") {
  #|       return withInternalId(value, toBidiNodeValue(value));
  #|     }
  #|     if (value instanceof RegExp) return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     if (value instanceof Date) return { type: "date", value: value.toISOString() };
  #|     if (value instanceof Error) return { type: "error" };
  #|     if (value instanceof Promise) return { type: "promise" };
  #|     if (value instanceof Map) {
  #|       const entries = [];
  #|       for (const [k, v] of value) {
  #|         entries.push([typeof k === "string" ? k : toBidiValue(k), toBidiValue(v)]);
  #|       }
  #|       return withInternalId(value, { type: "map", value: entries });
  #|     }
  #|     if (value instanceof Set) {
  #|       return withInternalId(
  #|         value,
  #|         { type: "set", value: Array.from(value).map(toBidiValue) },
  #|       );
  #|     }
  #|     if (value instanceof WeakMap) return { type: "weakmap" };
  #|     if (value instanceof WeakSet) return { type: "weakset" };
  #|     if (ArrayBuffer.isView(value)) return { type: "typedarray" };
  #|     if (value instanceof ArrayBuffer) return { type: "arraybuffer" };
  #|     if (Array.isArray(value)) {
  #|       return withInternalId(
  #|         value,
  #|         { type: "array", value: value.map(toBidiValue) },
  #|       );
  #|     }
  #|     if (value && value.constructor === Object) {
  #|       const entries = Object.entries(value).map(([k, v]) => [k, toBidiValue(v)]);
  #|       return withInternalId(value, { type: "object", value: entries });
  #|     }
  #|     return { type: "object" };
  #|   }
  #|
  #|   const realm = realmId;
  #|   const wrapResult = (valueJson) =>
  #|     `{"id":${id},"type":"success","result":{"realm":${JSON.stringify(realm)},"result":${valueJson}}}`;
  #|   try {
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal(globalThis.window);
  #|     }
  #|     const result = (0, eval)(expression);
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal(globalThis.window);
  #|     }
  #|     if (result instanceof Promise) {
  #|       // Avoid process-level unhandled rejection when awaitPromise=false.
  #|       result.catch(() => {});
  #|     }
  #|     collectReferences(result);
  #|     if (result === undefined) return wrapResult('{"type":"undefined"}');
  #|     if (result === null) return wrapResult('{"type":"null"}');
  #|     const type = typeof result;
  #|     if (type === "boolean") {
  #|       return wrapResult(`{"type":"boolean","value":${result}}`);
  #|     }
  #|     if (type === "number") {
  #|       if (Number.isNaN(result)) {
  #|         return wrapResult('{"type":"number","value":"NaN"}');
  #|       }
  #|       if (!Number.isFinite(result)) {
  #|         return wrapResult(
  #|           `{"type":"number","value":"${result > 0 ? "Infinity" : "-Infinity"}"}`
  #|         );
  #|       }
  #|       if (Object.is(result, -0)) {
  #|         return wrapResult('{"type":"number","value":"-0"}');
  #|       }
  #|       return wrapResult(`{"type":"number","value":${result}}`);
  #|     }
  #|     if (type === "string") {
  #|       return wrapResult(
  #|         `{"type":"string","value":${JSON.stringify(result)}}`
  #|       );
  #|     }
  #|     if (type === "bigint") {
  #|       return wrapResult(
  #|         `{"type":"bigint","value":${JSON.stringify(String(result))}}`
  #|       );
  #|     }
  #|     if (type === "symbol") return wrapResult('{"type":"symbol"}');
  #|     if (type === "function") return wrapResult('{"type":"function"}');
  #|     const payload = { realm, result: toBidiValue(result) };
  #|     return JSON.stringify({ id, type: "success", result: payload });
  #|   } catch (e) {
  #|     const payload = {
  #|       realm,
  #|       exceptionDetails: {
  #|         columnNumber: 0,
  #|         lineNumber: 0,
  #|         text: String(e),
  #|         exception: toBidiValue(e),
  #|         stackTrace: { callFrames: [] }
  #|       }
  #|     };
  #|     return JSON.stringify({ id, type: "success", result: payload });
  #|   }
  #| }
