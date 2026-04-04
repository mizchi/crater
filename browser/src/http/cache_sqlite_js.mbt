///|
/// SQLite-backed HTTP cache for VRT/test persistence.
pub struct SqliteCacheBackend {
  db : @sqlite.Database
}

///|
pub fn SqliteCacheBackend::new(db_path : String) -> SqliteCacheBackend {
  let db = match @sqlite.Database::open(db_path) {
    Some(db) => db
    None => panic()
  }
  db.exec(
    "CREATE TABLE IF NOT EXISTS http_cache (url TEXT PRIMARY KEY, status INTEGER NOT NULL, headers TEXT NOT NULL, body TEXT, etag TEXT, last_modified TEXT, cache_control TEXT, stored_at REAL NOT NULL)",
  )
  |> ignore
  { db, }
}

///|
pub fn SqliteCacheBackend::lookup(
  self : SqliteCacheBackend,
  url : String,
) -> CacheEntry? {
  let stmt = match
    self.db.prepare(
      "SELECT url, status, headers, body, etag, last_modified, cache_control, stored_at FROM http_cache WHERE url = ?",
    ) {
    Some(s) => s
    None => return None
  }
  stmt.bind(1, @sqlite.Text(@sqlite.string_to_bytes(url))) |> ignore
  if stmt.step() {
    let entry_url = @sqlite.bytes_to_string(stmt.column_text(0))
    let status = stmt.column_int(1)
    let headers_json = @sqlite.bytes_to_string(stmt.column_text(2))
    let body = @sqlite.bytes_to_string(stmt.column_text(3))
    let etag = sqlite_optional_text(stmt, 4)
    let last_modified = sqlite_optional_text(stmt, 5)
    let cache_control = @sqlite.bytes_to_string(stmt.column_text(6))
    let stored_at = match stmt.column(7) {
      @sqlite.Double(v) => v
      @sqlite.Int(v) => v.to_double()
      _ => 0.0
    }
    stmt.finalize()
    let headers = sqlite_parse_headers(headers_json)
    let directives = parse_cache_control(cache_control)
    Some({
      url: entry_url,
      status,
      headers,
      body,
      etag,
      last_modified,
      directives,
      stored_at,
    })
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
  let stmt = match
    self.db.prepare(
      "INSERT OR REPLACE INTO http_cache (url, status, headers, body, etag, last_modified, cache_control, stored_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    ) {
    Some(s) => s
    None => return
  }
  let cc = match get_header(entry.headers, "cache-control") {
    Some(h) => h
    None => ""
  }
  stmt.bind(1, @sqlite.Text(@sqlite.string_to_bytes(entry.url))) |> ignore
  stmt.bind(2, @sqlite.Int(entry.status)) |> ignore
  stmt.bind(
    3,
    @sqlite.Text(@sqlite.string_to_bytes(headers_to_json(entry.headers))),
  )
  |> ignore
  stmt.bind(4, @sqlite.Text(@sqlite.string_to_bytes(entry.body))) |> ignore
  stmt.bind(
    5,
    match entry.etag {
      Some(e) => @sqlite.Text(@sqlite.string_to_bytes(e))
      None => @sqlite.Null
    },
  )
  |> ignore
  stmt.bind(
    6,
    match entry.last_modified {
      Some(lm) => @sqlite.Text(@sqlite.string_to_bytes(lm))
      None => @sqlite.Null
    },
  )
  |> ignore
  stmt.bind(7, @sqlite.Text(@sqlite.string_to_bytes(cc))) |> ignore
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
  stmt.bind(1, @sqlite.Text(@sqlite.string_to_bytes(url))) |> ignore
  stmt.execute() |> ignore
  stmt.finalize()
}

///|
pub fn SqliteCacheBackend::clear(self : SqliteCacheBackend) -> Unit {
  self.db.exec("DELETE FROM http_cache") |> ignore
}

///|
fn sqlite_optional_text(stmt : @sqlite.Statement, col : Int) -> String? {
  match stmt.column(col) {
    @sqlite.Text(bytes) => {
      let s = @sqlite.bytes_to_string(bytes)
      if s.is_empty() {
        None
      } else {
        Some(s)
      }
    }
    @sqlite.Null => None
    _ => None
  }
}

///|
fn sqlite_parse_headers(json_str : String) -> Map[String, String] {
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
