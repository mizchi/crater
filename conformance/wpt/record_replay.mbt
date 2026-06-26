///|
fn wpt_render_context(width : Int, height : Int) -> @renderer.RenderContext {
  {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
}

///|
/// Render `html` while recording the external side effects (text measurement +
/// image intrinsic sizing), and return the recording serialized as one string
/// (text part length-prefixed, then the image part). Persist this to reproduce
/// the render later with renderHtmlWithReplayForWpt — no font/image engine
/// needed. Pair with renderHtmlToJsonForWpt to also capture the layout.
pub fn recordRenderSideEffectsForWpt(
  html : String,
  width : Int,
  height : Int,
) -> String {
  install_wpt_external_measurement_providers()
  let ctx = wpt_render_context(width, height)
  @renderer.start_text_metrics_recording()
  @renderer.start_image_intrinsic_recording()
  let _ = @renderer.render_to_node_and_layout_full_document(html, ctx)
  let text = @renderer.serialize_text_metrics_recording(
    @renderer.take_text_metrics_recording(),
  )
  let image = @renderer.serialize_image_intrinsic_recording(
    @renderer.take_image_intrinsic_recording(),
  )
  text.length().to_string() + ":" + text + image
}

///|
/// Render `html` by replaying a recording captured by
/// recordRenderSideEffectsForWpt (no external providers consulted for recorded
/// inputs; misses fall back to the live provider). Returns the layout JSON.
pub fn renderHtmlWithReplayForWpt(
  html : String,
  width : Int,
  height : Int,
  recording : String,
) -> String {
  install_wpt_external_measurement_providers()
  let len = recording.length()
  let mut i = 0
  let colon = ':'.to_int()
  while i < len && recording[i].to_int() != colon {
    i = i + 1
  }
  let text_len = @string.parse_int(recording[0:i].to_owned()) catch { _ => 0 }
  let text_start = i + 1
  let text = recording[text_start:text_start + text_len].to_owned()
  let image = recording[text_start + text_len:len].to_owned()
  @renderer.install_text_metrics_replay(
    @renderer.deserialize_text_metrics_recording(text),
  )
  @renderer.install_image_intrinsic_replay(
    @renderer.deserialize_image_intrinsic_recording(image),
  )
  let ctx = wpt_render_context(width, height)
  let (_, layout) = @renderer.render_to_node_and_layout_full_document(html, ctx)
  @renderer.clear_text_metrics_record_replay()
  @renderer.clear_image_intrinsic_record_replay()
  @renderer.layout_to_json(layout)
}
