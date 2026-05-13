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
