///|
test "SqliteCacheBackend: store and lookup" {
  let cache = SqliteCacheBackend::new(":memory:")
  let entry = make_entry(
    directives=parse_cache_control("max-age=300"),
    stored_at=1000.0,
  )
  cache.store(entry)
  let found = cache.lookup("https://example.test/resource")
  inspect(found is Some(_), content="true")
  match found {
    Some(e) => {
      inspect(e.status, content="200")
      inspect(e.body, content="")
      inspect(
        e.directives.max_age,
        content=(
          #|Some(300)
        ),
      )
    }
    None => ()
  }
}

///|
test "SqliteCacheBackend: lookup miss" {
  let cache = SqliteCacheBackend::new(":memory:")
  inspect(cache.lookup("https://missing.com") is None, content="true")
}

///|
test "SqliteCacheBackend: directives roundtrip without cache-control header" {
  let cache = SqliteCacheBackend::new(":memory:")
  let entry = make_entry(
    directives=parse_cache_control(
      "private, max-age=0, no-cache, must-revalidate, immutable",
    ),
    stored_at=1000.0,
  )
  cache.store(entry)
  match cache.lookup("https://example.test/resource") {
    Some(e) => {
      inspect(e.directives.private_, content="true")
      inspect(e.directives.max_age, content="Some(0)")
      inspect(e.directives.no_cache, content="true")
      inspect(e.directives.must_revalidate, content="true")
      inspect(e.directives.immutable, content="true")
    }
    None => panic()
  }
}

///|
test "SqliteCacheBackend: remove" {
  let cache = SqliteCacheBackend::new(":memory:")
  cache.store(
    make_entry(directives=CacheDirectives::default(), stored_at=1000.0),
  )
  cache.remove("https://example.test/resource")
  inspect(cache.lookup("https://example.test/resource") is None, content="true")
}

///|
test "SqliteCacheBackend: clear" {
  let cache = SqliteCacheBackend::new(":memory:")
  cache.store(
    make_entry(directives=CacheDirectives::default(), stored_at=1000.0),
  )
  cache.clear()
  inspect(cache.lookup("https://example.test/resource") is None, content="true")
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

///|
test "SqliteCacheBackend: cached_fetch can reuse stored response" {
  let cache = SqliteCacheBackend::new(":memory:")
  let log : Array[String] = []
  let fetcher = fn(
    url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    log.push(url)
    { status: 200, headers: { "cache-control": "max-age=300" }, body: "body" }
  }
  let opts = FetchOptions::default()
  let r1 = cached_fetch(
    url="https://example.test/sqlite.css",
    options=opts,
    cache~,
    fetcher~,
  )
  inspect(r1.status, content="200")
  inspect(log.length(), content="1")
  let r2 = cached_fetch(
    url="https://example.test/sqlite.css",
    options=opts,
    cache~,
    fetcher~,
  )
  inspect(r2.body, content="body")
  inspect(log.length(), content="1")
}
