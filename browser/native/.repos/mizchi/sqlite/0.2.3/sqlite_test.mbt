// Cross-target SQLite tests
// These tests should produce identical output on both native and js targets

///|
fn bytes_to_str(b : Bytes) -> String {
  let sb = StringBuilder::new()
  @encoding.decode_to(b[:], sb, encoding=UTF8) catch {
    _ => ()
  }
  sb.to_string()
}

///|
fn str_to_bytes(s : String) -> Bytes {
  @encoding.encode(UTF8, s)
}

///|
test "basic: open and close" {
  let db = Database::open(":memory:")
  inspect(db is None, content="false")
  match db {
    Some(db) => db.close()
    None => ()
  }
}

///|
test "basic: create table and insert" {
  let db = Database::open(":memory:").unwrap()
  let ok = db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
  inspect(ok, content="true")
  let ok2 = db.exec("INSERT INTO test (name) VALUES ('Alice')")
  inspect(ok2, content="true")
  db.close()
}

///|
test "basic: select single row" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)") |> ignore
  db.exec("INSERT INTO test (name) VALUES ('Alice')") |> ignore
  let stmt = db.prepare("SELECT id, name FROM test").unwrap()
  inspect(stmt.step(), content="true")
  inspect(stmt.column_int(0), content="1")
  let name = bytes_to_str(stmt.column_text(1))
  inspect(name, content="Alice")
  stmt.finalize()
  db.close()
}

///|
test "basic: select multiple rows" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)") |> ignore
  db.exec("INSERT INTO test (name) VALUES ('Alice')") |> ignore
  db.exec("INSERT INTO test (name) VALUES ('Bob')") |> ignore
  db.exec("INSERT INTO test (name) VALUES ('Charlie')") |> ignore
  let stmt = db.prepare("SELECT name FROM test ORDER BY id").unwrap()
  let names : Array[String] = []
  while stmt.step() {
    names.push(bytes_to_str(stmt.column_text(0)))
  }
  inspect(names, content="[\"Alice\", \"Bob\", \"Charlie\"]")
  stmt.finalize()
  db.close()
}

///|
test "basic: bind parameters" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, value INTEGER)") |> ignore
  let stmt = db.prepare("INSERT INTO test (value) VALUES (?)").unwrap()
  stmt.bind(1, SqlValue::Int(42)) |> ignore
  stmt.execute() |> ignore
  stmt.finalize()
  let query = db.prepare("SELECT value FROM test").unwrap()
  query.step() |> ignore
  inspect(query.column_int(0), content="42")
  query.finalize()
  db.close()
}

///|
test "basic: column count" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE test (a INTEGER, b TEXT, c REAL)") |> ignore
  let stmt = db.prepare("SELECT a, b, c FROM test").unwrap()
  inspect(stmt.column_count(), content="3")
  stmt.finalize()
  db.close()
}

///|
test "basic: transaction" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)") |> ignore
  db.begin() |> ignore
  db.exec("INSERT INTO test (name) VALUES ('Alice')") |> ignore
  db.exec("INSERT INTO test (name) VALUES ('Bob')") |> ignore
  db.commit() |> ignore
  let stmt = db.prepare("SELECT COUNT(*) FROM test").unwrap()
  stmt.step() |> ignore
  inspect(stmt.column_int(0), content="2")
  stmt.finalize()
  db.close()
}

///|
test "basic: rollback" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)") |> ignore
  db.exec("INSERT INTO test (name) VALUES ('Initial')") |> ignore
  db.begin() |> ignore
  db.exec("INSERT INTO test (name) VALUES ('ToBeCancelled')") |> ignore
  db.rollback() |> ignore
  let stmt = db.prepare("SELECT COUNT(*) FROM test").unwrap()
  stmt.step() |> ignore
  inspect(stmt.column_int(0), content="1")
  stmt.finalize()
  db.close()
}

///|
test "basic: iter" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, value INTEGER)") |> ignore
  db.exec("INSERT INTO test (value) VALUES (10)") |> ignore
  db.exec("INSERT INTO test (value) VALUES (20)") |> ignore
  db.exec("INSERT INTO test (value) VALUES (30)") |> ignore
  let stmt = db.prepare("SELECT value FROM test ORDER BY id").unwrap()
  let values = stmt.iter().map(fn(s) { s.column_int(0) }).collect()
  inspect(values, content="[10, 20, 30]")
  stmt.finalize()
  db.close()
}

// High-level API tests (from sqlite_wbtest.mbt)

