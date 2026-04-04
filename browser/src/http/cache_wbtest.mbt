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

// ============================================================
// RFC 9111: must-revalidate, error caching, status code tests
// ============================================================

///|
test "is_fresh: must-revalidate without max-age is always stale" {
  let entry = make_entry(
    directives=parse_cache_control("must-revalidate"),
    stored_at=1000.0,
  )
  // must-revalidate without max-age → always stale
  inspect(is_fresh(entry, 1001.0), content="false")
}

///|
test "is_fresh: must-revalidate with max-age=300, not expired" {
  let entry = make_entry(
    directives=parse_cache_control("max-age=300, must-revalidate"),
    stored_at=1000.0,
  )
  // elapsed=100 < 300 → still fresh even with must-revalidate
  inspect(is_fresh(entry, 1100.0), content="true")
}

///|
test "is_fresh: must-revalidate with max-age=300, expired" {
  let entry = make_entry(
    directives=parse_cache_control("max-age=300, must-revalidate"),
    stored_at=1000.0,
  )
  // elapsed=400 > 300 → stale, must-revalidate prevents serving stale
  inspect(is_fresh(entry, 1400.0), content="false")
}

///|
test "is_cacheable_status: 200 OK" {
  inspect(is_cacheable_status(200), content="true")
}

///|
test "is_cacheable_status: 301 Moved Permanently" {
  inspect(is_cacheable_status(301), content="true")
}

///|
test "is_cacheable_status: 404 Not Found" {
  inspect(is_cacheable_status(404), content="false")
}

///|
test "is_cacheable_status: 500 Internal Server Error" {
  inspect(is_cacheable_status(500), content="false")
}

///|
test "is_cacheable_status: 204 No Content" {
  inspect(is_cacheable_status(204), content="true")
}

///|
test "cached_fetch: 404 response is not cached" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    {
      status: 404,
      headers: { "cache-control": "max-age=300" },
      body: "not found",
    }
  }
  let _ = cached_fetch(
    url="https://example.com/missing",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  inspect(
    cache.lookup("https://example.com/missing").is_empty(),
    content="true",
  )
}

///|
test "cached_fetch: 500 response is not cached" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    { status: 500, headers: {}, body: "error" }
  }
  let _ = cached_fetch(
    url="https://example.com/err",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  inspect(cache.lookup("https://example.com/err").is_empty(), content="true")
}

///|
test "cached_fetch: 301 response is cached" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    {
      status: 301,
      headers: {
        "cache-control": "max-age=3600",
        "location": "https://example.com/new",
      },
      body: "",
    }
  }
  let _ = cached_fetch(
    url="https://example.com/old",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  inspect(cache.lookup("https://example.com/old").is_empty(), content="false")
}

///|
test "cached_fetch: no-cache forces revalidation even when entry exists" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  // Pre-populate with entry that has no-cache
  let entry : CacheEntry = {
    url: "https://example.com/nc.css",
    status: 200,
    headers: { "cache-control": "no-cache" },
    body: "cached-body",
    etag: Some("\"v1\""),
    last_modified: None,
    directives: parse_cache_control("no-cache"),
    stored_at: 1000.0,
  }
  cache.store(entry)
  let log : Array[String] = []
  let fetcher = fn(
    url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    log.push(url)
    { status: 304, headers: {}, body: "" }
  }
  let r = cached_fetch(
    url="https://example.com/nc.css",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  // Should have called fetcher (revalidation) even though entry exists
  inspect(log.length(), content="1")
  // Should return cached body after 304
  inspect(r.body, content="cached-body")
}

// ============================================================
// parse_cache_control edge cases
// ============================================================

///|
test "parse_cache_control: mixed case" {
  let d = parse_cache_control("Max-Age=600, No-Cache, Must-Revalidate")
  inspect(d.max_age, content="Some(600)")
  inspect(d.no_cache, content="true")
  inspect(d.must_revalidate, content="true")
}

///|
test "parse_cache_control: extra whitespace" {
  let d = parse_cache_control("  max-age=120  ,  no-store  ,  public  ")
  inspect(d.max_age, content="Some(120)")
  inspect(d.no_store, content="true")
  inspect(d.public_, content="true")
}

///|
test "parse_cache_control: invalid max-age value" {
  let d = parse_cache_control("max-age=abc")
  inspect(d.max_age, content="None")
}

///|
test "parse_cache_control: max-age=0" {
  let d = parse_cache_control("max-age=0")
  inspect(d.max_age, content="Some(0)")
}

