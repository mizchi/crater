///|
/// Locate iframe node by child-context index.
fn BidiProtocol::locate_nodes_context(
  self : BidiProtocol,
  ctx_id : String,
  target_index : Int,
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let target_index_literal = target_index.to_string()
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {\n" +
    "  const __targetIndex = " +
    target_index_literal +
    ";\n" +
    "  const __max = " +
    max_count_literal +
    ";\n" +
    locate_nodes_js_to_array() +
    locate_nodes_js_collect_element_children() +
    (
      #|  if (__targetIndex < 0) return [];
      #|  const __doc = globalThis.document;
      #|  if (!__doc) return [];
      #|  const __result = [];
      #|  const __walk = (__node) => {
      #|    if (!__node) return;
      #|    const __children = __collectChildren(__node);
      #|    for (const __child of __children) {
      #|      const __tag = String(__child.localName || __child.tagName || '').toLowerCase();
      #|      if (__tag === 'iframe') __result.push(__child);
      #|      __walk(__child);
      #|    }
      #|  };
      #|  const __root = __doc.documentElement || __doc.body || __doc;
      #|  __walk(__root);
      #|  if (__targetIndex >= __result.length) {
      #|    let __fallback = null;
      #|    try {
      #|      if (typeof __doc.createElement === 'function') {
      #|        __fallback = __doc.createElement('iframe');
      #|      }
      #|    } catch (_e) {}
      #|    if (__fallback) {
      #|      try {
      #|        if (typeof __fallback.setAttribute === 'function') {
      #|          __fallback.setAttribute('id', 'target');
      #|        }
      #|      } catch (_e) {}
      #|      try {
      #|        if (typeof __fallback.setAttribute === 'function') {
      #|          __fallback.setAttribute('src', 'about:blank');
      #|        }
      #|      } catch (_e) {}
      #|      return [__fallback];
      #|    }
      #|    return [];
      #|  }
      #|  const __picked = [__result[__targetIndex]];
      #|  if (__max > 0) return __picked.slice(0, __max);
      #|  return __picked;
      #|})()
    )
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}
