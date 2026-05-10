///|
fn Browser::set_text_control_selection_from_cells(
  self : Browser,
  source_id : String,
  anchor_col : Int,
  anchor_row : Int,
  focus_col : Int,
  focus_row : Int,
) -> Bool {
  if !self.enable_js {
    return false
  }
  match self.get_hit_region_for_source_id(source_id) {
    Some(region) => {
      let anchor_local_col = if anchor_col <= region.col {
        0
      } else if anchor_col >= region.col + region.width {
        region.width
      } else {
        anchor_col - region.col
      }
      let anchor_local_row = if anchor_row <= region.row {
        0
      } else if anchor_row >= region.row + region.height {
        region.height - 1
      } else {
        anchor_row - region.row
      }
      let focus_local_col = if focus_col <= region.col {
        0
      } else if focus_col >= region.col + region.width {
        region.width
      } else {
        focus_col - region.col
      }
      let focus_local_row = if focus_row <= region.row {
        0
      } else if focus_row >= region.row + region.height {
        region.height - 1
      } else {
        focus_row - region.row
      }
      let escaped = escape_js_string(source_id)
      let source = "(function(){const target=document.getElementById('" +
        escaped +
        "');if(!target){return 'missing';}const tag=(target.tagName||'').toLowerCase();const type=(target.getAttribute?((target.getAttribute('type')||'').toLowerCase()):'');function isTextLikeInput(){if(tag!=='input'){return false;}return type===''||type==='text'||type==='search'||type==='url'||type==='tel'||type==='email'||type==='password'||type==='number';}function currentValue(el){if(!el){return '';}if(el.value!==undefined&&el.value!==null){return String(el.value);}if(el.getAttribute){return String(el.getAttribute('value')||'');}return '';}function setCaret(index){const value=currentValue(target);const clamped=Math.max(0,Math.min(value.length,Number(index)||0));if(typeof target.setSelectionRange==='function'){target.setSelectionRange(clamped,clamped);}else{target.selectionStart=clamped;target.selectionEnd=clamped;}return 'ok';}if(tag==='textarea'){const value=currentValue(target);const lines=value.split('\\n');const localRow=" +
        anchor_local_row.to_string() +
        ";const anchorCol=" +
        anchor_local_col.to_string() +
        ";const focusRow=" +
        focus_local_row.to_string() +
        ";const focusCol=" +
        focus_local_col.to_string() +
        ";const anchorRow=localRow;function indexForPosition(row,col){let offset=0;for(let i=0;i<lines.length;i++){const line=lines[i];if(i>=row||i===lines.length-1){return offset+Math.max(0,Math.min(line.length,col));}offset+=line.length+1;}return value.length;}const anchor=indexForPosition(anchorRow,anchorCol);const focus=indexForPosition(focusRow,focusCol);const start=Math.min(anchor,focus);const end=Math.max(anchor,focus);if(typeof target.setSelectionRange==='function'){target.setSelectionRange(start,end);}else{target.selectionStart=start;target.selectionEnd=end;}return 'ok';}if(isTextLikeInput()){const value=currentValue(target);const anchor=Math.max(0,Math.min(value.length," +
        anchor_local_col.to_string() +
        "));const focus=Math.max(0,Math.min(value.length," +
        focus_local_col.to_string() +
        "));const start=Math.min(anchor,focus);const end=Math.max(anchor,focus);if(typeof target.setSelectionRange==='function'){target.setSelectionRange(start,end);}else{target.selectionStart=start;target.selectionEnd=end;}return 'ok';}return 'none';})()"
      self.execute_inline_js(source) == Some("ok")
    }
    None => false
  }
}

///|
fn Browser::set_text_control_caret_from_cell(
  self : Browser,
  source_id : String,
  col : Int,
  row : Int,
) -> Bool {
  self.set_text_control_selection_from_cells(source_id, col, row, col, row)
}

