///|
/// Regression (#64 review / css-overflow): renderHtmlToJsonForWpt must render
/// the full document with viewport-skeleton culling disabled. The skeleton
/// optimization collapses below-the-fold content to height 0 once the node
/// count exceeds ~2000, which produced spurious WPT mismatches on large
/// fixtures (the whole layout tree is compared against a browser that lays out
/// the entire document). This builds a >2000-node document and asserts the
/// last element keeps its real height rather than being skeletonized to 0.
test "renderHtmlToJsonForWpt renders full document without skeleton culling" {
  let buf = StringBuilder::new()
  buf.write_string(
    "<style>.row{height:10px;width:100px}#last{height:33px;width:55px}</style><body>",
  )
  // Emit well over the 2000-node skeleton cutoff.
  for i = 0; i < 2600; i = i + 1 {
    buf.write_string("<div class=\"row\"></div>")
  }
  buf.write_string("<div id=\"last\"></div></body>")
  let json = renderHtmlToJsonForWpt(buf.to_string(), 800, 600)
  // The trailing #last div must survive with its explicit 33px height — if the
  // skeleton path were active it would collapse to "height":0.
  inspect(json.contains("\"height\":33"), content="true")
  inspect(json.contains("\"width\":55"), content="true")
}
