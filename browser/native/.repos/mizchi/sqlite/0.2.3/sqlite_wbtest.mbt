// Low-level C FFI tests (native only)
// High-level API tests are in sqlite_test.mbt (cross-target)

///|
test "sqlite_open_close" {
  let db = sqlite_open(cstring(":memory:"))
  assert_false(sqlite_is_null(db) == 1)
  sqlite_close(db)
}

///|
test "sqlite_exec" {
  let db = sqlite_open(cstring(":memory:"))
  let rc = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER)"))
  assert_eq(rc, SQLITE_OK)
  sqlite_close(db)
}

///|
test "sqlite_bind_int" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER, value INTEGER)"))
  let stmt = sqlite_prepare(
    db,
    cstring("INSERT INTO t (id, value) VALUES (?, ?)"),
  )
  assert_false(sqlite_stmt_is_null(stmt) == 1)
  let _ = sqlite_bind_int(stmt, 1, 100)
  let _ = sqlite_bind_int(stmt, 2, 42)
  let _ = sqlite_step(stmt)
  sqlite_finalize(stmt)
  let stmt2 = sqlite_prepare(db, cstring("SELECT value FROM t WHERE id = 100"))
  assert_eq(sqlite_step(stmt2), SQLITE_ROW)
  assert_eq(sqlite_column_int(stmt2, 0), 42)
  sqlite_finalize(stmt2)
  sqlite_close(db)
}

///|
test "sqlite_bind_text" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER, name TEXT)"))
  let stmt = sqlite_prepare(
    db,
    cstring("INSERT INTO t (id, name) VALUES (?, ?)"),
  )
  let _ = sqlite_bind_int(stmt, 1, 1)
  let _ = sqlite_bind_text(stmt, 2, cstring("hello"))
  let _ = sqlite_step(stmt)
  sqlite_finalize(stmt)
  let stmt2 = sqlite_prepare(db, cstring("SELECT name FROM t WHERE id = 1"))
  assert_eq(sqlite_step(stmt2), SQLITE_ROW)
  let got_column_text = sqlite_column_text(stmt2, 0)
  assert_eq(@encoding.decoder(UTF8).decode_lossy(got_column_text[:]), "hello")
  sqlite_finalize(stmt2)
  sqlite_close(db)
}

///|
test "sqlite_reset" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER)"))
  let stmt = sqlite_prepare(db, cstring("INSERT INTO t (id) VALUES (?)"))
  let _ = sqlite_bind_int(stmt, 1, 1)
  let _ = sqlite_step(stmt)
  sqlite_reset(stmt)
  let _ = sqlite_bind_int(stmt, 1, 2)
  let _ = sqlite_step(stmt)
  sqlite_finalize(stmt)
  let stmt2 = sqlite_prepare(db, cstring("SELECT COUNT(*) FROM t"))
  let _ = sqlite_step(stmt2)
  assert_eq(sqlite_column_int(stmt2, 0), 2)
  sqlite_finalize(stmt2)
  sqlite_close(db)
}

///|
test "sqlite_bind_double" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER, value REAL)"))
  let stmt = sqlite_prepare(
    db,
    cstring("INSERT INTO t (id, value) VALUES (?, ?)"),
  )
  let _ = sqlite_bind_int(stmt, 1, 1)
  let _ = sqlite_bind_double(stmt, 2, 3.14)
  let _ = sqlite_step(stmt)
  sqlite_finalize(stmt)
  let stmt2 = sqlite_prepare(db, cstring("SELECT value FROM t WHERE id = 1"))
  assert_eq(sqlite_step(stmt2), SQLITE_ROW)
  let val = sqlite_column_double(stmt2, 0)
  assert_true(val > 3.13 && val < 3.15)
  sqlite_finalize(stmt2)
  sqlite_close(db)
}

