///|
/// JavaScript Runtime - V8 implementation (native target)
///
/// Uses mizchi/v8 (rusty_v8 bindings) for real JavaScript execution
/// with full mock DOM support.

///|
pub struct V8JsRuntime {
  mut initialized : Bool
  mut dom_initialized : Bool
  mut dom_synced : Bool
  mut runtime : @v8.Runtime?
  mock_dom_source : String?
  id_map : Map[Int, @dom.NodeId]
}

///|
/// Create a V8JsRuntime without mock DOM (basic eval only).
pub fn V8JsRuntime::new() -> V8JsRuntime {
  {
    initialized: false,
    dom_initialized: false,
    dom_synced: false,
    runtime: None,
    mock_dom_source: None,
    id_map: {},
  }
}

///|
/// Create a V8JsRuntime with mock DOM source code.
/// The mock DOM JS will be evaluated on first execute() call.
pub fn V8JsRuntime::new_with_mock_dom(mock_dom_js : String) -> V8JsRuntime {
  {
    initialized: false,
    dom_initialized: false,
    dom_synced: false,
    runtime: None,
    mock_dom_source: Some(mock_dom_js),
    id_map: {},
  }
}

///|
/// Get V8JsRuntime as a JsRuntime trait object for use with JsContext.
pub fn V8JsRuntime::as_js_runtime(self : V8JsRuntime) -> &@js.JsRuntime {
  self as &@js.JsRuntime
}

///|
/// Console setup for no-mock-DOM mode (basic eval only)
let console_setup_js : String = "const __logs = [];\nconst console = {\n  log: (...args) => __logs.push(args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ')),\n  warn: (...args) => __logs.push('[WARN] ' + args.map(a => String(a)).join(' ')),\n  error: (...args) => __logs.push('[ERROR] ' + args.map(a => String(a)).join(' ')),\n  info: (...args) => __logs.push(args.map(a => String(a)).join(' ')),\n  debug: (...args) => {},\n};\nfunction __getLogs() { const l = [...__logs]; __logs.length = 0; return JSON.stringify(l); }"

///|
/// Logs setup for mock-DOM mode (mock DOM defines its own console that writes to `logs`)
let logs_bridge_js : String = "function __getLogs() { const l = [...logs]; logs.length = 0; return JSON.stringify(l); }"

