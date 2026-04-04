# HTTP Browser Cache for Static Assets

## Overview

Add an HTTP cache layer to `browser/src/http/` that transparently caches static asset responses (CSS, JS, images, fonts) with full HTTP cache semantics. Two backends: in-memory for the BiDi server (inter-navigation caching) and SQLite (`mizchi/sqlite`) for VRT/test persistence.

## Goals

- Avoid redundant fetches for unchanged static assets across navigations
- Support standard HTTP cache validation: `Cache-Control`, `ETag`, `If-None-Match`, `Last-Modified`, `If-Modified-Since`, `304 Not Modified`
- Persist cache across VRT/test runs via SQLite
- Keep fetch logic injectable so callers can swap the underlying transport

## Non-Goals

- `Vary` header support
- `stale-while-revalidate`, `stale-if-error` directives
- Shared/proxy cache semantics
- Document (HTML) caching — always fetched fresh

---

## Architecture

### Integration Point

Cache sits in `browser/src/http/` as a `cached_fetch` function that wraps any fetcher:

```
fetch() is injected
         ↓
cached_fetch(url, options, cache, fetcher)
  → cache.lookup(url)
  → hit & fresh? → return cached response
  → hit & stale? → add If-None-Match / If-Modified-Since → fetcher()
                   → 304? → return cached (update stored_at)
                   → 200? → cache.store() → return
  → miss? → fetcher() → no_store? skip : cache.store() → return
```

Only GET requests are cached. Non-GET bypasses directly to `fetcher`.

### Cache Key

URL string (exact match). No query-string stripping or normalization.

---

## Core Types

### CacheDirectives

Parsed representation of the `Cache-Control` header.

```
CacheDirectives {
  max_age: Int?
  no_cache: Bool        // must revalidate before use
  no_store: Bool        // do not cache
  must_revalidate: Bool // stale entries must be revalidated
  public_: Bool
  private_: Bool
  immutable: Bool       // never changes
}
```

### CacheEntry

```
CacheEntry {
  url: String
  status: Int
  headers: Map[String, String]
  body: String
  etag: String?
  last_modified: String?
  directives: CacheDirectives
  stored_at: Double     // Unix epoch seconds
}
```

### Freshness Check

`is_fresh(entry: CacheEntry, now: Double) -> Bool`

1. `no_store` → false (should not be cached at all, but defensive)
2. `immutable` → true
3. `max_age` present → `now - stored_at < max_age`
4. `max_age` absent, `last_modified` present → heuristic: `(now - stored_at) < (stored_at - last_modified_epoch) * 0.1`
5. None of the above → false (stale)

---

## CacheBackend Trait

```
trait CacheBackend {
  lookup(self, url: String) -> CacheEntry?
  store(self, entry: CacheEntry) -> Unit
  remove(self, url: String) -> Unit
  clear(self) -> Unit
}
```

### MemoryCacheBackend

For BiDi server. Volatile, cleared on restart.

```
MemoryCacheBackend {
  entries: Map[String, CacheEntry]
  max_entries: Int  // default 1000
}
```

When `max_entries` is reached, the oldest entry (by `stored_at`) is evicted.

### SqliteCacheBackend

For VRT/test. Uses `mizchi/sqlite`.

```
SqliteCacheBackend {
  db_path: String  // default ".crater-cache/http-cache.db"
}
```

Schema:

```sql
CREATE TABLE IF NOT EXISTS http_cache (
  url TEXT PRIMARY KEY,
  status INTEGER NOT NULL,
  headers TEXT NOT NULL,
  body BLOB,
  etag TEXT,
  last_modified TEXT,
  cache_control TEXT,
  stored_at REAL NOT NULL
);
```

`headers` stored as JSON-encoded `Map[String, String]`.

---

## cached_fetch

```
pub fn cached_fetch(
  url: String,
  options: FetchOptions,
  cache: &CacheBackend,
  fetcher: (String, FetchOptions) -> HttpResponse!HttpError
) -> HttpResponse!HttpError
```

### Flow

1. If `options.http_method != "GET"` → call `fetcher` directly, return
2. `cache.lookup(url)` → match:
   - `Some(entry)` where `is_fresh(entry, now())`:
     - Return `HttpResponse` from entry
   - `Some(entry)` (stale):
     - Clone `options.headers`
     - If `entry.etag` is `Some(etag)` → set `If-None-Match: <etag>`
     - If `entry.last_modified` is `Some(lm)` → set `If-Modified-Since: <lm>`
     - Call `fetcher(url, modified_options)`
     - If response status == 304:
       - Update `entry.stored_at` to now, `cache.store(entry)`
       - Return `HttpResponse` from original entry
     - Else:
       - Parse and store new entry, return response
   - `None`:
     - Call `fetcher(url, options)`
     - Parse `Cache-Control` from response headers
     - If `no_store` → return without caching
     - Else → `cache.store(new_entry)`, return response

### Resource Type Caching Policy

| ResourceType | Cached | Reason |
|-------------|--------|--------|
| Stylesheet  | Yes    | Rarely changes |
| Script      | Yes    | Rarely changes |
| Image       | Yes    | Large, expensive to refetch |
| Font        | Yes    | Large, nearly immutable |
| Document    | No     | Always fetch fresh |
| Other       | Yes    | Default to caching |

Callers decide whether to use `cached_fetch` or direct `fetch` based on resource type. `Document` should always use `fetch` directly.

---

## File Layout

```
browser/src/http/
  http.mbt                  -- existing: core types, CORS, sandbox
  http_js.mbt               -- existing: JS target fetch
  http_native.mbt           -- existing: native target fetch
  cache.mbt                 -- NEW: CacheDirectives, CacheEntry, parse_cache_control, is_fresh
  cache_backend.mbt         -- NEW: CacheBackend trait, MemoryCacheBackend
  cache_fetch.mbt           -- NEW: cached_fetch (backend-agnostic, fetcher-injectable)
  cache_sqlite_js.mbt       -- NEW: SqliteCacheBackend (JS target, mizchi/sqlite)
  cache_sqlite_native.mbt   -- NEW: SqliteCacheBackend (native target)
  cache_wbtest.mbt          -- NEW: tests
```

`moon.pkg` additions:
- Add `mizchi/sqlite` dependency (for SQLite backend)

---

## Testing

### Unit Tests (cache_wbtest.mbt)

**parse_cache_control:**
- `"max-age=300"` → `{ max_age: Some(300), ... }`
- `"no-store"` → `{ no_store: true, ... }`
- `"no-cache, must-revalidate"` → both flags set
- `"public, max-age=3600, immutable"` → all three
- Empty string → all defaults (None/false)

**is_fresh:**
- `max_age=300`, stored 100s ago → true
- `max_age=300`, stored 400s ago → false
- `immutable` → always true
- `no_store` → false
- Heuristic with `last_modified` only

**MemoryCacheBackend:**
- store → lookup returns entry
- lookup miss → None
- remove → lookup returns None
- clear → all entries gone
- max_entries eviction: store 3 with max=2, oldest evicted

**cached_fetch with mock fetcher:**
- Cache miss → fetcher called, entry stored
- Cache hit (fresh) → fetcher NOT called
- Cache stale with etag → fetcher called with `If-None-Match`, 304 → cached returned
- Cache stale → fetcher returns 200 → new entry stored
- `no_store` response → not cached
- Non-GET request → fetcher called directly, not cached

---

## Dependencies

- `mizchi/sqlite` — SQLite bindings for MoonBit (existing published module)
- No new external dependencies for memory backend