///|
test "sqlite_bind_null" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER, value TEXT)"))
  let stmt = sqlite_prepare(
    db,
    cstring("INSERT INTO t (id, value) VALUES (?, ?)"),
  )
  let _ = sqlite_bind_int(stmt, 1, 1)
  let _ = sqlite_bind_null(stmt, 2)
  let _ = sqlite_step(stmt)
  sqlite_finalize(stmt)
  let stmt2 = sqlite_prepare(db, cstring("SELECT value FROM t WHERE id = 1"))
  assert_eq(sqlite_step(stmt2), SQLITE_ROW)
  assert_eq(sqlite_column_type(stmt2, 0), SQLITE_NULL)
  sqlite_finalize(stmt2)
  sqlite_close(db)
}

///|
test "sqlite_int64" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER, value INTEGER)"))
  let stmt = sqlite_prepare(
    db,
    cstring("INSERT INTO t (id, value) VALUES (?, ?)"),
  )
  let _ = sqlite_bind_int(stmt, 1, 1)
  let large_val : Int64 = 9223372036854775807L
  let _ = sqlite_bind_int64(stmt, 2, large_val)
  let _ = sqlite_step(stmt)
  sqlite_finalize(stmt)
  let stmt2 = sqlite_prepare(db, cstring("SELECT value FROM t WHERE id = 1"))
  assert_eq(sqlite_step(stmt2), SQLITE_ROW)
  assert_eq(sqlite_column_int64(stmt2, 0), large_val)
  sqlite_finalize(stmt2)
  sqlite_close(db)
}

///|
test "sqlite_bind_blob" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER, data BLOB)"))
  let stmt = sqlite_prepare(
    db,
    cstring("INSERT INTO t (id, data) VALUES (?, ?)"),
  )
  let _ = sqlite_bind_int(stmt, 1, 1)
  let blob_data = cstring("binary\u{0000}data")
  let _ = sqlite_bind_blob(stmt, 2, blob_data)
  let _ = sqlite_step(stmt)
  sqlite_finalize(stmt)
  let stmt2 = sqlite_prepare(db, cstring("SELECT data FROM t WHERE id = 1"))
  assert_eq(sqlite_step(stmt2), SQLITE_ROW)
  let got_blob = sqlite_column_blob(stmt2, 0)
  assert_true(sqlite_column_bytes(stmt2, 0) > 0)
  assert_eq(got_blob, blob_data)
  sqlite_finalize(stmt2)
  sqlite_close(db)
}

///|
test "sqlite_column_type" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(
    db,
    cstring("CREATE TABLE t (i INTEGER, r REAL, t TEXT, b BLOB, n TEXT)"),
  )
  let _ = sqlite_exec(
    db,
    cstring("INSERT INTO t VALUES (42, 3.14, 'hello', X'DEAD', NULL)"),
  )
  let stmt = sqlite_prepare(db, cstring("SELECT * FROM t"))
  assert_eq(sqlite_step(stmt), SQLITE_ROW)
  assert_eq(sqlite_column_type(stmt, 0), SQLITE_INTEGER)
  assert_eq(sqlite_column_type(stmt, 1), SQLITE_FLOAT)
  assert_eq(sqlite_column_type(stmt, 2), SQLITE_TEXT)
  assert_eq(sqlite_column_type(stmt, 3), SQLITE_BLOB)
  assert_eq(sqlite_column_type(stmt, 4), SQLITE_NULL)
  sqlite_finalize(stmt)
  sqlite_close(db)
}

///|
test "sqlite_column_count_and_name" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(
    db,
    cstring("CREATE TABLE t (id INTEGER, name TEXT, age INTEGER)"),
  )
  let stmt = sqlite_prepare(db, cstring("SELECT id, name, age FROM t"))
  assert_eq(sqlite_column_count(stmt), 3)
  let _ = sqlite_column_name(stmt, 0)
  let _ = sqlite_column_name(stmt, 1)
  let _ = sqlite_column_name(stmt, 2)
  sqlite_finalize(stmt)
  sqlite_close(db)
}

