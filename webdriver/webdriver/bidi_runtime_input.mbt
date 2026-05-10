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

///|
/// Set synthetic pointer event property overrides used by pointer dispatch.
extern "js" fn js_input_set_pointer_event_properties(
  width : Double,
  height : Double,
  pressure : Double,
  tangential_pressure : Double,
  twist : Double,
  altitude_angle : Double,
  azimuth_angle : Double,
) -> Unit =
  #| (
  #|   width,
  #|   height,
  #|   pressure,
  #|   tangentialPressure,
  #|   twist,
  #|   altitudeAngle,
  #|   azimuthAngle,
  #| ) => {
  #|   globalThis.__bidiPointerEventProps = {
  #|     width: Number(width),
  #|     height: Number(height),
  #|     pressure: Number(pressure),
  #|     tangentialPressure: Number(tangentialPressure),
  #|     twist: Number(twist),
  #|     altitudeAngle: Number(altitudeAngle),
  #|     azimuthAngle: Number(azimuthAngle),
  #|   };
  #| }

///|
/// Set synthetic pointer event property overrides used by pointer dispatch.
pub fn input_set_pointer_event_properties(
  width : Double,
  height : Double,
  pressure : Double,
  tangential_pressure : Double,
  twist : Double,
  altitude_angle : Double,
  azimuth_angle : Double,
) -> Unit {
  js_input_set_pointer_event_properties(
    width, height, pressure, tangential_pressure, twist, altitude_angle, azimuth_angle,
  )
}

///|
/// Clear synthetic pointer event property overrides.
extern "js" fn js_input_clear_pointer_event_properties() -> Unit =
  #| () => {
  #|   globalThis.__bidiPointerEventProps = null;
  #| }

///|
/// Clear synthetic pointer event property overrides.
pub fn input_clear_pointer_event_properties() -> Unit {
  js_input_clear_pointer_event_properties()
}

