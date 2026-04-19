// SQLite bindings for MoonBit (Native backend via C FFI)

// Opaque external types (corresponding to C pointers)

///|
type Sqlite3

///|
type Sqlite3Stmt

// Low-level extern declarations
// #borrow: Treats arguments as borrowed, MoonBit automatically manages memory

///|
#borrow(filename)
extern "C" fn sqlite_open(filename : Bytes) -> Sqlite3 = "sqlite_open"

///|
#borrow(filename, vfs)
pub extern "C" fn sqlite_open_v2(
  filename : Bytes,
  flags : Int,
  vfs : Bytes,
) -> Sqlite3 = "sqlite_open_v2"

///|
#borrow(ptr)
extern "C" fn sqlite_is_null(ptr : Sqlite3) -> Int = "sqlite_is_null"

///|
#borrow(db)
extern "C" fn sqlite_close(db : Sqlite3) -> Unit = "sqlite_close"

///|
#borrow(db, sql)
extern "C" fn sqlite_exec(db : Sqlite3, sql : Bytes) -> Int = "sqlite_exec"

///|
#borrow(db, sql)
pub extern "C" fn sqlite_prepare(db : Sqlite3, sql : Bytes) -> Sqlite3Stmt = "sqlite_prepare"

///|
#borrow(stmt)
pub extern "C" fn sqlite_stmt_is_null(stmt : Sqlite3Stmt) -> Int = "sqlite_stmt_is_null"

///|
#borrow(stmt)
pub extern "C" fn sqlite_finalize(stmt : Sqlite3Stmt) -> Unit = "sqlite_finalize"

///|
#borrow(stmt)
pub extern "C" fn sqlite_bind_int(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Int,
) -> Int = "sqlite_bind_int"

///|
#borrow(stmt, text)
pub extern "C" fn sqlite_bind_text(
  stmt : Sqlite3Stmt,
  idx : Int,
  text : Bytes,
) -> Int = "sqlite_bind_text"

///|
#borrow(stmt)
pub extern "C" fn sqlite_step(stmt : Sqlite3Stmt) -> Int = "sqlite_step"

///|
#borrow(stmt)
pub extern "C" fn sqlite_column_int(stmt : Sqlite3Stmt, col : Int) -> Int = "sqlite_column_int"

///|
#borrow(stmt)
pub extern "C" fn sqlite_column_text(stmt : Sqlite3Stmt, col : Int) -> Bytes = "sqlite_column_text"

///|
#borrow(stmt)
extern "C" fn sqlite_reset(stmt : Sqlite3Stmt) -> Unit = "sqlite_reset"

// Error handling

///|
#borrow(db)
pub extern "C" fn sqlite_errcode(db : Sqlite3) -> Int = "sqlite_errcode"

///|
#borrow(db)
pub extern "C" fn sqlite_errmsg(db : Sqlite3) -> Bytes = "sqlite_errmsg"

///|
#borrow(db)
pub extern "C" fn sqlite_extended_errcode(db : Sqlite3) -> Int = "sqlite_extended_errcode"

///|
pub extern "C" fn sqlite_errstr(errcode : Int) -> Bytes = "sqlite_errstr"

// Additional bind functions

///|
#borrow(stmt)
pub extern "C" fn sqlite_bind_null(stmt : Sqlite3Stmt, idx : Int) -> Int = "sqlite_bind_null"

///|
#borrow(stmt)
extern "C" fn sqlite_bind_int64_ffi(
  stmt : Sqlite3Stmt,
  idx : Int64,
  value : Int64,
) -> Int = "sqlite_bind_int64"

///|
pub fn sqlite_bind_int64(stmt : Sqlite3Stmt, idx : Int, value : Int64) -> Int {
  sqlite_bind_int64_ffi(stmt, idx.to_int64(), value)
}

///|
#borrow(stmt)
pub extern "C" fn sqlite_bind_double(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Double,
) -> Int = "sqlite_bind_double"

