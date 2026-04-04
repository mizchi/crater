///|
/// White-box tests for HTTP cache helpers

///|
fn make_entry(
  directives? : CacheDirectives = CacheDirectives::default(),
  stored_at? : Double = 0.0,
  last_modified? : String,
) -> CacheEntry {
  {
    url: "https://example.test/resource",
    status: 200,
    headers: {},
    body: "",
    etag: None,
    last_modified,
    directives,
    stored_at,
  }
}

///|
test "parse_cache_control: max-age=300" {
  inspect(
    parse_cache_control("max-age=300"),
    content=(
      #|{max_age: Some(300), no_cache: false, no_store: false, must_revalidate: false, public_: false, private_: false, immutable: false}
    ),
  )
}

///|
test "parse_cache_control: no-store" {
  inspect(
    parse_cache_control("no-store"),
    content=(
      #|{max_age: None, no_cache: false, no_store: true, must_revalidate: false, public_: false, private_: false, immutable: false}
    ),
  )
}

///|
test "parse_cache_control: no-cache, must-revalidate" {
  inspect(
    parse_cache_control("no-cache, must-revalidate"),
    content=(
      #|{max_age: None, no_cache: true, no_store: false, must_revalidate: true, public_: false, private_: false, immutable: false}
    ),
  )
}

///|
test "parse_cache_control: public, max-age=3600, immutable" {
  inspect(
    parse_cache_control("public, max-age=3600, immutable"),
    content=(
      #|{max_age: Some(3600), no_cache: false, no_store: false, must_revalidate: false, public_: true, private_: false, immutable: true}
    ),
  )
}

///|
test "parse_cache_control: empty string" {
  inspect(
    parse_cache_control(""),
    content=(
      #|{max_age: None, no_cache: false, no_store: false, must_revalidate: false, public_: false, private_: false, immutable: false}
    ),
  )
}

///|
test "parse_cache_control: private, max-age=0, must-revalidate" {
  inspect(
    parse_cache_control("private, max-age=0, must-revalidate"),
    content=(
      #|{max_age: Some(0), no_cache: false, no_store: false, must_revalidate: true, public_: false, private_: true, immutable: false}
    ),
  )
}

///|
test "is_fresh: max_age=300, stored 100s ago -> fresh" {
  let entry = make_entry(
    directives={ ..CacheDirectives::default(), max_age: Some(300) },
    stored_at=1000.0,
  )
  inspect(is_fresh(entry, 1100.0), content="true")
}

///|
test "is_fresh: max_age=300, stored 400s ago -> stale" {
  let entry = make_entry(
    directives={ ..CacheDirectives::default(), max_age: Some(300) },
    stored_at=1000.0,
  )
  inspect(is_fresh(entry, 1400.0), content="false")
}

///|
test "is_fresh: immutable -> always fresh" {
  let entry = make_entry(
    directives={ ..CacheDirectives::default(), immutable: true },
    stored_at=0.0,
  )
  inspect(is_fresh(entry, 999999.0), content="true")
}

///|
test "is_fresh: no_store -> always stale" {
  let entry = make_entry(
    directives={ ..CacheDirectives::default(), no_store: true },
    stored_at=1000.0,
  )
  inspect(is_fresh(entry, 1000.0), content="false")
}

///|
test "is_fresh: no directives, no last_modified -> stale" {
  let entry = make_entry()
  inspect(is_fresh(entry, 1000.0), content="false")
}

///|
test "is_fresh: heuristic fresh (elapsed < 10% of age)" {
  // stored_at=1000, last_modified="500" => resource age = 500
  // heuristic lifetime = 500 * 0.1 = 50
  // now=1030 => elapsed=30 < 50 => fresh
  let entry = make_entry(stored_at=1000.0, last_modified="500")
  inspect(is_fresh(entry, 1030.0), content="true")
}

///|
test "is_fresh: heuristic stale (elapsed > 10% of age)" {
  // stored_at=1000, last_modified="500" => resource age = 500
  // heuristic lifetime = 500 * 0.1 = 50
  // now=1060 => elapsed=60 > 50 => stale
  let entry = make_entry(stored_at=1000.0, last_modified="500")
  inspect(is_fresh(entry, 1060.0), content="false")
}

