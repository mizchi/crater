///|
test "browser/http re-exports Profile" {
  let _ : @http.Profile = @http.Profile::default()
  inspect(true, content="true")
}