///|
test "database: integration" {
  let db = Database::open(":memory:").unwrap()
  let ok = db.exec(
    "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)",
  )
  inspect(ok, content="true")
  inspect(
    db.exec("INSERT INTO users (name, age) VALUES ('Alice', 30)"),
    content="true",
  )
  inspect(
    db.exec("INSERT INTO users (name, age) VALUES ('Bob', 25)"),
    content="true",
  )
  let stmt = db.prepare("SELECT id, name, age FROM users").unwrap()
  // First row: Alice
  inspect(stmt.step(), content="true")
  inspect(stmt.column_int(0), content="1")
  inspect(stmt.column_int(2), content="30")
  // Second row: Bob
  inspect(stmt.step(), content="true")
  inspect(stmt.column_int(0), content="2")
  inspect(stmt.column_int(2), content="25")
  stmt.finalize()
  db.close()
}

///|
test "database: changes and rowid" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE t (id INTEGER PRIMARY KEY, value INTEGER)") |> ignore
  db.exec("INSERT INTO t (value) VALUES (100)") |> ignore
  inspect(db.changes(), content="1")
  inspect(db.last_insert_rowid(), content="1")
  db.exec("INSERT INTO t (value) VALUES (200)") |> ignore
  inspect(db.changes(), content="1")
  inspect(db.last_insert_rowid(), content="2")
  db.close()
}

///|
test "database: total changes" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE t (id INTEGER)") |> ignore
  inspect(db.total_changes(), content="0")
  db.exec("INSERT INTO t VALUES (1)") |> ignore
  db.exec("INSERT INTO t VALUES (2)") |> ignore
  inspect(db.total_changes(), content="2")
  db.close()
}

///|
test "transaction: basic" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE t (id INTEGER, value INTEGER)") |> ignore
  inspect(db.begin(), content="true")
  // Note: get_autocommit is not supported in JS target (always returns true)
  db.exec("INSERT INTO t VALUES (1, 100)") |> ignore
  db.exec("INSERT INTO t VALUES (2, 200)") |> ignore
  inspect(db.commit(), content="true")
  let stmt = db.prepare("SELECT COUNT(*) FROM t").unwrap()
  stmt.step() |> ignore
  inspect(stmt.column_int(0), content="2")
  stmt.finalize()
  db.close()
}

///|
test "transaction: rollback" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE t (id INTEGER, value INTEGER)") |> ignore
  db.exec("INSERT INTO t VALUES (1, 100)") |> ignore
  db.begin() |> ignore
  db.exec("INSERT INTO t VALUES (2, 200)") |> ignore
  db.rollback() |> ignore
  let stmt = db.prepare("SELECT COUNT(*) FROM t").unwrap()
  stmt.step() |> ignore
  inspect(stmt.column_int(0), content="1")
  stmt.finalize()
  db.close()
}

///|
test "transaction: savepoint" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE t (id INTEGER, value INTEGER)") |> ignore
  db.begin() |> ignore
  db.exec("INSERT INTO t VALUES (1, 100)") |> ignore
  db.savepoint("sp1") |> ignore
  db.exec("INSERT INTO t VALUES (2, 200)") |> ignore
  db.rollback_to("sp1") |> ignore
  db.release("sp1") |> ignore
  db.commit() |> ignore
  let stmt = db.prepare("SELECT COUNT(*) FROM t").unwrap()
  stmt.step() |> ignore
  inspect(stmt.column_int(0), content="1")
  stmt.finalize()
  db.close()
}

///|
test "transaction: immediate and exclusive" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE t (id INTEGER)") |> ignore
  inspect(db.begin_immediate(), content="true")
  db.exec("INSERT INTO t VALUES (1)") |> ignore
  db.commit() |> ignore
  inspect(db.begin_exclusive(), content="true")
  db.exec("INSERT INTO t VALUES (2)") |> ignore
  db.commit() |> ignore
  // Verify both rows were inserted
  let stmt = db.prepare("SELECT COUNT(*) FROM t").unwrap()
  stmt.step() |> ignore
  inspect(stmt.column_int(0), content="2")
  stmt.finalize()
  db.close()
}

///|
test "statement: iterator each" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE users (id INTEGER, name TEXT, age INTEGER)") |> ignore
  db.exec("INSERT INTO users VALUES (1, 'Alice', 30)") |> ignore
  db.exec("INSERT INTO users VALUES (2, 'Bob', 25)") |> ignore
  db.exec("INSERT INTO users VALUES (3, 'Charlie', 35)") |> ignore
  let stmt = db.query("SELECT * FROM users").unwrap()
  let mut count = 0
  for row in stmt.iter() {
    count = count + 1
    let id = row.column_int(0)
    inspect(id >= 1 && id <= 3, content="true")
  }
  inspect(count, content="3")
  stmt.finalize()
  db.close()
}