///|
let element_internals_polyfill_js : String =
  #|(function() {
  #|  if (typeof document === 'undefined' || typeof Element === 'undefined' || typeof DOMException === 'undefined') {
  #|    return;
  #|  }
  #|  function containsAsciiWhitespace(value) {
  #|    return /[\t\n\f\r ]/.test(value);
  #|  }
  #|  function syncCustomStates(host, states) {
  #|    if (!host) return;
  #|    host.__customStates = new Set(states);
  #|    if (host._mockId) {
  #|      domOps.push({
  #|        op: 'setCustomStates',
  #|        id: host._mockId,
  #|        value: Array.from(states).join(' ')
  #|      });
  #|    }
  #|  }
  #|  function CustomStateSet(host) {
  #|    this._host = host || null;
  #|    this._states = new Set();
  #|    if (host && host.__customStates instanceof Set) {
  #|      host.__customStates.forEach((state) => {
  #|        this._states.add(String(state));
  #|      });
  #|    }
  #|  }
  #|  CustomStateSet.prototype._validateState = function(value) {
  #|    const str = String(value);
  #|    if (str.length === 0) {
  #|      throw new DOMException('The custom state token provided must not be empty.', 'SyntaxError');
  #|    }
  #|    if (containsAsciiWhitespace(str)) {
  #|      throw new DOMException(
  #|        'The custom state token provided contains HTML space characters, which are not valid in tokens.',
  #|        'InvalidCharacterError'
  #|      );
  #|    }
  #|    return str;
  #|  };
  #|  Object.defineProperty(CustomStateSet.prototype, 'size', {
  #|    get() { return this._states.size; },
  #|    configurable: true
  #|  });
  #|  CustomStateSet.prototype.add = function(value) {
  #|    const state = this._validateState(value);
  #|    this._states.add(state);
  #|    syncCustomStates(this._host, this._states);
  #|    return this;
  #|  };
  #|  CustomStateSet.prototype.clear = function() {
  #|    this._states.clear();
  #|    syncCustomStates(this._host, this._states);
  #|  };
  #|  CustomStateSet.prototype['delete'] = function(value) {
  #|    const state = this._validateState(value);
  #|    const deleted = this._states.delete(state);
  #|    if (deleted) syncCustomStates(this._host, this._states);
  #|    return deleted;
  #|  };
  #|  CustomStateSet.prototype.has = function(value) {
  #|    return this._states.has(String(value));
  #|  };
  #|  CustomStateSet.prototype.forEach = function(callback, thisArg) {
  #|    this._states.forEach((value) => callback.call(thisArg, value, value, this));
  #|  };
  #|  CustomStateSet.prototype.keys = function() { return this._states.keys(); };
  #|  CustomStateSet.prototype.values = function() { return this._states.values(); };
  #|  CustomStateSet.prototype.entries = function() { return this._states.entries(); };
  #|  CustomStateSet.prototype[Symbol.iterator] = function() { return this.values(); };
  #|
  #|  function ElementInternals(host) {
  #|    this._host = host || null;
  #|    this._validity = {};
  #|    this._validationMessage = '';
  #|  }
  #|  function resolveFormOwnerForSubmitter(element) {
  #|    if (!element || element.nodeType !== 1) return null;
  #|    const formAttr = element.getAttribute && element.getAttribute('form');
  #|    if (formAttr !== null && formAttr !== undefined && String(formAttr) !== '') {
  #|      return document.getElementById(String(formAttr));
  #|    }
  #|    return element.closest ? element.closest('form') : null;
  #|  }
  #|  function isSubmitButtonElement(element) {
  #|    if (!element || element.nodeType !== 1) return false;
  #|    const localName = String(element.localName || element._localName || element.tagName || '').toLowerCase();
  #|    const type = element.getAttribute ? String(element.getAttribute('type') || '').toLowerCase() : '';
  #|    if (localName === 'button') return type === '' || type === 'submit';
  #|    if (localName === 'input') return type === 'submit' || type === 'image';
  #|    return false;
  #|  }
  #|  function isResetButtonElement(element) {
  #|    if (!element || element.nodeType !== 1) return false;
  #|    const localName = String(element.localName || element._localName || element.tagName || '').toLowerCase();
  #|    const type = element.getAttribute ? String(element.getAttribute('type') || '').toLowerCase() : '';
  #|    if (localName === 'button') return type === 'reset';
  #|    if (localName === 'input') return type === 'reset';
  #|    return false;
  #|  }
  #|  function rememberInputDefaultValue(element) {
  #|    if (!element || !element.hasAttribute || !element.setAttribute) return;
  #|    if (element.hasAttribute('data-crater-default-value')) return;
  #|    const current = element.getAttribute ? element.getAttribute('value') : null;
  #|    element.setAttribute(
  #|      'data-crater-default-value',
  #|      current === null || current === undefined ? '' : String(current),
  #|    );
  #|  }
  #|  function rememberTextAreaDefaultValue(element) {
  #|    if (!element || !element.hasAttribute || !element.setAttribute) return;
  #|    if (element.hasAttribute('data-crater-default-value')) return;
  #|    element.setAttribute(
  #|      'data-crater-default-value',
  #|      element.textContent === null || element.textContent === undefined ? '' : String(element.textContent),
  #|    );
  #|  }
  #|  function rememberInputDefaultChecked(element) {
  #|    if (!element || !element.hasAttribute || !element.setAttribute) return;
  #|    if (element.hasAttribute('data-crater-default-checked')) return;
  #|    element.setAttribute('data-crater-default-checked', element.hasAttribute('checked') ? 'true' : 'false');
  #|  }
  #|  function rememberOptionDefaultSelected(element) {
  #|    if (!element || !element.hasAttribute || !element.setAttribute) return;
  #|    if (element.hasAttribute('data-crater-default-selected')) return;
  #|    element.setAttribute('data-crater-default-selected', element.hasAttribute('selected') ? 'true' : 'false');
  #|  }
  #|  function setBooleanAttribute(element, name, value) {
  #|    if (!element) return;
  #|    if (value) {
  #|      if (element.setAttribute) element.setAttribute(name, '');
  #|    } else if (element.removeAttribute) {
  #|      element.removeAttribute(name);
  #|    }
  #|  }
  #|  function collectSelectOptions(select) {
  #|    const items = [];
  #|    function walk(node) {
  #|      if (!node || !node.childNodes) return;
  #|      for (let i = 0; i < node.childNodes.length; i++) {
  #|        const child = node.childNodes[i];
  #|        if (!child || child.nodeType !== 1) continue;
  #|        const tag = String(child.localName || child._localName || child.tagName || '').toLowerCase();
  #|        if (tag === 'option') items.push(child);
  #|        else if (tag === 'optgroup') walk(child);
  #|      }
  #|    }
  #|    walk(select);
  #|    return items;
  #|  }
  #|  function resetFormControls(form) {
  #|    if (!form || !form.querySelectorAll) return;
  #|    const controls = form.querySelectorAll('input, textarea, select');
  #|    for (let i = 0; i < controls.length; i++) {
  #|      const control = controls[i];
  #|      const localName = String(control.localName || control._localName || control.tagName || '').toLowerCase();
  #|      if (localName === 'input') {
  #|        const type = control.getAttribute ? String(control.getAttribute('type') || '').toLowerCase() : '';
  #|        if (type === 'checkbox' || type === 'radio') {
  #|          const defaultChecked = control.getAttribute ? control.getAttribute('data-crater-default-checked') : null;
  #|          setBooleanAttribute(
  #|            control,
  #|            'checked',
  #|            defaultChecked === null ? control.hasAttribute('checked') : defaultChecked === 'true',
  #|          );
  #|        } else if (
  #|          type !== 'submit' &&
  #|          type !== 'button' &&
  #|          type !== 'image' &&
  #|          type !== 'reset' &&
  #|          type !== 'file'
  #|        ) {
  #|          const defaultValue = control.getAttribute ? control.getAttribute('data-crater-default-value') : null;
  #|          control.setAttribute(
  #|            'value',
  #|            defaultValue === null ? String(control.getAttribute('value') || '') : String(defaultValue),
  #|          );
  #|        }
  #|      } else if (localName === 'textarea') {
  #|        const defaultValue = control.getAttribute ? control.getAttribute('data-crater-default-value') : null;
  #|        control.textContent = defaultValue === null
  #|          ? (control.textContent === null || control.textContent === undefined ? '' : String(control.textContent))
  #|          : String(defaultValue);
  #|      } else if (localName === 'select') {
  #|        const options = collectSelectOptions(control);
  #|        let selectedIndex = -1;
  #|        for (let j = 0; j < options.length; j++) {
  #|          const option = options[j];
  #|          const defaultSelected = option.getAttribute ? option.getAttribute('data-crater-default-selected') : null;
  #|          const selected = defaultSelected === null
  #|            ? !!(option.hasAttribute && option.hasAttribute('selected'))
  #|            : defaultSelected === 'true';
  #|          setBooleanAttribute(option, 'selected', selected);
  #|          if (selected && selectedIndex < 0) selectedIndex = j;
  #|        }
  #|        if (selectedIndex < 0 && options.length > 0) {
  #|          setBooleanAttribute(options[0], 'selected', true);
  #|        }
  #|      }
  #|    }
  #|  }
  #|  function isValidationIgnoredInputType(type) {
  #|    switch (String(type || '').toLowerCase()) {
  #|      case 'hidden':
  #|      case 'button':
  #|      case 'reset':
  #|      case 'submit':
  #|      case 'image':
  #|        return true;
  #|      default:
  #|        return false;
  #|    }
  #|  }
  #|  function computeControlWillValidate(element) {
  #|    if (!element || element.nodeType !== 1) return false;
  #|    const localName = String(element.localName || element._localName || element.tagName || '').toLowerCase();
  #|    if (localName === 'button' || localName === 'fieldset' || localName === 'output') return false;
  #|    if (element.hasAttribute && (element.hasAttribute('disabled') || element.hasAttribute('readonly'))) return false;
  #|    if (localName === 'input') {
  #|      const type = element.getAttribute ? String(element.getAttribute('type') || '').toLowerCase() : '';
  #|      if (isValidationIgnoredInputType(type)) return false;
  #|    }
  #|    let current = element.parentNode || null;
  #|    while (current) {
  #|      const ancestorName = String(current.localName || current._localName || current.tagName || '').toLowerCase();
  #|      if (ancestorName === 'datalist') return false;
  #|      if (ancestorName === 'fieldset' && current.hasAttribute && current.hasAttribute('disabled')) return false;
  #|      current = current.parentNode || null;
  #|    }
  #|    return localName === 'input' || localName === 'textarea' || localName === 'select';
  #|  }
  #|  function findCheckedRadioInGroup(element) {
  #|    if (!element || !document || !document.querySelectorAll) return null;
  #|    const ownerForm = resolveFormOwnerForSubmitter(element);
  #|    const name = element.getAttribute ? String(element.getAttribute('name') || '') : '';
  #|    const radios = document.querySelectorAll('input');
  #|    for (let i = 0; i < radios.length; i++) {
  #|      const radio = radios[i];
  #|      if (!radio || radio === element) continue;
  #|      const type = radio.getAttribute ? String(radio.getAttribute('type') || '').toLowerCase() : '';
  #|      if (type !== 'radio') continue;
  #|      const radioName = radio.getAttribute ? String(radio.getAttribute('name') || '') : '';
  #|      if (radioName !== name) continue;
  #|      if (resolveFormOwnerForSubmitter(radio) !== ownerForm) continue;
  #|      if (radio.checked) return radio;
  #|    }
  #|    return null;
  #|  }
  #|  function computeRequiredValueMissing(element) {
  #|    if (!element || !element.hasAttribute || !element.hasAttribute('required')) return false;
  #|    const localName = String(element.localName || element._localName || element.tagName || '').toLowerCase();
  #|    if (localName === 'textarea') return String(element.value || '') === '';
  #|    if (localName === 'select') {
  #|      const options = collectSelectOptions(element);
  #|      const selected = options.find((option) => !!option.selected) || options[0] || null;
  #|      if (!selected) return true;
  #|      let value = selected.getAttribute ? selected.getAttribute('value') : null;
  #|      if (value === null || value === undefined) value = selected.textContent || '';
  #|      return String(value) === '';
  #|    }
  #|    if (localName === 'input') {
  #|      const type = element.getAttribute ? String(element.getAttribute('type') || '').toLowerCase() : '';
  #|      if (type === 'checkbox') return !element.checked;
  #|      if (type === 'radio') {
  #|        if (element.checked) return false;
  #|        return findCheckedRadioInGroup(element) === null;
  #|      }
  #|      if (isValidationIgnoredInputType(type) || type === 'file') return false;
  #|      return String(element.value || '') === '';
  #|    }
  #|    return false;
  #|  }
  #|  function computeValidationStateForElement(element) {
  #|    const validity = { valueMissing: false, customError: false, valid: true };
  #|    let message = '';
  #|    if (!computeControlWillValidate(element)) return { validity, message };
  #|    const customMessage = Object.prototype.hasOwnProperty.call(element, '__customValidationMessage')
  #|      ? String(element.__customValidationMessage || '')
  #|      : '';
  #|    if (customMessage !== '') {
  #|      validity.customError = true;
  #|      message = customMessage;
  #|    }
  #|    if (computeRequiredValueMissing(element)) {
  #|      validity.valueMissing = true;
  #|      if (message === '') message = 'Please fill out this field.';
  #|    }
  #|    validity.valid = !validity.valueMissing && !validity.customError;
  #|    if (validity.valid) message = '';
  #|    return { validity, message };
  #|  }
  #|  function dispatchInvalidEventForElement(element) {
  #|    if (!element || typeof element.dispatchEvent !== 'function') return;
  #|    element.dispatchEvent(new Event('invalid', { bubbles: false, cancelable: true }));
  #|  }
  #|  function checkFormControlValidity(element, report) {
  #|    const state = computeValidationStateForElement(element);
  #|    if (state.validity.valid) return true;
  #|    if (report) dispatchInvalidEventForElement(element);
  #|    return false;
  #|  }
  #|  function shouldSkipFormValidation(form, submitter) {
  #|    if (submitter && submitter.hasAttribute && submitter.hasAttribute('formnovalidate')) return true;
  #|    return !!(form && form.hasAttribute && form.hasAttribute('novalidate'));
  #|  }
  #|  function validateFormForSubmission(form, report, submitter) {
  #|    if (!form || !form.querySelectorAll) return true;
  #|    if (shouldSkipFormValidation(form, submitter)) return true;
  #|    const controls = form.querySelectorAll('input, textarea, select');
  #|    let allValid = true;
  #|    for (let i = 0; i < controls.length; i++) {
  #|      if (!checkFormControlValidity(controls[i], report)) allValid = false;
  #|    }
  #|    return allValid;
  #|  }
  #|  function wrapPatchedProperty(element, propertyName, beforeSet) {
  #|    const marker = '__craterPatched_' + propertyName;
  #|    if (!element || element[marker]) return;
  #|    let prototype = element;
  #|    let descriptor = null;
  #|    while (prototype && !descriptor) {
  #|      descriptor = Object.getOwnPropertyDescriptor(prototype, propertyName);
  #|      prototype = Object.getPrototypeOf(prototype);
  #|    }
  #|    if (!descriptor || typeof descriptor.get !== 'function' || typeof descriptor.set !== 'function') return;
  #|    Object.defineProperty(element, propertyName, {
  #|      get() { return descriptor.get.call(this); },
  #|      set(value) {
  #|        beforeSet(this);
  #|        descriptor.set.call(this, value);
  #|      },
  #|      configurable: true,
  #|      enumerable: !!descriptor.enumerable,
  #|    });
  #|    element[marker] = true;
  #|  }
  #|  if (typeof globalThis.SubmitEvent !== 'function') {
  #|    class SubmitEvent extends Event {
  #|      constructor(type, options) {
  #|        options = options || {};
  #|        super(type, options);
  #|        this._submitter = Object.prototype.hasOwnProperty.call(options, 'submitter')
  #|          ? options.submitter
  #|          : null;
  #|      }
  #|      get submitter() { return this._submitter; }
  #|    }
  #|    globalThis.SubmitEvent = SubmitEvent;
  #|    if (typeof window !== 'undefined') {
  #|      window.SubmitEvent = SubmitEvent;
  #|    }
  #|  }
  #|  Object.defineProperties(ElementInternals.prototype, {
  #|    shadowRoot: {
  #|      get() {
  #|        return this._host ? (this._host.__elementInternalsShadowRoot || null) : null;
  #|      }
  #|    },
  #|    form: { get() { return null; } },
  #|    willValidate: { get() { return false; } },
  #|    validity: { get() { return this._validity; } },
  #|    validationMessage: { get() { return this._validationMessage; } },
  #|    labels: { get() { return []; } },
  #|    states: {
  #|      get() {
  #|        if (!this._statesSet) this._statesSet = new CustomStateSet(this._host);
  #|        return this._statesSet;
  #|      }
  #|    }
  #|  });
  #|
  #|  function attachInternalsImpl() {
  #|    const localName = String(this.localName || this._localName || this.tagName || '').toLowerCase();
  #|    if (localName.indexOf('-') < 0) {
  #|      throw new DOMException('attachInternals is only supported on custom elements', 'NotSupportedError');
  #|    }
  #|    if (this.__elementInternals) {
  #|      throw new DOMException('ElementInternals already attached', 'NotSupportedError');
  #|    }
  #|    const internals = new ElementInternals(this);
  #|    this.__elementInternals = internals;
  #|    this.__elementInternalsShadowRoot = this.shadowRoot || null;
  #|    return internals;
  #|  }
  #|
  #|  function defineValidationSurface(element) {
  #|    if (!element || element.__craterValidationSurface) return;
  #|    const localName = String(element.localName || element._localName || element.tagName || '').toLowerCase();
  #|    if (localName === 'form') {
  #|      Object.defineProperty(element, 'noValidate', {
  #|        get() { return !!(this.hasAttribute && this.hasAttribute('novalidate')); },
  #|        set(v) { setBooleanAttribute(this, 'novalidate', v); },
  #|        configurable: true,
  #|      });
  #|      element.reset = function() {
  #|        const event = new Event('reset', { bubbles: true, cancelable: true });
  #|        if (!this.dispatchEvent(event)) return;
  #|        resetFormControls(this);
  #|      };
  #|      element.submit = function() {
  #|        return undefined;
  #|      };
  #|      element.checkValidity = function() {
  #|        return validateFormForSubmission(this, true, null);
  #|      };
  #|      element.reportValidity = function() {
  #|        return validateFormForSubmission(this, true, null);
  #|      };
  #|      element.requestSubmit = function(submitter) {
  #|        if (submitter !== undefined && submitter !== null) {
  #|          if (!isSubmitButtonElement(submitter)) {
  #|            throw new TypeError(
  #|              "Failed to execute 'requestSubmit' on 'HTMLFormElement': parameter 1 is not a submit button"
  #|            );
  #|          }
  #|          if (resolveFormOwnerForSubmitter(submitter) !== this) {
  #|            throw new DOMException(
  #|              "Failed to execute 'requestSubmit' on 'HTMLFormElement': the specified element is not owned by this form element",
  #|              'NotFoundError'
  #|            );
  #|          }
  #|        }
  #|        const normalizedSubmitter = submitter === undefined ? null : submitter;
  #|        if (!validateFormForSubmission(this, true, normalizedSubmitter)) return undefined;
  #|        const event = new SubmitEvent('submit', {
  #|          bubbles: true,
  #|          cancelable: true,
  #|          submitter: normalizedSubmitter,
  #|        });
  #|        this.dispatchEvent(event);
  #|        return undefined;
  #|      };
  #|    } else if (localName === 'input' || localName === 'textarea' || localName === 'select' || localName === 'button') {
  #|      Object.defineProperties(element, {
  #|        willValidate: {
  #|          get() { return computeControlWillValidate(this); },
  #|          configurable: true,
  #|        },
  #|        validity: {
  #|          get() { return computeValidationStateForElement(this).validity; },
  #|          configurable: true,
  #|        },
  #|        validationMessage: {
  #|          get() { return computeValidationStateForElement(this).message; },
  #|          configurable: true,
  #|        },
  #|      });
  #|      element.setCustomValidity = function(message) {
  #|        this.__customValidationMessage = message === undefined || message === null ? '' : String(message);
  #|      };
  #|      element.checkValidity = function() {
  #|        return checkFormControlValidity(this, true);
  #|      };
  #|      element.reportValidity = function() {
  #|        return checkFormControlValidity(this, true);
  #|      };
  #|      if (localName === 'input' || localName === 'button') {
  #|        Object.defineProperty(element, 'formNoValidate', {
  #|          get() { return !!(this.hasAttribute && this.hasAttribute('formnovalidate')); },
  #|          set(v) { setBooleanAttribute(this, 'formnovalidate', v); },
  #|          configurable: true,
  #|        });
  #|      }
  #|    }
  #|    element.__craterValidationSurface = true;
  #|  }
  #|
  #|  function patchElement(element) {
  #|    if (!element || element.nodeType !== 1) return element;
  #|    element.attachInternals = attachInternalsImpl;
  #|    const localName = String(element.localName || element._localName || element.tagName || '').toLowerCase();
  #|    defineValidationSurface(element);
  #|    if (localName === 'input') {
  #|      wrapPatchedProperty(element, 'value', rememberInputDefaultValue);
  #|      wrapPatchedProperty(element, 'checked', rememberInputDefaultChecked);
  #|    } else if (localName === 'textarea') {
  #|      wrapPatchedProperty(element, 'value', rememberTextAreaDefaultValue);
  #|    } else if (localName === 'option') {
  #|      wrapPatchedProperty(element, 'selected', rememberOptionDefaultSelected);
  #|    }
  #|    if (!element.__craterClickWrapped) {
  #|      element.click = function() {
  #|        if (this.hasAttribute && this.hasAttribute('disabled')) return;
  #|        const event = typeof MouseEvent === 'function'
  #|          ? new MouseEvent('click', { bubbles: true, cancelable: true, composed: true })
  #|          : new Event('click', { bubbles: true, cancelable: true });
  #|        const allowed = this.dispatchEvent(event);
  #|        if (!allowed) return;
  #|        if (isSubmitButtonElement(this)) {
  #|          const form = resolveFormOwnerForSubmitter(this);
  #|          if (form && typeof form.requestSubmit === 'function') {
  #|            form.requestSubmit(this);
  #|          }
  #|          return;
  #|        }
  #|        if (isResetButtonElement(this)) {
  #|          const form = resolveFormOwnerForSubmitter(this);
  #|          if (form && typeof form.reset === 'function') {
  #|            form.reset();
  #|          }
  #|        }
  #|      };
  #|      element.__craterClickWrapped = true;
  #|    }
  #|    if (typeof element.attachShadow === 'function' && !element.__craterInternalsShadowWrapped) {
  #|      const originalAttachShadow = element.attachShadow;
  #|      element.attachShadow = function(init) {
  #|        const shadow = originalAttachShadow.call(this, init);
  #|        if (this.__elementInternals) {
  #|          this.__elementInternalsShadowRoot = shadow;
  #|        }
  #|        return shadow;
  #|      };
  #|      element.__craterInternalsShadowWrapped = true;
  #|    }
  #|    return element;
  #|  }
  #|
  #|  function patchTree(node) {
  #|    if (!node) return;
  #|    if (node.nodeType === 1) patchElement(node);
  #|    if (node.shadowRoot) patchTree(node.shadowRoot);
  #|    if (!node.childNodes) return;
  #|    for (let i = 0; i < node.childNodes.length; i++) {
  #|      patchTree(node.childNodes[i]);
  #|    }
  #|  }
  #|
  #|  const originalCreateElement = document.createElement.bind(document);
  #|  document.createElement = function(tagName, options) {
  #|    return patchElement(originalCreateElement(tagName, options));
  #|  };
  #|  const originalCreateElementNS = document.createElementNS ? document.createElementNS.bind(document) : null;
  #|  if (originalCreateElementNS) {
  #|    document.createElementNS = function(ns, qualifiedName, options) {
  #|      return patchElement(originalCreateElementNS(ns, qualifiedName, options));
  #|    };
  #|  }
  #|
  #|  patchTree(document.documentElement);
  #|  patchTree(document.head);
  #|  patchTree(document.body);
  #|
  #|  globalThis.CustomStateSet = CustomStateSet;
  #|  globalThis.ElementInternals = ElementInternals;
  #|  if (typeof window !== 'undefined') {
  #|    window.CustomStateSet = CustomStateSet;
  #|    window.ElementInternals = ElementInternals;
  #|    window.SubmitEvent = globalThis.SubmitEvent;
  #|  }
  #|})();

