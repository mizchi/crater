// MoonBit SQLite Benchmark
// Run with: moon bench --target native

///|
fn setup_database() -> Database {
  let db = Database::open(":memory:").unwrap()
  db.exec(
    "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER NOT NULL)",
  )
  |> ignore
  db
}

///|
/// Database Open/Close
test "bench: Database Open/Close" (b : @bench.T) {
  b.bench(fn() {
    let db = Database::open(":memory:").unwrap()
    db.close()
  })
}

///|
/// Create Table
test "bench: Create Table" (b : @bench.T) {
  b.bench(fn() {
    let db = Database::open(":memory:").unwrap()
    db.exec(
      "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER NOT NULL)",
    )
    |> ignore
    db.close()
  })
}

///|
/// Insert Single Row
test "bench: Insert Single Row" (b : @bench.T) {
  b.bench(fn() {
    let db = setup_database()
    let stmt = db
      .prepare("INSERT INTO users (name, age) VALUES (?, ?)")
      .unwrap()
    stmt.bind(1, Text(cstring("Alice"))) |> ignore
    stmt.bind(2, Int(30)) |> ignore
    stmt.execute() |> ignore
    stmt.finalize()
    db.close()
  })
}

///|
/// Insert 100 Rows
test "bench: Insert 100 Rows" (b : @bench.T) {
  b.bench(fn() {
    let db = setup_database()
    let stmt = db
      .prepare("INSERT INTO users (name, age) VALUES (?, ?)")
      .unwrap()
    for i = 0; i < 100; i = i + 1 {
      stmt.bind(1, Text(cstring("User\{i}"))) |> ignore
      stmt.bind(2, Int(20 + i % 50)) |> ignore
      stmt.execute() |> ignore
      stmt.reset()
    }
    stmt.finalize()
    db.close()
  })
}

///|
/// Insert with Transaction (100 rows)
test "bench: Insert with Transaction (100 rows)" (b : @bench.T) {
  b.bench(fn() {
    let db = setup_database()
    db.begin() |> ignore
    let stmt = db
      .prepare("INSERT INTO users (name, age) VALUES (?, ?)")
      .unwrap()
    for i = 0; i < 100; i = i + 1 {
      stmt.bind(1, Text(cstring("User\{i}"))) |> ignore
      stmt.bind(2, Int(20 + i % 50)) |> ignore
      stmt.execute() |> ignore
      stmt.reset()
    }
    stmt.finalize()
    db.commit() |> ignore
    db.close()
  })
}

///|
/// Select All Rows
test "bench: Select All Rows" (b : @bench.T) {
  b.bench(fn() {
    let db = setup_database()
    // Insert test data
    let insert_stmt = db
      .prepare("INSERT INTO users (name, age) VALUES (?, ?)")
      .unwrap()
    for i = 0; i < 100; i = i + 1 {
      insert_stmt.bind(1, Text(cstring("User\{i}"))) |> ignore
      insert_stmt.bind(2, Int(20 + i % 50)) |> ignore
      insert_stmt.execute() |> ignore
      insert_stmt.reset()
    }
    insert_stmt.finalize()
    // Select all
    let select_stmt = db.prepare("SELECT * FROM users").unwrap()
    while select_stmt.step() {
      select_stmt.column_int(0) |> ignore
      select_stmt.column_text(1) |> ignore
      select_stmt.column_int(2) |> ignore
    }
    select_stmt.finalize()
    db.close()
  })
}

///|
/// Select with WHERE clause
test "bench: Select with WHERE clause" (b : @bench.T) {
  b.bench(fn() {
    let db = setup_database()
    // Insert test data
    let insert_stmt = db
      .prepare("INSERT INTO users (name, age) VALUES (?, ?)")
      .unwrap()
    for i = 0; i < 100; i = i + 1 {
      insert_stmt.bind(1, Text(cstring("User\{i}"))) |> ignore
      insert_stmt.bind(2, Int(20 + i % 50)) |> ignore
      insert_stmt.execute() |> ignore
      insert_stmt.reset()
    }
    insert_stmt.finalize()
    // Select with WHERE
    let select_stmt = db.prepare("SELECT * FROM users WHERE age > ?").unwrap()
    select_stmt.bind(1, Int(30)) |> ignore
    while select_stmt.step() {
      select_stmt.column_int(0) |> ignore
      select_stmt.column_text(1) |> ignore
      select_stmt.column_int(2) |> ignore
    }
    select_stmt.finalize()
    db.close()
  })
}

///|
/// Update Rows
test "bench: Update Rows" (b : @bench.T) {
  b.bench(fn() {
    let db = setup_database()
    // Insert test data
    let insert_stmt = db
      .prepare("INSERT INTO users (name, age) VALUES (?, ?)")
      .unwrap()
    for i = 0; i < 100; i = i + 1 {
      insert_stmt.bind(1, Text(cstring("User\{i}"))) |> ignore
      insert_stmt.bind(2, Int(20 + i % 50)) |> ignore
      insert_stmt.execute() |> ignore
      insert_stmt.reset()
    }
    insert_stmt.finalize()
    // Update
    let update_stmt = db
      .prepare("UPDATE users SET age = ? WHERE age > ?")
      .unwrap()
    update_stmt.bind(1, Int(25)) |> ignore
    update_stmt.bind(2, Int(30)) |> ignore
    update_stmt.execute() |> ignore
    update_stmt.finalize()
    db.close()
  })
}

///|
/// Delete Rows
test "bench: Delete Rows" (b : @bench.T) {
  b.bench(fn() {
    let db = setup_database()
    // Insert test data
    let insert_stmt = db
      .prepare("INSERT INTO users (name, age) VALUES (?, ?)")
      .unwrap()
    for i = 0; i < 100; i = i + 1 {
      insert_stmt.bind(1, Text(cstring("User\{i}"))) |> ignore
      insert_stmt.bind(2, Int(20 + i % 50)) |> ignore
      insert_stmt.execute() |> ignore
      insert_stmt.reset()
    }
    insert_stmt.finalize()
    // Delete
    let delete_stmt = db.prepare("DELETE FROM users WHERE age > ?").unwrap()
    delete_stmt.bind(1, Int(40)) |> ignore
    delete_stmt.execute() |> ignore
    delete_stmt.finalize()
    db.close()
  })
}

///|
/// Prepared Statement Reuse
test "bench: Prepared Statement Reuse" (b : @bench.T) {
  b.bench(fn() {
    let db = setup_database()
    let stmt = db
      .prepare("INSERT INTO users (name, age) VALUES (?, ?)")
      .unwrap()
    for i = 0; i < 50; i = i + 1 {
      stmt.bind(1, Text(cstring("User\{i}"))) |> ignore
      stmt.bind(2, Int(20 + i)) |> ignore
      stmt.execute() |> ignore
      stmt.reset()
    }
    stmt.finalize()
    db.close()
  })
}
