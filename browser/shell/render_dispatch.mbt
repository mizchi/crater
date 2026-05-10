///|
/// Render current content in selected output mode
pub fn Browser::render_output(self : Browser, mode : OutputMode) -> String {
  self.ensure_declarative_shadow_dom_normalized()
  match mode {
    Sixel => self.render()
    Kitty => self.render_kitty()
    Text => self.render_text()
    Json => self.render_json()
    Aom => self.render_aom()
    Arc90 => self.render_arc90()
    ExtractMain => self.render_extract_main()
    Grounding => self.render_grounding()
  }
}

///|
pub async fn[T : @io.Writer] Browser::write_output(
  self : Browser,
  mode : OutputMode,
  writer : T,
) -> Unit {
  match mode {
    Kitty => self.write_kitty_output(writer)
    _ => writer.write(self.render_output(mode)) catch { _ => () }
  }
}
