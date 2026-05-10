///|
fn parse_navigation_request(json_str : String) -> NavigationRequest? {
  let parsed = @json.parse(json_str) catch { _ => return None }
  match parsed {
    Object(map) =>
      match
        (
          map.get("url"),
          map.get("http_method"),
          map.get("content_type"),
          map.get("body"),
        ) {
        (
          Some(String(url)),
          Some(String(http_method)),
          Some(String(content_type)),
          Some(String(body)),
        ) =>
          Some({ url, http_method: http_method.to_upper(), content_type, body })
        _ => None
      }
    _ => None
  }
}

///|
async fn Browser::drain_pending_form_submission_navigation(
  self : Browser,
) -> Bool raise @http.HttpError {
  let value = self.peek_pending_form_submission_navigation()
  match value {
    Some(value) =>
      if value.length() == 0 {
        false
      } else if value.has_prefix("request:") {
        match
          parse_navigation_request(
            value.unsafe_substring(start=8, end=value.length()),
          ) {
          Some(request) => {
            let _ = self.shift_pending_form_submission_navigation()
            let resolved_request = {
              ..request,
              url: resolve_url(self.current_url, request.url),
            }
            let _ = self.navigate_request(resolved_request)
            true
          }
          None => {
            let _ = self.shift_pending_form_submission_navigation()
            self.drain_pending_form_submission_navigation()
          }
        }
      } else {
        let _ = self.shift_pending_form_submission_navigation()
        self.drain_pending_form_submission_navigation()
      }
    None => false
  }
}

///|
fn Browser::drain_pending_form_submission_navigation_sync(
  self : Browser,
) -> Bool {
  let value = self.peek_pending_form_submission_navigation()
  match value {
    Some(value) =>
      if value.length() == 0 {
        false
      } else if value.has_prefix("request:") {
        match
          parse_navigation_request(
            value.unsafe_substring(start=8, end=value.length()),
          ) {
          Some(request) => {
            let resolved_request = {
              ..request,
              url: resolve_url(self.current_url, request.url),
            }
            if self.navigate_sync_if_supported(resolved_request) {
              let _ = self.shift_pending_form_submission_navigation()
              true
            } else {
              false
            }
          }
          None => {
            let _ = self.shift_pending_form_submission_navigation()
            self.drain_pending_form_submission_navigation_sync()
          }
        }
      } else {
        let _ = self.shift_pending_form_submission_navigation()
        self.drain_pending_form_submission_navigation_sync()
      }
    None => false
  }
}