///|
#borrow(stmt, blob)
pub extern "C" fn sqlite_bind_blob(
  stmt : Sqlite3Stmt,
  idx : Int,
  blob : Bytes,
) -> Int = "sqlite_bind_blob"

// Additional column retrieval functions

///|
#borrow(stmt)
pub extern "C" fn sqlite_column_int64(stmt : Sqlite3Stmt, col : Int) -> Int64 = "sqlite_column_int64"

///|
#borrow(stmt)
pub extern "C" fn sqlite_column_double(stmt : Sqlite3Stmt, col : Int) -> Double = "sqlite_column_double"

///|
#borrow(stmt)
pub extern "C" fn sqlite_column_blob(stmt : Sqlite3Stmt, col : Int) -> Bytes = "sqlite_column_blob"

///|
#borrow(stmt)
pub extern "C" fn sqlite_column_bytes(stmt : Sqlite3Stmt, col : Int) -> Int = "sqlite_column_bytes"

///|
#borrow(stmt)
pub extern "C" fn sqlite_column_type(stmt : Sqlite3Stmt, col : Int) -> Int = "sqlite_column_type"

// Metadata functions

///|
#borrow(stmt)
pub extern "C" fn sqlite_column_count(stmt : Sqlite3Stmt) -> Int = "sqlite_column_count"

///|
#borrow(stmt)
pub extern "C" fn sqlite_column_name(stmt : Sqlite3Stmt, col : Int) -> Bytes = "sqlite_column_name"

///|
#borrow(db)
pub extern "C" fn sqlite_changes(db : Sqlite3) -> Int = "sqlite_changes"

///|
#borrow(db)
pub extern "C" fn sqlite_last_insert_rowid(db : Sqlite3) -> Int64 = "sqlite_last_insert_rowid"

// Statement clear

///|
#borrow(stmt)
pub extern "C" fn sqlite_clear_bindings(stmt : Sqlite3Stmt) -> Int = "sqlite_clear_bindings"

// Concurrency control

///|
#borrow(db)
pub extern "C" fn sqlite_busy_timeout(db : Sqlite3, ms : Int) -> Int = "sqlite_busy_timeout"

// Transaction management

///|
#borrow(db)
pub extern "C" fn sqlite_get_autocommit(db : Sqlite3) -> Int = "sqlite_get_autocommit"

///|
#borrow(db)
pub extern "C" fn sqlite_total_changes(db : Sqlite3) -> Int = "sqlite_total_changes"

// Statement introspection

///|
#borrow(stmt)
pub extern "C" fn sqlite_sql(stmt : Sqlite3Stmt) -> Bytes = "sqlite_sql"

///|
#borrow(stmt)
pub extern "C" fn sqlite_bind_parameter_count(stmt : Sqlite3Stmt) -> Int = "sqlite_bind_parameter_count"

///|
#borrow(stmt)
pub extern "C" fn sqlite_stmt_readonly(stmt : Sqlite3Stmt) -> Int = "sqlite_stmt_readonly"

// Parameter names and indices

///|
#borrow(stmt)
pub extern "C" fn sqlite_bind_parameter_name(
  stmt : Sqlite3Stmt,
  idx : Int,
) -> Bytes = "sqlite_bind_parameter_name"

///|
#borrow(stmt, name)
pub extern "C" fn sqlite_bind_parameter_index(
  stmt : Sqlite3Stmt,
  name : Bytes,
) -> Int = "sqlite_bind_parameter_index"

// Database metadata

///|
#borrow(db, dbname)
pub extern "C" fn sqlite_db_filename(db : Sqlite3, dbname : Bytes) -> Bytes = "sqlite_db_filename"

///|
#borrow(db, dbname)
pub extern "C" fn sqlite_db_readonly(db : Sqlite3, dbname : Bytes) -> Int = "sqlite_db_readonly"

// SQL expansion

///|
#borrow(stmt)
pub extern "C" fn sqlite_expanded_sql(stmt : Sqlite3Stmt) -> Bytes = "sqlite_expanded_sql"

// Query control

///|
#borrow(db)
pub extern "C" fn sqlite_interrupt(db : Sqlite3) -> Unit = "sqlite_interrupt"

