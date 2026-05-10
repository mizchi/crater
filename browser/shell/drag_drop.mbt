///|
fn Browser::is_draggable_source_id(self : Browser, source_id : String) -> Bool {
  if !self.enable_js {
    return false
  }
  let escaped = escape_js_string(source_id)
  match
    self.execute_inline_js(
      "(function(){const target=document.getElementById('" +
      escaped +
      "');return target&&target.draggable===true?'true':'false';})()",
    ) {
    Some("true") => true
    _ => false
  }
}

///|
fn Browser::dispatch_drag_event_status_to_source_id(
  self : Browser,
  source_id : String,
  event_type : String,
  client_x : Int,
  client_y : Int,
  related_source_id? : String? = None,
) -> (Bool, Bool) {
  let escaped = escape_js_string(source_id)
  let related_js = match related_source_id {
    Some(id) => "document.getElementById('" + escape_js_string(id) + "')"
    None => "null"
  }
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'missing';}const clientX=" +
    client_x.to_string() +
    ";const clientY=" +
    client_y.to_string() +
    ";const relatedTarget=" +
    related_js +
    ";let dataTransfer=globalThis.__craterDragDataTransfer||null;if('" +
    escape_js_string(event_type) +
    "'==='dragstart'){dataTransfer=new DataTransfer();globalThis.__craterDragDataTransfer=dataTransfer;}const dispatched=target.dispatchEvent(new DragEvent('" +
    escape_js_string(event_type) +
    "',{bubbles:true,cancelable:true,clientX,clientY,relatedTarget,dataTransfer}));if('" +
    escape_js_string(event_type) +
    "'==='dragend'){globalThis.__craterDragDataTransfer=null;}return dispatched?'ok':'canceled';})()"
  let result = self.execute_inline_js(source)
  let _ = self.sync_render_state_from_dom_tree()
  match result {
    Some("ok") => (true, false)
    Some("canceled") => (true, true)
    _ => (false, false)
  }
}

///|
fn Browser::dispatch_drag_event_to_source_id(
  self : Browser,
  source_id : String,
  event_type : String,
  client_x : Int,
  client_y : Int,
  related_source_id? : String? = None,
) -> Bool {
  let (handled, _) = self.dispatch_drag_event_status_to_source_id(
    source_id,
    event_type,
    client_x,
    client_y,
    related_source_id~,
  )
  handled
}

///|
fn Browser::is_current_drop_allowed(self : Browser) -> Bool {
  match
    self.execute_inline_js(
      "(function(){const dt=globalThis.__craterDragDataTransfer||null;if(!dt){return 'none/none';}const allowed=String(dt.effectAllowed||'all').toLowerCase();let drop=String(dt.dropEffect||'none').toLowerCase();function fallbackDropEffect(v){switch(v){case 'copy':case 'copylink':case 'copymove':return 'copy';case 'link':case 'linkmove':return 'link';case 'move':return 'move';case 'all':case 'uninitialized':return 'copy';default:return 'none';}}if(drop==='none'){const fallback=fallbackDropEffect(allowed);if(fallback!=='none'){dt.dropEffect=fallback;drop=fallback;}}return allowed + '/' + drop;})()",
    ) {
    Some("none/none") => false
    Some(state) => {
      let slash = state.find("/")
      match slash {
        Some(idx) => {
          let effect_allowed = state
            .unsafe_substring(start=0, end=idx)
            .to_lower()
          let drop_effect = state
            .unsafe_substring(start=idx + 1, end=state.length())
            .to_lower()
          @interaction_policy.is_drop_effect_compatible(
            effect_allowed, drop_effect,
          )
        }
        None => false
      }
    }
    None => false
  }
}