///|
test "MemoryCacheBackend: store and lookup" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let entry = make_entry(
    directives=CacheDirectives::default(),
    stored_at=1000.0,
  )
  cache.store(entry)
  let found = cache.lookup("https://example.test/resource")
  inspect(!found.is_empty(), content="true")
}

///|
test "MemoryCacheBackend: lookup miss" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  inspect(cache.lookup("https://missing.com").is_empty(), content="true")
}

///|
test "MemoryCacheBackend: remove" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  cache.store(
    make_entry(directives=CacheDirectives::default(), stored_at=1000.0),
  )
  cache.remove("https://example.test/resource")
  inspect(
    cache.lookup("https://example.test/resource").is_empty(),
    content="true",
  )
}

///|
test "MemoryCacheBackend: clear" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  cache.store(
    make_entry(directives=CacheDirectives::default(), stored_at=1000.0),
  )
  cache.clear()
  inspect(
    cache.lookup("https://example.test/resource").is_empty(),
    content="true",
  )
}

///|
test "MemoryCacheBackend: eviction at max_entries" {
  let cache = MemoryCacheBackend::new(max_entries=2)
  let e1 : CacheEntry = {
    url: "https://a.com/1",
    status: 200,
    headers: {},
    body: "1",
    etag: None,
    last_modified: None,
    directives: CacheDirectives::default(),
    stored_at: 100.0,
  }
  let e2 : CacheEntry = { ..e1, url: "https://a.com/2", stored_at: 200.0 }
  let e3 : CacheEntry = { ..e1, url: "https://a.com/3", stored_at: 300.0 }
  cache.store(e1)
  cache.store(e2)
  cache.store(e3) // should evict e1 (oldest)
  inspect(cache.lookup("https://a.com/1").is_empty(), content="true")
  inspect(!cache.lookup("https://a.com/2").is_empty(), content="true")
  inspect(!cache.lookup("https://a.com/3").is_empty(), content="true")
}

///|
test "cached_fetch: miss then hit" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let log : Array[String] = []
  let fetcher = fn(
    url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    log.push(url)
    {
      status: 200,
      headers: { "cache-control": "max-age=300" },
      body: ".h1{color:red}",
    }
  }
  let opts = FetchOptions::default()
  let r1 = cached_fetch(
    url="https://example.com/style.css",
    options=opts,
    cache~,
    fetcher~,
  )
  inspect(r1.status, content="200")
  inspect(log.length(), content="1")
  let r2 = cached_fetch(
    url="https://example.com/style.css",
    options=opts,
    cache~,
    fetcher~,
  )
  inspect(r2.body, content=".h1{color:red}")
  inspect(log.length(), content="1")
}

///|
test "cached_fetch: no-store skips cache" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let fetcher = fn(
    url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    let _ = url
    { status: 200, headers: { "cache-control": "no-store" }, body: "body" }
  }
  let _ = cached_fetch(
    url="https://example.com/ns.css",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  inspect(cache.lookup("https://example.com/ns.css").is_empty(), content="true")
}

///|
test "cached_fetch: stale with etag sends conditional request" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let stale : CacheEntry = {
    url: "https://example.com/old.css",
    status: 200,
    headers: { "cache-control": "max-age=0" },
    body: "old-body",
    etag: Some("\"abc123\""),
    last_modified: None,
    directives: parse_cache_control("max-age=0"),
    stored_at: 0.0,
  }
  cache.store(stale)
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    { status: 304, headers: {}, body: "" }
  }
  let r = cached_fetch(
    url="https://example.com/old.css",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  inspect(r.body, content="old-body")
  inspect(r.status, content="200")
}

///|
test "cached_fetch: non-GET bypasses cache" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    {
      status: 200,
      headers: { "cache-control": "max-age=3600" },
      body: "response",
    }
  }
  let opts : FetchOptions = { ..FetchOptions::default(), http_method: "POST" }
  let _ = cached_fetch(
    url="https://example.com/api",
    options=opts,
    cache~,
    fetcher~,
  )
  inspect(cache.lookup("https://example.com/api").is_empty(), content="true")
}