///|
test "statement: iterator map" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE users (id INTEGER, name TEXT, age INTEGER)") |> ignore
  db.exec("INSERT INTO users VALUES (1, 'Alice', 30)") |> ignore
  db.exec("INSERT INTO users VALUES (2, 'Bob', 25)") |> ignore
  let stmt = db.query("SELECT id, age FROM users").unwrap()
  let ages = stmt.iter().map(fn(row) { row.column_int(1) }).collect()
  inspect(ages.length(), content="2")
  inspect(ages[0], content="30")
  inspect(ages[1], content="25")
  stmt.finalize()
  db.close()
}

///|
test "statement: reset and reuse" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE t (id INTEGER)") |> ignore
  db.exec("INSERT INTO t VALUES (1)") |> ignore
  db.exec("INSERT INTO t VALUES (2)") |> ignore
  let stmt = db.query("SELECT * FROM t").unwrap()
  // First iteration
  let first = stmt.iter().map(fn(row) { row.column_int(0) }).collect()
  inspect(first.length(), content="2")
  // Reset and iterate again
  let second = stmt.iter().map(fn(row) { row.column_int(0) }).collect()
  inspect(second.length(), content="2")
  inspect(first[0] == second[0], content="true")
  stmt.finalize()
  db.close()
}

///|
test "statement: bind and column" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE t (id INTEGER, name TEXT, value REAL)") |> ignore
  let stmt = db.prepare("INSERT INTO t VALUES (?, ?, ?)").unwrap()
  stmt.bind(1, Int(42)) |> ignore
  stmt.bind(2, Text(str_to_bytes("Alice"))) |> ignore
  stmt.bind(3, Double(3.14)) |> ignore
  stmt.execute() |> ignore
  stmt.finalize()
  let select_stmt = db.query("SELECT * FROM t WHERE id = 42").unwrap()
  inspect(select_stmt.step(), content="true")
  // Integer column: JS returns Int, native returns Int64
  match select_stmt.column(0) {
    Int64(v) => inspect(v, content="42")
    Int(v) => inspect(v, content="42")
    _ => inspect(false, content="true") // fail
  }
  match select_stmt.column(1) {
    Text(_) => ()
    _ => inspect(false, content="true") // fail
  }
  match select_stmt.column(2) {
    Double(v) => inspect(v > 3.13 && v < 3.15, content="true")
    _ => inspect(false, content="true") // fail
  }
  select_stmt.finalize()
  db.close()
}

///|
test "statement: bind all types" {
  let db = Database::open(":memory:").unwrap()
  db.exec(
    "CREATE TABLE t (id INTEGER, int_val INTEGER, double_val REAL, text_val TEXT, blob_val BLOB, null_val INTEGER)",
  )
  |> ignore
  let stmt = db.prepare("INSERT INTO t VALUES (?, ?, ?, ?, ?, ?)").unwrap()
  stmt.bind(1, Int(1)) |> ignore
  stmt.bind(2, Int(100)) |> ignore
  stmt.bind(3, Double(2.71828)) |> ignore
  stmt.bind(4, Text(str_to_bytes("Hello"))) |> ignore
  stmt.bind(5, Blob(str_to_bytes("binary"))) |> ignore
  stmt.bind(6, Null) |> ignore
  stmt.execute() |> ignore
  stmt.finalize()
  let select_stmt = db.query("SELECT * FROM t WHERE id = 1").unwrap()
  inspect(select_stmt.step(), content="true")
  // Integer columns: JS returns Int, native returns Int64
  match select_stmt.column(1) {
    Int64(v) => inspect(v, content="100")
    Int(v) => inspect(v, content="100")
    _ => inspect(false, content="true")
  }
  match select_stmt.column(2) {
    Double(_) => ()
    _ => inspect(false, content="true")
  }
  match select_stmt.column(3) {
    Text(_) => ()
    _ => inspect(false, content="true")
  }
  match select_stmt.column(4) {
    Blob(_) => ()
    _ => inspect(false, content="true")
  }
  match select_stmt.column(5) {
    Null => ()
    _ => inspect(false, content="true")
  }
  select_stmt.finalize()
  db.close()
}

///|
test "statement: bind all" {
  let db = Database::open(":memory:").unwrap()
  db.exec("CREATE TABLE t (id INTEGER, name TEXT, value REAL)") |> ignore
  let stmt = db.prepare("INSERT INTO t VALUES (?, ?, ?)").unwrap()
  stmt.bind_all([Int(1), Text(str_to_bytes("Alice")), Double(3.14)]) |> ignore
  stmt.execute() |> ignore
  stmt.finalize()
  let select_stmt = db.query("SELECT * FROM t WHERE id = 1").unwrap()
  inspect(select_stmt.step(), content="true")
  inspect(select_stmt.column_int(0), content="1")
  select_stmt.finalize()
  db.close()
}