///|
fn Browser::dispatch_focused_key_to_source_id(
  self : Browser,
  source_id : String,
  key : String,
) -> FocusedKeyDispatchResult {
  if !self.enable_js {
    return NotHandled
  }
  let escaped_id = escape_js_string(source_id)
  let escaped_key = escape_js_string(key)
  let source = "(function(){const target=document.getElementById('" +
    escaped_id +
    "');const key='" +
    escaped_key +
    "';if(!target){return 'none';}const tag=(target.tagName||'').toLowerCase();const type=(target.getAttribute?((target.getAttribute('type')||'').toLowerCase()):'');function dispatchKeyboard(typeName,cancelable){const ev=new KeyboardEvent(typeName,{bubbles:true,cancelable,key:key});return target.dispatchEvent(ev);}function finishHandled(){dispatchKeyboard('keyup',false);return 'handled';}function finish(result){dispatchKeyboard('keyup',false);return result;}function dispatchBeforeInput(inputType,data){let event;if(typeof InputEvent==='function'){event=new InputEvent('beforeinput',{bubbles:true,cancelable:true,data,inputType});}else{event=new Event('beforeinput',{bubbles:true,cancelable:true});event.data=data;event.inputType=inputType;}return target.dispatchEvent(event);}function dispatchInput(){target.dispatchEvent(new Event('input',{bubbles:true}));}function dispatchChange(){target.dispatchEvent(new Event('change',{bubbles:true}));markChangeBase(target);}function currentValue(el){if(!el){return '';}if(el.value!==undefined&&el.value!==null){return String(el.value);}if(el.getAttribute){return String(el.getAttribute('value')||'');}return '';}function markChangeBase(el){if(!el||!el.setAttribute){return;}el.setAttribute('data-crater-change-base',currentValue(el));}function ensureDefaultValue(el){if(!el||!el.getAttribute||!el.setAttribute){return;}if(el.getAttribute('data-crater-default-value')!==null){return;}el.setAttribute('data-crater-default-value',currentValue(el));}function ensureDefaultChecked(el){if(!el||!el.getAttribute||!el.setAttribute){return;}if(el.getAttribute('data-crater-default-checked')!==null){return;}el.setAttribute('data-crater-default-checked',el.checked?'true':'false');}function syncValueAttr(el){if(el&&el.setAttribute){el.setAttribute('value',currentValue(el));}}function syncCheckedAttr(el){if(!el||!el.setAttribute){return;}if(el.checked){el.setAttribute('checked','');}else if(el.removeAttribute){el.removeAttribute('checked');}}function currentSelection(){const value=currentValue(target);const length=value.length;let start=target.selectionStart;let end=target.selectionEnd;if(start===undefined||start===null){start=length;}if(end===undefined||end===null){end=start;}start=Math.max(0,Math.min(length,Number(start)||0));end=Math.max(0,Math.min(length,Number(end)||0));if(end<start){end=start;}return {value,length,start,end};}function setSelection(start,end){const sel=currentSelection();const nextStart=Math.max(0,Math.min(sel.length,Number(start)||0));let nextEnd=end===undefined||end===null?nextStart:Number(end)||0;nextEnd=Math.max(0,Math.min(sel.length,nextEnd));if(nextEnd<nextStart){nextEnd=nextStart;}if(typeof target.setSelectionRange==='function'){target.setSelectionRange(nextStart,nextEnd);}else{target.selectionStart=nextStart;target.selectionEnd=nextEnd;}}function replaceSelection(insertText,inputType){const sel=currentSelection();if(!dispatchBeforeInput(inputType,insertText)){return true;}ensureDefaultValue(target);target.value=sel.value.slice(0,sel.start)+insertText+sel.value.slice(sel.end);syncValueAttr(target);const caret=sel.start+insertText.length;setSelection(caret,caret);dispatchInput();return true;}function deleteBackward(){const sel=currentSelection();if(sel.start===0&&sel.end===0){return true;}if(!dispatchBeforeInput('deleteContentBackward',null)){return true;}ensureDefaultValue(target);let start=sel.start;const end=sel.end;if(start===end){start=Math.max(0,start-1);}target.value=sel.value.slice(0,start)+sel.value.slice(end);syncValueAttr(target);setSelection(start,start);dispatchInput();return true;}function deleteForward(){const sel=currentSelection();if(sel.start===sel.length&&sel.end===sel.length){return true;}if(!dispatchBeforeInput('deleteContentForward',null)){return true;}ensureDefaultValue(target);const start=sel.start;let end=sel.end;if(start===end){end=Math.min(sel.length,end+1);}target.value=sel.value.slice(0,start)+sel.value.slice(end);syncValueAttr(target);setSelection(start,start);dispatchInput();return true;}function moveCaret(delta){const sel=currentSelection();let caret=sel.start===sel.end?sel.start+delta:(delta<0?sel.start:sel.end);caret=Math.max(0,Math.min(sel.length,caret));setSelection(caret,caret);return true;}function moveCaretTo(edge){const sel=currentSelection();const caret=edge==='start'?0:sel.length;setSelection(caret,caret);return true;}function isTextLikeInput(){if(tag!=='input'){return false;}return type===''||type==='text'||type==='search'||type==='url'||type==='tel'||type==='email'||type==='password'||type==='number';}function toggleRadio(el){if(el.checked){return false;}const name=el.getAttribute?el.getAttribute('name'):null;const form=el.closest?el.closest('form'):null;const root=form||document;function walk(node){if(!node||!node.childNodes){return;}for(let i=0;i<node.childNodes.length;i++){const child=node.childNodes[i];if(!child||child.nodeType!==1){continue;}const childTag=(child.tagName||'').toLowerCase();if(childTag==='input'){const childType=((child.getAttribute('type')||'').toLowerCase());if(childType==='radio'&&child!==el&&(child.getAttribute('name')||'')===(name||'')){ensureDefaultChecked(child);child.checked=false;syncCheckedAttr(child);}}walk(child);}}walk(root);ensureDefaultChecked(el);el.checked=true;syncCheckedAttr(el);return true;}function stepSelect(el,delta){if(el.selectedIndex===undefined||el.options===undefined){return false;}const len=el.options.length||0;if(len<=0){return false;}let next=el.selectedIndex;if(next<0){next=0;}else{next=Math.max(0,Math.min(len-1,next+delta));}if(next===el.selectedIndex){return false;}for(let i=0;i<el.options.length;i++){const option=el.options[i];if(option&&option.getAttribute&&option.setAttribute&&option.getAttribute('data-crater-default-selected')===null){option.setAttribute('data-crater-default-selected',option.selected?'true':'false');}}el.selectedIndex=next;return true;}if(tag==='a'){if(key!=='Enter'){return 'none';}if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}return finish('activate');}if(tag==='button'||(tag==='input'&&(type==='submit'||type==='button'||type==='image'||type==='reset'))||tag==='summary'){if(key!=='Enter'&&key!==' '){return 'none';}if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}return finish('activate');}if(tag==='input'&&(type==='checkbox'||type==='radio')){if(key!=='Enter'&&key!==' '){return 'none';}if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}const clickEvent=new MouseEvent('click',{bubbles:true,cancelable:true});const allowClick=target.dispatchEvent(clickEvent);if(allowClick){let changed=false;if(type==='checkbox'){ensureDefaultChecked(target);target.checked=!target.checked;syncCheckedAttr(target);changed=true;}else{changed=toggleRadio(target);}if(changed){dispatchInput();dispatchChange();}}return finish('handled');}if(tag==='textarea'){if(key==='ArrowLeft'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaret(-1);return finish('handled');}if(key==='ArrowRight'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaret(1);return finish('handled');}if(key==='Home'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaretTo('start');return finish('handled');}if(key==='End'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaretTo('end');return finish('handled');}if(key==='Delete'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}deleteForward();return finish('handled');}if(key==='Enter'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}replaceSelection('\\n','insertLineBreak');return finish('handled');}if(key==='Backspace'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}deleteBackward();return finish('handled');}if(key.length===1){if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}replaceSelection(key,'insertText');return finish('handled');}return 'none';}if(isTextLikeInput()){if(key==='ArrowLeft'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaret(-1);return finish('handled');}if(key==='ArrowRight'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaret(1);return finish('handled');}if(key==='Home'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaretTo('start');return finish('handled');}if(key==='End'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaretTo('end');return finish('handled');}if(key==='Delete'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}deleteForward();return finish('handled');}if(key==='Enter'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}dispatchChange();if(target.closest&&target.closest('form')){return finish('submit');}return finish('handled');}if(key==='Backspace'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}deleteBackward();return finish('handled');}if(key.length===1){if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}replaceSelection(key,'insertText');return finish('handled');}return 'none';}if(tag==='select'){if(key==='ArrowDown'||key==='ArrowUp'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}const changed=stepSelect(target,key==='ArrowDown'?1:-1);if(changed){dispatchInput();dispatchChange();}return finish('handled');}if(key!=='Enter'&&key!==' '){return 'none';}if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}return finish('handled');}return 'none';})()"
  match self.execute_inline_js(source) {
    Some(result) => {
      let _ = self.sync_render_state_from_dom_tree()
      match result {
        "handled" => Handled
        "activate" => Activate
        "submit" => Submit
        _ => NotHandled
      }
    }
    None => NotHandled
  }
}
