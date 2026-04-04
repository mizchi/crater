///|
test "SqliteCacheBackend: store and lookup" {
  let cache = SqliteCacheBackend::new(":memory:")
  let entry = make_entry(
    directives=parse_cache_control("max-age=300"),
    stored_at=1000.0,
  )
  cache.store(entry)
  let found = cache.lookup("https://example.test/resource")
  inspect(!found.is_empty(), content="true")
  match found {
    Some(e) => {
      inspect(e.status, content="200")
      inspect(e.body, content="")
      inspect(e.directives.max_age, content=(
        #|None
      ))
    }
    None => ()
  }
}

///|
test "SqliteCacheBackend: lookup miss" {
  let cache = SqliteCacheBackend::new(":memory:")
  inspect(cache.lookup("https://missing.com").is_empty(), content="true")
}

///|
test "SqliteCacheBackend: remove" {
  let cache = SqliteCacheBackend::new(":memory:")
  cache.store(make_entry(directives=CacheDirectives::default(), stored_at=1000.0))
  cache.remove("https://example.test/resource")
  inspect(
    cache.lookup("https://example.test/resource").is_empty(),
    content="true",
  )
}

///|
test "SqliteCacheBackend: clear" {
  let cache = SqliteCacheBackend::new(":memory:")
  cache.store(make_entry(directives=CacheDirectives::default(), stored_at=1000.0))
  cache.clear()
  inspect(
    cache.lookup("https://example.test/resource").is_empty(),
    content="true",
  )
}

///|
test "SqliteCacheBackend: etag and last_modified roundtrip" {
  let cache = SqliteCacheBackend::new(":memory:")
  let entry : CacheEntry = {
    url: "https://example.com/img.png",
    status: 200,
    headers: {
      "content-type": "image/png",
      "cache-control": "public, max-age=86400",
    },
    body: "imgdata",
    etag: Some("\"xyz789\""),
    last_modified: Some("Wed, 01 Jan 2025 00:00:00 GMT"),
    directives: parse_cache_control("public, max-age=86400"),
    stored_at: 5000.0,
  }
  cache.store(entry)
  match cache.lookup("https://example.com/img.png") {
    Some(e) => {
      inspect(e.etag, content="Some(\"\\\"xyz789\\\"\")")
      inspect(
        e.last_modified,
        content="Some(\"Wed, 01 Jan 2025 00:00:00 GMT\")",
      )
      inspect(e.directives.public_, content="true")
      inspect(e.directives.max_age, content="Some(86400)")
      inspect(e.stored_at, content="5000")
    }
    None => panic()
  }
}
