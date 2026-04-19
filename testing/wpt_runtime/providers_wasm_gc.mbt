///|
#cfg(target="wasm-gc")
fn install_wpt_external_measurement_providers() -> Unit {
  @renderer.clear_text_metrics_provider()
  @renderer.clear_image_intrinsic_size_provider()
}