///|
test "sqlite_changes_and_last_insert_rowid" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(
    db,
    cstring("CREATE TABLE t (id INTEGER PRIMARY KEY, value INTEGER)"),
  )
  let stmt = sqlite_prepare(db, cstring("INSERT INTO t (value) VALUES (?)"))
  let _ = sqlite_bind_int(stmt, 1, 100)
  let _ = sqlite_step(stmt)
  sqlite_finalize(stmt)
  assert_eq(sqlite_changes(db), 1)
  assert_eq(sqlite_last_insert_rowid(db), 1L)
  let stmt2 = sqlite_prepare(db, cstring("INSERT INTO t (value) VALUES (?)"))
  let _ = sqlite_bind_int(stmt2, 1, 200)
  let _ = sqlite_step(stmt2)
  sqlite_finalize(stmt2)
  assert_eq(sqlite_changes(db), 1)
  assert_eq(sqlite_last_insert_rowid(db), 2L)
  sqlite_close(db)
}

///|
test "sqlite_clear_bindings" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER, value INTEGER)"))
  let stmt = sqlite_prepare(
    db,
    cstring("INSERT INTO t (id, value) VALUES (?, ?)"),
  )
  let _ = sqlite_bind_int(stmt, 1, 1)
  let _ = sqlite_bind_int(stmt, 2, 100)
  let _ = sqlite_clear_bindings(stmt)
  sqlite_reset(stmt)
  let _ = sqlite_bind_int(stmt, 1, 2)
  let _ = sqlite_bind_int(stmt, 2, 200)
  let _ = sqlite_step(stmt)
  sqlite_finalize(stmt)
  let stmt2 = sqlite_prepare(db, cstring("SELECT value FROM t WHERE id = 2"))
  assert_eq(sqlite_step(stmt2), SQLITE_ROW)
  assert_eq(sqlite_column_int(stmt2, 0), 200)
  sqlite_finalize(stmt2)
  sqlite_close(db)
}

///|
test "sqlite_extended_errcode_and_errstr" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER)"))
  assert_eq(sqlite_errcode(db), SQLITE_OK)
  assert_eq(sqlite_extended_errcode(db), SQLITE_OK)
  let _ = sqlite_exec(db, cstring("INVALID SQL"))
  let errcode = sqlite_errcode(db)
  assert_true(errcode != SQLITE_OK)
  let ext_errcode = sqlite_extended_errcode(db)
  assert_true(ext_errcode != SQLITE_OK)
  let _ = sqlite_errstr(errcode)
  let _ = sqlite_errstr(ext_errcode)
  let _ = sqlite_errstr(SQLITE_OK)
  sqlite_close(db)
}

///|
test "sqlite_busy_timeout" {
  let db = sqlite_open(cstring(":memory:"))
  let rc = sqlite_busy_timeout(db, 1000)
  assert_eq(rc, SQLITE_OK)
  sqlite_close(db)
}

///|
test "sqlite_get_autocommit" {
  let db = sqlite_open(cstring(":memory:"))
  assert_true(sqlite_get_autocommit(db) != 0)
  let _ = sqlite_exec(db, cstring("BEGIN"))
  assert_eq(sqlite_get_autocommit(db), 0)
  let _ = sqlite_exec(db, cstring("COMMIT"))
  assert_true(sqlite_get_autocommit(db) != 0)
  sqlite_close(db)
}

///|
test "sqlite_total_changes" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER, value INTEGER)"))
  assert_eq(sqlite_total_changes(db), 0)
  let _ = sqlite_exec(db, cstring("INSERT INTO t VALUES (1, 100)"))
  let _ = sqlite_exec(db, cstring("INSERT INTO t VALUES (2, 200)"))
  let _ = sqlite_exec(db, cstring("INSERT INTO t VALUES (3, 300)"))
  assert_eq(sqlite_total_changes(db), 3)
  let _ = sqlite_exec(db, cstring("DELETE FROM t WHERE id = 2"))
  assert_eq(sqlite_total_changes(db), 4)
  sqlite_close(db)
}

///|
test "sqlite_sql" {
  let db = sqlite_open(cstring(":memory:"))
  let sql_text = "SELECT * FROM sqlite_master"
  let stmt = sqlite_prepare(db, cstring(sql_text))
  let _ = sqlite_sql(stmt)
  sqlite_finalize(stmt)
  sqlite_close(db)
}