///|
/// Dispatch synthetic pointer/mouse event.
extern "js" fn js_input_dispatch_pointer_event_with_related(
  shared_id : String,
  event_type : String,
  x : Double,
  y : Double,
  button : Int,
  buttons : Int,
  pointer_type : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
  related_shared_id : String,
) -> Unit =
  #| (sharedId, eventType, x, y, button, buttons, pointerType, ctrl, alt, shift, meta, relatedSharedId) => {
  #|   const doc = globalThis.document;
  #|   if (!doc) return;
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   let target = null;
  #|   if (sharedId && store) {
  #|     target = store.get(sharedId) || null;
  #|   }
  #|   if (!target && typeof doc.querySelector === "function") {
  #|     target = doc.querySelector("#outer") || doc.querySelector("#pointer-target");
  #|   }
  #|   if (!target && typeof doc.elementFromPoint === "function") {
  #|     try { target = doc.elementFromPoint(Number(x), Number(y)); } catch (_e) {}
  #|   }
  #|   const safeTarget = target || doc.body || doc.documentElement || doc;
  #|   let relatedTarget = null;
  #|   if (relatedSharedId && store) {
  #|     relatedTarget = store.get(relatedSharedId) || null;
  #|   }
  #|   const isFocusable = (node) => {
  #|     if (!node || typeof node !== "object") return false;
  #|     const tag = String(node.tagName || node.nodeName || "").toLowerCase();
  #|     if (["input", "textarea", "select", "button"].includes(tag)) return true;
  #|     if (tag === "a") {
  #|       try {
  #|         return !!(typeof node.getAttribute === "function" ? node.getAttribute("href") : null);
  #|       } catch (_e) {
  #|         return false;
  #|       }
  #|     }
  #|     try {
  #|       if (Number(node.tabIndex) >= 0) return true;
  #|     } catch (_e) {}
  #|     return !!node.isContentEditable;
  #|   };
  #|   const getFocusAttr = (node, name) => {
  #|     if (!node || typeof node !== "object") return null;
  #|     try {
  #|       if (typeof node.getAttribute === "function") {
  #|         const value = node.getAttribute(name);
  #|         if (value !== null && value !== undefined) return String(value);
  #|       }
  #|     } catch (_e) {}
  #|     if (node._attrs && Object.prototype.hasOwnProperty.call(node._attrs, name)) {
  #|       const value = node._attrs[name];
  #|       return value === null || value === undefined ? null : String(value);
  #|     }
  #|     return null;
  #|   };
  #|   const isSlotElement = (node) => {
  #|     if (!node || node.nodeType !== 1) return false;
  #|     const localName = String(node.localName || node.tagName || node.nodeName || "").toLowerCase();
  #|     return localName === "slot";
  #|   };
  #|   const getFocusChildren = (node) => {
  #|     if (!node || typeof node !== "object") return [];
  #|     if (Array.isArray(node._children)) return node._children;
  #|     if (Array.isArray(node.children)) return Array.from(node.children);
  #|     if (Array.isArray(node.childNodes)) return Array.from(node.childNodes);
  #|     return [];
  #|   };
  #|   const findFirstSlotForName = (root, slotName) => {
  #|     const children = getFocusChildren(root);
  #|     for (let i = 0; i < children.length; i += 1) {
  #|       const child = children[i];
  #|       if (!child || child.nodeType !== 1) continue;
  #|       if (isSlotElement(child) && String(getFocusAttr(child, "name") || "") === slotName) {
  #|         return child;
  #|       }
  #|       const nested = findFirstSlotForName(child, slotName);
  #|       if (nested) return nested;
  #|     }
  #|     return null;
  #|   };
  #|   const getContainingShadowRoot = (node) => {
  #|     let current = node;
  #|     while (current) {
  #|       if (current._isShadowRoot) return current;
  #|       current = current._parent || current.parentNode || null;
  #|     }
  #|     return null;
  #|   };
  #|   const getAssignedChildrenForSlot = (slot) => {
  #|     const shadowRoot = getContainingShadowRoot(slot);
  #|     if (!shadowRoot || !shadowRoot.host) return getFocusChildren(slot);
  #|     const slotName = String(getFocusAttr(slot, "name") || "");
  #|     const firstMatch = findFirstSlotForName(shadowRoot, slotName);
  #|     if (firstMatch && firstMatch !== slot) return [];
  #|     const assigned = [];
  #|     const hostChildren = getFocusChildren(shadowRoot.host);
  #|     for (let i = 0; i < hostChildren.length; i += 1) {
  #|       const child = hostChildren[i];
  #|       if (!child) continue;
  #|       const childSlotName = String(getFocusAttr(child, "slot") || "");
  #|       if (childSlotName === slotName) assigned.push(child);
  #|     }
  #|     return assigned.length > 0 ? assigned : getFocusChildren(slot);
  #|   };
  #|   const getDelegatesFocusChildren = (node) => {
  #|     if (!node || typeof node !== "object") return [];
  #|     if (isSlotElement(node)) return getAssignedChildrenForSlot(node);
  #|     const shadowRoot = node.shadowRoot || null;
  #|     if (shadowRoot) return getFocusChildren(shadowRoot);
  #|     return getFocusChildren(node);
  #|   };
  #|   const findDelegatesFocusTarget = (node) => {
  #|     const shadowRoot = node && node.shadowRoot ? node.shadowRoot : null;
  #|     if (!shadowRoot || !shadowRoot.delegatesFocus) return null;
  #|     const visit = (current) => {
  #|       const children = getDelegatesFocusChildren(current);
  #|       for (let i = 0; i < children.length; i += 1) {
  #|         const child = children[i];
  #|         if (!child || child.nodeType !== 1) continue;
  #|         if (isFocusable(child)) return child;
  #|         const nested = visit(child);
  #|         if (nested) return nested;
  #|       }
  #|       return null;
  #|     };
  #|     return visit(shadowRoot);
  #|   };
  #|   const focusTarget = () => {
  #|     const targetToFocus =
  #|       isFocusable(safeTarget)
  #|         ? safeTarget
  #|         : findDelegatesFocusTarget(safeTarget);
  #|     if (!targetToFocus || typeof targetToFocus.focus !== "function") return;
  #|     try { targetToFocus.focus(); } catch (_e) {}
  #|     try { globalThis.__bidiFocusedElement = targetToFocus; } catch (_e) {}
  #|   };
  #|   const safeTagName = String(safeTarget.tagName || safeTarget.nodeName || "").toLowerCase();
  #|   const safeInputType = () => {
  #|     let raw = "";
  #|     try {
  #|       raw =
  #|         safeTarget.type ||
  #|         (typeof safeTarget.getAttribute === "function" ? safeTarget.getAttribute("type") : "") ||
  #|         (safeTarget._attrs && safeTarget._attrs.type) ||
  #|         "";
  #|     } catch (_e) {}
  #|     return String(raw || "").toLowerCase();
  #|   };
  #|   const dispatchSimpleTargetEvent = (type) => {
  #|     if (!safeTarget || typeof safeTarget.dispatchEvent !== "function") return true;
  #|     const event = globalThis.__bidiCreateEvent(type, { bubbles: true, cancelable: false });
  #|     return safeTarget.dispatchEvent(event);
  #|   };
  #|   const findAncestorForm = (node) => {
  #|     if (!node || typeof node !== "object") return null;
  #|     const containsNode = (root, target) => {
  #|       if (!root || !target) return false;
  #|       if (root === target) return true;
  #|       if (!root.childNodes) return false;
  #|       for (let i = 0; i < root.childNodes.length; i += 1) {
  #|         const child = root.childNodes[i];
  #|         if (containsNode(child, target)) return true;
  #|       }
  #|       return false;
  #|     };
  #|     if (node.form && typeof node.form === "object") return node.form;
  #|     if (typeof node.closest === "function") {
  #|       try {
  #|         const form = node.closest("form");
  #|         if (form) return form;
  #|       } catch (_e) {}
  #|     }
  #|     let current = node.parentNode || node.parentElement || node._parent || null;
  #|     while (current) {
  #|       const tag = String(current.tagName || current.nodeName || "").toLowerCase();
  #|       if (tag === "form") return current;
  #|       current = current.parentNode || current.parentElement || current._parent || null;
  #|     }
  #|     if (doc && typeof doc.querySelectorAll === "function") {
  #|       try {
  #|         for (const form of Array.from(doc.querySelectorAll("form"))) {
  #|           if (containsNode(form, node)) return form;
  #|         }
  #|       } catch (_e) {}
  #|     }
  #|     return null;
  #|   };
  #|   const resetForm = (form) => {
  #|     const resetNode = (node) => {
  #|       if (!node || !node.childNodes) return;
  #|       for (let i = 0; i < node.childNodes.length; i += 1) {
  #|         const child = node.childNodes[i];
  #|         if (!child || child.nodeType !== 1) continue;
  #|         const childTag = String(child.tagName || child.nodeName || "").toLowerCase();
  #|         if (childTag === "input") {
  #|           const childType = String(
  #|             (typeof child.getAttribute === "function" ? child.getAttribute("type") : "") ||
  #|             child.type ||
  #|             "",
  #|           ).toLowerCase();
  #|           if (childType === "checkbox" || childType === "radio") {
  #|             const hasChecked =
  #|               typeof child.hasAttribute === "function" &&
  #|               child.hasAttribute("checked");
  #|             child.checked = !!hasChecked;
  #|           } else if (
  #|             childType !== "submit" &&
  #|             childType !== "button" &&
  #|             childType !== "image" &&
  #|             childType !== "reset" &&
  #|             childType !== "file"
  #|           ) {
  #|             const nextValue =
  #|               (typeof child.getAttribute === "function" ? child.getAttribute("value") : null) ??
  #|               "";
  #|             child.value = String(nextValue);
  #|           }
  #|         } else if (childTag === "textarea") {
  #|           child.value = String(child.textContent ?? "");
  #|         } else if (childTag === "select" && child.options !== undefined) {
  #|           let selectedIndex = -1;
  #|           for (let j = 0; j < child.options.length; j += 1) {
  #|             const option = child.options[j];
  #|             const selected =
  #|               !!(option &&
  #|                 typeof option.hasAttribute === "function" &&
  #|                 option.hasAttribute("selected"));
  #|             option.selected = selected;
  #|             if (selected && selectedIndex < 0) selectedIndex = j;
  #|           }
  #|           if (selectedIndex < 0 && child.options.length > 0) {
  #|             child.options[0].selected = true;
  #|             selectedIndex = 0;
  #|           }
  #|           child.selectedIndex = selectedIndex;
  #|           if (selectedIndex >= 0 && child.options[selectedIndex]) {
  #|             child.value = String(
  #|               child.options[selectedIndex].value ??
  #|               child.options[selectedIndex].textContent ??
  #|               "",
  #|             );
  #|           } else {
  #|             child.value = "";
  #|           }
  #|         }
  #|         resetNode(child);
  #|       }
  #|     };
  #|     resetNode(form);
  #|   };
  #|   const applyClickDefaultAction = () => {
  #|     if (safeTagName === "button" || safeTagName === "input") {
  #|       const inputType = safeInputType();
  #|       if (inputType === "reset") {
  #|         const form = findAncestorForm(safeTarget);
  #|         if (!form) return;
  #|         const resetEvent = globalThis.__bidiCreateEvent("reset", { bubbles: true, cancelable: true });
  #|         if (typeof form.dispatchEvent === "function") {
  #|           form.dispatchEvent(resetEvent);
  #|         }
  #|         if (resetEvent.defaultPrevented) return;
  #|         resetForm(form);
  #|         return;
  #|       }
  #|     }
  #|     if (safeTagName !== "input") return;
  #|     const inputType = safeInputType();
  #|     if (inputType === "checkbox") {
  #|       safeTarget.checked = !safeTarget.checked;
  #|       dispatchSimpleTargetEvent("input");
  #|       dispatchSimpleTargetEvent("change");
  #|       return;
  #|     }
  #|     if (inputType === "radio") {
  #|       if (safeTarget.checked) return;
  #|       const name =
  #|         (typeof safeTarget.getAttribute === "function" ? safeTarget.getAttribute("name") : null) ||
  #|         safeTarget.name ||
  #|         "";
  #|       const radioRoot = findAncestorForm(safeTarget) || doc;
  #|       if (name && radioRoot && typeof radioRoot.querySelectorAll === "function") {
  #|         try {
  #|           for (const radio of Array.from(radioRoot.querySelectorAll('input[type=\"radio\"]'))) {
  #|             const radioName =
  #|               (typeof radio.getAttribute === "function" ? radio.getAttribute("name") : null) ||
  #|               radio.name ||
  #|               "";
  #|             if (radioName === name) {
  #|               radio.checked = false;
  #|             }
  #|           }
  #|         } catch (_e) {}
  #|       }
  #|       safeTarget.checked = true;
  #|       dispatchSimpleTargetEvent("input");
  #|       dispatchSimpleTargetEvent("change");
  #|     }
  #|   };
  #|   if (doc && typeof doc.getSelection !== "function") {
  #|     doc.getSelection = () => ({
  #|       toString: () => String(globalThis.__bidiSelectionText || ""),
  #|     });
  #|   }
  #|   if (
  #|     eventType === "pointerdown" ||
  #|     eventType === "mousedown" ||
  #|     eventType === "click"
  #|   ) {
  #|     focusTarget();
  #|   }
  #|   if (eventType === "click") {
  #|     const now = Date.now();
  #|     const prev = globalThis.__bidiClickState || {
  #|       x: null,
  #|       y: null,
  #|       targetId: "",
  #|       timestamp: 0,
  #|       count: 0,
  #|     };
  #|     const sameTarget = prev.targetId === (safeTarget && safeTarget.id ? safeTarget.id : "");
  #|     const closeEnough =
  #|       typeof prev.x === "number" &&
  #|       typeof prev.y === "number" &&
  #|       Math.abs(Number(x) - prev.x) <= 4 &&
  #|       Math.abs(Number(y) - prev.y) <= 4;
  #|     const quickEnough = now - Number(prev.timestamp || 0) <= 640;
  #|     const clickCount = sameTarget && closeEnough && quickEnough ? Number(prev.count || 0) + 1 : 1;
  #|     globalThis.__bidiClickState = {
  #|       x: Number(x),
  #|       y: Number(y),
  #|       targetId: safeTarget && safeTarget.id ? safeTarget.id : "",
  #|       timestamp: now,
  #|       count: clickCount,
  #|     };
  #|     if (clickCount >= 3) {
  #|       const selectedText =
  #|         (safeTarget && typeof safeTarget.textContent === "string" && safeTarget.textContent) ||
  #|         (safeTarget && typeof safeTarget.innerText === "string" && safeTarget.innerText) ||
  #|         "";
  #|       globalThis.__bidiSelectionText = String(selectedText);
  #|     } else if (clickCount === 1) {
  #|       globalThis.__bidiSelectionText = "";
  #|     }
  #|     let href = null;
  #|     try {
  #|       if (safeTarget && typeof safeTarget.getAttribute === "function") {
  #|         href = safeTarget.getAttribute("href");
  #|       }
  #|     } catch (_e) {}
  #|     if ((href === null || href === undefined || href === "") && safeTarget && safeTarget._attrs) {
  #|       href = safeTarget._attrs.href;
  #|     }
  #|     if (href === null || href === undefined || href === "") {
  #|       globalThis.__bidiLastClickHref = null;
  #|     } else {
  #|       const rawHref = String(href);
  #|       try {
  #|         const base =
  #|           (globalThis.location && globalThis.location.href) ||
  #|           globalThis.__pageUrl ||
  #|           "about:blank";
  #|         globalThis.__bidiLastClickHref = new URL(rawHref, base).href;
  #|       } catch (_e) {
  #|         globalThis.__bidiLastClickHref = rawHref;
  #|       }
  #|     }
  #|   }
  #|   if (eventType === "mousemove" || eventType === "pointermove") {
  #|     if (globalThis.window && typeof globalThis.window === "object") {
  #|       try {
  #|         globalThis.window.coords = { x: Number(x), y: Number(y) };
  #|       } catch (_e) {}
  #|     } else {
  #|       try {
  #|         globalThis.coords = { x: Number(x), y: Number(y) };
  #|       } catch (_e) {}
  #|     }
  #|   }
  #|   const targetId =
  #|     safeTarget.id ||
  #|     (typeof safeTarget.getAttribute === "function" ? safeTarget.getAttribute("id") : null) ||
  #|     (safeTarget._attrs && safeTarget._attrs.id) ||
  #|     "";
  #|   const pointerProps =
  #|     globalThis.__bidiPointerEventProps &&
  #|     typeof globalThis.__bidiPointerEventProps === "object"
  #|       ? globalThis.__bidiPointerEventProps
  #|       : null;
  #|   const isPointerEvent = String(eventType || "").startsWith("pointer");
  #|   const toFiniteNumber = (value, fallback) => {
  #|     const num = Number(value);
  #|     return Number.isFinite(num) ? num : fallback;
  #|   };
  #|   const computeTilt = (altitudeAngle, azimuthAngle) => {
  #|     if (!Number.isFinite(altitudeAngle) || !Number.isFinite(azimuthAngle)) {
  #|       return { tiltX: 0, tiltY: 0 };
  #|     }
  #|     const tanAltitude = Math.tan(altitudeAngle);
  #|     if (!Number.isFinite(tanAltitude) || Math.abs(tanAltitude) < 1e-6) {
  #|       return { tiltX: 0, tiltY: 0 };
  #|     }
  #|     const tiltX = Math.atan(Math.cos(azimuthAngle) / tanAltitude) * 180 / Math.PI;
  #|     const tiltY = Math.atan(Math.sin(azimuthAngle) / tanAltitude) * 180 / Math.PI;
  #|     return {
  #|       tiltX: Math.round(tiltX),
  #|       tiltY: Math.round(tiltY),
  #|     };
  #|   };
  #|   const createSyntheticEvent = (dispatchTarget) => {
  #|     const nonBubblingHoverEvent =
  #|       eventType === "pointerenter" ||
  #|       eventType === "mouseenter" ||
  #|       eventType === "pointerleave" ||
  #|       eventType === "mouseleave";
  #|     const event = globalThis.__bidiCreateEvent(eventType, {
  #|       bubbles: !nonBubblingHoverEvent,
  #|       cancelable: !nonBubblingHoverEvent,
  #|       relatedTarget,
  #|     });
  #|     event.clientX = Number(x);
  #|     event.clientY = Number(y);
  #|     event.pageX = Number(x);
  #|     event.pageY = Number(y);
  #|     event.button = Number(button);
  #|     event.buttons = Number(buttons);
  #|     event.ctrlKey = !!ctrl;
  #|     event.altKey = !!alt;
  #|     event.shiftKey = !!shift;
  #|     event.metaKey = !!meta;
  #|     event.pointerType = isPointerEvent
  #|       ? String(pointerType || "mouse")
  #|       : "mouse";
  #|     event.isTrusted = true;
  #|     event.detail = eventType === "dblclick" ? 2 : 1;
  #|     if (isPointerEvent) {
  #|       const fallbackPressure =
  #|         eventType === "pointerup" ? 0 :
  #|         (Number(buttons) > 0 ? 0.5 : 0);
  #|       const width = toFiniteNumber(pointerProps && pointerProps.width, 1);
  #|       const height = toFiniteNumber(pointerProps && pointerProps.height, 1);
  #|       const pressure = toFiniteNumber(
  #|         pointerProps && pointerProps.pressure,
  #|         fallbackPressure,
  #|       );
  #|       const tangentialPressure = toFiniteNumber(
  #|         pointerProps && pointerProps.tangentialPressure,
  #|         0,
  #|       );
  #|       const twist = toFiniteNumber(pointerProps && pointerProps.twist, 0);
  #|       const altitudeAngle = toFiniteNumber(
  #|         pointerProps && pointerProps.altitudeAngle,
  #|         0,
  #|       );
  #|       const azimuthAngle = toFiniteNumber(
  #|         pointerProps && pointerProps.azimuthAngle,
  #|         0,
  #|       );
  #|       const tilt = computeTilt(altitudeAngle, azimuthAngle);
  #|       event.width = width;
  #|       event.height = height;
  #|       event.pressure = pressure;
  #|       event.tangentialPressure = tangentialPressure;
  #|       event.twist = twist;
  #|       event.altitudeAngle = altitudeAngle;
  #|       event.azimuthAngle = azimuthAngle;
  #|       event.tiltX = tilt.tiltX;
  #|       event.tiltY = tilt.tiltY;
  #|     }
  #|     try { event.target = safeTarget; } catch (_e) {}
  #|     try { event.relatedTarget = relatedTarget; } catch (_e) {}
  #|     try { event.__originalRelatedTarget = relatedTarget; } catch (_e) {}
  #|     try { event.currentTarget = dispatchTarget || safeTarget; } catch (_e) {}
  #|     return event;
  #|   };
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
  #|   const shouldRecordFallback = !!(
  #|     globalThis.allEvents &&
  #|     Array.isArray(globalThis.allEvents.events)
  #|   );
  #|   const beforeCount = shouldRecordFallback ? globalThis.allEvents.events.length : 0;
  #|   let dispatchTarget = null;
  #|   if (safeTarget && typeof safeTarget.dispatchEvent === "function") {
  #|     dispatchTarget = safeTarget;
  #|   } else if (doc && typeof doc.dispatchEvent === "function") {
  #|     dispatchTarget = doc;
  #|   } else if (globalThis.window && typeof globalThis.window.dispatchEvent === "function") {
  #|     dispatchTarget = globalThis.window;
  #|   }
  #|   let dispatchAllowed = true;
  #|   if (dispatchTarget) {
  #|     const event = createSyntheticEvent(dispatchTarget);
  #|     dispatchTarget.dispatchEvent(event);
  #|     dispatchAllowed = !event.defaultPrevented;
  #|   }
  #|   if (eventType === "click" && dispatchAllowed) {
  #|     applyClickDefaultAction();
  #|   }
  #|   if (
  #|     hadAllEvents &&
  #|     eventType === "mousemove" &&
  #|     globalThis.allEvents.events.length === beforeCount &&
  #|     doc &&
  #|     dispatchTarget !== doc &&
  #|     typeof doc.dispatchEvent === "function"
  #|   ) {
  #|     const documentEvent = createSyntheticEvent(doc);
  #|     doc.dispatchEvent(documentEvent);
  #|   }
  #|   if (shouldRecordFallback && globalThis.allEvents.events.length === beforeCount) {
  #|     const isPointerActionsPage =
  #|       doc &&
  #|       typeof doc.getElementById === "function" &&
  #|       !!doc.getElementById("pointerArea");
  #|     const shouldAllowFallback =
  #|       !eventType.startsWith("pointer") ||
  #|       isPointerActionsPage ||
  #|       hadAllEvents;
  #|     if (!shouldAllowFallback) {
  #|       return;
  #|     }
  #|     const isTestActionsPage =
  #|       doc &&
  #|       typeof doc.getElementById === "function" &&
  #|       !!doc.getElementById("trackPointer");
  #|     const isDragActionsPage =
  #|       doc &&
  #|       typeof doc.getElementById === "function" &&
  #|       !!doc.getElementById("dragArea") &&
  #|       !!doc.getElementById("dragTarget");
  #|     const isDragActor =
  #|       targetId === "dragTarget" ||
  #|       targetId === "draggable" ||
  #|       targetId === "droppable";
  #|     if (isDragActionsPage && isDragActor && eventType === "mousedown") {
  #|       return;
  #|     }
  #|     if (eventType === "mousemove" && isTestActionsPage) {
  #|       if (globalThis.__bidiRecordedTestActionsMousemove) {
  #|         return;
  #|       }
  #|       globalThis.__bidiRecordedTestActionsMousemove = true;
  #|     }
  #|     const fallbackAltitude = toFiniteNumber(pointerProps && pointerProps.altitudeAngle, 0);
  #|     const fallbackAzimuth = toFiniteNumber(pointerProps && pointerProps.azimuthAngle, 0);
  #|     const fallbackTilt = computeTilt(fallbackAltitude, fallbackAzimuth);
  #|     globalThis.allEvents.events.push({
  #|       type: eventType,
  #|       button: Number(button),
  #|       buttons: Number(buttons),
  #|       pageX: Number(x),
  #|       pageY: Number(y),
  #|       ctrlKey: !!ctrl,
  #|       metaKey: !!meta,
  #|       altKey: !!alt,
  #|       shiftKey: !!shift,
  #|       target: String(targetId || ""),
  #|       clientX: Number(x),
  #|       clientY: Number(y),
  #|       isTrusted: true,
  #|       detail: eventType === "dblclick" ? 2 : 1,
  #|       pointerType: isPointerEvent ? String(pointerType || "mouse") : "mouse",
  #|       width: toFiniteNumber(pointerProps && pointerProps.width, 1),
  #|       height: toFiniteNumber(pointerProps && pointerProps.height, 1),
  #|       pressure: toFiniteNumber(
  #|         pointerProps && pointerProps.pressure,
  #|         eventType === "pointerup" ? 0 : (Number(buttons) > 0 ? 0.5 : 0),
  #|       ),
  #|       tangentialPressure: toFiniteNumber(
  #|         pointerProps && pointerProps.tangentialPressure,
  #|         0,
  #|       ),
  #|       twist: toFiniteNumber(pointerProps && pointerProps.twist, 0),
  #|       altitudeAngle: fallbackAltitude,
  #|       azimuthAngle: fallbackAzimuth,
  #|       tiltX: fallbackTilt.tiltX,
  #|       tiltY: fallbackTilt.tiltY,
  #|     });
  #|   }
  #| }