///|
test "parse_cache_control: unknown directives ignored" {
  let d = parse_cache_control(
    "max-age=300, stale-while-revalidate=60, s-maxage=600",
  )
  inspect(d.max_age, content="Some(300)")
  // Unknown directives are silently ignored
  inspect(d.no_cache, content="false")
  inspect(d.no_store, content="false")
}

///|
test "parse_cache_control: duplicate directives" {
  // Last one wins for max-age
  let d = parse_cache_control("max-age=100, max-age=200")
  inspect(d.max_age, content="Some(200)")
}

///|
test "parse_cache_control: no-store and max-age combined" {
  // RFC 9111: no-store takes precedence
  let d = parse_cache_control("max-age=3600, no-store")
  inspect(d.max_age, content="Some(3600)")
  inspect(d.no_store, content="true")
  // is_fresh should return false because no_store
  let entry = make_entry(directives=d, stored_at=1000.0)
  inspect(is_fresh(entry, 1001.0), content="false")
}

// ============================================================
// ATTACKER PERSPECTIVE: Cache Poisoning / Deception
// ============================================================

///|
/// Attack: Stale entry revalidation returns 500 → must NOT overwrite cached good entry
test "cache attack: stale revalidation with 500 should not poison cache" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  // Pre-populate with good cached response (stale)
  let good_entry : CacheEntry = {
    url: "https://victim.test/api.js",
    status: 200,
    headers: { "cache-control": "max-age=0" },
    body: "legitimate-script",
    etag: Some("\"good\""),
    last_modified: None,
    directives: parse_cache_control("max-age=0"),
    stored_at: 0.0,
  }
  cache.store(good_entry)
  // Attacker causes server to return 500 during revalidation
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    { status: 500, headers: {}, body: "attacker-controlled-error" }
  }
  let r = cached_fetch(
    url="https://victim.test/api.js",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  // Should return the 500 (can't serve stale without must-revalidate special handling)
  inspect(r.status, content="500")
  // But the 500 must NOT be stored in cache
  match cache.lookup("https://victim.test/api.js") {
    Some(e) => {
      // Original good entry should still be there (not overwritten by 500)
      inspect(e.body, content="legitimate-script")
      inspect(e.status, content="200")
    }
    None => assert_true(false) // Should still have the original entry
  }
}

///|
/// Attack: HEAD request response should not be cached as GET
test "cache attack: HEAD response should not pollute GET cache" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    { status: 200, headers: { "cache-control": "max-age=300" }, body: "" }
  }
  let opts : FetchOptions = { ..FetchOptions::default(), http_method: "HEAD" }
  let _ = cached_fetch(
    url="https://victim.test/secret",
    options=opts,
    cache~,
    fetcher~,
  )
  // HEAD should bypass cache entirely
  inspect(cache.lookup("https://victim.test/secret").is_empty(), content="true")
}

///|
/// Attack: DELETE should invalidate but not itself be cached
test "cache attack: DELETE response should not be cached" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    { status: 200, headers: { "cache-control": "max-age=300" }, body: "deleted" }
  }
  let opts : FetchOptions = { ..FetchOptions::default(), http_method: "DELETE" }
  let _ = cached_fetch(
    url="https://victim.test/resource",
    options=opts,
    cache~,
    fetcher~,
  )
  inspect(cache.lookup("https://victim.test/resource").is_empty(), content="true")
}

///|
/// Attack: Response with no Cache-Control and no Last-Modified should not be cached
/// (no explicit or heuristic freshness → stale immediately, wasting cache space)
test "cache attack: response without any cache hints is still stored but immediately stale" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    { status: 200, headers: {}, body: "no-cache-headers" }
  }
  let _ = cached_fetch(
    url="https://example.com/no-hints",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  // Entry is stored (no no-store directive)
  match cache.lookup("https://example.com/no-hints") {
    Some(entry) =>
      // But it should be immediately stale (no max-age, no last-modified)
      inspect(is_fresh(entry, entry.stored_at + 1.0), content="false")
    None => () // Also acceptable: not stored at all
  }
}

///|
/// Attack: Cache key confusion — URLs with different query params should be separate
test "cache attack: different query params are separate cache keys" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let call_count = [0]
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    call_count[0] = call_count[0] + 1
    {
      status: 200,
      headers: { "cache-control": "max-age=300" },
      body: "response-" + call_count[0].to_string(),
    }
  }
  let opts = FetchOptions::default()
  let r1 = cached_fetch(
    url="https://example.com/api?user=alice",
    options=opts,
    cache~,
    fetcher~,
  )
  let r2 = cached_fetch(
    url="https://example.com/api?user=bob",
    options=opts,
    cache~,
    fetcher~,
  )
  // Different query params → different cache entries → different bodies
  inspect(r1.body, content="response-1")
  inspect(r2.body, content="response-2")
  inspect(call_count[0], content="2")
}

