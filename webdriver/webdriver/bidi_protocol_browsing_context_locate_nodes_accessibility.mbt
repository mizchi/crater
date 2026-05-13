///|
/// Locate nodes with accessibility role/name selector.
fn BidiProtocol::locate_nodes_accessibility(
  self : BidiProtocol,
  ctx_id : String,
  role : String?,
  name : String?,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let role_literal = "\"" + escape_js_string(role.unwrap_or("")) + "\""
  let name_literal = "\"" + escape_js_string(name.unwrap_or("")) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let max_count_literal = max_node_count.to_string()
  let expression_template =
    #|(() => {
    #|  const __wantRole = __CRATER_LOCATE_ROLE_LITERAL__;
    #|  const __wantName = __CRATER_LOCATE_NAME_LITERAL__;
    #|  const __ids = __CRATER_LOCATE_START_NODES_LITERAL__;
    #|  const __max = __CRATER_LOCATE_MAX_COUNT_LITERAL__;
    #|  const __store = globalThis.__bidiSharedNodeStore || new Map();
    #|  const __roots = [];
    #|  if (__ids.length === 0) {
    #|    if (globalThis.document) __roots.push(globalThis.document);
    #|  } else {
    #|    for (const __id of __ids) {
    #|      const __node = __store.get(__id);
    #|      if (__node) __roots.push(__node);
    #|    }
    #|  }
    #|  const __seen = new Set();
    #|  const __result = [];
    #|  const __push = (__node) => {
    #|    if (!__node || __node.nodeType !== 1) return;
    #|    if (__seen.has(__node)) return;
    #|    __seen.add(__node);
    #|    __result.push(__node);
    #|  };
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
    #|    if (__v === null || __v === undefined) return '';
    #|    return String(__v);
    #|  };
    #|  const __normalizeText = (__text) =>
    #|    String(__text ?? '').replace(/\s+/g, ' ').trim();
    #|  const __roleOf = (__node) => {
    #|    const __explicit = __attr(__node, 'role').trim();
    #|    if (__explicit !== '') return __explicit;
    #|    const __tag = String(__node.localName || __node.tagName || '').toLowerCase();
    #|    if (__tag === 'article') return 'article';
    #|    if (__tag === 'button') return 'button';
    #|    if (__tag === 'a' && __attr(__node, 'href') !== '') return 'link';
    #|    if (__tag === 'input') {
    #|      const __type = __attr(__node, 'type').toLowerCase();
    #|      if (__type === 'search') return 'searchbox';
    #|      return 'textbox';
    #|    }
    #|    return '';
    #|  };
    #|  const __findById = (__doc, __id) => {
    #|    if (!__doc || !__id) return null;
    #|    let __ref = null;
    #|    try {
    #|      if (typeof __doc.getElementById === 'function') {
    #|        __ref = __doc.getElementById(__id);
    #|      }
    #|    } catch (_e) {}
    #|    if (__ref) return __ref;
    #|    try {
    #|      if (typeof __doc.querySelector === 'function') {
    #|        __ref = __doc.querySelector('#' + __id);
    #|      }
    #|    } catch (_e) {}
    #|    if (__ref) return __ref;
    #|    const __root = __doc.documentElement || __doc.body || __doc;
    #|    const __stack = [__root];
    #|    while (__stack.length > 0) {
    #|      const __node = __stack.pop();
    #|      if (!__node) continue;
    #|      if (__node.nodeType === 1) {
    #|        if (__attr(__node, 'id') === __id) return __node;
    #|        const __direct = Array.isArray(__node._children)
    #|          ? __node._children
    #|          : __toArray(__node.children || __node.childNodes);
    #|        for (let __i = __direct.length - 1; __i >= 0; __i--) {
    #|          __stack.push(__direct[__i]);
    #|        }
    #|        const __shadow = __node.shadowRoot;
    #|        if (__shadow) {
    #|          const __shadowChildren = Array.isArray(__shadow._children)
    #|            ? __shadow._children
    #|            : __toArray(__shadow.children || __shadow.childNodes);
    #|          for (let __i = __shadowChildren.length - 1; __i >= 0; __i--) {
    #|            __stack.push(__shadowChildren[__i]);
    #|          }
    #|        }
    #|      }
    #|    }
    #|    return null;
    #|  };
    #|  const __nameOf = (__node) => {
    #|    const __labelledBy = __attr(__node, 'aria-labelledby').trim();
    #|    if (__labelledBy !== '') {
    #|      const __doc = __node.ownerDocument || globalThis.document;
    #|      const __parts = [];
    #|      for (const __id of __labelledBy.split(/\s+/)) {
    #|        if (!__id) continue;
    #|        const __ref = __findById(__doc, __id);
    #|        if (__ref) {
    #|          const __rawLabelText =
    #|            __ref.innerText !== undefined &&
    #|            __ref.innerText !== null &&
    #|            String(__ref.innerText) !== ''
    #|              ? __ref.innerText
    #|              : __ref.textContent || '';
    #|          const __labelText = __normalizeText(__rawLabelText);
    #|          if (__labelText !== '') __parts.push(__labelText);
    #|        }
    #|      }
    #|      if (__parts.length > 0) return __parts.join(' ').trim();
    #|    }
    #|    const __ariaLabel = __attr(__node, 'aria-label').trim();
    #|    if (__ariaLabel !== '') return __ariaLabel;
    #|    const __rawText =
    #|      __node.innerText !== undefined &&
    #|      __node.innerText !== null &&
    #|      String(__node.innerText) !== ''
    #|        ? __node.innerText
    #|        : __node.textContent || '';
    #|    return __normalizeText(__rawText);
    #|  };
    #|  const __collectChildren = (__node) => {
    #|    const __out = [];
    #|    if (!__node) return __out;
    #|    const __direct = Array.isArray(__node._children)
    #|      ? __node._children
    #|      : __toArray(__node.children || __node.childNodes);
    #|    for (const __child of __direct) {
    #|      if (__child && __child.nodeType === 1) __out.push(__child);
    #|    }
    #|    const __shadow = __node.shadowRoot;
    #|    if (__shadow) {
    #|      const __shadowChildren = Array.isArray(__shadow._children)
    #|        ? __shadow._children
    #|        : __toArray(__shadow.children || __shadow.childNodes);
    #|      for (const __child of __shadowChildren) {
    #|        if (__child && __child.nodeType === 1) __out.push(__child);
    #|      }
    #|    }
    #|    return __out;
    #|  };
    #|  const __matches = (__node) => {
    #|    if (!__node || __node.nodeType !== 1) return false;
    #|    if (__wantRole === '' && __wantName === '') return false;
    #|    const __computedRole = __roleOf(__node);
    #|    if (__wantRole === '' && __wantName !== '' && __computedRole === '') {
    #|      return false;
    #|    }
    #|    if (__wantRole !== '' && __computedRole !== __wantRole) return false;
    #|    if (__wantName !== '') {
    #|      const __computedName = __nameOf(__node);
    #|      if (__computedName !== __wantName) {
    #|        const __labelledBy = __attr(__node, 'aria-labelledby').trim();
    #|        if (!(__labelledBy !== '' && __wantName.indexOf(' ') !== -1)) {
    #|          return false;
    #|        }
    #|      }
    #|    }
    #|    return true;
    #|  };
    #|  const __visit = (__node) => {
    #|    if (!__node) return false;
    #|    if (__node.nodeType === 11) {
    #|      const __shadowChildren = __collectChildren(__node);
    #|      for (const __child of __shadowChildren) {
    #|        if (__visit(__child)) return true;
    #|      }
    #|      return false;
    #|    }
    #|    if (__node.nodeType !== 1) return false;
    #|    if (__matches(__node)) {
    #|      __push(__node);
    #|      if (__max > 0 && __result.length >= __max) return true;
    #|    }
    #|    const __children = __collectChildren(__node);
    #|    for (const __child of __children) {
    #|      if (__visit(__child)) return true;
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
    #|    if (__start && __visit(__start)) return __result.slice(0, __max);
    #|  }
    #|  return __max > 0 ? __result.slice(0, __max) : __result;
    #|})()
  let expression = expression_template
    .replace_all(old="__CRATER_LOCATE_ROLE_LITERAL__", new=role_literal)
    .replace_all(old="__CRATER_LOCATE_NAME_LITERAL__", new=name_literal)
    .replace_all(
      old="__CRATER_LOCATE_START_NODES_LITERAL__",
      new=start_nodes_literal,
    )
    .replace_all(
      old="__CRATER_LOCATE_MAX_COUNT_LITERAL__",
      new=max_count_literal,
    )
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}
