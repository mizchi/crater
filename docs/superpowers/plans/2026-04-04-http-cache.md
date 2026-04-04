# HTTP Browser Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an HTTP cache layer to `browser/src/http/` that transparently caches static asset responses with full HTTP cache semantics, backed by in-memory or SQLite storage.

**Architecture:** `cached_fetch` wraps any injected fetcher function. Before calling the fetcher, it checks the cache backend for a fresh entry. Stale entries trigger conditional requests with `If-None-Match`/`If-Modified-Since`. Two backends: `MemoryCacheBackend` (in-memory Map) and `SqliteCacheBackend` (`mizchi/sqlite`).

**Tech Stack:** MoonBit, `mizchi/sqlite` v0.2.3 (Node.js `node:sqlite` bindings), JS target `Date.now()` for timestamps.

---

## File Map

| File | Responsibility |
|------|---------------|
| `browser/src/http/cache.mbt` | `CacheDirectives`, `CacheEntry`, `parse_cache_control`, `is_fresh`, `now_seconds` |
| `browser/src/http/cache_backend.mbt` | `MemoryCacheBackend` (trait-duck-typed: `lookup`, `store`, `remove`, `clear`) |
| `browser/src/http/cache_fetch.mbt` | `cached_fetch` (backend-agnostic, fetcher-injectable) |
| `browser/src/http/cache_sqlite_js.mbt` | `SqliteCacheBackend` for JS target using `mizchi/sqlite` |
| `browser/src/http/cache_wbtest.mbt` | All cache tests |
| `browser/src/http/moon.pkg` | Add `mizchi/sqlite` dependency, target config for sqlite file |

> **Note on traits:** MoonBit uses structural typing for method dispatch. Both backends implement the same method signatures (`lookup`, `store`, `remove`, `clear`) but `cached_fetch` takes a concrete backend type via generics rather than a trait object. We use `MemoryCacheBackend` in tests and the caller picks the backend type at the call site.

---

### Task 1: CacheDirectives and parse_cache_control

**Files:**
- Create: `browser/src/http/cache.mbt`
- Create: `browser/src/http/cache_wbtest.mbt`

- [ ] **Step 1: Write failing tests for parse_cache_control**

In `browser/src/http/cache_wbtest.mbt`:

```moonbit
///|
test "parse_cache_control: max-age only" {
  let d = parse_cache_control("max-age=300")
  inspect(d.max_age, content="Some(300)")
  inspect(d.no_cache, content="false")
  inspect(d.no_store, content="false")
  inspect(d.must_revalidate, content="false")
  inspect(d.immutable, content="false")
}

///|
test "parse_cache_control: no-store" {
  let d = parse_cache_control("no-store")
  inspect(d.no_store, content="true")
  inspect(d.max_age, content="None")
}

///|
test "parse_cache_control: no-cache, must-revalidate" {
  let d = parse_cache_control("no-cache, must-revalidate")
  inspect(d.no_cache, content="true")
  inspect(d.must_revalidate, content="true")
}

///|
test "parse_cache_control: public, max-age=3600, immutable" {
  let d = parse_cache_control("public, max-age=3600, immutable")
  inspect(d.public_, content="true")
  inspect(d.max_age, content="Some(3600)")
  inspect(d.immutable, content="true")
}

///|
test "parse_cache_control: empty string" {
  let d = parse_cache_control("")
  inspect(d.max_age, content="None")
  inspect(d.no_cache, content="false")
  inspect(d.no_store, content="false")
}

///|
test "parse_cache_control: private" {
  let d = parse_cache_control("private, max-age=0, must-revalidate")
  inspect(d.private_, content="true")
  inspect(d.max_age, content="Some(0)")
  inspect(d.must_revalidate, content="true")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test -p mizchi/crater-browser/http -f cache_wbtest.mbt 2>&1 | tail -5`
Expected: Compilation errors (`parse_cache_control` not defined)

- [ ] **Step 3: Implement CacheDirectives and parse_cache_control**

In `browser/src/http/cache.mbt`:

