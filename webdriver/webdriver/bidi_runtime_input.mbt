///|
/// Dispatch synthetic keyboard event and keep `allEvents` in sync for WPT pages.
extern "js" fn js_input_dispatch_key_action(
  action_type : String,
  raw_value : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit =
  #| (actionType, rawValue, ctrl, alt, shift, meta) => {
  #|   const value = String(rawValue ?? "");
  #|   const special = {
  #|     "\uE000": { key: "Unidentified", code: "", location: 0, printable: false, text: "" },
  #|     "\uE001": { key: "Cancel", code: "", location: 0, printable: false, text: "" },
  #|     "\uE002": { key: "Help", code: "Help", location: 0, printable: false, text: "" },
  #|     "\uE003": { key: "Backspace", code: "Backspace", which: 8, location: 0, printable: false, text: "" },
  #|     "\uE004": { key: "Tab", code: "Tab", which: 9, location: 0, printable: false, text: "" },
  #|     "\uE005": { key: "Clear", code: "", location: 0, printable: false, text: "" },
  #|     "\uE006": { key: "Enter", code: "Enter", which: 13, location: 0, printable: false, text: "" },
  #|     "\uE007": { key: "Enter", code: "NumpadEnter", which: 13, location: 1, printable: false, text: "" },
  #|     "\uE008": { key: "Shift", code: "ShiftLeft", which: 16, location: 1, printable: false, text: "" },
  #|     "Shift": { key: "Shift", code: "ShiftLeft", which: 16, location: 1, printable: false, text: "" },
  #|     "ShiftLeft": { key: "Shift", code: "ShiftLeft", which: 16, location: 1, printable: false, text: "" },
  #|     "shift": { key: "Shift", code: "ShiftLeft", which: 16, location: 1, printable: false, text: "" },
  #|     "\uE009": { key: "Control", code: "ControlLeft", which: 17, location: 1, printable: false, text: "" },
  #|     "Control": { key: "Control", code: "ControlLeft", which: 17, location: 1, printable: false, text: "" },
  #|     "ControlLeft": { key: "Control", code: "ControlLeft", which: 17, location: 1, printable: false, text: "" },
  #|     "control": { key: "Control", code: "ControlLeft", which: 17, location: 1, printable: false, text: "" },
  #|     "\uE00A": { key: "Alt", code: "AltLeft", which: 18, location: 1, printable: false, text: "" },
  #|     "Alt": { key: "Alt", code: "AltLeft", which: 18, location: 1, printable: false, text: "" },
  #|     "AltLeft": { key: "Alt", code: "AltLeft", which: 18, location: 1, printable: false, text: "" },
  #|     "alt": { key: "Alt", code: "AltLeft", which: 18, location: 1, printable: false, text: "" },
  #|     "\uE00B": { key: "Pause", code: "Pause", location: 0, printable: false, text: "" },
  #|     "\uE00C": { key: "Escape", code: "Escape", which: 27, location: 0, printable: false, text: "" },
  #|     "\uE00D": { key: " ", code: "Space", which: 32, location: 0, printable: true, text: " " },
  #|     "\uE00E": { key: "PageUp", code: "PageUp", location: 0, printable: false, text: "" },
  #|     "\uE00F": { key: "PageDown", code: "PageDown", location: 0, printable: false, text: "" },
  #|     "\uE010": { key: "End", code: "End", location: 0, printable: false, text: "" },
  #|     "\uE011": { key: "Home", code: "Home", location: 0, printable: false, text: "" },
  #|     "\uE012": { key: "ArrowLeft", code: "ArrowLeft", location: 0, printable: false, text: "" },
  #|     "\uE013": { key: "ArrowUp", code: "ArrowUp", location: 0, printable: false, text: "" },
  #|     "\uE014": { key: "ArrowRight", code: "ArrowRight", location: 0, printable: false, text: "" },
  #|     "\uE015": { key: "ArrowDown", code: "ArrowDown", location: 0, printable: false, text: "" },
  #|     "\uE016": { key: "Insert", code: "Insert", location: 0, printable: false, text: "" },
  #|     "\uE017": { key: "Delete", code: "Delete", location: 0, printable: false, text: "" },
  #|     "\uE018": { key: ";", code: "", location: 0, printable: true, text: ";" },
  #|     "\uE019": { key: "=", code: "NumpadEqual", location: 3, printable: true, text: "=" },
  #|     "\uE01A": { key: "0", code: "Numpad0", location: 3, printable: true, text: "0" },
  #|     "\uE01B": { key: "1", code: "Numpad1", location: 3, printable: true, text: "1" },
  #|     "\uE01C": { key: "2", code: "Numpad2", location: 3, printable: true, text: "2" },
  #|     "\uE01D": { key: "3", code: "Numpad3", location: 3, printable: true, text: "3" },
  #|     "\uE01E": { key: "4", code: "Numpad4", location: 3, printable: true, text: "4" },
  #|     "\uE01F": { key: "5", code: "Numpad5", location: 3, printable: true, text: "5" },
  #|     "\uE020": { key: "6", code: "Numpad6", location: 3, printable: true, text: "6" },
  #|     "\uE021": { key: "7", code: "Numpad7", location: 3, printable: true, text: "7" },
  #|     "\uE022": { key: "8", code: "Numpad8", location: 3, printable: true, text: "8" },
  #|     "\uE023": { key: "9", code: "Numpad9", location: 3, printable: true, text: "9" },
  #|     "\uE024": { key: "*", code: "NumpadMultiply", location: 3, printable: true, text: "*" },
  #|     "\uE025": { key: "+", code: "NumpadAdd", location: 3, printable: true, text: "+" },
  #|     "\uE026": { key: ",", code: "NumpadComma", location: 3, printable: true, text: "," },
  #|     "\uE027": { key: "-", code: "NumpadSubtract", location: 3, printable: true, text: "-" },
  #|     "\uE028": { key: ".", code: "NumpadDecimal", location: 3, printable: true, text: "." },
  #|     "\uE029": { key: "/", code: "NumpadDivide", location: 3, printable: true, text: "/" },
  #|     "\uE031": { key: "F1", code: "F1", location: 0, printable: false, text: "" },
  #|     "\uE032": { key: "F2", code: "F2", location: 0, printable: false, text: "" },
  #|     "\uE033": { key: "F3", code: "F3", location: 0, printable: false, text: "" },
  #|     "\uE034": { key: "F4", code: "F4", location: 0, printable: false, text: "" },
  #|     "\uE035": { key: "F5", code: "F5", location: 0, printable: false, text: "" },
  #|     "\uE036": { key: "F6", code: "F6", location: 0, printable: false, text: "" },
  #|     "\uE037": { key: "F7", code: "F7", location: 0, printable: false, text: "" },
  #|     "\uE038": { key: "F8", code: "F8", location: 0, printable: false, text: "" },
  #|     "\uE039": { key: "F9", code: "F9", location: 0, printable: false, text: "" },
  #|     "\uE03A": { key: "F10", code: "F10", location: 0, printable: false, text: "" },
  #|     "\uE03B": { key: "F11", code: "F11", location: 0, printable: false, text: "" },
  #|     "\uE03C": { key: "F12", code: "F12", location: 0, printable: false, text: "" },
  #|     "\uE03D": { key: "Meta", code: "MetaLeft", which: 91, location: 1, printable: false, text: "" },
  #|     "Meta": { key: "Meta", code: "MetaLeft", which: 91, location: 1, printable: false, text: "" },
  #|     "MetaLeft": { key: "Meta", code: "MetaLeft", which: 91, location: 1, printable: false, text: "" },
  #|     "meta": { key: "Meta", code: "MetaLeft", which: 91, location: 1, printable: false, text: "" },
  #|     "\uE040": { key: "ZenkakuHankaku", code: "", location: 0, printable: false, text: "" },
  #|     "\uE050": { key: "Shift", code: "ShiftRight", which: 16, location: 2, printable: false, text: "" },
  #|     "\uE051": { key: "Control", code: "ControlRight", which: 17, location: 2, printable: false, text: "" },
  #|     "\uE052": { key: "Alt", code: "AltRight", which: 18, location: 2, printable: false, text: "" },
  #|     "\uE053": { key: "Meta", code: "MetaRight", which: 91, location: 2, printable: false, text: "" },
  #|     "\uE054": { key: "PageUp", code: "Numpad9", location: 3, printable: false, text: "" },
  #|     "\uE055": { key: "PageDown", code: "Numpad3", location: 3, printable: false, text: "" },
  #|     "\uE056": { key: "End", code: "Numpad1", location: 3, printable: false, text: "" },
  #|     "\uE057": { key: "Home", code: "Numpad7", location: 3, printable: false, text: "" },
  #|     "\uE058": { key: "ArrowLeft", code: "Numpad4", location: 3, printable: false, text: "" },
  #|     "\uE059": { key: "ArrowUp", code: "Numpad8", location: 3, printable: false, text: "" },
  #|     "\uE05A": { key: "ArrowRight", code: "Numpad6", location: 3, printable: false, text: "" },
  #|     "\uE05B": { key: "ArrowDown", code: "Numpad2", location: 3, printable: false, text: "" },
  #|     "\uE05C": { key: "Insert", code: "Numpad0", location: 3, printable: false, text: "" },
  #|     "\uE05D": { key: "Delete", code: "NumpadDecimal", location: 3, printable: false, text: "" },
  #|   };
  #|   const resolved = special[value];
  #|   let key = resolved ? resolved.key : value;
  #|   let code = resolved ? resolved.code : "";
  #|   let which = resolved ? (resolved.which ?? 0) : 0;
  #|   let location = resolved ? resolved.location : 0;
  #|   let printable = resolved ? !!resolved.printable : true;
  #|   let text = resolved ? resolved.text : value;
  #|
  #|   if (!resolved) {
  #|     const printableCode = {
  #|       "\"": "Quote",
  #|       ",": "Comma",
  #|       "@": "Digit2",
  #|     };
  #|     if (value === " ") {
  #|       key = " ";
  #|       code = "Space";
  #|       which = 32;
  #|     } else if (/^[a-zA-Z]$/.test(value)) {
  #|       code = "Key" + value.toUpperCase();
  #|       which = value.toUpperCase().charCodeAt(0);
  #|     } else if (/^[0-9]$/.test(value)) {
  #|       code = "Digit" + value;
  #|       which = value.charCodeAt(0);
  #|     } else if (Object.prototype.hasOwnProperty.call(printableCode, value)) {
  #|       code = printableCode[value];
  #|       which = value.charCodeAt(0);
  #|     } else if (value.length > 0) {
  #|       which = value.charCodeAt(0);
  #|     }
  #|   }
  #|   if (which === 0 && key.length === 1) {
  #|     which = key.charCodeAt(0);
  #|   }
  #|
  #|   const doc = globalThis.document;
  #|   if (!doc) return;
  #|   const resolveDeepActiveElement = () => {
  #|     let current = doc.activeElement || null;
  #|     const visited = new Set();
  #|     while (current && !visited.has(current)) {
  #|       visited.add(current);
  #|       let next = null;
  #|       try {
  #|         if (current.shadowRoot && current.shadowRoot.activeElement) {
  #|           next = current.shadowRoot.activeElement;
  #|         }
  #|       } catch (_e) {}
  #|       if (!next) {
  #|         const globalShadow = globalThis._shadowRoot;
  #|         try {
  #|           if (globalShadow && globalShadow.activeElement) {
  #|             next = globalShadow.activeElement;
  #|           }
  #|         } catch (_e) {}
  #|       }
  #|       if (!next) break;
  #|       current = next;
  #|     }
  #|     return current;
  #|   };
  #|   let focused = globalThis.__bidiFocusedElement || null;
  #|   if (focused) {
  #|     const focusedDoc = focused.ownerDocument || null;
  #|     let detached = false;
  #|     if (focusedDoc && focusedDoc !== doc) {
  #|       detached = true;
  #|     } else if (focused && focused.isConnected === false) {
  #|       detached = true;
  #|     } else if (typeof doc.contains === "function") {
  #|       try {
  #|         detached = !doc.contains(focused);
  #|       } catch (_e) {}
  #|     }
  #|     if (detached) {
  #|       focused = null;
  #|       try { globalThis.__bidiFocusedElement = null; } catch (_e) {}
  #|     }
  #|   }
  #|   let element = focused || resolveDeepActiveElement();
  #|   const hasExplicitTarget = !!focused;
  #|   if (!element) {
  #|     element =
  #|       doc.activeElement ||
  #|       doc.body ||
  #|       doc.documentElement ||
  #|       doc;
  #|   }
  #|   if (!element) return;
  #|   if (hasExplicitTarget && typeof element.focus === "function") {
  #|     try { element.focus(); } catch (_e) {}
  #|   }
  #|   const getSequentialContainingShadowRoot = (node) => {
  #|     let current = node;
  #|     while (current) {
  #|       if (current._isShadowRoot) return current;
  #|       current = current._parent || current.parentNode || null;
  #|     }
  #|     return null;
  #|   };
  #|   const getSequentialChildren = (node) => {
  #|     if (!node || typeof node !== "object") return [];
  #|     const getAttr = (target, name) => {
  #|       if (!target || typeof target !== "object") return null;
  #|       try {
  #|         if (typeof target.getAttribute === "function") {
  #|           const value = target.getAttribute(name);
  #|           if (value !== null && value !== undefined) return String(value);
  #|         }
  #|       } catch (_e) {}
  #|       if (target._attrs && Object.prototype.hasOwnProperty.call(target._attrs, name)) {
  #|         const value = target._attrs[name];
  #|         return value === null || value === undefined ? null : String(value);
  #|       }
  #|       return null;
  #|     };
  #|     const isSlotElement = (target) => {
  #|       if (!target || target.nodeType !== 1) return false;
  #|       const localName = String(target.localName || target.tagName || target.nodeName || "").toLowerCase();
  #|       return localName === "slot";
  #|     };
  #|     const getDirectChildren = (target) => {
  #|       if (!target || typeof target !== "object") return [];
  #|       if (Array.isArray(target._children)) return target._children;
  #|       if (Array.isArray(target.children)) return Array.from(target.children);
  #|       if (Array.isArray(target.childNodes)) return Array.from(target.childNodes);
  #|       return [];
  #|     };
  #|     const findFirstSlotForName = (root, slotName) => {
  #|       const children = getDirectChildren(root);
  #|       for (let i = 0; i < children.length; i += 1) {
  #|         const child = children[i];
  #|         if (!child || child.nodeType !== 1) continue;
  #|         if (isSlotElement(child) && String(getAttr(child, "name") || "") === slotName) {
  #|           return child;
  #|         }
  #|         const nested = findFirstSlotForName(child, slotName);
  #|         if (nested) return nested;
  #|       }
  #|       return null;
  #|     };
  #|     const getAssignedChildrenForSlot = (slot) => {
  #|       const shadowRoot = getSequentialContainingShadowRoot(slot);
  #|       if (!shadowRoot || !shadowRoot.host) return getDirectChildren(slot);
  #|       const slotName = String(getAttr(slot, "name") || "");
  #|       const firstMatch = findFirstSlotForName(shadowRoot, slotName);
  #|       if (firstMatch && firstMatch !== slot) return [];
  #|       const assigned = [];
  #|       const hostChildren = getDirectChildren(shadowRoot.host);
  #|       for (let i = 0; i < hostChildren.length; i += 1) {
  #|         const child = hostChildren[i];
  #|         if (!child) continue;
  #|         const childSlotName = String(getAttr(child, "slot") || "");
  #|         if (childSlotName === slotName) assigned.push(child);
  #|       }
  #|       return assigned.length > 0 ? assigned : getDirectChildren(slot);
  #|     };
  #|     if (isSlotElement(node)) return getAssignedChildrenForSlot(node);
  #|     const shadowRoot = node.shadowRoot || null;
  #|     if (shadowRoot && Array.isArray(shadowRoot._children)) return shadowRoot._children;
  #|     return getDirectChildren(node);
  #|   };
  #|   const hasExplicitTabIndex = (node) => {
  #|     if (!node || typeof node !== "object") return false;
  #|     try {
  #|       if (typeof node.getAttribute === "function" && node.getAttribute("tabindex") !== null) {
  #|         return true;
  #|       }
  #|     } catch (_e) {}
  #|     return !!(node._attrs && Object.prototype.hasOwnProperty.call(node._attrs, "tabindex"));
  #|   };
  #|   const isSequentiallyFocusable = (node) => {
  #|     if (!node || node.nodeType !== 1) return false;
  #|     if (node.disabled) return false;
  #|     if (node.hidden) return false;
  #|     const style = node.style || {};
  #|     if (style.display === "none" || style.visibility === "hidden") return false;
  #|     if (hasExplicitTabIndex(node)) {
  #|       try {
  #|         return Number(node.tabIndex) >= 0;
  #|       } catch (_e) {
  #|         return false;
  #|       }
  #|     }
  #|     const tag = String(node.tagName || node.nodeName || "").toLowerCase();
  #|     if (["input", "textarea", "select", "button"].includes(tag)) return true;
  #|     if (tag === "a") {
  #|       try {
  #|         return !!(typeof node.getAttribute === "function" ? node.getAttribute("href") : null);
  #|       } catch (_e) {
  #|         return false;
  #|       }
  #|     }
  #|     return !!node.isContentEditable;
  #|   };
  #|   const collectSequentialFocusables = (node, results) => {
  #|     const children = getSequentialChildren(node);
  #|     for (let i = 0; i < children.length; i += 1) {
  #|       const child = children[i];
  #|       if (!child || child.nodeType !== 1) continue;
  #|       if (isSequentiallyFocusable(child)) results.push(child);
  #|       collectSequentialFocusables(child, results);
  #|     }
  #|   };
  #|   const moveSequentialFocus = (backward) => {
  #|     const root = doc.body || doc.documentElement || doc;
  #|     const order = [];
  #|     collectSequentialFocusables(root, order);
  #|     if (order.length === 0) return false;
  #|     const current = resolveDeepActiveElement();
  #|     const currentIndex = order.indexOf(current);
  #|     let nextIndex = 0;
  #|     if (currentIndex >= 0) {
  #|       nextIndex = currentIndex + (backward ? -1 : 1);
  #|       if (nextIndex < 0 || nextIndex >= order.length) return false;
  #|     } else if (backward) {
  #|       nextIndex = order.length - 1;
  #|     }
  #|     const next = order[nextIndex];
  #|     if (!next || typeof next.focus !== "function") return false;
  #|     try { next.focus(); } catch (_e) { return false; }
  #|     try { globalThis.__bidiFocusedElement = next; } catch (_e) {}
  #|     return true;
  #|   };
  #|
  #|   const makeEvent = (type) => {
  #|     const event = globalThis.__bidiCreateEvent(type, { bubbles: true, cancelable: true });
  #|     event.key = key;
  #|     event.code = code;
  #|     event.which = which;
  #|     event.keyCode = which;
  #|     event.location = location;
  #|     event.ctrlKey = !!ctrl;
  #|     event.altKey = !!alt;
  #|     event.shiftKey = !!shift;
  #|     event.metaKey = !!meta;
  #|     event.repeat = false;
  #|     return event;
  #|   };
  #|
  #|   let windowAllEvents =
  #|     globalThis.window &&
  #|     globalThis.window.allEvents &&
  #|     Array.isArray(globalThis.window.allEvents.events)
  #|       ? globalThis.window.allEvents
  #|       : null;
  #|   if (
  #|     !windowAllEvents &&
  #|     typeof allEvents !== "undefined" &&
  #|     allEvents &&
  #|     Array.isArray(allEvents.events)
  #|   ) {
  #|     windowAllEvents = allEvents;
  #|     if (globalThis.window && typeof globalThis.window === "object") {
  #|       try { globalThis.window.allEvents = windowAllEvents; } catch (_e) {}
  #|     }
  #|   }
  #|   const hadAllEvents = !!windowAllEvents;
  #|   if (hadAllEvents) {
  #|     globalThis.allEvents = windowAllEvents;
  #|   } else {
  #|     globalThis.allEvents = { events: [] };
  #|   }
  #|   if (globalThis.__bidiContextWindows && typeof globalThis.__bidiContextWindows.forEach === "function") {
  #|     try {
  #|       globalThis.__bidiContextWindows.forEach((ctxWindow) => {
  #|         try { ctxWindow.allEvents = globalThis.allEvents; } catch (_e) {}
  #|       });
  #|     } catch (_e) {}
  #|   }
  #|   if (globalThis.window && typeof globalThis.window === "object") {
  #|     try { globalThis.window.allEvents = globalThis.allEvents; } catch (_e) {}
  #|   }
  #|   const fallbackEnabled = !!(
  #|     globalThis.window &&
  #|     globalThis.window.__craterAllEventsFallbackInit
  #|   );
  #|   const shouldRecordFallback =
  #|     fallbackEnabled &&
  #|     hasExplicitTarget &&
  #|     !!(globalThis.allEvents && Array.isArray(globalThis.allEvents.events));
  #|   const pushFallback = (type) => {
  #|     if (!shouldRecordFallback) return;
  #|     globalThis.allEvents.events.push({
  #|       type,
  #|       code,
  #|       key,
  #|       which,
  #|       location,
  #|       ctrl: !!ctrl,
  #|       alt: !!alt,
  #|       meta: !!meta,
  #|       shift: !!shift,
  #|       repeat: false,
  #|       altKey: !!alt,
  #|       ctrlKey: !!ctrl,
  #|       metaKey: !!meta,
  #|       shiftKey: !!shift,
  #|     });
  #|   };
  #|   const dispatchWithFallback = (type) => {
  #|     const beforeCount = shouldRecordFallback ? globalThis.allEvents.events.length : 0;
  #|     const allowed = element.dispatchEvent(makeEvent(type));
  #|     if (shouldRecordFallback && globalThis.allEvents.events.length === beforeCount) {
  #|       pushFallback(type);
  #|     }
  #|     return allowed;
  #|   };
  #|   const getSelection = () => {
  #|     const value = typeof element.value === "string" ? element.value : "";
  #|     let start = typeof element.selectionStart === "number" ? element.selectionStart : null;
  #|     let end = typeof element.selectionEnd === "number" ? element.selectionEnd : null;
  #|     if (start === null || end === null) {
  #|       start = typeof element.__bidiSelectionStart === "number" ? element.__bidiSelectionStart : value.length;
  #|       end = typeof element.__bidiSelectionEnd === "number" ? element.__bidiSelectionEnd : value.length;
  #|     }
  #|     start = Math.max(0, Math.min(value.length, Number(start)));
  #|     end = Math.max(0, Math.min(value.length, Number(end)));
  #|     if (end < start) {
  #|       const tmp = start;
  #|       start = end;
  #|       end = tmp;
  #|     }
  #|     return { start, end, value };
  #|   };
  #|   const setSelection = (start, end) => {
  #|     const value = typeof element.value === "string" ? element.value : "";
  #|     const safeStart = Math.max(0, Math.min(value.length, Number(start)));
  #|     const safeEnd = Math.max(0, Math.min(value.length, Number(end)));
  #|     try { element.selectionStart = safeStart; } catch (_e) {}
  #|     try { element.selectionEnd = safeEnd; } catch (_e) {}
  #|     element.__bidiSelectionStart = safeStart;
  #|     element.__bidiSelectionEnd = safeEnd;
  #|   };
  #|   const replaceSelection = (insertText) => {
  #|     const { start, end, value } = getSelection();
  #|     const next = value.slice(0, start) + String(insertText ?? "") + value.slice(end);
  #|     element.value = next;
  #|     const caret = start + String(insertText ?? "").length;
  #|     setSelection(caret, caret);
  #|   };
  #|   const dispatchInputLike = (type, inputType, data) => {
  #|     const event = globalThis.__bidiCreateEvent(type, {
  #|       bubbles: true,
  #|       cancelable: type === "beforeinput",
  #|     });
  #|     event.inputType = String(inputType || "");
  #|     event.data = data == null ? null : String(data);
  #|     return element.dispatchEvent(event);
  #|   };
  #|   const replaceSelectionWithEvents = (insertText, inputType) => {
  #|     const textValue = String(insertText ?? "");
  #|     if (!dispatchInputLike("beforeinput", inputType, textValue)) {
  #|       return false;
  #|     }
  #|     replaceSelection(textValue);
  #|     dispatchInputLike("input", inputType, textValue);
  #|     return true;
  #|   };
  #|   const deleteSelectionWithEvents = (inputType, start, end) => {
  #|     if (!dispatchInputLike("beforeinput", inputType, null)) {
  #|       return false;
  #|     }
  #|     setSelection(start, end);
  #|     replaceSelection("");
  #|     dispatchInputLike("input", inputType, null);
  #|     return true;
  #|   };
  #|   const tagName = String(element.tagName || element.nodeName || "").toLowerCase();
  #|   const dispatchSimpleEvent = (type) => {
  #|     const event = globalThis.__bidiCreateEvent(type, { bubbles: true, cancelable: false });
  #|     return element.dispatchEvent(event);
  #|   };
  #|   const optionList = () => {
  #|     if (Array.isArray(element.options)) return element.options;
  #|     if (Array.isArray(element._children)) {
  #|       return element._children.filter((child) => {
  #|         const childTag = String(child && (child.tagName || child.nodeName) || "").toLowerCase();
  #|         return childTag === "option";
  #|       });
  #|     }
  #|     return [];
  #|   };
  #|   const syncSelectChoice = (nextIndex) => {
  #|     const options = optionList();
  #|     if (!options.length) return false;
  #|     const safeIndex = Math.max(0, Math.min(options.length - 1, Number(nextIndex)));
  #|     const currentIndex =
  #|       typeof element.selectedIndex === "number"
  #|         ? Number(element.selectedIndex)
  #|         : options.findIndex((option) => !!option.selected);
  #|     if (currentIndex === safeIndex) return false;
  #|     options.forEach((option, index) => {
  #|       option.selected = index === safeIndex;
  #|     });
  #|     element.selectedIndex = safeIndex;
  #|     const selected = options[safeIndex];
  #|     element.value =
  #|       selected && selected.value != null && selected.value !== ""
  #|         ? String(selected.value)
  #|         : String((selected && selected.textContent) || "");
  #|     dispatchSimpleEvent("input");
  #|     dispatchSimpleEvent("change");
  #|     return true;
  #|   };
  #|
  #|   if (actionType === "keyDown") {
  #|     const keydownAllowed = dispatchWithFallback("keydown");
  #|     if (key === "Tab") {
  #|       if (keydownAllowed) {
  #|         moveSequentialFocus(!!shift);
  #|       }
  #|       return;
  #|     }
  #|
  #|     const usesShortcut = (ctrl || meta) && !alt;
  #|     const lowerKey = key.length === 1 ? key.toLowerCase() : key;
  #|     if (usesShortcut && lowerKey === "a") {
  #|       if (typeof element.value === "string") {
  #|         setSelection(0, element.value.length);
  #|       }
  #|       return;
  #|     }
  #|     if (usesShortcut && lowerKey === "c") {
  #|       const { start, end, value } = getSelection();
  #|       globalThis.__bidiClipboardText = value.slice(start, end);
  #|       return;
  #|     }
  #|     if (usesShortcut && lowerKey === "x") {
  #|       const { start, end, value } = getSelection();
  #|       globalThis.__bidiClipboardText = value.slice(start, end);
  #|       deleteSelectionWithEvents("deleteByCut", start, end);
  #|       return;
  #|     }
  #|     if (usesShortcut && lowerKey === "v") {
  #|       const clip = typeof globalThis.__bidiClipboardText === "string" ? globalThis.__bidiClipboardText : "";
  #|       replaceSelectionWithEvents(clip, "insertFromPaste");
  #|       return;
  #|     }
  #|     if (key === "ArrowRight") {
  #|       const { start, end, value } = getSelection();
  #|       if (start !== end) {
  #|         setSelection(end, end);
  #|       } else {
  #|         const next = Math.min(value.length, end + 1);
  #|         setSelection(next, next);
  #|       }
  #|       return;
  #|     }
  #|     if (tagName === "select" && (key === "ArrowDown" || key === "ArrowUp")) {
  #|       const options = optionList();
  #|       if (options.length > 0) {
  #|         const currentIndex =
  #|           typeof element.selectedIndex === "number"
  #|             ? Number(element.selectedIndex)
  #|             : options.findIndex((option) => !!option.selected);
  #|         const baseIndex = currentIndex >= 0 ? currentIndex : -1;
  #|         const delta = key === "ArrowDown" ? 1 : -1;
  #|         syncSelectChoice(baseIndex + delta);
  #|       }
  #|       return;
  #|     }
  #|     if (key === "Backspace") {
  #|       const { start, end, value } = getSelection();
  #|       if (start !== end) {
  #|         deleteSelectionWithEvents("deleteContentBackward", start, end);
  #|       } else if (value.length > 0 && start > 0) {
  #|         deleteSelectionWithEvents("deleteContentBackward", start - 1, start);
  #|       } else if (value.length > 0 && start === value.length) {
  #|         deleteSelectionWithEvents("deleteContentBackward", value.length - 1, value.length);
  #|       }
  #|     } else if (key === "Delete") {
  #|       const { start, end, value } = getSelection();
  #|       if (start !== end) {
  #|         deleteSelectionWithEvents("deleteContentForward", start, end);
  #|       } else if (start < value.length) {
  #|         deleteSelectionWithEvents("deleteContentForward", start, start + 1);
  #|       }
  #|     } else if (printable && text.length > 0 && !usesShortcut && !alt) {
  #|       let insertText = text;
  #|       if (shift && insertText.length === 1 && /^[a-z]$/.test(insertText)) {
  #|         insertText = insertText.toUpperCase();
  #|       }
  #|       replaceSelectionWithEvents(insertText, "insertText");
  #|       dispatchWithFallback("keypress");
  #|     }
  #|     return;
  #|   }
  #|
  #|   dispatchWithFallback("keyup");
  #| }

///|
/// Dispatch synthetic keyboard event and keep `allEvents` in sync for WPT pages.
pub fn input_dispatch_key_action(
  action_type : String,
  raw_value : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit {
  js_input_dispatch_key_action(action_type, raw_value, ctrl, alt, shift, meta)
}

///|
/// Check whether string contains exactly one grapheme cluster.
extern "js" fn js_input_is_single_grapheme(value : String) -> Bool =
  #| (value) => {
  #|   const text = String(value ?? "");
  #|   if (text.length === 0) return false;
  #|   if (typeof Intl !== "undefined" && typeof Intl.Segmenter === "function") {
  #|     try {
  #|       const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });
  #|       const segments = Array.from(segmenter.segment(text));
  #|       return segments.length === 1;
  #|     } catch (_e) {}
  #|   }
  #|   return Array.from(text).length === 1;
  #| }

///|
/// Check whether string contains exactly one grapheme cluster.
pub fn input_is_single_grapheme(value : String) -> Bool {
  js_input_is_single_grapheme(value)
}