///|
/// Attack: URL with fragment should use same cache key as without fragment
/// (Fragments are client-side only per RFC 9110)
test "cache key: URLs differing only in fragment are separate (conservative)" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let call_count = [0]
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    call_count[0] = call_count[0] + 1
    {
      status: 200,
      headers: { "cache-control": "max-age=300" },
      body: "r" + call_count[0].to_string(),
    }
  }
  let opts = FetchOptions::default()
  // Current behavior: fragment is part of URL string → separate keys
  // This is conservative (safe, but wastes cache)
  let _ = cached_fetch(
    url="https://example.com/page",
    options=opts,
    cache~,
    fetcher~,
  )
  let _ = cached_fetch(
    url="https://example.com/page#section1",
    options=opts,
    cache~,
    fetcher~,
  )
  // Both URLs fetched separately
  inspect(call_count[0], content="2")
}

///|
/// Attack: Malicious 304 to a no-store entry should not extend its lifetime
test "cache attack: 304 on no-store entry should not refresh" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  // Pre-populate with no-store entry (should never have been stored, but testing defense-in-depth)
  let bad_entry : CacheEntry = {
    url: "https://example.com/secret",
    status: 200,
    headers: { "cache-control": "no-store" },
    body: "secret-data",
    etag: Some("\"v1\""),
    last_modified: None,
    directives: parse_cache_control("no-store"),
    stored_at: 0.0,
  }
  cache.store(bad_entry) // Simulating a bug that stored a no-store entry
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    { status: 304, headers: {}, body: "" }
  }
  let r = cached_fetch(
    url="https://example.com/secret",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  // is_fresh returns false for no-store, so fetcher is called
  // 304 refreshes stored_at, but the entry still has no-store
  // On next access, is_fresh will still return false
  inspect(r.status, content="200") // Returns cached body via 304
  match cache.lookup("https://example.com/secret") {
    Some(e) => inspect(is_fresh(e, e.stored_at + 1.0), content="false")
    None => ()
  }
}

///|
/// Attack: Very large max-age should not cause integer overflow
test "cache attack: very large max-age does not overflow" {
  let d = parse_cache_control("max-age=999999999")
  inspect(d.max_age, content="Some(999999999)")
  let entry = make_entry(directives=d, stored_at=1000.0)
  // Should still be fresh after a million seconds
  inspect(is_fresh(entry, 1000000.0), content="true")
}

///|
/// Attack: Negative-like max-age (starts with -)
test "cache attack: negative max-age is treated as invalid" {
  let d = parse_cache_control("max-age=-1")
  // parse_int_string rejects non-digit chars → None
  inspect(d.max_age, content="None")
}

///|
/// Attack: max-age with decimal point
test "cache attack: max-age with decimal is treated as invalid" {
  let d = parse_cache_control("max-age=300.5")
  inspect(d.max_age, content="None")
}

// ============================================================
// MODERN ATTACK VECTORS (2024-2026)
// ============================================================

///|
/// Web Cache Deception (WCD): Attacker tricks victim into visiting
/// /account/settings/nonexistent.css — if CDN caches based on extension,
/// private data gets cached publicly. Our cache uses exact URL key,
/// so verify private (no-store) content is never cached regardless of URL suffix.
test "WCD: private response with .css suffix must not be cached" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    {
      status: 200,
      headers: { "cache-control": "no-store, private", "content-type": "text/html" },
      body: "<html>secret account page</html>",
    }
  }
  let _ = cached_fetch(
    url="https://example.com/account/settings/evil.css",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  // no-store → must not be cached regardless of URL pattern
  inspect(
    cache.lookup("https://example.com/account/settings/evil.css").is_empty(),
    content="true",
  )
}

///|
/// Web Cache Deception variant: path confusion with encoded slash
/// /account%2Fsettings → should not share cache with /account/settings
test "WCD: URL-encoded path is distinct cache key" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let call_count = [0]
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    call_count[0] = call_count[0] + 1
    {
      status: 200,
      headers: { "cache-control": "max-age=300" },
      body: "resp" + call_count[0].to_string(),
    }
  }
  let opts = FetchOptions::default()
  let _ = cached_fetch(
    url="https://example.com/account/settings",
    options=opts,
    cache~,
    fetcher~,
  )
  let r2 = cached_fetch(
    url="https://example.com/account%2Fsettings",
    options=opts,
    cache~,
    fetcher~,
  )
  // Encoded path is separate key — not served from cache of decoded path
  inspect(call_count[0], content="2")
  inspect(r2.body, content="resp2")
}

