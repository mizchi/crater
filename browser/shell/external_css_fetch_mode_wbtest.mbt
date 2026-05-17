///|
/// Regression lock for the `external_css_fetch` mode invariant.
///
/// External `<link rel="stylesheet">` loads MUST use
/// `RequestMode::NoCors` so they don't trigger a CORS preflight on a
/// CDN that has no `Access-Control-Allow-Origin` echo. The Fetch spec
/// treats the response as opaque (the page can't read the rules
/// cross-origin without `<link crossorigin>`), but the request itself
/// must still go through.
///
/// We test the builder seam `build_external_css_options` rather than
/// running the full `fetch_external_css` pipeline because the builder
/// is the only knob that decides the mode. A future "make it Cors so
/// we can read the stylesheet text" refactor would have to flip this
/// line and trip this test.

///|
test "build_external_css_options uses NoCors mode" {
  let opts = build_external_css_options(
    "https://example.com/",
    @http.RequestSandbox::Open,
  )
  // RequestMode derives Eq but not Show, so we compare against the
  // expected variant directly rather than relying on inspect.
  let is_nocors = opts.mode == @http.RequestMode::NoCors
  inspect(is_nocors, content="true")
  // Sanity: it must NOT be Cors (which would force a preflight on
  // most CDN-hosted stylesheets).
  let is_cors = opts.mode == @http.RequestMode::Cors
  inspect(is_cors, content="false")
}

///|
test "build_external_css_options preserves origin and sandbox" {
  let opts = build_external_css_options(
    "https://example.com/page",
    @http.RequestSandbox::SameOrigin,
  )
  inspect(opts.origin, content="https://example.com/page")
  // sandbox round-trip — Allowlist would also round-trip but SameOrigin
  // is enough to confirm the field isn't dropped.
  let sandbox_is_same_origin = match opts.sandbox {
    @http.RequestSandbox::SameOrigin => true
    _ => false
  }
  inspect(sandbox_is_same_origin, content="true")
}

///|
test "build_external_css_options defaults to GET" {
  let opts = build_external_css_options(
    "https://example.com/",
    @http.RequestSandbox::Open,
  )
  // GET + NoCors is a "simple" request per the CORS classifier, so
  // classify_request returns Allow — no preflight needed. If either
  // the method or the mode changes, the gate would start asking for
  // an OPTIONS roundtrip.
  inspect(opts.http_method, content="GET")
}
