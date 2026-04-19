///|
test "testing facade renders html to wpt json" {
  let json = render_html_to_json_for_wpt(
    "<html><body><div style=\"width: 20px; height: 10px;\">ok</div></body></html>",
    320, 200,
  )
  assert_true(json.contains("\"id\":\"div\""))
}

///|
test "testing facade exposes taffy helpers" {
  assert_approx(10.0, 10.05)
  let _ = default_dispatch()
  inspect(true, content="true")
}
