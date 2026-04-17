///|
test "shell package can use MemoryCacheBackend with cached_fetch" {
  let cache = @http.MemoryCacheBackend::new(max_entries=4)
  let response = @http.cached_fetch(
    url="https://example.test/app.css",
    options=@http.FetchOptions::default(),
    cache~,
    fetcher=fn(
      _url : String,
      _options : @http.FetchOptions,
    ) -> @http.HttpResponse {
      { status: 200, headers: { "cache-control": "max-age=60" }, body: "ok" }
    },
  )
  inspect(response.body, content="ok")
}