///|
fn browser_form_submit_bridge_source() -> String {
  let source =
    #|(() => {
    #|  const queue = (globalThis.__craterPendingFormSubmissions = []);
    #|  function isSubmitButtonElement(element) {
    #|    if (!element || !element.tagName || !element.getAttribute) return false;
    #|    const tag = String(element.tagName || '').toLowerCase();
    #|    const type = String(element.getAttribute('type') || '').toLowerCase();
    #|    if (tag === 'button') return type === '' || type === 'submit';
    #|    return tag === 'input' && (type === 'submit' || type === 'image');
    #|  }
    #|  function resolveFormOwnerForSubmitter(element) {
    #|    if (!element) return null;
    #|    if (element.form !== undefined && element.form !== null) return element.form;
    #|    return element.closest ? element.closest('form') : null;
    #|  }
    #|  function hasSubmitListenersInPath(target) {
    #|    let current = target;
    #|    while (current) {
    #|      const store = current._listeners && current._listeners.submit;
    #|      if (store && store.length > 0) return true;
    #|      current = current.parentNode || null;
    #|    }
    #|    const docStore = document && document._listeners && document._listeners.submit;
    #|    if (docStore && docStore.length > 0) return true;
    #|    const winStore = window && window._listeners && window._listeners.submit;
    #|    return !!(winStore && winStore.length > 0);
    #|  }
    #|  function buildFormNavigationRequest(form, submitter, clientX, clientY) {
    #|    if (!form) return 'none';
    #|    const submitMethodAttr = submitter && submitter.getAttribute ? submitter.getAttribute('formmethod') : null;
    #|    const methodSource = submitMethodAttr === null ? ((form.getAttribute && form.getAttribute('method')) || 'get') : String(submitMethodAttr);
    #|    const method = methodSource ? String(methodSource).toLowerCase() : 'get';
    #|    const submitTargetAttr = submitter && submitter.getAttribute ? submitter.getAttribute('formtarget') : null;
    #|    const targetSource = submitTargetAttr === null ? ((form.getAttribute && form.getAttribute('target')) || '') : String(submitTargetAttr);
    #|    const normalizedTarget = targetSource ? String(targetSource).toLowerCase() : '';
    #|    if (normalizedTarget !== '' && normalizedTarget !== '_self' && normalizedTarget !== '_top' && normalizedTarget !== '_parent') return 'handled';
    #|    const submitActionAttr = submitter && submitter.getAttribute ? submitter.getAttribute('formaction') : null;
    #|    let action = submitActionAttr === null ? ((form.getAttribute && form.getAttribute('action')) || '') : String(submitActionAttr);
    #|    if (!action) action = (document && document.URL) || ((window && window.location && window.location.href) || '');
    #|    if (!action) return 'handled';
    #|    const submitEnctypeAttr = submitter && submitter.getAttribute ? submitter.getAttribute('formenctype') : null;
    #|    const enctypeSource = submitEnctypeAttr === null ? ((form.getAttribute && form.getAttribute('enctype')) || 'application/x-www-form-urlencoded') : String(submitEnctypeAttr);
    #|    const enctype = enctypeSource ? String(enctypeSource).toLowerCase() : 'application/x-www-form-urlencoded';
    #|    const encodedPairs = [];
    #|    const plainPairs = [];
    #|    function pushPair(name, value) {
    #|      const stringName = String(name);
    #|      const stringValue = String(value);
    #|      encodedPairs.push(encodeURIComponent(stringName) + '=' + encodeURIComponent(stringValue));
    #|      plainPairs.push(stringName + '=' + stringValue);
    #|    }
    #|    function pushField(element) {
    #|      if (!element || !element.getAttribute) return;
    #|      const name = element.getAttribute('name');
    #|      if (!name) return;
    #|      const tag = String(element.tagName || '').toLowerCase();
    #|      const type = String(element.getAttribute('type') || '').toLowerCase();
    #|      if (tag === 'input' && (type === 'submit' || type === 'button' || type === 'image' || type === 'reset' || type === 'file')) return;
    #|      if ((type === 'checkbox' || type === 'radio') && !element.checked) return;
    #|      const value = element.value !== undefined && element.value !== null ? String(element.value) : String(element.getAttribute('value') || '');
    #|      pushPair(name, value);
    #|    }
    #|    function walk(node) {
    #|      if (!node || !node.childNodes) return;
    #|      for (let i = 0; i < node.childNodes.length; i++) {
    #|        const child = node.childNodes[i];
    #|        if (!child || child.nodeType !== 1) continue;
    #|        const childTag = String(child.tagName || '').toLowerCase();
    #|        if (childTag === 'input' || childTag === 'select' || childTag === 'textarea') pushField(child);
    #|        walk(child);
    #|      }
    #|    }
    #|    walk(form);
    #|    if (submitter && submitter.getAttribute) {
    #|      const submitTag = String(submitter.tagName || '').toLowerCase();
    #|      const submitType = String(submitter.getAttribute('type') || '').toLowerCase();
    #|      const submitName = submitter.getAttribute('name');
    #|      if (submitTag === 'input' && submitType === 'image') {
    #|        const rect = submitter.getBoundingClientRect ? submitter.getBoundingClientRect() : { left: 0, top: 0 };
    #|        const imageX = Math.max(0, Math.floor(Number(clientX) - (Number(rect.left) || 0)));
    #|        const imageY = Math.max(0, Math.floor(Number(clientY) - (Number(rect.top) || 0)));
    #|        const prefix = submitName ? String(submitName) + '.' : '';
    #|        pushPair(prefix + 'x', imageX);
    #|        pushPair(prefix + 'y', imageY);
    #|      } else if (submitName) {
    #|        const submitValue = submitter.value !== undefined && submitter.value !== null ? String(submitter.value) : String(submitter.getAttribute('value') || '');
    #|        pushPair(submitName, submitValue);
    #|      }
    #|    }
    #|    if (method === 'get') {
    #|      if (encodedPairs.length > 0) action += (action.indexOf('?') >= 0 ? '&' : '?') + encodedPairs.join('&');
    #|      return 'request:' + JSON.stringify({ url: action, http_method: 'GET', content_type: '', body: '' });
    #|    }
    #|    let contentType = 'application/x-www-form-urlencoded;charset=UTF-8';
    #|    let body = encodedPairs.join('&');
    #|    if (enctype === 'text/plain') {
    #|      contentType = 'text/plain;charset=UTF-8';
    #|      body = plainPairs.join('\r\n');
    #|    } else if (enctype === 'multipart/form-data') {
    #|      const boundary = '----CraterFormBoundary';
    #|      contentType = 'multipart/form-data; boundary=' + boundary;
    #|      body = '';
    #|      for (const pair of plainPairs) {
    #|        const idx = pair.indexOf('=');
    #|        const partName = idx >= 0 ? pair.slice(0, idx) : pair;
    #|        const partValue = idx >= 0 ? pair.slice(idx + 1) : '';
    #|        body += '--' + boundary + '\r\n';
    #|        body += 'Content-Disposition: form-data; name="' + partName.replace(/"/g, '%22') + '"\r\n\r\n';
    #|        body += partValue + '\r\n';
    #|      }
    #|      body += '--' + boundary + '--\r\n';
    #|    }
    #|    return 'request:' + JSON.stringify({ url: action, http_method: method.toUpperCase(), content_type: contentType, body });
    #|  }
    #|  function shouldSkipValidation(form, submitter) {
    #|    if (submitter && submitter.hasAttribute && submitter.hasAttribute('formnovalidate')) return true;
    #|    return !!(form && form.hasAttribute && form.hasAttribute('novalidate'));
    #|  }
    #|  function dispatchFormSubmitThroughBridge(form, submitter, clientX, clientY) {
    #|    if (!form) return 'none';
    #|    if (!shouldSkipValidation(form, submitter) &&
    #|        typeof form.reportValidity === 'function' &&
    #|        !form.reportValidity()) {
    #|      return 'invalid';
    #|    }
    #|    const event = new SubmitEvent('submit', { bubbles: true, cancelable: true, submitter });
    #|    if (!form.dispatchEvent(event) && hasSubmitListenersInPath(form)) return 'prevent';
    #|    return buildFormNavigationRequest(form, submitter, clientX, clientY);
    #|  }
    #|  function submitThroughBridge() {
    #|    const result = buildFormNavigationRequest(this, null, 0, 0);
    #|    if (result !== 'none' && result !== 'prevent') queue.push(result);
    #|    return undefined;
    #|  }
    #|  function requestSubmitThroughBridge(submitter) {
    #|    const normalizedSubmitter = submitter === undefined ? null : submitter;
    #|    if (normalizedSubmitter !== null) {
    #|      if (!isSubmitButtonElement(normalizedSubmitter)) {
    #|        throw new TypeError("Failed to execute 'requestSubmit' on 'HTMLFormElement': parameter 1 is not a submit button");
    #|      }
    #|      if (resolveFormOwnerForSubmitter(normalizedSubmitter) !== this) {
    #|        throw new DOMException("Failed to execute 'requestSubmit' on 'HTMLFormElement': the specified element is not owned by this form element", 'NotFoundError');
    #|      }
    #|    }
    #|    const result = dispatchFormSubmitThroughBridge(this, normalizedSubmitter, 0, 0);
    #|    if (result !== 'none' && result !== 'prevent' && result !== 'invalid') queue.push(result);
    #|    return undefined;
    #|  }
    #|  globalThis.__craterBuildFormNavigationRequest = buildFormNavigationRequest;
    #|  globalThis.__craterDispatchFormSubmit = dispatchFormSubmitThroughBridge;
    #|  Object.defineProperty(HTMLFormElement.prototype, 'submit', {
    #|    value: submitThroughBridge,
    #|    configurable: true,
    #|    writable: true,
    #|  });
    #|  Object.defineProperty(HTMLFormElement.prototype, 'requestSubmit', {
    #|    value: requestSubmitThroughBridge,
    #|    configurable: true,
    #|    writable: true,
    #|  });
    #|  if (document && typeof document.querySelectorAll === 'function') {
    #|    const forms = document.querySelectorAll('form');
    #|    for (let i = 0; i < forms.length; i++) {
    #|      const form = forms[i];
    #|      if (!form) continue;
    #|      Object.defineProperty(form, 'submit', {
    #|        value: submitThroughBridge,
    #|        configurable: true,
    #|        writable: true,
    #|      });
    #|      Object.defineProperty(form, 'requestSubmit', {
    #|        value: requestSubmitThroughBridge,
    #|        configurable: true,
    #|        writable: true,
    #|      });
    #|    }
    #|  }
    #|  globalThis.__craterHasSubmitListenersInPath = hasSubmitListenersInPath;
    #|  globalThis.__craterBrowserFormSubmitBridgeInstalled = true;
    #|  return 'ok';
    #|})()
  source
}