///|
impl @js.JsRuntime for V8JsRuntime with init(self : V8JsRuntime) -> Unit {
  if !self.initialized {
    match @v8.runtime_new() {
      Ok(rt) => {
        self.runtime = Some(rt)
        self.initialized = true
        // If mock DOM source is provided, it defines its own console/logs.
        // Otherwise, set up basic console capture.
        match self.mock_dom_source {
          Some(_) => () // Console setup deferred to mock DOM init
          None => ignore(rt.eval_string(console_setup_js))
        }
      }
      Err(_) => ()
    }
  }
}

///|
impl @js.JsRuntime for V8JsRuntime with execute(
  self : V8JsRuntime,
  _context_id : Int,
  dom : @dom.DomTree,
  code : String,
  async_mode : @js.AsyncExecutionMode,
) -> @js.JsResult raise @js.JsError {
  let rt = match self.runtime {
    Some(rt) => rt
    None => raise @js.JsError::execution_error("V8 runtime not initialized")
  }
  // Initialize mock DOM on first execute if source is available
  if !self.dom_initialized {
    match self.mock_dom_source {
      Some(src) =>
        match rt.eval_string(src) {
          Ok(_) => {
            self.dom_initialized = true
            // Bridge: mock DOM uses `logs` array, __getLogs reads from it
            ignore(rt.eval_string(logs_bridge_js))
            ignore(rt.eval_string(element_internals_polyfill_js))
          }
          Err(e) =>
            raise @js.JsError::execution_error(
              "mock DOM init failed: " + e.to_string(),
            )
        }
      None => ()
    }
  }
  // If mock DOM is loaded, initialize DOM on first call only
  if self.dom_initialized {
    // Reset logs and domOps for this execution
    ignore(rt.eval_string("logs.length = 0; domOps.length = 0;"))
    // Serialize DomTree into JS DOM only on first execute (avoid duplicating nodes)
    if !self.dom_synced {
      let init_code = @js.create_dom_init_code(dom)
      match rt.eval_string(init_code) {
        Ok(_) => ()
        Err(e) => println("[V8 initCode error] " + e.to_string())
      }
      populate_id_map(dom, self.id_map)
      self.dom_synced = true
    }
  }
  // Execute user code
  let flush = match async_mode {
    @js.ImmediateFlush => true
    @js.DeferredFlush => false
  }
  // Step 1: Execute user code and capture result
  let exec_code = "try {\n  globalThis.__lastResult = (function() { " +
    code +
    "\n})();\n  globalThis.__lastSuccess = true;\n} catch(e) {\n  globalThis.__lastError = e.message || String(e);\n  globalThis.__lastSuccess = false;\n}"
  ignore(rt.eval_string(exec_code))
  // Step 2: Flush microtasks (mock DOM's _SyncPromise + V8 native)
  // Mock DOM replaces Promise with _SyncPromise which uses _flushMicrotasks()
  if self.dom_initialized {
    ignore(rt.eval_string("_flushMicrotasks()"))
  }
  ignore(rt.perform_microtask_checkpoint())
  // Step 3: Flush mock DOM timers (setTimeout) with microtask interleaving
  if flush && self.dom_initialized {
    for i = 0; i < 100; i = i + 1 {
      match rt.eval_string("_runOneTimeout()") {
        Ok(v) => if v != "true" { break }
        Err(_) => break
      }
      ignore(rt.perform_microtask_checkpoint())
    }
  }
  // Step 4: Collect results
  let collect_code = if self.dom_initialized {
    "(function() {\n  const __logsResult = __getLogs();\n  const v = globalThis.__lastSuccess\n    ? JSON.stringify({ success: true, value: globalThis.__lastResult === undefined ? 'undefined' : String(globalThis.__lastResult), logs: JSON.parse(__logsResult), domOps: domOps || [] })\n    : JSON.stringify({ success: false, error: globalThis.__lastError || 'unknown', logs: JSON.parse(__logsResult), domOps: domOps || [] });\n  return v;\n})()"
  } else {
    "(function() {\n  const __logsResult = __getLogs();\n  const v = globalThis.__lastSuccess\n    ? JSON.stringify({ success: true, value: globalThis.__lastResult === undefined ? 'undefined' : String(globalThis.__lastResult), logs: JSON.parse(__logsResult) })\n    : JSON.stringify({ success: false, error: globalThis.__lastError || 'unknown', logs: JSON.parse(__logsResult) });\n  return v;\n})()"
  }
  match rt.eval_string(collect_code) {
    Ok(result_json) =>
      if self.dom_initialized {
        let (result, dom_ops) = parse_result_with_ops(result_json)
        if dom_ops.length() > 0 {
          apply_dom_ops(dom, dom_ops, self.id_map)
        }
        result
      } else {
        parse_v8_result(result_json)
      }
    Err(v8_err) => {
      let logs = collect_logs(rt)
      @js.JsResult::new(v8_err.to_string(), logs, false)
    }
  }
}

