///|
let default_image_cache_max_bytes : Int = 8 * 1024 * 1024

///|
pub struct ImageCache {
  data : Map[String, String]
  order : Array[String]
  mut total_bytes : Int
  mut max_bytes : Int
}

///|
pub fn ImageCache::new(
  max_bytes? : Int = default_image_cache_max_bytes,
) -> ImageCache {
  { data: {}, order: [], total_bytes: 0, max_bytes: max_bytes.max(0) }
}

///|
fn remove_order_key(order : Array[String], src : String) -> Unit {
  let mut found_idx : Int? = None
  for i, key in order {
    if key == src {
      found_idx = Some(i)
      break
    }
  }
  match found_idx {
    Some(idx) => {
      let _ = order.remove(idx)
    }
    None => ()
  }
}

///|
fn ImageCache::evict_if_needed(self : ImageCache) -> Unit {
  while self.total_bytes > self.max_bytes && !self.order.is_empty() {
    let evicted_src = self.order.remove(0)
    match self.data.get(evicted_src) {
      Some(cached_data) => {
        self.data.remove(evicted_src)
        self.total_bytes = (self.total_bytes - cached_data.length()).max(0)
      }
      None => ()
    }
  }
}

///|
pub fn ImageCache::set_max_bytes(self : ImageCache, max_bytes : Int) -> Unit {
  self.max_bytes = max_bytes.max(0)
  self.evict_if_needed()
}

///|
pub fn ImageCache::put(self : ImageCache, src : String, data : String) -> Unit {
  if self.data.contains(src) {
    match self.data.get(src) {
      Some(existing) =>
        self.total_bytes = (self.total_bytes - existing.length()).max(0)
      None => ()
    }
    self.data.remove(src)
    remove_order_key(self.order, src)
  }
  self.data.set(src, data)
  self.order.push(src)
  self.total_bytes += data.length()
  self.evict_if_needed()
}

///|
pub fn ImageCache::get(self : ImageCache, src : String) -> String? {
  self.data.get(src)
}

///|
pub fn ImageCache::contains(self : ImageCache, src : String) -> Bool {
  self.data.contains(src)
}

///|
pub fn ImageCache::is_empty(self : ImageCache) -> Bool {
  self.data.is_empty()
}

///|
pub fn ImageCache::total_bytes(self : ImageCache) -> Int {
  self.total_bytes
}

///|
pub fn ImageCache::max_bytes(self : ImageCache) -> Int {
  self.max_bytes
}
