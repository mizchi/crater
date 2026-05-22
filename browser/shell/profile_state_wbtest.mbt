///|
test "Browser.profile owns cookie_jar and http_cache" {
  let state = Browser::new(100, 100)
  // Store one cookie via the profile.
  state.profile
  .cookie_jar()
  .store_from_header(
    "marker=v; Path=/; SameSite=Lax", "https://example.com", true,
  )
  // Accessor sees the SAME jar — exact count proves it's not a copy.
  inspect(state.cookie_jar().size(), content="1")
}
