///|
test "image cache evicts oldest entries by byte budget" {
  let cache = ImageCache::new(max_bytes=5)
  cache.put("a", "123")
  cache.put("b", "456")
  inspect(cache.get("a"), content="None")
  inspect(cache.get("b"), content="Some(\"456\")")
  inspect(cache.total_bytes(), content="3")
}

///|
test "image cache replaces entries without double-counting bytes" {
  let cache = ImageCache::new(max_bytes=10)
  cache.put("a", "1234")
  cache.put("a", "12")
  inspect(cache.get("a"), content="Some(\"12\")")
  inspect(cache.total_bytes(), content="2")
}