///|
impl @js.JsRuntime for V8JsRuntime with tick(
  self : V8JsRuntime,
  _context_id : Int,
  dom : @dom.DomTree,
) -> @js.JsResult raise @js.JsError {
  match self.runtime {
    Some(rt) => {
      ignore(rt.perform_microtask_checkpoint())
      if self.dom_initialized {
        // Run one timer + flush microtasks
        let tick_code = "logs.length = 0; domOps.length = 0;\nconst __hadWork = _runOneTimeout() || _runOneAnimationFrame();\n_flushMicrotasks();\nJSON.stringify({ success: true, value: String(__hadWork), logs: logs.slice(), domOps: domOps.slice() })"
        match rt.eval_string(tick_code) {
          Ok(json) => {
            let (result, dom_ops) = parse_result_with_ops(json)
            apply_dom_ops(dom, dom_ops, self.id_map)
            result
          }
          Err(_) => @js.JsResult::new("false", [], true)
        }
      } else {
        let logs = collect_logs(rt)
        @js.JsResult::new("false", logs, true)
      }
    }
    None => @js.JsResult::new("false", [], true)
  }
}

// ============================================================
// ID map management
// ============================================================

///|
/// Populate id_map with identity mappings for all existing DomTree nodes.
/// The mock DOM's `create_dom_init_code` sets `_mockId = domtree_id` for
/// serialized elements, so existing nodes have mock_id == domtree_id.
fn populate_id_map(dom : @dom.DomTree, id_map : Map[Int, @dom.NodeId]) -> Unit {
  // Clear previous mappings
  id_map.clear()
  // Traverse all existing nodes by walking the tree from document root
  populate_id_map_recursive(dom, dom.get_document(), id_map)
}