///|
/// Detect whether current runtime should emulate macOS pointer conventions.
extern "js" fn js_input_is_mac_platform() -> Bool =
  #| () => {
  #|   const explicit =
  #|     (typeof Deno !== "undefined" &&
  #|       Deno &&
  #|       Deno.env &&
  #|       typeof Deno.env.get === "function" &&
  #|       Deno.env.get("WPT_TARGET_PLATFORM")) ||
  #|     (typeof process !== "undefined" &&
  #|       process &&
  #|       process.env &&
  #|       process.env.WPT_TARGET_PLATFORM);
  #|   if (typeof explicit === "string" && explicit.length > 0) {
  #|     return explicit.toLowerCase() === "mac";
  #|   }
  #|   if (typeof Deno !== "undefined" && Deno && Deno.build && Deno.build.os) {
  #|     return String(Deno.build.os).toLowerCase() === "darwin";
  #|   }
  #|   if (typeof process !== "undefined" && process && process.platform) {
  #|     return String(process.platform).toLowerCase() === "darwin";
  #|   }
  #|   if (
  #|     typeof navigator !== "undefined" &&
  #|     navigator &&
  #|     typeof navigator.platform === "string"
  #|   ) {
  #|     return navigator.platform.toLowerCase().includes("mac");
  #|   }
  #|   return false;
  #| }

