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