///|
fn populate_id_map_recursive(
  dom : @dom.DomTree,
  node_id : @dom.NodeId,
  id_map : Map[Int, @dom.NodeId],
) -> Unit {
  let id_int = node_id.to_int()
  id_map[id_int] = node_id
  match dom.get_children(node_id) {
    Ok(children) =>
      for child in children {
        populate_id_map_recursive(dom, child, id_map)
      }
    Err(_) => ()
  }
}

// ============================================================
// DOM operation parsing and application
// ============================================================

///|
priv struct DomOp {
  op : String
  id : Int
  parent_id : Int
  child_id : Int
  ref_id : Int
  tag_name : String
  text : String
  name : String
  value : String
  delegates_focus : Bool
  slot_assignment : String
  clonable : Bool
  serializable : Bool
}

///|
fn parse_result_with_ops(json : String) -> (@js.JsResult, Array[DomOp]) {
  let success = json.contains("\"success\":true")
  let value = if success {
    extract_json_field(json, "value")
  } else {
    extract_json_field(json, "error")
  }
  let logs = extract_json_array(json, "logs")
  let dom_ops = parse_dom_ops(json)
  (@js.JsResult::new(value, logs, success), dom_ops)
}

///|
fn parse_dom_ops(json : String) -> Array[DomOp] {
  let ops : Array[DomOp] = []
  let pattern = "\"domOps\":["
  match json.find(pattern) {
    Some(start) => {
      let array_start = start + pattern.length()
      let chars = json.to_array()
      let mut i = array_start
      let mut depth = 0
      let mut obj_start = -1
      while i < chars.length() {
        let c = chars[i]
        if c == '{' {
          if depth == 0 {
            obj_start = c.to_int()
            ignore(obj_start)
            obj_start = i
          }
          depth += 1
        } else if c == '}' {
          depth -= 1
          if depth == 0 && obj_start >= 0 {
            let obj_str = json[obj_start:i + 1].to_string()
            ops.push(parse_single_dom_op(obj_str))
            obj_start = -1
          }
        } else if c == ']' && depth == 0 {
          break
        }
        i += 1
      }
    }
    None => ()
  }
  ops
}

