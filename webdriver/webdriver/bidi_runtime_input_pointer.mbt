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
