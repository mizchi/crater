///|
fn Browser::dispatch_focus_transition(
  self : Browser,
  previous_source_id : String?,
  next_source_id : String?,
) -> Unit {
  if !self.enable_js {
    return
  }
  if previous_source_id == next_source_id {
    return
  }
  let previous_js = match previous_source_id {
    Some(id) => "'" + escape_js_string(id) + "'"
    None => "null"
  }
  let next_js = match next_source_id {
    Some(id) => "'" + escape_js_string(id) + "'"
    None => "null"
  }
  let source = "(function(){const prevId=" +
    previous_js +
    ";const nextId=" +
    next_js +
    ";const prev=prevId?document.getElementById(prevId):null;const next=nextId?document.getElementById(nextId):null;function isChangeOnBlurTarget(target){if(!target){return false;}const tag=(target.tagName||'').toLowerCase();const type=(target.getAttribute?((target.getAttribute('type')||'').toLowerCase()):'');if(tag==='textarea'){return true;}if(tag!=='input'){return false;}return type===''||type==='text'||type==='search'||type==='url'||type==='tel'||type==='email'||type==='password'||type==='number';}function currentValue(target){if(!target){return '';}if(target.value!==undefined&&target.value!==null){return String(target.value);}if(target.getAttribute){return String(target.getAttribute('value')||'');}return '';}function maybeDispatchChangeOnBlur(target){if(!isChangeOnBlurTarget(target)||!target.getAttribute||!target.setAttribute){return;}const base=target.getAttribute('data-crater-change-base');if(base===null){return;}const current=currentValue(target);if(current!==String(base)){target.dispatchEvent(new Event('change',{bubbles:true}));}target.setAttribute('data-crater-change-base',current);}function markFocusBase(target){if(!isChangeOnBlurTarget(target)||!target.setAttribute){return;}target.setAttribute('data-crater-change-base',currentValue(target));}if(prev&&prev!==next){maybeDispatchChangeOnBlur(prev);prev.dispatchEvent(new Event('blur'));prev.dispatchEvent(new Event('focusout',{bubbles:true}));}if(next&&prev!==next){markFocusBase(next);next.dispatchEvent(new Event('focus'));next.dispatchEvent(new Event('focusin',{bubbles:true}));}return 'ok';})()"
  let _ = self.execute_inline_js(source)
  let _ = self.sync_render_state_from_dom_tree()
}

///|
fn Browser::dispatch_activation_default_to_source_id(
  self : Browser,
  source_id : String,
) -> Bool {
  if !self.enable_js {
    return false
  }
  let escaped = escape_js_string(source_id)
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'false';}const tag=(target.tagName||'').toLowerCase();const type=(target.getAttribute?((target.getAttribute('type')||'').toLowerCase()):'');function resetForm(form){function resetNode(node){if(!node||!node.childNodes){return;}for(let i=0;i<node.childNodes.length;i++){const child=node.childNodes[i];if(!child||child.nodeType!==1){continue;}const childTag=(child.tagName||'').toLowerCase();if(childTag==='input'){const childType=((child.getAttribute('type')||'').toLowerCase());if(childType==='checkbox'||childType==='radio'){const defaultChecked=child.getAttribute&&child.getAttribute('data-crater-default-checked');child.checked=defaultChecked==='true'||(defaultChecked===null&&child.hasAttribute&&child.hasAttribute('checked'));if(child.checked){child.setAttribute('checked','');}else if(child.removeAttribute){child.removeAttribute('checked');}}else if(childType!=='submit'&&childType!=='button'&&childType!=='image'&&childType!=='reset'&&childType!=='file'){const defaultValue=(child.getAttribute&&child.getAttribute('data-crater-default-value'));child.value=String(defaultValue===null?((child.getAttribute&&child.getAttribute('value'))||''):defaultValue);if(child.setAttribute){child.setAttribute('value',child.value);}}}else if(childTag==='textarea'){const defaultValue=(child.getAttribute&&child.getAttribute('data-crater-default-value'));const resetValue=String(defaultValue===null?((child.textContent!==undefined&&child.textContent!==null)?child.textContent:''):defaultValue);child.value=resetValue;}else if(childTag==='select'&&child.options!==undefined){let selectedIndex=-1;for(let j=0;j<child.options.length;j++){const option=child.options[j];const defaultSelected=option.getAttribute&&option.getAttribute('data-crater-default-selected');const selected=defaultSelected==='true'||(defaultSelected===null&&option.hasAttribute&&option.hasAttribute('selected'));option.selected=selected;if(selected&&selectedIndex<0){selectedIndex=j;}}if(selectedIndex<0&&child.options.length>0){child.options[0].selected=true;selectedIndex=0;}child.selectedIndex=selectedIndex;}resetNode(child);}}resetNode(form);}if(tag==='summary'){const details=target.closest?target.closest('details'):null;if(!details||!details.setAttribute){return 'false';}if(details.hasAttribute('open')){details.removeAttribute('open');}else{details.setAttribute('open','');}return 'true';}if((tag==='button'&&type==='reset')||(tag==='input'&&type==='reset')){const form=target.closest?target.closest('form'):null;if(!form){return 'false';}const resetEvent=new Event('reset',{bubbles:true,cancelable:true});if(!form.dispatchEvent(resetEvent)){return 'true';}resetForm(form);return 'true';}return 'false';})()"
  match self.execute_inline_js(source) {
    Some("true") => {
      let _ = self.sync_render_state_from_dom_tree()
      true
    }
    _ => false
  }
}