///|
/// Cache Poisoning via header injection: Cache-Control value with CRLF
/// Attacker tries to inject extra headers via Cache-Control value
test "cache poisoning: CRLF in Cache-Control header value" {
  let d = parse_cache_control("max-age=300\r\nX-Injected: evil")
  // Should either parse max-age=300 only or fail gracefully
  // The \r\n is part of the string, not a real header boundary
  // parse_int_string will reject "300\r\nX-Injected: evil" since it contains non-digits
  // But split by comma first, so "max-age=300\r\nX-Injected: evil" is one token
  // trimmed.has_prefix("max-age=") → true
  // value_str = "300\r\nx-injected: evil" → parse_int_string rejects (non-digit \r)
  inspect(d.max_age, content="None")
  inspect(d.no_cache, content="false")
}

///|
/// Cache Poisoning: Cache-Control with null byte injection
test "cache poisoning: null byte in Cache-Control" {
  let d = parse_cache_control("max-age=300\x00no-store")
  // \x00 in the middle — should not silently truncate and parse max-age=300
  // Actually "max-age=300\x00no-store" is one comma-separated token
  // trim → to_lower → has_prefix("max-age=") → value_str contains \x00 → rejected
  inspect(d.max_age, content="None")
}

///|
/// XS-Leak via cache timing: ensure fetcher is called for no-cache entries
/// (If we served from cache, attacker could detect via timing whether user visited a URL)
test "XS-Leak: no-cache always revalidates (timing-safe)" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let entry : CacheEntry = {
    url: "https://sensitive.test/inbox",
    status: 200,
    headers: { "cache-control": "no-cache" },
    body: "private-emails",
    etag: Some("\"v1\""),
    last_modified: None,
    directives: parse_cache_control("no-cache"),
    stored_at: 1000.0,
  }
  cache.store(entry)
  let fetcher_called = [false]
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    fetcher_called[0] = true
    { status: 304, headers: {}, body: "" }
  }
  let _ = cached_fetch(
    url="https://sensitive.test/inbox",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  // Must always call fetcher for no-cache (prevents timing-based detection)
  inspect(fetcher_called[0], content="true")
}

///|
/// HTTP Response Splitting: ETag with CRLF injection
/// Attacker controls ETag value to inject headers in conditional request
test "response splitting: ETag with CRLF does not corrupt conditional request" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let malicious_etag = "\"valid\"\r\nX-Injected: evil"
  let entry : CacheEntry = {
    url: "https://example.com/resource",
    status: 200,
    headers: { "cache-control": "max-age=0" },
    body: "original",
    etag: Some(malicious_etag),
    last_modified: None,
    directives: parse_cache_control("max-age=0"),
    stored_at: 0.0,
  }
  cache.store(entry)
  let captured_headers = [("", "")]
  let fetcher = fn(
    _url : String,
    options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    // Capture what If-None-Match was sent
    match options.headers.get("If-None-Match") {
      Some(v) => captured_headers[0] = ("If-None-Match", v)
      None => ()
    }
    { status: 200, headers: { "cache-control": "max-age=300" }, body: "new" }
  }
  let _ = cached_fetch(
    url="https://example.com/resource",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  // The CRLF is passed as a single header value (not split)
  // In real HTTP, the transport layer should reject this
  // Our responsibility: don't create multiple headers from one value
  let (key, val) = captured_headers[0]
  inspect(key, content="If-None-Match")
  // Value contains the raw string including \r\n — it's the transport's job to reject
  inspect(val.contains("evil"), content="true")
}

///|
/// Prototype Pollution: header key "__proto__" should not affect behavior
test "prototype pollution: __proto__ header key is harmless" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  headers["__proto__"] = "{\"polluted\":true}"
  headers["constructor"] = "Object"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://victim.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "safe" },
  )
  // __proto__ and constructor are filtered by CORS (not safelisted)
  inspect(result.headers.contains("__proto__"), content="false")
  inspect(result.headers.contains("constructor"), content="false")
  inspect(result.status, content="200")
}

