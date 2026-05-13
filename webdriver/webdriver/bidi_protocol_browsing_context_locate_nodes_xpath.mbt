///|
/// Locate nodes with XPath selector.
fn BidiProtocol::locate_nodes_xpath(
  self : BidiProtocol,
  ctx_id : String,
  selector : String,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let selector_literal = "\"" + escape_js_string(selector) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {\n" +
    "  const __xpath = " +
    selector_literal +
    ";\n" +
    "  const __ids = " +
    start_nodes_literal +
    ";\n" +
    "  const __max = " +
    max_count_literal +
    ";\n" +
    locate_nodes_js_shared_roots_from_ids() +
    locate_nodes_js_unique_result_push() +
    (
      #|  for (const __root of __roots) {
      #|    if (!__root) continue;
      #|    const __doc =
      #|      __root.nodeType === 9
      #|        ? __root
      #|        : __root.ownerDocument || globalThis.document;
      #|    if (
      #|      !__doc ||
      #|      typeof __doc.evaluate !== 'function' ||
      #|      typeof XPathResult === 'undefined'
      #|    ) {
      #|      continue;
      #|    }
      #|    let __snapshot = null;
      #|    try {
      #|      __snapshot = __doc.evaluate(
      #|        __xpath,
      #|        __root,
      #|        null,
      #|        XPathResult.ORDERED_NODE_SNAPSHOT_TYPE,
      #|        null,
      #|      );
      #|    } catch (_e) {
      #|      return [];
      #|    }
      #|    const __len = Number(
      #|      __snapshot && __snapshot.snapshotLength ? __snapshot.snapshotLength : 0,
      #|    );
      #|    for (let __i = 0; __i < __len; __i++) {
      #|      const __node = __snapshot.snapshotItem(__i);
      #|      __push(__node);
      #|      if (__max > 0 && __result.length >= __max) {
      #|        return __result.slice(0, __max);
      #|      }
      #|    }
      #|  }
      #|  return __max > 0 ? __result.slice(0, __max) : __result;
      #|})()
    )
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}
