///|
/// Recording the text-measurement side effect and replaying it reproduces a
/// byte-identical render, and the replayed metrics are actually used (modifying
/// them changes the output). Replay needs no font engine — it serves the
/// recorded results, which is what makes a VRT snapshot portable/deterministic.
test "text metrics record/replay reproduces and drives the render" {
  let html =
    #|<!DOCTYPE html><style>body{margin:0}.col{display:inline-block}</style>
    #|<div class="col">The quick brown fox</div>
  let ctx = @renderer.RenderContext::default()
  let base = @renderer.layout_to_json(@renderer.render(html, ctx))

  // Record a render, then take the captured measurements.
  @renderer.start_text_metrics_recording()
  let _ = @renderer.render(html, ctx)
  let recording = @renderer.take_text_metrics_recording()
  inspect(recording.length() > 0, content="true")

  // Replay reproduces the base render exactly.
  @renderer.install_text_metrics_replay(recording)
  let replayed = @renderer.layout_to_json(@renderer.render(html, ctx))
  @renderer.clear_text_metrics_record_replay()
  inspect(replayed == base, content="true")

  // Serialized recording round-trips and still reproduces the render.
  let round_tripped = @renderer.deserialize_text_metrics_recording(
    @renderer.serialize_text_metrics_recording(recording),
  )
  @renderer.install_text_metrics_replay(round_tripped)
  let from_disk = @renderer.layout_to_json(@renderer.render(html, ctx))
  @renderer.clear_text_metrics_record_replay()
  inspect(from_disk == base, content="true")

  // The replayed metrics drive layout: doubling every recorded width changes
  // the wrapped text's geometry, so the render differs from the base.
  let widened : Array[@renderer.RecordedMetric] = []
  for m in recording {
    widened.push({
      key: m.key,
      min_width: m.min_width * 2.0,
      max_width: m.max_width * 2.0,
      min_height: m.min_height,
      max_height: m.max_height,
    })
  }
  @renderer.install_text_metrics_replay(widened)
  let widened_render = @renderer.layout_to_json(@renderer.render(html, ctx))
  @renderer.clear_text_metrics_record_replay()
  inspect(widened_render != base, content="true")
}