///|
/// Cache key pollution: URL with backslash (path traversal attempt)
/// Some servers normalize \ to / — our cache should treat them as distinct
test "cache key: backslash vs forward slash are distinct" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let call_count = [0]
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    call_count[0] = call_count[0] + 1
    {
      status: 200,
      headers: { "cache-control": "max-age=300" },
      body: "r" + call_count[0].to_string(),
    }
  }
  let opts = FetchOptions::default()
  let _ = cached_fetch(
    url="https://example.com/path/resource",
    options=opts,
    cache~,
    fetcher~,
  )
  let r2 = cached_fetch(
    url="https://example.com/path\\resource",
    options=opts,
    cache~,
    fetcher~,
  )
  inspect(call_count[0], content="2")
  inspect(r2.body, content="r2")
}

///|
/// Cache key: case-sensitive path (spec-compliant)
/// /Page and /page should be separate cache entries
test "cache key: path is case-sensitive" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let call_count = [0]
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    call_count[0] = call_count[0] + 1
    {
      status: 200,
      headers: { "cache-control": "max-age=300" },
      body: "r" + call_count[0].to_string(),
    }
  }
  let opts = FetchOptions::default()
  let _ = cached_fetch(
    url="https://example.com/Page",
    options=opts,
    cache~,
    fetcher~,
  )
  let r2 = cached_fetch(
    url="https://example.com/page",
    options=opts,
    cache~,
    fetcher~,
  )
  inspect(call_count[0], content="2")
  inspect(r2.body, content="r2")
}

///|
/// Supply chain attack: CDN serves stale malicious JS after server fixed
/// must-revalidate should force recheck even if max-age hasn't expired
test "supply chain: must-revalidate entry serves fresh within max-age" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  // Server initially serves compromised script with long max-age + must-revalidate
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    {
      status: 200,
      headers: { "cache-control": "max-age=86400, must-revalidate" },
      body: "compromised();",
    }
  }
  let _ = cached_fetch(
    url="https://cdn.test/lib.js",
    options=FetchOptions::default(),
    cache~,
    fetcher~,
  )
  // Within max-age: still served from cache (must-revalidate doesn't prevent this)
  let hit_fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    { status: 200, headers: {}, body: "fixed();" }
  }
  let r = cached_fetch(
    url="https://cdn.test/lib.js",
    options=FetchOptions::default(),
    cache=cache,
    fetcher=hit_fetcher,
  )
  // Within max-age → served from cache (this is correct per spec)
  // must-revalidate only applies AFTER expiry
  inspect(r.body, content="compromised();")
}

///|
/// Race condition: concurrent requests to same URL
/// After first fetch stores entry, second should use cache
test "race: sequential fetches use cache correctly" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let call_count = [0]
  let fetcher = fn(
    _url : String,
    _options : FetchOptions,
  ) -> HttpResponse raise HttpError {
    call_count[0] = call_count[0] + 1
    {
      status: 200,
      headers: { "cache-control": "max-age=300" },
      body: "v" + call_count[0].to_string(),
    }
  }
  let opts = FetchOptions::default()
  // Simulate 5 sequential requests
  let mut last_body = ""
  for i = 0; i < 5; i = i + 1 {
    let r = cached_fetch(
      url="https://example.com/hot-resource",
      options=opts,
      cache~,
      fetcher~,
    )
    last_body = r.body
  }
  // Only first should call fetcher
  inspect(call_count[0], content="1")
  inspect(last_body, content="v1")
}

///|
/// Cache eviction attack: attacker floods cache with unique URLs to evict victim's entries
test "eviction attack: flooding evicts oldest entries" {
  let cache = MemoryCacheBackend::new(max_entries=3)
  // Victim stores a legitimate entry
  let victim_entry : CacheEntry = {
    url: "https://victim.test/important.js",
    status: 200,
    headers: {},
    body: "important",
    etag: None,
    last_modified: None,
    directives: parse_cache_control("max-age=3600"),
    stored_at: 100.0,
  }
  cache.store(victim_entry)
  // Attacker floods with 3 unique URLs (exceeds max_entries)
  for i = 0; i < 3; i = i + 1 {
    let attacker_entry : CacheEntry = {
      url: "https://attacker.test/" + i.to_string(),
      status: 200,
      headers: {},
      body: "junk",
      etag: None,
      last_modified: None,
      directives: CacheDirectives::default(),
      stored_at: 200.0 + i.to_double(),
    }
    cache.store(attacker_entry)
  }
  // Victim's entry (oldest) should be evicted
  inspect(
    cache.lookup("https://victim.test/important.js").is_empty(),
    content="true",
  )
}