```moonbit
///|
/// Parsed Cache-Control header directives
pub(all) struct CacheDirectives {
  max_age : Int?
  no_cache : Bool
  no_store : Bool
  must_revalidate : Bool
  public_ : Bool
  private_ : Bool
  immutable : Bool
} derive(Show)

///|
/// Default CacheDirectives (no directives set)
pub fn CacheDirectives::default() -> CacheDirectives {
  {
    max_age: None,
    no_cache: false,
    no_store: false,
    must_revalidate: false,
    public_: false,
    private_: false,
    immutable: false,
  }
}

///|
/// Parse Cache-Control header value into CacheDirectives.
/// Example: "public, max-age=3600, immutable"
pub fn parse_cache_control(header : String) -> CacheDirectives {
  let mut max_age : Int? = None
  let mut no_cache = false
  let mut no_store = false
  let mut must_revalidate = false
  let mut public_ = false
  let mut private_ = false
  let mut immutable = false
  let parts = header.split(",")
  for part in parts {
    let directive = part.to_string().trim().to_string().to_lower()
    if directive == "no-cache" {
      no_cache = true
    } else if directive == "no-store" {
      no_store = true
    } else if directive == "must-revalidate" {
      must_revalidate = true
    } else if directive == "public" {
      public_ = true
    } else if directive == "private" {
      private_ = true
    } else if directive == "immutable" {
      immutable = true
    } else if directive.has_prefix("max-age=") {
      let val_str = directive.unsafe_substring(
        start="max-age=".length(),
        end=directive.length(),
      )
      let mut num = 0
      let mut valid = true
      let chars = val_str.to_array()
      for c in chars {
        if c >= '0' && c <= '9' {
          num = num * 10 + (c.to_int() - '0'.to_int())
        } else {
          valid = false
          break
        }
      }
      if valid && chars.length() > 0 {
        max_age = Some(num)
      }
    }
  }
  { max_age, no_cache, no_store, must_revalidate, public_, private_, immutable }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test -p mizchi/crater-browser/http -f cache_wbtest.mbt 2>&1 | tail -5`
Expected: All 6 tests pass

- [ ] **Step 5: Commit**

```bash
git add browser/src/http/cache.mbt browser/src/http/cache_wbtest.mbt
git commit -m "feat(http): add CacheDirectives and parse_cache_control"
```

---

### Task 2: CacheEntry and is_fresh

**Files:**
- Modify: `browser/src/http/cache.mbt`
- Modify: `browser/src/http/cache_wbtest.mbt`

- [ ] **Step 1: Write failing tests for is_fresh**

Append to `browser/src/http/cache_wbtest.mbt`:

```moonbit
///|
fn make_entry(
  directives : CacheDirectives,
  stored_at : Double,
  last_modified? : String? = None,
) -> CacheEntry {
  {
    url: "https://example.com/style.css",
    status: 200,
    headers: {},
    body: "body",
    etag: None,
    last_modified,
    directives,
    stored_at,
  }
}

///|
test "is_fresh: max_age not expired" {
  let entry = make_entry(
    parse_cache_control("max-age=300"),
    1000.0,
  )
  // now = 1100 → 100s elapsed < 300s max_age → fresh
  inspect(is_fresh(entry, 1100.0), content="true")
}

///|
test "is_fresh: max_age expired" {
  let entry = make_entry(
    parse_cache_control("max-age=300"),
    1000.0,
  )
  // now = 1400 → 400s elapsed > 300s max_age → stale
  inspect(is_fresh(entry, 1400.0), content="false")
}

///|
test "is_fresh: immutable" {
  let entry = make_entry(
    parse_cache_control("immutable"),
    0.0,
  )
  inspect(is_fresh(entry, 999999.0), content="true")
}

///|
test "is_fresh: no_store" {
  let entry = make_entry(
    parse_cache_control("no-store"),
    1000.0,
  )
  inspect(is_fresh(entry, 1000.0), content="false")
}

///|
test "is_fresh: no directives, no last_modified" {
  let entry = make_entry(
    CacheDirectives::default(),
    1000.0,
  )
  inspect(is_fresh(entry, 1001.0), content="false")
}

///|
test "is_fresh: heuristic with last_modified" {
  // last_modified is an HTTP-date string. For heuristic, we parse the epoch.
  // For simplicity, store the epoch as string "500"
  // stored_at=1000, last_modified_epoch=500 → age_of_resource=500
  // heuristic_lifetime = 500 * 0.1 = 50
  // elapsed=30 < 50 → fresh
  let entry = make_entry(
    CacheDirectives::default(),
    1000.0,
    last_modified=Some("500"),
  )
  inspect(is_fresh(entry, 1030.0), content="true")
}

///|
test "is_fresh: heuristic expired" {
  // heuristic_lifetime = 500 * 0.1 = 50
  // elapsed=60 > 50 → stale
  let entry = make_entry(
    CacheDirectives::default(),
    1000.0,
    last_modified=Some("500"),
  )
  inspect(is_fresh(entry, 1060.0), content="false")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test -p mizchi/crater-browser/http -f cache_wbtest.mbt 2>&1 | tail -5`
