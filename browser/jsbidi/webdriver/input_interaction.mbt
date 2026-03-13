///|
fn bidi_key_interaction_command(
  action_type : String,
  normalized_key : String,
) -> @interaction.InteractionCommand {
  if action_type == "keyUp" {
    @interaction.key_up_command(normalized_key)
  } else {
    @interaction.key_down_command(normalized_key)
  }
}

///|
fn bidi_pointer_interaction_command(
  action_type : String,
  x : Double,
  y : Double,
  button : Int,
) -> @interaction.InteractionCommand {
  let col = x.to_int()
  let row = y.to_int()
  match action_type {
    "pointerMove" => @interaction.pointer_move_command(col, row)
    "pointerDown" => @interaction.pointer_button_down_command(col, row, button)
    "pointerUp" => @interaction.pointer_button_up_command(col, row, button)
    _ => @interaction.pointer_move_command(col, row)
  }
}

///|
fn BidiProtocol::dispatch_interaction_key_command(
  self : BidiProtocol,
  command : @interaction.InteractionCommand,
  raw_key : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit {
  let _ = self
  match command {
    @interaction.KeyDown(_) =>
      input_dispatch_key_action("keyDown", raw_key, ctrl, alt, shift, meta)
    @interaction.KeyUp(_) =>
      input_dispatch_key_action("keyUp", raw_key, ctrl, alt, shift, meta)
    _ => ()
  }
}

///|
fn BidiProtocol::dispatch_interaction_pointer_command(
  self : BidiProtocol,
  command : @interaction.InteractionCommand,
  target_shared : String,
  x : Double,
  y : Double,
  buttons : Int,
  pointer_type : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit {
  let _ = self
  match command {
    @interaction.PointerMove(_, _) => {
      input_dispatch_pointer_event(
        target_shared, "pointermove", x, y, 0, buttons, pointer_type, ctrl, alt,
        shift, meta,
      )
      if pointer_type == "mouse" {
        input_dispatch_pointer_event(
          target_shared, "mousemove", x, y, 0, buttons, pointer_type, ctrl, alt,
          shift, meta,
        )
      }
    }
    @interaction.PointerButtonDown(_, _, button) =>
      input_dispatch_pointer_event(
        target_shared, "pointerdown", x, y, button, buttons, pointer_type, ctrl,
        alt, shift, meta,
      )
    @interaction.PointerButtonUp(_, _, button) =>
      input_dispatch_pointer_event(
        target_shared, "pointerup", x, y, button, buttons, pointer_type, ctrl, alt,
        shift, meta,
      )
    _ => ()
  }
}
