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
