///|
/// Locate nodes with innerText selector.
fn BidiProtocol::locate_nodes_inner_text(
  self : BidiProtocol,
  ctx_id : String,
  text_value : String,
  ignore_case : Bool,
  match_type : String,
  max_depth : Int,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let value_literal = "\"" + escape_js_string(text_value) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let ignore_case_literal = if ignore_case { "true" } else { "false" }
  let match_type_literal = "\"" + escape_js_string(match_type) + "\""
  let max_depth_literal = max_depth.to_string()
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {\n" +
    "  const __value = " +
    value_literal +
    ";\n" +
    "  const __ids = " +
    start_nodes_literal +
    ";\n" +
    "  const __ignoreCase = " +
    ignore_case_literal +
    ";\n" +
    "  const __matchType = " +
    match_type_literal +
    ";\n" +
    "  const __maxDepth = " +
    max_depth_literal +
    ";\n" +
    "  const __max = " +
    max_count_literal +
    ";\n" +
    locate_nodes_js_shared_roots_from_ids() +
    locate_nodes_js_to_array() +
    locate_nodes_js_collect_element_children() +
    (
      #|  const __normalize = (__text) => {
      #|    let __t = String(__text ?? '');
      #|    if (__ignoreCase) __t = __t.toLowerCase();
      #|    return __t.replace(/\s+/g, ' ').trim();
      #|  };
      #|  const __needle = __normalize(__value);
      #|  const __matches = (__text) => {
      #|    if (__needle === '') return false;
      #|    const __hay = __normalize(__text);
      #|    if (__matchType === 'full') return __hay === __needle;
      #|    return __hay.indexOf(__needle) !== -1;
      #|  };
      #|  const __candidates = [];
      #|  const __seen = new Set();
      #|  const __addCandidate = (__node) => {
      #|    if (!__node || __node.nodeType !== 1) return;
      #|    if (__seen.has(__node)) return;
      #|    __seen.add(__node);
      #|    __candidates.push(__node);
      #|  };
      #|  const __visit = (__node, __depth) => {
      #|    if (!__node) return;
      #|    if (__node.nodeType === 11) {
      #|      const __shadowChildren = __collectChildren(__node);
      #|      for (const __child of __shadowChildren) {
      #|        __visit(__child, __depth);
      #|      }
      #|      return;
      #|    }
      #|    if (__node.nodeType !== 1) return;
      #|    if (__maxDepth < 0 || __depth <= __maxDepth) {
      #|      const __text =
      #|        __node.innerText !== undefined &&
      #|        __node.innerText !== null &&
      #|        String(__node.innerText) !== ''
      #|          ? __node.innerText
      #|          : __node.textContent || '';
      #|      if (__matches(__text)) {
      #|        __addCandidate(__node);
      #|      }
      #|    }
      #|    if (__maxDepth >= 0 && __depth >= __maxDepth) return;
      #|    const __children = __collectChildren(__node);
      #|    for (const __child of __children) {
      #|      __visit(__child, __depth + 1);
      #|    }
      #|  };
      #|  const __isDescendant = (__ancestor, __node) => {
      #|    let __current = __node
      #|      ? __node._parent || __node.parentElement || __node.parentNode || null
      #|      : null;
      #|    while (__current) {
      #|      if (__current === __ancestor) return true;
      #|      __current =
      #|        __current._parent || __current.parentElement || __current.parentNode || null;
      #|    }
      #|    return false;
      #|  };
      #|  for (const __root of __roots) {
      #|    let __start = null;
      #|    if (__root && __root.nodeType === 9) {
      #|      __start = __root.documentElement || __root.body || null;
      #|    } else if (__root && (__root.nodeType === 1 || __root.nodeType === 11)) {
      #|      __start = __root;
      #|    }
      #|    if (__start) __visit(__start, 0);
      #|  }
      #|  const __result = [];
      #|  for (const __candidate of __candidates) {
      #|    let __hasDesc = false;
      #|    for (const __other of __candidates) {
      #|      if (__other === __candidate) continue;
      #|      if (__isDescendant(__candidate, __other)) {
      #|        __hasDesc = true;
      #|        break;
      #|      }
      #|    }
      #|    if (!__hasDesc) {
      #|      __result.push(__candidate);
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
