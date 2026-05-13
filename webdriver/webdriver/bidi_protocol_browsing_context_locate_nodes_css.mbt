///|
/// Locate nodes with CSS selector and serialize as BiDi node values.
fn BidiProtocol::locate_nodes_css(
  self : BidiProtocol,
  ctx_id : String,
  selector : String,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  if start_node_shared_ids.length() == 0 {
    match self.manager.get_session(ctx_id) {
      Some(session) => {
        let doc = session.get_tree().get_document()
        match session.get_tree().query_selector_all(doc, selector) {
          Ok(nodes) => if nodes.length() == 0 { return Json::array([]) }
          Err(_) => ()
        }
      }
      None => ()
    }
  }

  let selector_literal = "\"" + escape_js_string(selector) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {\n" +
    "  const __selector = String(" +
    selector_literal +
    " || '').trim();\n" +
    "  const __ids = " +
    start_nodes_literal +
    ";\n" +
    "  const __max = " +
    max_count_literal +
    ";\n" +
    locate_nodes_js_shared_roots_from_ids() +
    locate_nodes_js_to_array() +
    locate_nodes_js_collect_element_children() +
    (
      #|  const __attr = (__node, __name) => {
      #|    let __v = null;
      #|    try {
      #|      if (__node && typeof __node.getAttribute === 'function') {
      #|        __v = __node.getAttribute(__name);
      #|      }
      #|    } catch (_e) {}
      #|    if ((__v === null || __v === undefined) && __node && __node._attrs) {
      #|      __v = __node._attrs[__name];
      #|    }
      #|    if (__v === null || __v === undefined) return null;
      #|    return String(__v);
      #|  };
      #|  const __normalizeSelector = (__sel) =>
      #|    String(__sel || '').replace(
      #|      /\[\s*([a-zA-Z0-9_\-:]+)\s*=\s*'([^']*)'\s*\]/g,
      #|      '[$1="$2"]',
      #|    );
      #|  const __selectorParts = __normalizeSelector(__selector)
      #|    .split(/\s+/)
      #|    .filter(Boolean);
      #|  const __matchesSimple = (__node, __simpleRaw) => {
      #|    if (!__node || __node.nodeType !== 1) return false;
      #|    let __simple = String(__simpleRaw || '').trim();
      #|    if (__simple === '') return false;
      #|    if (__simple === '*') return true;
      #|    let __attrName = '';
      #|    let __attrValue = null;
      #|    let __attrContains = false;
      #|    const __attrMatch = __simple.match(
      #|      /^(.*)\[([a-zA-Z0-9_\-:]+)(\*)?="([^"]*)"\]$/,
      #|    );
      #|    if (__attrMatch) {
      #|      __simple = String(__attrMatch[1] || '').trim();
      #|      __attrName = String(__attrMatch[2] || '');
      #|      __attrContains = !!__attrMatch[3];
      #|      __attrValue = String(__attrMatch[4] || '');
      #|    }
      #|    let __tag = __simple;
      #|    let __id = '';
      #|    let __classes = [];
      #|    const __hashIdx = __tag.indexOf('#');
      #|    if (__hashIdx >= 0) {
      #|      __id = __tag.slice(__hashIdx + 1);
      #|      __tag = __tag.slice(0, __hashIdx);
      #|    }
      #|    if (__tag.indexOf('.') >= 0) {
      #|      const __parts = __tag.split('.');
      #|      __tag = __parts.shift() || '';
      #|      __classes = __parts.filter(Boolean);
      #|    } else if (__tag === '' && __simple.startsWith('.')) {
      #|      __classes = __simple.slice(1).split('.').filter(Boolean);
      #|    }
      #|    if (
      #|      __tag !== '' &&
      #|      String(__node.localName || __node.tagName || '').toLowerCase() !==
      #|        __tag.toLowerCase()
      #|    ) {
      #|      return false;
      #|    }
      #|    if (__id !== '') {
      #|      const __nodeId = __attr(__node, 'id');
      #|      if (__nodeId !== __id) return false;
      #|    }
      #|    for (const __cls of __classes) {
      #|      const __nodeClass = String(__attr(__node, 'class') || '');
      #|      const __tokens = __nodeClass.split(/\s+/).filter(Boolean);
      #|      if (__tokens.indexOf(__cls) === -1) return false;
      #|    }
      #|    if (__attrName !== '') {
      #|      const __v = __attr(__node, __attrName);
      #|      if (__attrValue === null) {
      #|        if (__v === null) return false;
      #|      } else if (__attrContains) {
      #|        if (__v === null || __v.indexOf(__attrValue) === -1) return false;
      #|      } else if (__v !== __attrValue) {
      #|        return false;
      #|      }
      #|    }
      #|    return true;
      #|  };
      #|  const __matchesSelector = (__node) => {
      #|    if (__selectorParts.length === 0) return false;
      #|    let __current = __node;
      #|    let __idx = __selectorParts.length - 1;
      #|    if (!__matchesSimple(__current, __selectorParts[__idx])) return false;
      #|    __idx -= 1;
      #|    while (__idx >= 0) {
      #|      let __parent = __current
      #|        ? __current._parent ||
      #|          __current.parentElement ||
      #|          __current.parentNode ||
      #|          null
      #|        : null;
      #|      let __found = false;
      #|      while (__parent) {
      #|        if (
      #|          __parent.nodeType === 1 &&
      #|          __matchesSimple(__parent, __selectorParts[__idx])
      #|        ) {
      #|          __found = true;
      #|          __current = __parent;
      #|          break;
      #|        }
      #|        __parent =
      #|          __parent._parent || __parent.parentElement || __parent.parentNode || null;
      #|      }
      #|      if (!__found) return false;
      #|      __idx -= 1;
      #|    }
      #|    return true;
      #|  };
    ) +
    locate_nodes_js_unique_result_push() +
    (
      #|  const __walk = (__node) => {
      #|    if (!__node) return false;
      #|    const __children = __collectChildren(__node);
      #|    for (const __child of __children) {
      #|      if (__matchesSelector(__child)) {
      #|        __push(__child);
      #|        if (__max > 0 && __result.length >= __max) return true;
      #|      }
      #|      if (__walk(__child)) return true;
      #|    }
      #|    return false;
      #|  };
      #|  for (const __root of __roots) {
      #|    if (!__root) continue;
      #|    let __start = null;
      #|    if (__root.nodeType === 9) {
      #|      __start = __root.documentElement || __root.body || null;
      #|    } else if (__root.nodeType === 1 || __root.nodeType === 11) {
      #|      __start = __root;
      #|    }
      #|    if (!__start) continue;
      #|    if (__matchesSelector(__start)) {
      #|      __push(__start);
      #|      if (__max > 0 && __result.length >= __max) {
      #|        return __result.slice(0, __max);
      #|      }
      #|    }
      #|    if (__walk(__start)) return __result.slice(0, __max);
      #|  }
      #|  return __max > 0 ? __result.slice(0, __max) : __result;
      #|})()
    )
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}