Expected: Compilation errors (`CacheEntry`, `is_fresh` not defined)

- [ ] **Step 3: Implement CacheEntry and is_fresh**

Append to `browser/src/http/cache.mbt`:

```moonbit
///|
/// Cached HTTP response entry
pub(all) struct CacheEntry {
  url : String
  status : Int
  headers : Map[String, String]
  body : String
  etag : String?
  last_modified : String?
  directives : CacheDirectives
  stored_at : Double  // Unix epoch seconds
} derive(Show)

///|
/// Check if a cache entry is still fresh.
/// `now` is Unix epoch seconds.
pub fn is_fresh(entry : CacheEntry, now : Double) -> Bool {
  let d = entry.directives
  // no-store should never be cached, but defensively return stale
  if d.no_store {
    return false
  }
  // immutable never expires
  if d.immutable {
    return true
  }
  // no-cache means must revalidate (treat as stale)
  if d.no_cache {
    return false
  }
  let elapsed = now - entry.stored_at
  // max-age takes precedence
  match d.max_age {
    Some(max_age) => elapsed < max_age.to_double()
    None =>
      // Heuristic: 10% of resource age based on last_modified
      match entry.last_modified {
        Some(lm) => {
          let lm_epoch = parse_epoch_string(lm)
          if lm_epoch > 0.0 {
            let resource_age = entry.stored_at - lm_epoch
            let heuristic_lifetime = resource_age * 0.1
            elapsed < heuristic_lifetime
          } else {
            false
          }
        }
        None => false
      }
  }
}

///|
/// Parse a numeric epoch string (seconds). Returns 0.0 on failure.
/// In production, Last-Modified is an HTTP-date; for tests we use epoch strings.
fn parse_epoch_string(s : String) -> Double {
  let mut result = 0.0
  let chars = s.to_array()
  for c in chars {
    if c >= '0' && c <= '9' {
      result = result * 10.0 + (c.to_int() - '0'.to_int()).to_double()
    } else {
      return 0.0
    }
  }
  result
}

///|
/// Get current time as Unix epoch seconds (JS target)
extern "js" fn js_now_seconds() -> Double =
  #| () => Date.now() / 1000

///|
/// Get current time as Unix epoch seconds
pub fn now_seconds() -> Double {
  js_now_seconds()
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test -p mizchi/crater-browser/http -f cache_wbtest.mbt 2>&1 | tail -5`
Expected: All 13 tests pass

- [ ] **Step 5: Commit**

```bash
git add browser/src/http/cache.mbt browser/src/http/cache_wbtest.mbt
git commit -m "feat(http): add CacheEntry and is_fresh freshness check"
```

---

### Task 3: MemoryCacheBackend

**Files:**
- Create: `browser/src/http/cache_backend.mbt`
- Modify: `browser/src/http/cache_wbtest.mbt`

- [ ] **Step 1: Write failing tests**

Append to `browser/src/http/cache_wbtest.mbt`:

```moonbit
///|
test "MemoryCacheBackend: store and lookup" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let entry = make_entry(CacheDirectives::default(), 1000.0)
  cache.store(entry)
  let found = cache.lookup("https://example.com/style.css")
  inspect(found.is_empty().not(), content="true")
}

///|
test "MemoryCacheBackend: lookup miss" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let found = cache.lookup("https://example.com/missing.css")
  inspect(found.is_empty(), content="true")
}

///|
test "MemoryCacheBackend: remove" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let entry = make_entry(CacheDirectives::default(), 1000.0)
  cache.store(entry)
  cache.remove("https://example.com/style.css")
  inspect(cache.lookup("https://example.com/style.css").is_empty(), content="true")
}

///|
test "MemoryCacheBackend: clear" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  cache.store(make_entry(CacheDirectives::default(), 1000.0))
  cache.clear()
  inspect(cache.lookup("https://example.com/style.css").is_empty(), content="true")
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
  inspect(cache.lookup("https://a.com/2").is_empty().not(), content="true")
  inspect(cache.lookup("https://a.com/3").is_empty().not(), content="true")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test -p mizchi/crater-browser/http -f cache_wbtest.mbt 2>&1 | tail -5`
Expected: `MemoryCacheBackend` not defined

- [ ] **Step 3: Implement MemoryCacheBackend**

In `browser/src/http/cache_backend.mbt`:

```moonbit
///|
/// In-memory cache backend for BiDi server use.
/// Entries are evicted by oldest stored_at when max_entries is reached.
pub struct MemoryCacheBackend {
  entries : Map[String, CacheEntry]
  max_entries : Int
}

///|
pub fn MemoryCacheBackend::new(
  max_entries? : Int = 1000,
) -> MemoryCacheBackend {
  { entries: {}, max_entries }
}

///|
pub fn MemoryCacheBackend::lookup(
  self : MemoryCacheBackend,
  url : String,
) -> CacheEntry? {
  self.entries.get(url)
}

///|
pub fn MemoryCacheBackend::store(
  self : MemoryCacheBackend,
  entry : CacheEntry,
) -> Unit {
  // Evict oldest if at capacity (and not an update)
  if not(self.entries.contains(entry.url)) &&
    self.entries.size() >= self.max_entries {
    let mut oldest_url = ""
    let mut oldest_time = 1.0e18 // large sentinel
    for url, e in self.entries {
      if e.stored_at < oldest_time {
        oldest_time = e.stored_at
        oldest_url = url
      }
    }
    if oldest_url.length() > 0 {
      self.entries.remove(oldest_url)
    }
  }
  self.entries[entry.url] = entry
}

///|
pub fn MemoryCacheBackend::remove(
  self : MemoryCacheBackend,
  url : String,
) -> Unit {
  self.entries.remove(url)
}

///|
pub fn MemoryCacheBackend::clear(self : MemoryCacheBackend) -> Unit {
  self.entries.clear()
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test -p mizchi/crater-browser/http -f cache_wbtest.mbt 2>&1 | tail -5`
Expected: All 18 tests pass

- [ ] **Step 5: Commit**

```bash
git add browser/src/http/cache_backend.mbt browser/src/http/cache_wbtest.mbt
git commit -m "feat(http): add MemoryCacheBackend with eviction"
```

---

### Task 4: cached_fetch

**Files:**
- Create: `browser/src/http/cache_fetch.mbt`
- Modify: `browser/src/http/cache_wbtest.mbt`

- [ ] **Step 1: Write failing tests with mock fetcher**

Append to `browser/src/http/cache_wbtest.mbt`:

```moonbit
///|
/// Mock fetcher that tracks call count via mutable array
fn mock_fetcher(
  responses : Map[String, HttpResponse],
  call_log : Array[String],
) -> (String, FetchOptions) -> HttpResponse!HttpError {
  fn(url : String, _options : FetchOptions) -> HttpResponse!HttpError {
    call_log.push(url)
    match responses.get(url) {
      Some(r) => r
      None => raise NetworkError("mock: not found")
    }
  }
}

///|
test "cached_fetch: miss then hit" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let responses : Map[String, HttpResponse] = {}
  responses["https://example.com/style.css"] = {
    status: 200,
    headers: { "cache-control": "max-age=300" },
    body: ".h1{color:red}",
  }
  let log : Array[String] = []
  let fetcher = mock_fetcher(responses, log)
  let opts = FetchOptions::default()

  // First call: cache miss → fetcher called
  let r1 = cached_fetch!("https://example.com/style.css", opts, cache, fetcher)
  inspect(r1.status, content="200")
  inspect(log.length(), content="1")

  // Second call: cache hit → fetcher NOT called
  let r2 = cached_fetch!("https://example.com/style.css", opts, cache, fetcher)
  inspect(r2.body, content=".h1{color:red}")
  inspect(log.length(), content="1") // still 1
}

///|
test "cached_fetch: no-store skips cache" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let responses : Map[String, HttpResponse] = {}
  responses["https://example.com/ns.css"] = {
    status: 200,
    headers: { "cache-control": "no-store" },
    body: "body",
  }
  let log : Array[String] = []
  let fetcher = mock_fetcher(responses, log)
  let opts = FetchOptions::default()

  let _ = cached_fetch!("https://example.com/ns.css", opts, cache, fetcher)
  // Should not be stored
  inspect(cache.lookup("https://example.com/ns.css").is_empty(), content="true")
}

///|
test "cached_fetch: stale entry with etag sends conditional request" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  // Pre-populate with stale entry (max-age=0, stored in past)
  let stale_entry : CacheEntry = {
    url: "https://example.com/old.css",
    status: 200,
    headers: { "cache-control": "max-age=0" },
    body: "old-body",
    etag: Some("\"abc123\""),
    last_modified: None,
    directives: parse_cache_control("max-age=0"),
    stored_at: 0.0,
  }
  cache.store(stale_entry)

  // Server returns 304
  let responses : Map[String, HttpResponse] = {}
  responses["https://example.com/old.css"] = {
    status: 304,
    headers: {},
    body: "",
  }
  let log : Array[String] = []
  let fetcher = mock_fetcher(responses, log)
  let opts = FetchOptions::default()

  let r = cached_fetch!("https://example.com/old.css", opts, cache, fetcher)
  // Should return cached body
  inspect(r.body, content="old-body")
  inspect(r.status, content="200")
  inspect(log.length(), content="1") // fetcher was called for revalidation
}

///|
test "cached_fetch: non-GET bypasses cache" {
  let cache = MemoryCacheBackend::new(max_entries=10)
  let responses : Map[String, HttpResponse] = {}
  responses["https://example.com/api"] = {
    status: 200,
    headers: { "cache-control": "max-age=3600" },
    body: "response",
  }
  let log : Array[String] = []
  let fetcher = mock_fetcher(responses, log)
  let opts : FetchOptions = { ..FetchOptions::default(), http_method: "POST" }

  let _ = cached_fetch!("https://example.com/api", opts, cache, fetcher)
  // Should not be stored
  inspect(cache.lookup("https://example.com/api").is_empty(), content="true")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test -p mizchi/crater-browser/http -f cache_wbtest.mbt 2>&1 | tail -5`
Expected: `cached_fetch` not defined

- [ ] **Step 3: Implement cached_fetch**

In `browser/src/http/cache_fetch.mbt`:

```moonbit
///|
/// Build a CacheEntry from a URL and HttpResponse.
fn build_cache_entry(url : String, response : HttpResponse) -> CacheEntry {
  let cache_control_header = get_header(response.headers, "cache-control")
  let directives = match cache_control_header {
    Some(h) => parse_cache_control(h)
    None => CacheDirectives::default()
  }
  let etag = get_header(response.headers, "etag")
  let last_modified = get_header(response.headers, "last-modified")
  {
    url,
    status: response.status,
    headers: response.headers,
    body: response.body,
    etag,
    last_modified,
    directives,
    stored_at: now_seconds(),
  }
}

///|
/// Convert a CacheEntry back to an HttpResponse.
fn entry_to_response(entry : CacheEntry) -> HttpResponse {
  { status: entry.status, headers: entry.headers, body: entry.body }
}

///|
/// Fetch with transparent HTTP caching.
///
/// Only GET requests are cached. The `fetcher` parameter allows callers to
/// inject any transport function (real HTTP, mock, BiDi-specific wrapper, etc.).
pub fn cached_fetch(
  url : String,
  options : FetchOptions,
  cache : MemoryCacheBackend,
  fetcher : (String, FetchOptions) -> HttpResponse!HttpError,
) -> HttpResponse!HttpError {
  // Only cache GET requests
  if options.http_method != "GET" {
    return fetcher!(url, options)
  }

  let now = now_seconds()

  // Check cache
  match cache.lookup(url) {
    Some(entry) =>
      if is_fresh(entry, now) {
        // Cache hit, fresh
        return entry_to_response(entry)
      } else {
        // Stale: send conditional request
        let mut modified_headers : Map[String, String] = {}
        for k, v in options.headers {
          modified_headers[k] = v
        }
        match entry.etag {
          Some(etag) => modified_headers["If-None-Match"] = etag
          None => ()
        }
        match entry.last_modified {
          Some(lm) => modified_headers["If-Modified-Since"] = lm
          None => ()
        }
        let modified_options : FetchOptions = {
          ..options,
          headers: modified_headers,
        }
        let response = fetcher!(url, modified_options)
        if response.status == 304 {
          // Not modified: refresh stored_at and return cached
          let refreshed : CacheEntry = { ..entry, stored_at: now }
          cache.store(refreshed)
          return entry_to_response(entry)
        }
        // New response: store if cacheable
        let new_entry = build_cache_entry(url, response)
        if not(new_entry.directives.no_store) {
          cache.store(new_entry)
        }
        return response
      }
    None => {
      // Cache miss
      let response = fetcher!(url, options)
      let entry = build_cache_entry(url, response)
      if not(entry.directives.no_store) {
        cache.store(entry)
      }
      return response
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test -p mizchi/crater-browser/http -f cache_wbtest.mbt 2>&1 | tail -5`
Expected: All 22 tests pass

- [ ] **Step 5: Commit**

```bash
git add browser/src/http/cache_fetch.mbt browser/src/http/cache_wbtest.mbt
git commit -m "feat(http): add cached_fetch with conditional request support"
```

---

### Task 5: SqliteCacheBackend

**Files:**
- Create: `browser/src/http/cache_sqlite_js.mbt`
- Modify: `browser/src/http/moon.pkg`
- Modify: `browser/src/http/cache_wbtest.mbt`

- [ ] **Step 1: Add mizchi/sqlite dependency to moon.pkg**

Update `browser/src/http/moon.pkg` to:

```json
import {
  "moonbitlang/async/http" @async_http,
  "moonbitlang/async/js_async",
  "moonbitlang/async/io" @async_io,
  "moonbitlang/core/json",
  "moonbitlang/core/strconv",
  "mizchi/sqlite",
}

warnings = "-unused_package"

options(
  targets: {
    "http_js.mbt": [ "js" ],
    "http_native.mbt": [ "native" ],
    "http_wasm.mbt": [ "wasm", "wasm-gc" ],
    "cache_sqlite_js.mbt": [ "js" ],
  },
)
```

Also add `mizchi/sqlite` to `browser/moon.mod.json` deps if not already present:

Run: `cat browser/moon.mod.json` to check, then add `"mizchi/sqlite": "0.2.3"` to deps.

- [ ] **Step 2: Write failing tests for SqliteCacheBackend**

Append to `browser/src/http/cache_wbtest.mbt`:

```moonbit
///|
test "SqliteCacheBackend: store and lookup" {
  let cache = SqliteCacheBackend::new(":memory:")
  let entry = make_entry(parse_cache_control("max-age=300"), 1000.0)
  cache.store(entry)
  let found = cache.lookup("https://example.com/style.css")
  inspect(found.is_empty().not(), content="true")
  match found {
    Some(e) => {
      inspect(e.status, content="200")
      inspect(e.body, content="body")
      inspect(e.directives.max_age, content="Some(300)")
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
  cache.store(make_entry(CacheDirectives::default(), 1000.0))
  cache.remove("https://example.com/style.css")
  inspect(cache.lookup("https://example.com/style.css").is_empty(), content="true")
}

///|
test "SqliteCacheBackend: clear" {
  let cache = SqliteCacheBackend::new(":memory:")
  cache.store(make_entry(CacheDirectives::default(), 1000.0))
  cache.clear()
  inspect(cache.lookup("https://example.com/style.css").is_empty(), content="true")
}

///|
test "SqliteCacheBackend: etag and last_modified roundtrip" {
  let cache = SqliteCacheBackend::new(":memory:")
  let entry : CacheEntry = {
    url: "https://example.com/img.png",
    status: 200,
    headers: { "content-type": "image/png" },
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
      inspect(e.last_modified, content="Some(\"Wed, 01 Jan 2025 00:00:00 GMT\")")
      inspect(e.directives.public_, content="true")
      inspect(e.directives.max_age, content="Some(86400)")
      inspect(e.stored_at, content="5000")
    }
    None => panic()
  }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `moon test -p mizchi/crater-browser/http -f cache_wbtest.mbt 2>&1 | tail -5`
Expected: `SqliteCacheBackend` not defined

- [ ] **Step 4: Implement SqliteCacheBackend**

In `browser/src/http/cache_sqlite_js.mbt`:

```moonbit
///|
/// SQLite-backed HTTP cache for VRT/test persistence.
/// Uses mizchi/sqlite (node:sqlite bindings).
pub struct SqliteCacheBackend {
  db : @sqlite.Database
}

///|
/// Create a new SQLite cache backend.
/// `db_path` is the SQLite database path. Use ":memory:" for in-memory.
pub fn SqliteCacheBackend::new(db_path : String) -> SqliteCacheBackend {
  let db = match @sqlite.Database::open(db_path) {
    Some(db) => db
    None => panic()
  }
  db.exec(
    "CREATE TABLE IF NOT EXISTS http_cache (url TEXT PRIMARY KEY, status INTEGER NOT NULL, headers TEXT NOT NULL, body TEXT, etag TEXT, last_modified TEXT, cache_control TEXT, stored_at REAL NOT NULL)",
  )
  |> ignore
  { db }
}

///|
pub fn SqliteCacheBackend::lookup(
  self : SqliteCacheBackend,
  url : String,
) -> CacheEntry? {
  let stmt = match self.db.prepare(
    "SELECT url, status, headers, body, etag, last_modified, cache_control, stored_at FROM http_cache WHERE url = ?",
  ) {
    Some(s) => s
    None => return None
  }
  stmt.bind(1, @sqlite.Text(string_to_bytes(url))) |> ignore
  if stmt.step() {
    let entry_url = bytes_to_string(stmt.column_text(0))
    let status = stmt.column_int(1)
    let headers_json = bytes_to_string(stmt.column_text(2))
    let body = bytes_to_string(stmt.column_text(3))
    let etag = column_optional_text(stmt, 4)
    let last_modified = column_optional_text(stmt, 5)
    let cache_control = bytes_to_string(stmt.column_text(6))
    let stored_at = match stmt.column(7) {
      @sqlite.Double(v) => v
      @sqlite.Int(v) => v.to_double()
      _ => 0.0
    }
    stmt.finalize()
    let headers = parse_headers_from_json(headers_json)
    let directives = parse_cache_control(cache_control)
    Some(
      {
        url: entry_url,
        status,
        headers,
        body,
        etag,
        last_modified,
        directives,
        stored_at,
      },
    )
  } else {
    stmt.finalize()
    None
  }
}