///|
fn browser_pending_form_submission_source() -> String {
  let source =
    #|(() => {
    #|  const queue = globalThis.__craterPendingFormSubmissions || [];
    #|  if (queue.length === 0) return JSON.stringify('');
    #|  const next = queue.shift();
    #|  return JSON.stringify(next === undefined || next === null ? '' : String(next));
    #|})()
  source
}

///|
fn browser_peek_pending_form_submission_source() -> String {
  let source =
    #|(() => {
    #|  const queue = globalThis.__craterPendingFormSubmissions || [];
    #|  if (queue.length === 0) return JSON.stringify('');
    #|  const next = queue[0];
    #|  return JSON.stringify(next === undefined || next === null ? '' : String(next));
    #|})()
  source
}

///|
fn Browser::peek_pending_form_submission_navigation(self : Browser) -> String? {
  match self.script_executor {
    Some(executor) =>
      decode_js_string_result(
        executor.execute_source(browser_peek_pending_form_submission_source()).value,
      ) catch {
        err => {
          println("[JS] Error: " + err.to_string())
          None
        }
      }
    None => None
  }
}

///|
fn Browser::shift_pending_form_submission_navigation(self : Browser) -> String? {
  match self.script_executor {
    Some(executor) =>
      decode_js_string_result(
        executor.execute_source(browser_pending_form_submission_source()).value,
      ) catch {
        err => {
          println("[JS] Error: " + err.to_string())
          None
        }
      }
    None => None
  }
}