///|
test "sqlite_bind_parameter_count" {
  let db = sqlite_open(cstring(":memory:"))
  let stmt1 = sqlite_prepare(db, cstring("SELECT 1"))
  assert_eq(sqlite_bind_parameter_count(stmt1), 0)
  sqlite_finalize(stmt1)
  let stmt2 = sqlite_prepare(db, cstring("SELECT ?, ?"))
  assert_eq(sqlite_bind_parameter_count(stmt2), 2)
  sqlite_finalize(stmt2)
  let stmt3 = sqlite_prepare(db, cstring("SELECT ?, ?, ?, ?, ?"))
  assert_eq(sqlite_bind_parameter_count(stmt3), 5)
  sqlite_finalize(stmt3)
  sqlite_close(db)
}

///|
test "sqlite_stmt_readonly" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER)"))
  let stmt1 = sqlite_prepare(db, cstring("SELECT * FROM t"))
  assert_true(sqlite_stmt_readonly(stmt1) != 0)
  sqlite_finalize(stmt1)
  let stmt2 = sqlite_prepare(db, cstring("INSERT INTO t VALUES (1)"))
  assert_eq(sqlite_stmt_readonly(stmt2), 0)
  sqlite_finalize(stmt2)
  let stmt3 = sqlite_prepare(db, cstring("UPDATE t SET id = 2"))
  assert_eq(sqlite_stmt_readonly(stmt3), 0)
  sqlite_finalize(stmt3)
  sqlite_close(db)
}

///|
test "sqlite_bind_parameter_name_and_index" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER, value TEXT)"))
  let stmt = sqlite_prepare(
    db,
    cstring("INSERT INTO t (id, value) VALUES (:id, :value)"),
  )
  assert_eq(sqlite_bind_parameter_count(stmt), 2)
  let _ = sqlite_bind_parameter_name(stmt, 1)
  let _ = sqlite_bind_parameter_name(stmt, 2)
  let id_idx = sqlite_bind_parameter_index(stmt, cstring(":id"))
  assert_eq(id_idx, 1)
  let value_idx = sqlite_bind_parameter_index(stmt, cstring(":value"))
  assert_eq(value_idx, 2)
  let _ = sqlite_bind_int(stmt, id_idx, 100)
  let _ = sqlite_bind_text(stmt, value_idx, cstring("test"))
  let _ = sqlite_step(stmt)
  sqlite_finalize(stmt)
  sqlite_close(db)
}

///|
test "sqlite_db_filename_and_readonly" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_db_filename(db, cstring("main"))
  let is_readonly = sqlite_db_readonly(db, cstring("main"))
  assert_eq(is_readonly, 0)
  sqlite_close(db)
}

///|
test "sqlite_expanded_sql" {
  let db = sqlite_open(cstring(":memory:"))
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER, value TEXT)"))
  let stmt = sqlite_prepare(
    db,
    cstring("SELECT * FROM t WHERE id = ? AND value = ?"),
  )
  let _ = sqlite_bind_int(stmt, 1, 42)
  let _ = sqlite_bind_text(stmt, 2, cstring("test"))
  let _ = sqlite_expanded_sql(stmt)
  sqlite_finalize(stmt)
  sqlite_close(db)
}

///|
test "sqlite_open_v2" {
  let db = sqlite_open_v2(
    cstring(":memory:"),
    SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_MEMORY,
    cstring(""),
  )
  assert_false(sqlite_is_null(db) == 1)
  let _ = sqlite_exec(db, cstring("CREATE TABLE t (id INTEGER)"))
  sqlite_close(db)
}

///|
test "sqlite_limit" {
  let db = sqlite_open(cstring(":memory:"))
  let current_limit = sqlite_limit(db, SQLITE_LIMIT_LENGTH, -1)
  assert_true(current_limit > 0)
  let sql_limit = sqlite_limit(db, SQLITE_LIMIT_SQL_LENGTH, -1)
  assert_true(sql_limit > 0)
  let column_limit = sqlite_limit(db, SQLITE_LIMIT_COLUMN, -1)
  assert_true(column_limit > 0)
  sqlite_close(db)
}