///|
pub fn SqliteCacheBackend::store(
  self : SqliteCacheBackend,
  entry : CacheEntry,
) -> Unit {
  let stmt = match self.db.prepare(
    "INSERT OR REPLACE INTO http_cache (url, status, headers, body, etag, last_modified, cache_control, stored_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
  ) {
    Some(s) => s
    None => return
  }
  let cc_header = match get_header(entry.headers, "cache-control") {
    Some(h) => h
    None => ""
  }
  stmt.bind(1, @sqlite.Text(string_to_bytes(entry.url))) |> ignore
  stmt.bind(2, @sqlite.Int(entry.status)) |> ignore
  stmt.bind(3, @sqlite.Text(string_to_bytes(headers_to_json(entry.headers))))
  |> ignore
  stmt.bind(4, @sqlite.Text(string_to_bytes(entry.body))) |> ignore
  stmt.bind(
    5,
    match entry.etag {
      Some(e) => @sqlite.Text(string_to_bytes(e))
      None => @sqlite.Null
    },
  )
  |> ignore
  stmt.bind(
    6,
    match entry.last_modified {
      Some(lm) => @sqlite.Text(string_to_bytes(lm))
      None => @sqlite.Null
    },
  )
  |> ignore
  stmt.bind(7, @sqlite.Text(string_to_bytes(cc_header))) |> ignore
  stmt.bind(8, @sqlite.Double(entry.stored_at)) |> ignore
  stmt.execute() |> ignore
  stmt.finalize()
}

///|
pub fn SqliteCacheBackend::remove(
  self : SqliteCacheBackend,
  url : String,
) -> Unit {
  let stmt = match self.db.prepare("DELETE FROM http_cache WHERE url = ?") {
    Some(s) => s
    None => return
  }
  stmt.bind(1, @sqlite.Text(string_to_bytes(url))) |> ignore
  stmt.execute() |> ignore
  stmt.finalize()
}

///|
pub fn SqliteCacheBackend::clear(self : SqliteCacheBackend) -> Unit {
  self.db.exec("DELETE FROM http_cache") |> ignore
}

///|
/// Helper: extract optional text column (returns None if NULL)
fn column_optional_text(stmt : @sqlite.Statement, col : Int) -> String? {
  match stmt.column(col) {
    @sqlite.Text(bytes) => {
      let s = bytes_to_string(bytes)
      if s.is_empty() { None } else { Some(s) }
    }
    @sqlite.Null => None
    _ => None
  }
}

///|
/// Helper: convert Bytes to String
fn bytes_to_string(bytes : Bytes) -> String {
  bytes.to_unchecked_string()
}

///|
/// Helper: convert String to Bytes
fn string_to_bytes(s : String) -> Bytes {
  s.to_bytes()
}

///|
/// Helper: parse JSON-encoded headers map
fn parse_headers_from_json(json_str : String) -> Map[String, String] {
  let headers : Map[String, String] = {}
  if json_str.is_empty() || json_str == "{}" {
    return headers
  }
  let json = @json.parse(json_str) catch { _ => return headers }
  match json {
    Object(map) =>
      map.each(fn(k, v) {
        match v {
          String(s) => headers[k] = s
          _ => ()
        }
      })
    _ => ()
  }
  headers
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `moon test -p mizchi/crater-browser/http -f cache_wbtest.mbt 2>&1 | tail -5`
Expected: All 27 tests pass

- [ ] **Step 6: Commit**

```bash
git add browser/src/http/cache_sqlite_js.mbt browser/src/http/moon.pkg browser/moon.mod.json browser/src/http/cache_wbtest.mbt
git commit -m "feat(http): add SqliteCacheBackend with mizchi/sqlite"
```

---

### Task 6: Update moon.pkg, run moon info && moon fmt, final verification

**Files:**
- Modify: `browser/src/http/moon.pkg` (if not done in Task 5)
- All new files

- [ ] **Step 1: Run full test suite for http package**

Run: `moon test -p mizchi/crater-browser/http 2>&1 | tail -10`
Expected: All tests pass (existing + new)

- [ ] **Step 2: Run moon check for entire project**

Run: `moon check 2>&1 | tail -5`
Expected: 0 errors

- [ ] **Step 3: Run moon info && moon fmt**

Run: `moon info && moon fmt`
Check: `git diff -- '*.mbti'` to verify only expected interface changes

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore(http): update interfaces and format for cache module"
```