///|
fn Browser::dispatch_click_to_source_id(
  self : Browser,
  source_id : String,
  client_x? : Int = 0,
  client_y? : Int = 0,
) -> ClickDispatchResult {
  let escaped = escape_js_string(source_id)
  let client_x_source = client_x.to_string()
  let client_y_source = client_y.to_string()
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'missing';}const clientX=" +
    client_x_source +
    ";const clientY=" +
    client_y_source +
    ";function dispatch(type, ctor){const event=new ctor(type,{bubbles:true,cancelable:true,clientX,clientY,pointerId:1,pointerType:'mouse',isPrimary:true});return target.dispatchEvent(event);}dispatch('pointerdown',PointerEvent);dispatch('mousedown',MouseEvent);dispatch('pointerup',PointerEvent);dispatch('mouseup',MouseEvent);return dispatch('click',MouseEvent)?'allow':'prevent';})()"
  let result = self.execute_inline_js(source)
  let _ = self.sync_render_state_from_dom_tree()
  match result {
    Some("prevent") => { handled: true, allow_default: false }
    Some("allow") => { handled: true, allow_default: true }
    Some(_) => { handled: false, allow_default: true }
    None => { handled: false, allow_default: true }
  }
}

///|
fn Browser::dispatch_pointer_mouse_event_to_source_id(
  self : Browser,
  source_id : String,
  pointer_type : String,
  mouse_type : String,
  client_x : Int,
  client_y : Int,
) -> Bool {
  let escaped = escape_js_string(source_id)
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'missing';}const clientX=" +
    client_x.to_string() +
    ";const clientY=" +
    client_y.to_string() +
    ";target.dispatchEvent(new PointerEvent('" +
    escape_js_string(pointer_type) +
    "',{bubbles:true,cancelable:true,clientX,clientY,pointerId:1,pointerType:'mouse',isPrimary:true}));target.dispatchEvent(new MouseEvent('" +
    escape_js_string(mouse_type) +
    "',{bubbles:true,cancelable:true,clientX,clientY}));return 'ok';})()"
  let result = self.execute_inline_js(source)
  let _ = self.sync_render_state_from_dom_tree()
  result == Some("ok")
}

///|
fn Browser::dispatch_click_only_to_source_id(
  self : Browser,
  source_id : String,
  client_x : Int,
  client_y : Int,
) -> ClickDispatchResult {
  let escaped = escape_js_string(source_id)
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'missing';}const clientX=" +
    client_x.to_string() +
    ";const clientY=" +
    client_y.to_string() +
    ";return target.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,clientX,clientY}))?'allow':'prevent';})()"
  let result = self.execute_inline_js(source)
  let _ = self.sync_render_state_from_dom_tree()
  match result {
    Some("prevent") => { handled: true, allow_default: false }
    Some("allow") => { handled: true, allow_default: true }
    Some(_) => { handled: false, allow_default: true }
    None => { handled: false, allow_default: true }
  }
}

///|
fn Browser::dispatch_hover_transition(
  self : Browser,
  previous_source_id : String?,
  next_source_id : String?,
  client_x : Int,
  client_y : Int,
) -> Bool {
  if !self.enable_js {
    return false
  }
  match (previous_source_id, next_source_id) {
    (None, None) => return false
    _ => ()
  }
  let previous_js = match previous_source_id {
    Some(id) => "document.getElementById('" + escape_js_string(id) + "')"
    None => "null"
  }
  let next_js = match next_source_id {
    Some(id) => "document.getElementById('" + escape_js_string(id) + "')"
    None => "null"
  }
  let source = "(function(){const previous=" +
    previous_js +
    ";const next=" +
    next_js +
    ";const clientX=" +
    client_x.to_string() +
    ";const clientY=" +
    client_y.to_string() +
    ";function dispatch(target,type,ctor,related,bubbles){if(!target){return;}const event=new ctor(type,{bubbles:bubbles,cancelable:false,clientX,clientY,pointerId:1,pointerType:'mouse',isPrimary:true,relatedTarget:related});target.dispatchEvent(event);}if(previous&&previous!==next){dispatch(previous,'pointerout',PointerEvent,next,true);dispatch(previous,'mouseout',MouseEvent,next,true);dispatch(previous,'pointerleave',PointerEvent,next,false);dispatch(previous,'mouseleave',MouseEvent,next,false);}if(next&&previous!==next){dispatch(next,'pointerover',PointerEvent,previous,true);dispatch(next,'mouseover',MouseEvent,previous,true);dispatch(next,'pointerenter',PointerEvent,previous,false);dispatch(next,'mouseenter',MouseEvent,previous,false);}if(next){dispatch(next,'pointermove',PointerEvent,previous,true);dispatch(next,'mousemove',MouseEvent,previous,true);}return 'ok';})()"
  let _ = self.execute_inline_js(source)
  self.sync_render_state_from_dom_tree()
}