///|
fn parse_single_dom_op(json : String) -> DomOp {
  {
    op: extract_json_field(json, "op"),
    id: parse_json_int(json, "id"),
    parent_id: parse_json_int(json, "parentId"),
    child_id: parse_json_int(json, "childId"),
    ref_id: parse_json_int(json, "refId"),
    tag_name: extract_json_field(json, "tagName"),
    text: extract_json_field(json, "text"),
    name: extract_json_field(json, "name"),
    value: extract_json_field(json, "value"),
    delegates_focus: parse_json_bool(json, "delegatesFocus"),
    slot_assignment: extract_json_field(json, "slotAssignment"),
    clonable: parse_json_bool(json, "clonable"),
    serializable: parse_json_bool(json, "serializable"),
  }
}

///|
fn parse_json_int(json : String, field : String) -> Int {
  let pattern = "\"" + field + "\":"
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let chars = json.to_array()
      let mut i = value_start
      // Skip whitespace
      while i < chars.length() && (chars[i] == ' ' || chars[i] == '\t') {
        i += 1
      }
      let mut result = 0
      let mut neg = false
      if i < chars.length() && chars[i] == '-' {
        neg = true
        i += 1
      }
      while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
        result = result * 10 + (chars[i].to_int() - '0'.to_int())
        i += 1
      }
      if neg {
        -result
      } else {
        result
      }
    }
    None => 0
  }
}