// Resource limits

///|
#borrow(db)
pub extern "C" fn sqlite_limit(db : Sqlite3, id : Int, newVal : Int) -> Int = "sqlite_limit"

// Constants

///|
const SQLITE_OK : Int = 0

///|
pub const SQLITE_ROW : Int = 100

///|
pub const SQLITE_DONE : Int = 101

// SQLite type constants

///|
pub const SQLITE_INTEGER : Int = 1

///|
pub const SQLITE_FLOAT : Int = 2

///|
pub const SQLITE_TEXT : Int = 3

///|
pub const SQLITE_BLOB : Int = 4

///|
pub const SQLITE_NULL : Int = 5

// sqlite3_open_v2 flags

///|
pub const SQLITE_OPEN_READONLY : Int = 0x00000001

///|
pub const SQLITE_OPEN_READWRITE : Int = 0x00000002

///|
pub const SQLITE_OPEN_CREATE : Int = 0x00000004

///|
pub const SQLITE_OPEN_MEMORY : Int = 0x00000080

///|
pub const SQLITE_OPEN_NOMUTEX : Int = 0x00008000

///|
pub const SQLITE_OPEN_FULLMUTEX : Int = 0x00010000

// sqlite3_limit ID constants

///|
pub const SQLITE_LIMIT_LENGTH : Int = 0

///|
pub const SQLITE_LIMIT_SQL_LENGTH : Int = 1

///|
pub const SQLITE_LIMIT_COLUMN : Int = 2

///|
pub const SQLITE_LIMIT_EXPR_DEPTH : Int = 3

///|
pub const SQLITE_LIMIT_COMPOUND_SELECT : Int = 4

///|
pub const SQLITE_LIMIT_VDBE_OP : Int = 5

///|
pub const SQLITE_LIMIT_FUNCTION_ARG : Int = 6

///|
pub const SQLITE_LIMIT_ATTACHED : Int = 7

///|
pub const SQLITE_LIMIT_LIKE_PATTERN_LENGTH : Int = 8

///|
pub const SQLITE_LIMIT_VARIABLE_NUMBER : Int = 9

///|
pub const SQLITE_LIMIT_TRIGGER_DEPTH : Int = 10

// String -> Bytes conversion helper (UTF-8 encoding)

///|
fn cstring(s : String) -> Bytes {
  @encoding.encode(UTF8, s)
}

// High-level API

///|
pub struct Database {
  priv handle : Sqlite3
}

///|
pub fn Database::open(path : String) -> Database? {
  let db = sqlite_open(cstring(path))
  if sqlite_is_null(db) == 1 {
    None
  } else {
    Some({ handle: db })
  }
}

///|
pub fn Database::close(self : Database) -> Unit {
  sqlite_close(self.handle)
}

///|
pub fn Database::exec(self : Database, sql : String) -> Bool {
  sqlite_exec(self.handle, cstring(sql)) == SQLITE_OK
}

///|
pub fn Database::prepare(self : Database, sql : String) -> Statement? {
  let stmt = sqlite_prepare(self.handle, cstring(sql))
  if sqlite_stmt_is_null(stmt) == 1 {
    None
  } else {
    Some({ stmt, done: false })
  }
}

///|
pub fn Database::query(self : Database, sql : String) -> Statement? {
  self.prepare(sql)
}

///|
pub fn Database::errcode(self : Database) -> Int {
  sqlite_errcode(self.handle)
}

///|
pub fn Database::errmsg(self : Database) -> Bytes {
  sqlite_errmsg(self.handle)
}

///|
pub fn Database::extended_errcode(self : Database) -> Int {
  sqlite_extended_errcode(self.handle)
}

///|
pub fn Database::changes(self : Database) -> Int {
  sqlite_changes(self.handle)
}

///|
pub fn Database::last_insert_rowid(self : Database) -> Int64 {
  sqlite_last_insert_rowid(self.handle)
}

///|
pub fn Database::busy_timeout(self : Database, ms : Int) -> Bool {
  sqlite_busy_timeout(self.handle, ms) == SQLITE_OK
}

