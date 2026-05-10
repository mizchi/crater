///|
/// Drain queued script channel callback payloads as serialized BiDi values.
extern "js" fn js_take_channel_messages() -> String =
  #| () => {
  #|   const queue = Array.isArray(globalThis.__bidiChannelMessages)
  #|     ? globalThis.__bidiChannelMessages
  #|     : [];
  #|   globalThis.__bidiChannelMessages = [];
  #|   if (typeof globalThis.__bidiNextChannelHandleId !== "number") {
  #|     globalThis.__bidiNextChannelHandleId = 1;
  #|   }
  #|
  #|   const serialize = (value, maxObjectDepth, depth = 0) => {
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
  #|
  #|     const limitReached =
  #|       typeof maxObjectDepth === "number" &&
  #|       maxObjectDepth >= 0 &&
  #|       depth >= maxObjectDepth;
  #|
  #|     if (Array.isArray(value)) {
  #|       if (limitReached) return { type: "array" };
  #|       return { type: "array", value: value.map((v) => serialize(v, maxObjectDepth, depth + 1)) };
  #|     }
  #|     if (value instanceof Map) {
  #|       if (limitReached) return { type: "map" };
  #|       const entries = [];
  #|       for (const [k, v] of value) {
  #|         entries.push([typeof k === "string" ? k : serialize(k, maxObjectDepth, depth + 1), serialize(v, maxObjectDepth, depth + 1)]);
  #|       }
  #|       return { type: "map", value: entries };
  #|     }
  #|     if (value instanceof Set) {
  #|       if (limitReached) return { type: "set" };
  #|       return { type: "set", value: Array.from(value).map((v) => serialize(v, maxObjectDepth, depth + 1)) };
  #|     }
  #|     if (value instanceof RegExp) return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     if (value instanceof Date) return { type: "date", value: value.toISOString() };
  #|
  #|     if (value && type === "object" && typeof value.nodeType === "number") {
  #|       return { type: "node" };
  #|     }
  #|     if (value && value.constructor === Object) {
  #|       if (limitReached) return { type: "object" };
  #|       const entries = Object.entries(value).map(([k, v]) => [k, serialize(v, maxObjectDepth, depth + 1)]);
  #|       return { type: "object", value: entries };
  #|     }
  #|     return { type: "object" };
  #|   };
  #|
  #|   const events = queue.map((entry) => {
  #|     const channel = entry && typeof entry.channel === "string" ? entry.channel : "";
  #|     const ownership = entry && entry.ownership === "root" ? "root" : "none";
  #|     const maxObjectDepth =
  #|       entry && typeof entry.maxObjectDepth === "number"
  #|         ? entry.maxObjectDepth
  #|         : -1;
  #|     let data = serialize(entry ? entry.data : undefined, maxObjectDepth, 0);
  #|     if (ownership === "root" && data && typeof data === "object") {
  #|       data = {
  #|         ...data,
  #|         handle: `channel-handle-${globalThis.__bidiNextChannelHandleId++}`,
  #|       };
  #|     }
  #|     return { channel, data };
  #|   }).filter((entry) => !!entry.channel);
  #|
  #|   return JSON.stringify(events);
  #| }

///|
/// Drain queued script channel callback payloads as JSON.
pub fn take_channel_messages_json() -> String {
  js_take_channel_messages()
}