///|
fn parse_json_bool(json : String, field : String) -> Bool {
  let pattern = "\"" + field + "\":"
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let remaining = json.unsafe_substring(
        start=value_start,
        end=json.length(),
      )
      remaining.has_prefix("true")
    }
    None => false
  }
}

///|
fn parse_custom_states_value(value : String) -> Array[String] {
  let states : Array[String] = []
  if value.is_empty() {
    return states
  }
  for part in value.split(" ") {
    let state = part.trim().to_string()
    if !state.is_empty() {
      states.push(state)
    }
  }
  states
}

///|
fn apply_dom_ops(
  dom : @dom.DomTree,
  ops : Array[DomOp],
  id_map : Map[Int, @dom.NodeId],
) -> Unit {
  ensure_mock_document_shell(dom, id_map)
  for op in ops {
    match op.op {
      "createElement" => {
        let node_id = dom.create_element(op.tag_name)
        // Map mock DOM id to actual DomTree id
        id_map[op.id] = node_id
      }
      "createTextNode" => {
        let node_id = dom.create_text(op.text)
        id_map[op.id] = node_id
      }
      "createDocumentFragment" => {
        let node_id = dom.create_document_fragment()
        id_map[op.id] = node_id
      }
      "attachShadow" => {
        let host = id_map.get(op.parent_id)
        let shadow_root = id_map.get(op.child_id)
        match (host, shadow_root) {
          (Some(host), Some(shadow_root)) => {
            let init = @dom.ShadowRootInit::new(
              mode=op.value,
              delegates_focus=op.delegates_focus,
              slot_assignment=if op.slot_assignment.length() > 0 {
                op.slot_assignment
              } else {
                "named"
              },
              clonable=op.clonable,
              serializable=op.serializable,
            )
            ignore(
              dom.attach_existing_shadow_root_with_init(host, shadow_root, init),
            )
          }
          _ => ()
        }
      }
      "appendChild" => {
        let parent = id_map.get(op.parent_id)
        let child = id_map.get(op.child_id)
        match (parent, child) {
          (Some(p), Some(c)) => ignore(dom.append_child(p, c))
          _ => ()
        }
      }
      "removeChild" => {
        let parent = id_map.get(op.parent_id)
        let child = id_map.get(op.child_id)
        match (parent, child) {
          (Some(p), Some(c)) => ignore(dom.remove_child(p, c))
          _ => ()
        }
      }
      "insertBefore" => {
        let parent = id_map.get(op.parent_id)
        let child = id_map.get(op.child_id)
        let ref_node = if op.ref_id != 0 { id_map.get(op.ref_id) } else { None }
        match (parent, child) {
          (Some(p), Some(c)) => ignore(dom.insert_before(p, c, ref_node))
          _ => ()
        }
      }
      "replaceChild" => {
        // replaceChild: parentId, childId (new), refId (old)
        let parent = id_map.get(op.parent_id)
        let new_child = id_map.get(op.child_id)
        let old_child = id_map.get(op.ref_id)
        match (parent, new_child, old_child) {
          (Some(p), Some(nc), Some(oc)) => {
            // Insert new before old, then remove old
            ignore(dom.insert_before(p, nc, Some(oc)))
            ignore(dom.remove_child(p, oc))
          }
          _ => ()
        }
      }
      "setAttribute" =>
        match id_map.get(op.id) {
          Some(node) => ignore(dom.set_attribute(node, op.name, op.value))
          None => ()
        }
      "removeAttribute" =>
        match id_map.get(op.id) {
          Some(node) => ignore(dom.remove_attribute(node, op.name))
          None => ()
        }
      "setCustomStates" =>
        match id_map.get(op.id) {
          Some(node) =>
            ignore(
              dom.set_custom_states(node, parse_custom_states_value(op.value)),
            )
          None => ()
        }
      "setTextContent" =>
        match id_map.get(op.id) {
          Some(node) => {
            let text = if op.value.length() > 0 { op.value } else { op.text }
            ignore(dom.set_text_content(node, text))
          }
          None => ()
        }
      _ => () // Unknown op, skip
    }
  }
}

