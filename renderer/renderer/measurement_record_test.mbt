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

///|
/// Image intrinsic sizes record/replay the same way: a recording captures the
/// provider's results, and replaying serves them with no provider installed.
test "image intrinsic size record/replay reproduces the render" {
  let html = "<!DOCTYPE html><img src=\"photo.png\">"
  let ctx = @renderer.RenderContext::default()

  // Provider that reports a fixed intrinsic size for any image.
  @renderer.set_image_intrinsic_size_provider(
    @renderer.ImageIntrinsicSizeProvider::new(fn(_src) { Some((120.0, 60.0)) }),
  )
  @renderer.start_image_intrinsic_recording()
  let with_provider = @renderer.layout_to_json(@renderer.render(html, ctx))
  let recording = @renderer.take_image_intrinsic_recording()
  @renderer.clear_image_intrinsic_size_provider()
  inspect(recording.length() > 0, content="true")

  // Without provider or replay the image no longer measures to 120x60.
  let without = @renderer.layout_to_json(@renderer.render(html, ctx))
  inspect(without != with_provider, content="true")

  // Replaying the recording reproduces the with-provider render — no provider.
  @renderer.install_image_intrinsic_replay(recording)
  let replayed = @renderer.layout_to_json(@renderer.render(html, ctx))
  @renderer.clear_image_intrinsic_record_replay()
  inspect(replayed == with_provider, content="true")

  // Serialized image recording round-trips.
  let round = @renderer.deserialize_image_intrinsic_recording(
    @renderer.serialize_image_intrinsic_recording(recording),
  )
  @renderer.install_image_intrinsic_replay(round)
  let from_disk = @renderer.layout_to_json(@renderer.render(html, ctx))
  @renderer.clear_image_intrinsic_record_replay()
  inspect(from_disk == with_provider, content="true")
}
