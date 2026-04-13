///|
/// In-memory cache backend with LRU-style eviction by oldest stored_at.
pub(all) struct MemoryCacheBackend {
  entries : Map[String, CacheEntry]
  max_entries : Int
}

///|
pub fn MemoryCacheBackend::new(max_entries? : Int = 1000) -> MemoryCacheBackend {
  { entries: {}, max_entries }
}

///|
/// Look up a cache entry by URL. Returns None if not found.
pub fn MemoryCacheBackend::lookup(
  self : MemoryCacheBackend,
  url : String,
) -> CacheEntry? {
  self.entries.get(url)
}

///|
/// Store a cache entry. If at capacity and key is new, evict the oldest entry by stored_at.
pub fn MemoryCacheBackend::store(
  self : MemoryCacheBackend,
  entry : CacheEntry,
) -> Unit {
  if !self.entries.contains(entry.url) &&
    self.entries.length() >= self.max_entries {
    // Find the entry with the smallest stored_at
    let mut oldest_url : String = ""
    let mut oldest_time : Double = @double.infinity
    for url, e in self.entries {
      if e.stored_at < oldest_time {
        oldest_time = e.stored_at
        oldest_url = url
      }
    }
    if oldest_url != "" {
      self.entries.remove(oldest_url)
    }
  }
  self.entries[entry.url] = entry
}

///|
/// Remove a cache entry by URL.
pub fn MemoryCacheBackend::remove(
  self : MemoryCacheBackend,
  url : String,
) -> Unit {
  self.entries.remove(url)
}

///|
/// Clear all cache entries.
pub fn MemoryCacheBackend::clear(self : MemoryCacheBackend) -> Unit {
  self.entries.clear()
}