///|
fn ensure_mock_document_shell(
  dom : @dom.DomTree,
  id_map : Map[Int, @dom.NodeId],
) -> Unit {
  let doc = dom.get_document()
  if !id_map.contains(1) {
    match dom.create_runtime_node(1, @dom.Element, tag_name="html") {
      Ok(html) => {
        id_map[1] = html
        ignore(dom.append_child(doc, html))
      }
      Err(_) => ()
    }
  }
  let html = id_map.get(1)
  if !id_map.contains(2) {
    match (html, dom.create_runtime_node(2, @dom.Element, tag_name="body")) {
      (Some(html), Ok(body)) => {
        id_map[2] = body
        ignore(dom.append_child(html, body))
      }
      _ => ()
    }
  }
}

// ============================================================
// JSON parsing helpers
// ============================================================

///|
fn collect_logs(rt : @v8.Runtime) -> Array[String] {
  match rt.eval_string("__getLogs()") {
    Ok(json) => parse_string_array(json)
    Err(_) => []
  }
}

///|
fn parse_v8_result(json : String) -> @js.JsResult {
  let success = json.contains("\"success\":true")
  let value = if success {
    extract_json_field(json, "value")
  } else {
    extract_json_field(json, "error")
  }
  let logs = extract_json_array(json, "logs")
  @js.JsResult::new(value, logs, success)
}

///|
fn extract_json_field(json : String, field : String) -> String {
  let pattern = "\"" + field + "\":\""
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let chars = json.to_array()
      let mut i = value_start
      while i < chars.length() {
        if chars[i] == '"' && (i == value_start || chars[i - 1] != '\\') {
          break
        }
        i += 1
      }
      unescape_json_string(json[value_start:i].to_string())
    }
    None => ""
  }
}

///|
fn extract_json_array(json : String, field : String) -> Array[String] {
  let pattern = "\"" + field + "\":["
  match json.find(pattern) {
    Some(start) => {
      let array_start = start + pattern.length()
      let chars = json.to_array()
      let result : Array[String] = []
      let mut i = array_start
      while i < chars.length() && chars[i] != ']' {
        if chars[i] == '"' {
          let str_start = i + 1
          let mut str_end = str_start
          while str_end < chars.length() {
            if chars[str_end] == '"' &&
              (str_end == str_start || chars[str_end - 1] != '\\') {
              break
            }
            str_end += 1
          }
          result.push(unescape_json_string(json[str_start:str_end].to_string()))
          i = str_end + 1
        } else {
          i += 1
        }
      }
      result
    }
    None => []
  }
}

///|
fn parse_string_array(json : String) -> Array[String] {
  if json.length() < 2 {
    return []
  }
  let result : Array[String] = []
  let chars = json.to_array()
  let mut i = 0
  while i < chars.length() && chars[i] != '[' {
    i += 1
  }
  i += 1
  while i < chars.length() && chars[i] != ']' {
    if chars[i] == '"' {
      i += 1
      let start = i
      while i < chars.length() {
        if chars[i] == '"' && (i == start || chars[i - 1] != '\\') {
          break
        }
        i += 1
      }
      result.push(unescape_json_string(json[start:i].to_string()))
      i += 1
    } else {
      i += 1
    }
  }
  result
}

///|
fn unescape_json_string(value : String) -> String {
  let chars = value.to_array()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' && i + 1 < chars.length() {
      i += 1
      match chars[i] {
        '"' => buf.write_char('"')
        '\\' => buf.write_char('\\')
        '/' => buf.write_char('/')
        'b' => buf.write_char('\b')
        'f' => buf.write_char('\f')
        'n' => buf.write_char('\n')
        'r' => buf.write_char('\r')
        't' => buf.write_char('\t')
        _ => {
          buf.write_char('\\')
          buf.write_char(chars[i])
        }
      }
    } else {
      buf.write_char(chars[i])
    }
    i += 1
  }
  buf.to_string()
}
