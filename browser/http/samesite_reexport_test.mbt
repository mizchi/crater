///|
test "browser/http re-exports SameSite types" {
  let s : @http.SiteContext = @http.SiteContext::SameSite
  inspect(s, content="SameSite")
}