///|
pub fn Database::get_autocommit(self : Database) -> Bool {
  sqlite_get_autocommit(self.handle) != 0
}

///|
pub fn Database::total_changes(self : Database) -> Int {
  sqlite_total_changes(self.handle)
}

// Transaction API

///|
pub fn Database::begin(self : Database) -> Bool {
  self.exec("BEGIN")
}

///|
pub fn Database::begin_immediate(self : Database) -> Bool {
  self.exec("BEGIN IMMEDIATE")
}

///|
pub fn Database::begin_exclusive(self : Database) -> Bool {
  self.exec("BEGIN EXCLUSIVE")
}

///|
pub fn Database::commit(self : Database) -> Bool {
  self.exec("COMMIT")
}

///|
pub fn Database::rollback(self : Database) -> Bool {
  self.exec("ROLLBACK")
}

///|
pub fn Database::savepoint(self : Database, name : String) -> Bool {
  self.exec("SAVEPOINT " + name)
}

///|
pub fn Database::release(self : Database, name : String) -> Bool {
  self.exec("RELEASE " + name)
}

///|
pub fn Database::rollback_to(self : Database, name : String) -> Bool {
  self.exec("ROLLBACK TO " + name)
}

///|
pub struct Statement {
  priv stmt : Sqlite3Stmt
  priv mut done : Bool
}

///|
pub fn Statement::step(self : Statement) -> Bool {
  if self.done {
    return false
  }
  let result = sqlite_step(self.stmt)
  if result == SQLITE_ROW {
    true
  } else {
    self.done = true
    false
  }
}

///|
pub fn Statement::execute(self : Statement) -> Bool {
  let result = sqlite_step(self.stmt)
  result == SQLITE_DONE || result == SQLITE_ROW
}

///|
pub fn Statement::column_int(self : Statement, col : Int) -> Int {
  sqlite_column_int(self.stmt, col)
}

///|
pub fn Statement::column_text(self : Statement, col : Int) -> Bytes {
  sqlite_column_text(self.stmt, col)
}

///|
pub fn Statement::column_count(self : Statement) -> Int {
  sqlite_column_count(self.stmt)
}

///|
pub fn Statement::bind(self : Statement, idx : Int, value : SqlValue) -> Bool {
  let result = match value {
    Null => sqlite_bind_null(self.stmt, idx)
    Int(v) => sqlite_bind_int(self.stmt, idx, v)
    Int64(v) => sqlite_bind_int64(self.stmt, idx, v)
    Double(v) => sqlite_bind_double(self.stmt, idx, v)
    Text(s) => sqlite_bind_text(self.stmt, idx, s)
    Blob(b) => sqlite_bind_blob(self.stmt, idx, b)
  }
  result == SQLITE_OK
}

///|
pub fn Statement::bind_all(self : Statement, values : Array[SqlValue]) -> Bool {
  for i = 0; i < values.length(); i = i + 1 {
    if not(self.bind(i + 1, values[i])) {
      return false
    }
  }
  true
}

///|
pub fn Statement::column(self : Statement, col : Int) -> SqlValue {
  let col_type = sqlite_column_type(self.stmt, col)
  match col_type {
    SQLITE_NULL => Null
    SQLITE_INTEGER => Int64(sqlite_column_int64(self.stmt, col))
    SQLITE_FLOAT => Double(sqlite_column_double(self.stmt, col))
    SQLITE_TEXT => Text(sqlite_column_text(self.stmt, col))
    SQLITE_BLOB => Blob(sqlite_column_blob(self.stmt, col))
    _ => Null
  }
}

///|
pub fn Statement::reset(self : Statement) -> Unit {
  sqlite_reset(self.stmt)
  self.done = false
}

///|
pub fn Statement::finalize(self : Statement) -> Unit {
  sqlite_finalize(self.stmt)
}

///|
pub fn Statement::iter(self : Statement) -> Iter[Statement] {
  self.reset()
  Iter::new(fn() { if self.step() { Some(self) } else { None } })
}