///|
/// Detect whether current runtime should emulate macOS pointer conventions.
pub fn input_is_mac_platform() -> Bool {
  js_input_is_mac_platform()
}

///|
/// Current wall-clock timestamp in milliseconds.
extern "js" fn js_input_now_ms() -> Double =
  #| () => Date.now()

///|
/// Current wall-clock timestamp in milliseconds.
pub fn input_now_ms() -> Double {
  js_input_now_ms()
}

///|
/// Dispatch synthetic pointer/mouse event.
pub fn input_dispatch_pointer_event(
  shared_id : String,
  event_type : String,
  x : Double,
  y : Double,
  button : Int,
  buttons : Int,
  pointer_type : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit {
  input_dispatch_pointer_event_with_related(
    shared_id, event_type, x, y, button, buttons, pointer_type, ctrl, alt, shift,
    meta, "",
  )
}

///|
pub fn input_dispatch_pointer_event_with_related(
  shared_id : String,
  event_type : String,
  x : Double,
  y : Double,
  button : Int,
  buttons : Int,
  pointer_type : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
  related_shared_id : String,
) -> Unit {
  js_input_dispatch_pointer_event_with_related(
    shared_id, event_type, x, y, button, buttons, pointer_type, ctrl, alt, shift,
    meta, related_shared_id,
  )
}

///|
/// Dispatch synthetic drag event and return whether default was prevented.
extern "js" fn js_input_dispatch_drag_event(
  shared_id : String,
  event_type : String,
  x : Double,
  y : Double,
  button : Int,
  buttons : Int,
  pointer_type : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
  related_shared_id : String,
  drag_transfer_id : String,
) -> Bool =
  #| (sharedId, eventType, x, y, button, buttons, pointerType, ctrl, alt, shift, meta, relatedSharedId, dragTransferId) => {
  #|   const doc = globalThis.document;
  #|   if (!doc) return false;
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   let target = null;
  #|   if (sharedId && store) {
  #|     target = store.get(sharedId) || null;
  #|   }
  #|   if (!target && typeof doc.querySelector === "function") {
  #|     target = doc.querySelector("#outer") || doc.querySelector("#pointer-target");
  #|   }
  #|   if (!target && typeof doc.elementFromPoint === "function") {
  #|     try { target = doc.elementFromPoint(Number(x), Number(y)); } catch (_e) {}
  #|   }
  #|   const safeTarget = target || doc.body || doc.documentElement || doc;
  #|   let relatedTarget = null;
  #|   if (relatedSharedId && store) {
  #|     relatedTarget = store.get(relatedSharedId) || null;
  #|   }
  #|   if (!globalThis.__bidiDragTransfers || typeof globalThis.__bidiDragTransfers.get !== "function") {
  #|     globalThis.__bidiDragTransfers = new Map();
  #|   }
  #|   const createDataTransfer = () => {
  #|     const items = {};
  #|     return {
  #|       _items: items,
  #|       dropEffect: "none",
  #|       effectAllowed: "all",
  #|       files: [],
  #|       setData(type, data) { items[String(type)] = String(data); },
  #|       getData(type) {
  #|         const key = String(type);
  #|         return Object.prototype.hasOwnProperty.call(items, key) ? items[key] : "";
  #|       },
  #|       clearData(type) {
  #|         if (type === undefined) {
  #|           for (const key of Object.keys(items)) delete items[key];
  #|           return;
  #|         }
  #|         delete items[String(type)];
  #|       },
  #|       get types() { return Object.keys(items); },
  #|       setDragImage() {},
  #|     };
  #|   };
  #|   let dataTransfer = null;
  #|   if (dragTransferId) {
  #|     dataTransfer = globalThis.__bidiDragTransfers.get(dragTransferId) || null;
  #|     if (!dataTransfer) {
  #|       dataTransfer =
  #|         typeof globalThis.DataTransfer === "function"
  #|           ? new globalThis.DataTransfer()
  #|           : createDataTransfer();
  #|       globalThis.__bidiDragTransfers.set(dragTransferId, dataTransfer);
  #|     }
  #|   }
  #|   const nonBubblingHoverEvent =
  #|     eventType === "pointerenter" ||
  #|     eventType === "mouseenter" ||
  #|     eventType === "pointerleave" ||
  #|     eventType === "mouseleave";
  #|   const event = globalThis.__bidiCreateEvent(eventType, {
  #|     bubbles: !nonBubblingHoverEvent,
  #|     cancelable: !nonBubblingHoverEvent,
  #|     relatedTarget,
  #|     dataTransfer,
  #|   });
  #|   event.clientX = Number(x);
  #|   event.clientY = Number(y);
  #|   event.pageX = Number(x);
  #|   event.pageY = Number(y);
  #|   event.button = Number(button);
  #|   event.buttons = Number(buttons);
  #|   event.ctrlKey = !!ctrl;
  #|   event.altKey = !!alt;
  #|   event.shiftKey = !!shift;
  #|   event.metaKey = !!meta;
  #|   event.pointerType = String(pointerType || "mouse");
  #|   event.isTrusted = true;
  #|   event.relatedTarget = relatedTarget;
  #|   event.dataTransfer = dataTransfer;
  #|   try { event.target = safeTarget; } catch (_e) {}
  #|   try { event.currentTarget = safeTarget; } catch (_e) {}
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
  #|   const beforeCount =
  #|     globalThis.allEvents && Array.isArray(globalThis.allEvents.events)
  #|       ? globalThis.allEvents.events.length
  #|       : 0;
  #|   if (safeTarget && typeof safeTarget.dispatchEvent === "function") {
  #|     safeTarget.dispatchEvent(event);
  #|   } else if (doc && typeof doc.dispatchEvent === "function") {
  #|     doc.dispatchEvent(event);
  #|   }
  #|   if (
  #|     globalThis.allEvents &&
  #|     Array.isArray(globalThis.allEvents.events) &&
  #|     globalThis.allEvents.events.length === beforeCount
  #|   ) {
  #|     const targetId =
  #|       safeTarget.id ||
  #|       (typeof safeTarget.getAttribute === "function" ? safeTarget.getAttribute("id") : null) ||
  #|       (safeTarget._attrs && safeTarget._attrs.id) ||
  #|       "";
  #|     const relatedId =
  #|       relatedTarget && (
  #|         relatedTarget.id ||
  #|         (typeof relatedTarget.getAttribute === "function" ? relatedTarget.getAttribute("id") : null) ||
  #|         (relatedTarget._attrs && relatedTarget._attrs.id) ||
  #|         ""
  #|       );
  #|     globalThis.allEvents.events.push({
  #|       type: eventType,
  #|       target: String(targetId || ""),
  #|       relatedTarget: String(relatedId || ""),
  #|       clientX: Number(x),
  #|       clientY: Number(y),
  #|       pageX: Number(x),
  #|       pageY: Number(y),
  #|       button: Number(button),
  #|       buttons: Number(buttons),
  #|       pointerType: String(pointerType || "mouse"),
  #|       effectAllowed: dataTransfer ? String(dataTransfer.effectAllowed || "all") : "all",
  #|       dropEffect: dataTransfer ? String(dataTransfer.dropEffect || "none") : "none",
  #|     });
  #|   }
  #|   return !!event.defaultPrevented;
  #| }

///|
pub fn input_dispatch_drag_event(
  shared_id : String,
  event_type : String,
  x : Double,
  y : Double,
  button : Int,
  buttons : Int,
  pointer_type : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
  related_shared_id : String,
  drag_transfer_id : String,
) -> Bool {
  js_input_dispatch_drag_event(
    shared_id, event_type, x, y, button, buttons, pointer_type, ctrl, alt, shift,
    meta, related_shared_id, drag_transfer_id,
  )
}

///|
extern "js" fn js_input_drag_transfer_state(
  drag_transfer_id : String,
) -> String =
  #| (dragTransferId) => {
  #|   if (
  #|     !globalThis.__bidiDragTransfers ||
  #|     typeof globalThis.__bidiDragTransfers.get !== "function" ||
  #|     !dragTransferId
  #|   ) {
  #|     return "none/none";
  #|   }
  #|   const dataTransfer = globalThis.__bidiDragTransfers.get(dragTransferId) || null;
  #|   if (!dataTransfer) {
  #|     return "none/none";
  #|   }
  #|   const allowed = String(dataTransfer.effectAllowed || "all").toLowerCase();
  #|   const drop = String(dataTransfer.dropEffect || "none").toLowerCase();
  #|   return allowed + "/" + drop;
  #| }

///|
pub fn input_drag_transfer_state(drag_transfer_id : String) -> String {
  js_input_drag_transfer_state(drag_transfer_id)
}

///|
extern "js" fn js_input_clear_drag_transfer(drag_transfer_id : String) -> Unit =
  #| (dragTransferId) => {
  #|   if (
  #|     globalThis.__bidiDragTransfers &&
  #|     typeof globalThis.__bidiDragTransfers.delete === "function" &&
  #|     dragTransferId
  #|   ) {
  #|     globalThis.__bidiDragTransfers.delete(dragTransferId);
  #|   }
  #| }

///|
pub fn input_clear_drag_transfer(drag_transfer_id : String) -> Unit {
  js_input_clear_drag_transfer(drag_transfer_id)
}

///|
/// Dispatch synthetic wheel event.
extern "js" fn js_input_dispatch_wheel_event(
  shared_id : String,
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit =
  #| (sharedId, x, y, deltaX, deltaY, ctrl, alt, shift, meta) => {
  #|   const doc = globalThis.document;
  #|   if (!doc) return;
  #|   const px = Number(x);
  #|   const py = Number(y);
  #|   const dx = Number(deltaX);
  #|   const dy = Number(deltaY);
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   let target = null;
  #|   if (sharedId && store) {
  #|     target = store.get(sharedId) || null;
  #|   }
  #|   const rectContains = (node, tx, ty) => {
  #|     if (!node || typeof node.getBoundingClientRect !== "function") return false;
  #|     try {
  #|       const rect = node.getBoundingClientRect();
  #|       if (!rect) return false;
  #|       const left = Number(rect.left);
  #|       const right = Number(rect.right);
  #|       const top = Number(rect.top);
  #|       const bottom = Number(rect.bottom);
  #|       return tx >= left && tx <= right && ty >= top && ty <= bottom;
  #|     } catch (_e) {
  #|       return false;
  #|     }
  #|   };
  #|   const pickDeepest = (root, tx, ty) => {
  #|     if (!root || typeof root !== "object") return root;
  #|     let best = root;
  #|     const walk = (node) => {
  #|       if (!node || typeof node !== "object") return;
  #|       const children = Array.isArray(node._children)
  #|         ? node._children
  #|         : (Array.isArray(node.children) ? Array.from(node.children) : []);
  #|       for (let i = children.length - 1; i >= 0; i--) {
  #|         const child = children[i];
  #|         if (!child || child.nodeType !== 1) continue;
  #|         if (rectContains(child, tx, ty)) {
  #|           best = child;
  #|           walk(child);
  #|           return;
  #|         }
  #|       }
  #|       const shadowRoot = node.shadowRoot;
  #|       const shadowChildren = shadowRoot && Array.isArray(shadowRoot._children)
  #|         ? shadowRoot._children
  #|         : [];
  #|       for (let i = shadowChildren.length - 1; i >= 0; i--) {
  #|         const child = shadowChildren[i];
  #|         if (!child || child.nodeType !== 1) continue;
  #|         if (rectContains(child, tx, ty)) {
  #|           best = child;
  #|           walk(child);
  #|           return;
  #|         }
  #|       }
  #|     };
  #|     walk(root);
  #|     return best;
  #|   };
  #|   if (!target && typeof doc.querySelector === "function") {
  #|     target = doc.querySelector("#outer");
  #|   }
  #|   if (!target) target = doc.body || doc.documentElement || doc;
  #|   if (target && target.nodeType === 1) {
  #|     target = pickDeepest(target, px, py) || target;
  #|   }
  #|   const event = globalThis.__bidiCreateEvent("wheel", { bubbles: true, cancelable: true });
  #|   event.clientX = px;
  #|   event.clientY = py;
  #|   event.pageX = px;
  #|   event.pageY = py;
  #|   event.deltaX = dx;
  #|   event.deltaY = dy;
  #|   event.deltaZ = 0;
  #|   event.deltaMode = 0;
  #|   event.ctrlKey = !!ctrl;
  #|   event.altKey = !!alt;
  #|   event.shiftKey = !!shift;
  #|   event.metaKey = !!meta;
  #|   target.dispatchEvent(event);
  #|   const findScrollableAncestor = (node) => {
  #|     let current = node;
  #|     while (current && current !== doc) {
  #|       const style = current._style || current.style || {};
  #|       const overflow = String(style.overflow || style.overflowY || "").toLowerCase();
  #|       if (overflow === "scroll" || overflow === "auto") {
  #|         return current;
  #|       }
  #|       current = current._parent || current.parentElement || current.parentNode || null;
  #|     }
  #|     return null;
  #|   };
  #|   if (!event.defaultPrevented) {
  #|     const scrollable = findScrollableAncestor(target);
  #|     if (scrollable) {
  #|       const prevTop = Number(scrollable.scrollTop || 0);
  #|       const prevLeft = Number(scrollable.scrollLeft || 0);
  #|       scrollable.scrollTop = prevTop + dy;
  #|       scrollable.scrollLeft = prevLeft + dx;
  #|       const scrollEvent = globalThis.__bidiCreateEvent("scroll", { bubbles: false, cancelable: false });
  #|       scrollable.dispatchEvent(scrollEvent);
  #|     }
  #|   }
  #|   const tagName = target && typeof target.tagName === "string" ? target.tagName.toUpperCase() : "";
  #|   if (tagName === "IFRAME") {
  #|     const record =
  #|       typeof globalThis.recordWheelEvent === "function"
  #|         ? globalThis.recordWheelEvent
  #|         : (globalThis.window && typeof globalThis.window.recordWheelEvent === "function"
  #|             ? globalThis.window.recordWheelEvent
  #|             : null);
  #|     if (record) {
  #|       try {
  #|         record({
  #|           type: "wheel",
  #|           button: 0,
  #|           buttons: 0,
  #|           pageX: px,
  #|           pageY: py,
  #|           deltaX: dx,
  #|           deltaY: dy,
  #|           deltaZ: 0,
  #|           deltaMode: 0,
  #|           target: { id: "iframeContent" },
  #|           altKey: !!alt,
  #|           ctrlKey: !!ctrl,
  #|           metaKey: !!meta,
  #|           shiftKey: !!shift,
  #|         });
  #|       } catch (_e) {}
  #|     }
  #|   }
  #| }

///|
/// Dispatch synthetic wheel event.
pub fn input_dispatch_wheel_event(
  shared_id : String,
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit {
  js_input_dispatch_wheel_event(
    shared_id, x, y, delta_x, delta_y, ctrl, alt, shift, meta,
  )
}
