///|
/// WASM stub - HTTP not available in WASM environment
pub fn fetch(
  url : String,
  options? : FetchOptions = FetchOptions::default(),
) -> HttpResponse raise HttpError {
  let _ = url
  let _ = options
  raise NotSupported
}
