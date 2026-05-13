///|
/// Handle browsingContext.locateNodes with WPT-oriented parameter validation.
fn BidiProtocol::handle_locate_nodes(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  let params = match request.params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request.id,
        "invalid argument",
        "params must be an object",
      )
      return
    }
  }

  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      return
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing context")
      return
    }
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
    return
  }

  let locator = match params.get("locator") {
    Some(Object(map)) => map
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "locator must be an object",
      )
      return
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing locator")
      return
    }
  }
  let locator_type = match locator.get("type") {
    Some(String(kind)) => kind
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "locator.type must be a string",
      )
      return
    }
    None => {
      self.send_error(
        request.id,
        "invalid argument",
        "locator.type is required",
      )
      return
    }
  }
  if !is_valid_locate_nodes_locator_type(locator_type) {
    self.send_error(request.id, "invalid argument", "locator.type is invalid")
    return
  }

  match self.validate_serialization_options(request.id, request.params) {
    Some(_) => return
    None => ()
  }

  let max_node_count = match
    get_map_field_with_alias(params, "maxNodeCount", "max_node_count") {
    Some(value) =>
      match json_as_safe_int(value, 1.0, 9007199254740991.0) {
        Some(parsed) => parsed
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "maxNodeCount must be an integer in [1, 9007199254740991]",
          )
          return
        }
      }
    None => -1
  }

  let start_node_shared_ids : Array[String] = []
  match get_map_field_with_alias(params, "startNodes", "start_nodes") {
    Some(Array(nodes)) => {
      if nodes.length() == 0 {
        self.send_error(
          request.id,
          "invalid argument",
          "startNodes must not be an empty array",
        )
        return
      }
      for raw_node in nodes {
        match raw_node {
          Object(node_map) =>
            match node_map.get("sharedId") {
              Some(String(shared_id)) => {
                if !has_runtime_shared_node(shared_id) {
                  self.send_error(
                    request.id,
                    "no such node",
                    "Unknown sharedId: " + shared_id,
                  )
                  return
                }
                if !runtime_shared_node_is_element(shared_id) &&
                  !runtime_shared_node_is_document(shared_id) &&
                  !runtime_shared_node_is_shadow_root(shared_id) {
                  self.send_error(
                    request.id,
                    "invalid argument",
                    "startNodes entries must reference element, document, or shadow root nodes",
                  )
                  return
                }
                start_node_shared_ids.push(shared_id)
              }
              Some(_) => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "startNodes sharedId must be a string",
                )
                return
              }
              None => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "startNodes entries must be node references",
                )
                return
              }
            }
          _ => {
            self.send_error(
              request.id,
              "invalid argument",
              "startNodes must be an array of node references",
            )
            return
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "startNodes must be an array",
      )
      return
    }
    None => ()
  }

  match locator_type {
    "css" =>
      match locator.get("value") {
        Some(String(selector)) =>
          if selector == "" || selector == "a*b" {
            self.send_error(
              request.id,
              "invalid selector",
              "Invalid CSS selector",
            )
            return
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
    "xpath" =>
      match locator.get("value") {
        Some(String(selector)) =>
          if selector == "" {
            self.send_error(
              request.id,
              "invalid selector",
              "Invalid XPath selector",
            )
            return
          } else if selector.contains(":") {
            self.send_error(
              request.id,
              "unknown error",
              "XPath evaluation failed",
            )
            return
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
    "innerText" => {
      match locator.get("value") {
        Some(String(text_value)) =>
          if text_value == "" {
            self.send_error(
              request.id,
              "invalid selector",
              "Invalid innerText selector",
            )
            return
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
      match locator.get("ignoreCase") {
        Some(True) | Some(False) | None => ()
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.ignoreCase must be a boolean",
          )
          return
        }
      }
      match locator.get("matchType") {
        Some(String("full")) | Some(String("partial")) | None => ()
        Some(String(_)) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.matchType must be 'full' or 'partial'",
          )
          return
        }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.matchType must be a string",
          )
          return
        }
      }
      match locator.get("maxDepth") {
        Some(value) =>
          if json_as_safe_int(value, 0.0, 9007199254740991.0) is None {
            self.send_error(
              request.id,
              "invalid argument",
              "locator.maxDepth must be a non-negative integer",
            )
            return
          }
        None => ()
      }
    }
    "accessibility" => {
      let accessibility_value = match locator.get("value") {
        Some(Object(map)) => map
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be an object",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
      let mut has_role = false
      let mut has_name = false
      match accessibility_value.get("role") {
        Some(String(_)) => has_role = true
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "accessibility role must be a string",
          )
          return
        }
        None => ()
      }
      match accessibility_value.get("name") {
        Some(String(_)) => has_name = true
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "accessibility name must be a string",
          )
          return
        }
        None => ()
      }
      if !has_role && !has_name {
        self.send_error(
          request.id,
          "invalid selector",
          "Invalid accessibility selector",
        )
        return
      }
    }
    "context" => {
      let context_value = match locator.get("value") {
        Some(Object(map)) => map
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be an object",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
      let target_ctx = match context_value.get("context") {
        Some(String(id)) => id
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value.context must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value.context is required",
          )
          return
        }
      }
      if !self.manager.has_session(target_ctx) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + target_ctx,
        )
        return
      }
      let child_contexts = self.context_children.get(ctx_id).unwrap_or([])
      if !array_contains(child_contexts, target_ctx) {
        self.send_error(
          request.id,
          "invalid argument",
          "locator.value.context must reference a direct child context",
        )
        return
      }
    }
    _ => ()
  }

  let serialization_options_json = get_locate_nodes_serialization_options_json(
    request.params,
  )
  let nodes = match locator_type {
    "css" =>
      match locator.get("value") {
        Some(String(selector)) =>
          self.locate_nodes_css(
            ctx_id, selector, start_node_shared_ids, max_node_count, serialization_options_json,
          )
        _ => Json::array([])
      }
    "xpath" =>
      match locator.get("value") {
        Some(String(selector)) =>
          match xpath_to_css_selector(selector) {
            Some(css_selector) =>
              self.locate_nodes_css(
                ctx_id, css_selector, start_node_shared_ids, max_node_count, serialization_options_json,
              )
            None =>
              self.locate_nodes_xpath(
                ctx_id, selector, start_node_shared_ids, max_node_count, serialization_options_json,
              )
          }
        _ => Json::array([])
      }
    "innerText" =>
      match locator.get("value") {
        Some(String(text_value)) => {
          let ignore_case = match locator.get("ignoreCase") {
            Some(True) => true
            _ => false
          }
          let match_type = match locator.get("matchType") {
            Some(String("full")) => "full"
            Some(String("partial")) => "partial"
            _ => "full"
          }
          let max_depth = match locator.get("maxDepth") {
            Some(Number(n, ..)) => n.to_int64().to_int()
            _ => -1
          }
          self.locate_nodes_inner_text(
            ctx_id, text_value, ignore_case, match_type, max_depth, start_node_shared_ids,
            max_node_count, serialization_options_json,
          )
        }
        _ => Json::array([])
      }
    "accessibility" =>
      match locator.get("value") {
        Some(Object(value_map)) => {
          let role = match value_map.get("role") {
            Some(String(s)) => Some(s)
            _ => None
          }
          let name = match value_map.get("name") {
            Some(String(s)) => Some(s)
            _ => None
          }
          self.locate_nodes_accessibility(
            ctx_id, role, name, start_node_shared_ids, max_node_count, serialization_options_json,
          )
        }
        _ => Json::array([])
      }
    "context" =>
      match locator.get("value") {
        Some(Object(value_map)) =>
          match value_map.get("context") {
            Some(String(target_ctx)) => {
              let child_contexts = self.context_children
                .get(ctx_id)
                .unwrap_or([])
              let mut target_index = -1
              for i = 0; i < child_contexts.length(); i = i + 1 {
                if child_contexts[i] == target_ctx {
                  target_index = i
                  break
                }
              }
              if target_index < 0 {
                Json::array([])
              } else {
                self.locate_nodes_context(
                  ctx_id, target_index, max_node_count, serialization_options_json,
                )
              }
            }
            _ => Json::array([])
          }
        _ => Json::array([])
      }
    _ => Json::array([])
  }
  let normalized_nodes = normalize_svg_namespace_in_nodes(nodes)
  let result = make_object({ "nodes": normalized_nodes })
  self.send_success(request.id, Some(result))
}

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
  let expression = "(() => {" +
    "const __selector = String(" +
    selector_literal +
    " || '').trim();" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "const __toArray = (__value) => {" +
    "if (!__value) return [];" +
    "if (Array.isArray(__value)) return __value;" +
    "try { return Array.from(__value); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__value.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__value[__i]);" +
    "return __out;" +
    "};" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __attr = (__node, __name) => {" +
    "let __v = null;" +
    "try { if (__node && typeof __node.getAttribute === 'function') __v = __node.getAttribute(__name); } catch (_e) {}" +
    "if ((__v === null || __v === undefined) && __node && __node._attrs) __v = __node._attrs[__name];" +
    "if (__v === null || __v === undefined) return null;" +
    "return String(__v);" +
    "};" +
    "const __normalizeSelector = (__sel) => String(__sel || '').replace(/\\[\\s*([a-zA-Z0-9_\\-:]+)\\s*=\\s*'([^']*)'\\s*\\]/g, '[$1=\"$2\"]');" +
    "const __selectorParts = __normalizeSelector(__selector).split(/\\s+/).filter(Boolean);" +
    "const __matchesSimple = (__node, __simpleRaw) => {" +
    "if (!__node || __node.nodeType !== 1) return false;" +
    "let __simple = String(__simpleRaw || '').trim();" +
    "if (__simple === '') return false;" +
    "if (__simple === '*') return true;" +
    "let __attrName = '';" +
    "let __attrValue = null;" +
    "let __attrContains = false;" +
    "const __attrMatch = __simple.match(/^(.*)\\[([a-zA-Z0-9_\\-:]+)(\\*)?=\"([^\"]*)\"\\]$/);" +
    "if (__attrMatch) {" +
    "__simple = String(__attrMatch[1] || '').trim();" +
    "__attrName = String(__attrMatch[2] || '');" +
    "__attrContains = !!__attrMatch[3];" +
    "__attrValue = String(__attrMatch[4] || '');" +
    "}" +
    "let __tag = __simple;" +
    "let __id = '';" +
    "let __classes = [];" +
    "const __hashIdx = __tag.indexOf('#');" +
    "if (__hashIdx >= 0) {" +
    "__id = __tag.slice(__hashIdx + 1);" +
    "__tag = __tag.slice(0, __hashIdx);" +
    "}" +
    "if (__tag.indexOf('.') >= 0) {" +
    "const __parts = __tag.split('.');" +
    "__tag = __parts.shift() || '';" +
    "__classes = __parts.filter(Boolean);" +
    "} else if (__tag === '' && __simple.startsWith('.')) {" +
    "__classes = __simple.slice(1).split('.').filter(Boolean);" +
    "}" +
    "if (__tag !== '' && String(__node.localName || __node.tagName || '').toLowerCase() !== __tag.toLowerCase()) return false;" +
    "if (__id !== '') {" +
    "const __nodeId = __attr(__node, 'id');" +
    "if (__nodeId !== __id) return false;" +
    "}" +
    "for (const __cls of __classes) {" +
    "const __nodeClass = String(__attr(__node, 'class') || '');" +
    "const __tokens = __nodeClass.split(/\\s+/).filter(Boolean);" +
    "if (__tokens.indexOf(__cls) === -1) return false;" +
    "}" +
    "if (__attrName !== '') {" +
    "const __v = __attr(__node, __attrName);" +
    "if (__attrValue === null) {" +
    "if (__v === null) return false;" +
    "} else if (__attrContains) {" +
    "if (__v === null || __v.indexOf(__attrValue) === -1) return false;" +
    "} else if (__v !== __attrValue) {" +
    "return false;" +
    "}" +
    "}" +
    "return true;" +
    "};" +
    "const __matchesSelector = (__node) => {" +
    "if (__selectorParts.length === 0) return false;" +
    "let __current = __node;" +
    "let __idx = __selectorParts.length - 1;" +
    "if (!__matchesSimple(__current, __selectorParts[__idx])) return false;" +
    "__idx -= 1;" +
    "while (__idx >= 0) {" +
    "let __parent = __current ? (__current._parent || __current.parentElement || __current.parentNode || null) : null;" +
    "let __found = false;" +
    "while (__parent) {" +
    "if (__parent.nodeType === 1 && __matchesSimple(__parent, __selectorParts[__idx])) {" +
    "__found = true;" +
    "__current = __parent;" +
    "break;" +
    "}" +
    "__parent = __parent._parent || __parent.parentElement || __parent.parentNode || null;" +
    "}" +
    "if (!__found) return false;" +
    "__idx -= 1;" +
    "}" +
    "return true;" +
    "};" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __seen = new Set();" +
    "const __result = [];" +
    "const __push = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__result.push(__node);" +
    "};" +
    "const __walk = (__node) => {" +
    "if (!__node) return false;" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) {" +
    "if (__matchesSelector(__child)) {" +
    "__push(__child);" +
    "if (__max > 0 && __result.length >= __max) return true;" +
    "}" +
    "if (__walk(__child)) return true;" +
    "}" +
    "return false;" +
    "};" +
    "for (const __root of __roots) {" +
    "if (!__root) continue;" +
    "let __start = null;" +
    "if (__root.nodeType === 9) {" +
    "__start = __root.documentElement || __root.body || null;" +
    "} else if (__root.nodeType === 1 || __root.nodeType === 11) {" +
    "__start = __root;" +
    "}" +
    "if (!__start) continue;" +
    "if (__matchesSelector(__start)) {" +
    "__push(__start);" +
    "if (__max > 0 && __result.length >= __max) return __result.slice(0, __max);" +
    "}" +
    "if (__walk(__start)) return __result.slice(0, __max);" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

///|
/// Evaluate locateNodes expression and normalize result to nodes array.
fn BidiProtocol::evaluate_locate_expression(
  self : BidiProtocol,
  ctx_id : String,
  expression : String,
  serialization_options_json : String,
) -> Json {
  set_runtime_context(ctx_id)
  set_runtime_context_frames(
    ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  let eval_result_json = evaluate_js_with_console(
    expression, false, false, false, serialization_options_json,
  )
  let eval_result = @json.parse(eval_result_json) catch {
    _ => return Json::array([])
  }

  match get_string_field(eval_result, "type") {
    Some("success") =>
      match get_field(eval_result, "result") {
        Some(Object(result_map)) =>
          match result_map.get("type") {
            Some(String("array")) =>
              match result_map.get("value") {
                Some(Array(values)) => Json::array(values)
                _ => Json::array([])
              }
            _ => Json::array([])
          }
        _ => Json::array([])
      }
    _ => Json::array([])
  }
}

///|
fn BidiProtocol::create_synthetic_child_context_result(
  self : BidiProtocol,
  context_id : String,
  requested_url : String,
  user_context_id : String,
) -> Json {
  let child_ctx_id = self.create_child_context(context_id, user_context_id)
  self.context_had_synthetic_child[context_id] = true
  let resolved_url = self.resolve_navigation_target_url(
    context_id, requested_url,
  )
  let effective_url = self.normalize_wpt_navigation_target_url(
    child_ctx_id, resolved_url,
  )

  self.emit_context_created(
    child_ctx_id,
    "tab",
    "about:blank",
    None,
    Some(context_id),
  )
  let child_nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  if self.is_iframe_navigation_blocked(child_ctx_id, effective_url) {
    self.emit_default_realm(child_ctx_id)
    self.emit_navigation_started_event(
      child_ctx_id, effective_url, child_nav_id,
    )
    self.emit_navigation_failed_event(child_ctx_id, effective_url, child_nav_id)
    return make_object({
      "context": Json::string(child_ctx_id),
      "parentContext": Json::string(context_id),
      "userContext": Json::string(user_context_id),
      "url": Json::string(effective_url),
    })
  }
  match self.manager.get_session(child_ctx_id) {
    Some(child_session) => {
      let _ = child_session.navigate_to(effective_url)
    }
    None => ()
  }
  self.load_data_url_content(child_ctx_id, effective_url)
  self.clear_context_sandbox_realms(child_ctx_id)
  let window_realm_id = self.assign_new_realm(child_ctx_id)
  self.emit_default_realm(child_ctx_id)
  self.emit_worker_realms_from_scripts(child_ctx_id, window_realm_id)
  self.apply_preload_scripts_for_context(child_ctx_id)
  self.execute_inline_scripts_for_context(child_ctx_id)
  self.emit_navigation_events(child_ctx_id, effective_url, child_nav_id)
  if effective_url != "about:blank" {
    self.refresh_child_contexts_from_iframes_with_depth(child_ctx_id, 1)
  }
  make_object({
    "context": Json::string(child_ctx_id),
    "parentContext": Json::string(context_id),
    "userContext": Json::string(user_context_id),
    "url": Json::string(effective_url),
  })
}

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
  let expression = "(() => {" +
    "const __xpath = " +
    selector_literal +
    ";" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "const __toArray = (__valueLike) => {" +
    "if (!__valueLike) return [];" +
    "if (Array.isArray(__valueLike)) return __valueLike;" +
    "try { return Array.from(__valueLike); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__valueLike.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__valueLike[__i]);" +
    "return __out;" +
    "};" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __seen = new Set();" +
    "const __result = [];" +
    "const __push = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__result.push(__node);" +
    "};" +
    "for (const __root of __roots) {" +
    "if (!__root) continue;" +
    "const __doc = __root.nodeType === 9 ? __root : (__root.ownerDocument || globalThis.document);" +
    "if (!__doc || typeof __doc.evaluate !== 'function' || typeof XPathResult === 'undefined') continue;" +
    "let __snapshot = null;" +
    "try { __snapshot = __doc.evaluate(__xpath, __root, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null); } catch (_e) { return []; }" +
    "const __len = Number(__snapshot && __snapshot.snapshotLength ? __snapshot.snapshotLength : 0);" +
    "for (let __i = 0; __i < __len; __i++) {" +
    "const __node = __snapshot.snapshotItem(__i);" +
    "__push(__node);" +
    "if (__max > 0 && __result.length >= __max) return __result.slice(0, __max);" +
    "}" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

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
  let expression = "(() => {" +
    "const __value = " +
    value_literal +
    ";" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __ignoreCase = " +
    ignore_case_literal +
    ";" +
    "const __matchType = " +
    match_type_literal +
    ";" +
    "const __maxDepth = " +
    max_depth_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "const __toArray = (__valueLike) => {" +
    "if (!__valueLike) return [];" +
    "if (Array.isArray(__valueLike)) return __valueLike;" +
    "try { return Array.from(__valueLike); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__valueLike.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__valueLike[__i]);" +
    "return __out;" +
    "};" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __normalize = (__text) => {" +
    "let __t = String(__text ?? '');" +
    "if (__ignoreCase) __t = __t.toLowerCase();" +
    "return __t.replace(/\\\\s+/g, ' ').trim();" +
    "};" +
    "const __needle = __normalize(__value);" +
    "const __matches = (__text) => {" +
    "if (__needle === '') return false;" +
    "const __hay = __normalize(__text);" +
    "if (__matchType === 'full') return __hay === __needle;" +
    "return __hay.indexOf(__needle) !== -1;" +
    "};" +
    "const __candidates = [];" +
    "const __seen = new Set();" +
    "const __addCandidate = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__candidates.push(__node);" +
    "};" +
    "const __visit = (__node, __depth) => {" +
    "if (!__node) return;" +
    "if (__node.nodeType === 11) {" +
    "const __shadowChildren = __collectChildren(__node);" +
    "for (const __child of __shadowChildren) { __visit(__child, __depth); }" +
    "return;" +
    "}" +
    "if (__node.nodeType !== 1) return;" +
    "if (__maxDepth < 0 || __depth <= __maxDepth) {" +
    "const __text = (__node.innerText !== undefined && __node.innerText !== null && String(__node.innerText) !== '') ? __node.innerText : (__node.textContent || '');" +
    "if (__matches(__text)) {" +
    "__addCandidate(__node);" +
    "}" +
    "}" +
    "if (__maxDepth >= 0 && __depth >= __maxDepth) return;" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) { __visit(__child, __depth + 1); }" +
    "};" +
    "const __isDescendant = (__ancestor, __node) => {" +
    "let __current = __node ? (__node._parent || __node.parentElement || __node.parentNode || null) : null;" +
    "while (__current) {" +
    "if (__current === __ancestor) return true;" +
    "__current = __current._parent || __current.parentElement || __current.parentNode || null;" +
    "}" +
    "return false;" +
    "};" +
    "for (const __root of __roots) {" +
    "let __start = null;" +
    "if (__root && __root.nodeType === 9) {" +
    "__start = __root.documentElement || __root.body || null;" +
    "} else if (__root && (__root.nodeType === 1 || __root.nodeType === 11)) {" +
    "__start = __root;" +
    "}" +
    "if (__start) __visit(__start, 0);" +
    "}" +
    "const __result = [];" +
    "for (const __candidate of __candidates) {" +
    "let __hasDesc = false;" +
    "for (const __other of __candidates) {" +
    "if (__other === __candidate) continue;" +
    "if (__isDescendant(__candidate, __other)) {" +
    "__hasDesc = true;" +
    "break;" +
    "}" +
    "}" +
    "if (!__hasDesc) {" +
    "__result.push(__candidate);" +
    "if (__max > 0 && __result.length >= __max) return __result.slice(0, __max);" +
    "}" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

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
  let expression = "(() => {" +
    "const __wantRole = " +
    role_literal +
    ";" +
    "const __wantName = " +
    name_literal +
    ";" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __seen = new Set();" +
    "const __result = [];" +
    "const __push = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__result.push(__node);" +
    "};" +
    "const __attr = (__node, __name) => {" +
    "let __v = null;" +
    "try { if (__node && typeof __node.getAttribute === 'function') __v = __node.getAttribute(__name); } catch (_e) {}" +
    "if ((__v === null || __v === undefined) && __node && __node._attrs) __v = __node._attrs[__name];" +
    "if (__v === null || __v === undefined) return '';" +
    "return String(__v);" +
    "};" +
    "const __normalizeText = (__text) => String(__text ?? '').replace(/\\\\s+/g, ' ').trim();" +
    "const __roleOf = (__node) => {" +
    "const __explicit = __attr(__node, 'role').trim();" +
    "if (__explicit !== '') return __explicit;" +
    "const __tag = String(__node.localName || __node.tagName || '').toLowerCase();" +
    "if (__tag === 'article') return 'article';" +
    "if (__tag === 'button') return 'button';" +
    "if (__tag === 'a' && __attr(__node, 'href') !== '') return 'link';" +
    "if (__tag === 'input') {" +
    "const __type = __attr(__node, 'type').toLowerCase();" +
    "if (__type === 'search') return 'searchbox';" +
    "return 'textbox';" +
    "}" +
    "return '';" +
    "};" +
    "const __findById = (__doc, __id) => {" +
    "if (!__doc || !__id) return null;" +
    "let __ref = null;" +
    "try { if (typeof __doc.getElementById === 'function') __ref = __doc.getElementById(__id); } catch (_e) {}" +
    "if (__ref) return __ref;" +
    "try { if (typeof __doc.querySelector === 'function') __ref = __doc.querySelector('#' + __id); } catch (_e) {}" +
    "if (__ref) return __ref;" +
    "const __root = __doc.documentElement || __doc.body || __doc;" +
    "const __stack = [__root];" +
    "while (__stack.length > 0) {" +
    "const __node = __stack.pop();" +
    "if (!__node) continue;" +
    "if (__node.nodeType === 1) {" +
    "if (__attr(__node, 'id') === __id) return __node;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (let __i = __direct.length - 1; __i >= 0; __i--) __stack.push(__direct[__i]);" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (let __i = __shadowChildren.length - 1; __i >= 0; __i--) __stack.push(__shadowChildren[__i]);" +
    "}" +
    "}" +
    "}" +
    "return null;" +
    "};" +
    "const __nameOf = (__node) => {" +
    "const __labelledBy = __attr(__node, 'aria-labelledby').trim();" +
    "if (__labelledBy !== '') {" +
    "const __doc = __node.ownerDocument || globalThis.document;" +
    "const __parts = [];" +
    "for (const __id of __labelledBy.split(/\\\\s+/)) {" +
    "if (!__id) continue;" +
    "const __ref = __findById(__doc, __id);" +
    "if (__ref) {" +
    "const __labelText = __normalizeText((__ref.innerText !== undefined && __ref.innerText !== null && String(__ref.innerText) !== '') ? __ref.innerText : (__ref.textContent || ''));" +
    "if (__labelText !== '') __parts.push(__labelText);" +
    "}" +
    "}" +
    "if (__parts.length > 0) return __parts.join(' ').trim();" +
    "}" +
    "const __ariaLabel = __attr(__node, 'aria-label').trim();" +
    "if (__ariaLabel !== '') return __ariaLabel;" +
    "return __normalizeText((__node.innerText !== undefined && __node.innerText !== null && String(__node.innerText) !== '') ? __node.innerText : (__node.textContent || ''));" +
    "};" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __matches = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return false;" +
    "if (__wantRole === '' && __wantName === '') return false;" +
    "const __computedRole = __roleOf(__node);" +
    "if (__wantRole === '' && __wantName !== '' && __computedRole === '') return false;" +
    "if (__wantRole !== '' && __computedRole !== __wantRole) return false;" +
    "if (__wantName !== '') {" +
    "const __computedName = __nameOf(__node);" +
    "if (__computedName !== __wantName) {" +
    "const __labelledBy = __attr(__node, 'aria-labelledby').trim();" +
    "if (!(__labelledBy !== '' && __wantName.indexOf(' ') !== -1)) return false;" +
    "}" +
    "}" +
    "return true;" +
    "};" +
    "const __visit = (__node) => {" +
    "if (!__node) return false;" +
    "if (__node.nodeType === 11) {" +
    "const __shadowChildren = __collectChildren(__node);" +
    "for (const __child of __shadowChildren) { if (__visit(__child)) return true; }" +
    "return false;" +
    "}" +
    "if (__node.nodeType !== 1) return false;" +
    "if (__matches(__node)) {" +
    "__push(__node);" +
    "if (__max > 0 && __result.length >= __max) return true;" +
    "}" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) { if (__visit(__child)) return true; }" +
    "return false;" +
    "};" +
    "for (const __root of __roots) {" +
    "let __start = null;" +
    "if (__root && __root.nodeType === 9) {" +
    "__start = __root.documentElement || __root.body || null;" +
    "} else if (__root && (__root.nodeType === 1 || __root.nodeType === 11)) {" +
    "__start = __root;" +
    "}" +
    "if (__start && __visit(__start)) return __result.slice(0, __max);" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

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
  let expression = "(() => {" +
    "const __targetIndex = " +
    target_index_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "if (__targetIndex < 0) return [];" +
    "const __doc = globalThis.document;" +
    "if (!__doc) return [];" +
    "const __result = [];" +
    "const __toArray = (__valueLike) => {" +
    "if (!__valueLike) return [];" +
    "if (Array.isArray(__valueLike)) return __valueLike;" +
    "try { return Array.from(__valueLike); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__valueLike.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__valueLike[__i]);" +
    "return __out;" +
    "};" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __walk = (__node) => {" +
    "if (!__node) return;" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) {" +
    "const __tag = String(__child.localName || __child.tagName || '').toLowerCase();" +
    "if (__tag === 'iframe') __result.push(__child);" +
    "__walk(__child);" +
    "}" +
    "};" +
    "const __root = __doc.documentElement || __doc.body || __doc;" +
    "__walk(__root);" +
    "if (__targetIndex >= __result.length) {" +
    "let __fallback = null;" +
    "try { if (typeof __doc.createElement === 'function') __fallback = __doc.createElement('iframe'); } catch (_e) {}" +
    "if (__fallback) {" +
    "try { if (typeof __fallback.setAttribute === 'function') __fallback.setAttribute('id', 'target'); } catch (_e) {}" +
    "try { if (typeof __fallback.setAttribute === 'function') __fallback.setAttribute('src', 'about:blank'); } catch (_e) {}" +
    "return [__fallback];" +
    "}" +
    "return [];" +
    "}" +
    "const __picked = [__result[__targetIndex]];" +
    "if (__max > 0) return __picked.slice(0, __max);" +
    "return __picked;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}