///|
fn Browser::dispatch_submit_to_source_id(
  self : Browser,
  source_id : String,
  client_x? : Int = 0,
  client_y? : Int = 0,
) -> SubmitDispatchResult {
  if !self.enable_js {
    return NotSubmittable
  }
  let escaped = escape_js_string(source_id)
  let source_client_x = client_x.to_string()
  let source_client_y = client_y.to_string()
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'none';}const clientX=" +
    source_client_x +
    ";const clientY=" +
    source_client_y +
    ";const tag=(target.tagName||'').toLowerCase();const type=(target.getAttribute?((target.getAttribute('type')||'').toLowerCase()):'');let form=null;let submitter=null;if(tag==='form'){form=target;}else{if(tag==='button'){if(type!==''&&type!=='submit'){return 'none';}submitter=target;}else if(tag==='input'){if(type==='submit'||type==='image'){submitter=target;}else if(type==='button'||type==='reset'||type==='checkbox'||type==='radio'||type==='file'){return 'none';}}else if(tag==='textarea'||tag==='select'){return 'none';}form=target.closest?target.closest('form'):null;}if(!form){return 'none';}const dispatchSubmit=globalThis.__craterDispatchFormSubmit;if(typeof dispatchSubmit==='function'){return dispatchSubmit(form,submitter,clientX,clientY);}const build=globalThis.__craterBuildFormNavigationRequest;if(typeof build!=='function'){return 'handled';}return build(form,submitter,clientX,clientY);})()"
  match self.execute_inline_js(source) {
    Some(result) => {
      let _ = self.sync_render_state_from_dom_tree()
      if result == "none" {
        NotSubmittable
      } else if result == "prevent" {
        Prevented
      } else if result == "invalid" {
        Handled
      } else if result == "handled" {
        Handled
      } else if result.has_prefix("request:") {
        match
          parse_navigation_request(
            result.unsafe_substring(start=8, end=result.length()),
          ) {
          Some(request) => Navigate(request)
          None => NotSubmittable
        }
      } else {
        NotSubmittable
      }
    }
    None => NotSubmittable
  }
}
