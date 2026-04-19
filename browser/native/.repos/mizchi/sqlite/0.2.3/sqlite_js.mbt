// Node.js SQLite bindings

///|
#external
pub type NodeDatabaseSync

///|
#borrow(path, opts)
extern "js" fn new_database_sync(
  path : String,
  opts : JsAny,
) -> NodeDatabaseSync =
  #| (path, opts) => new (require("node:sqlite").DatabaseSync)(path, opts)

///|
pub fn NodeDatabaseSync::new(
  path : String,
  returnArrays? : Bool = false,
) -> NodeDatabaseSync {
  let opts = js_new_object()
  js_set(opts, "returnArrays", to_any_bool(returnArrays))
  new_database_sync(path, opts)
}

///|
pub fn NodeDatabaseSync::close(self : NodeDatabaseSync) -> Unit {
  js_call0(to_any_node_db(self), "close") |> ignore
}

///|
pub fn NodeDatabaseSync::exec(self : NodeDatabaseSync, sql : String) -> Unit {
  js_call1(to_any_node_db(self), "exec", to_any_string(sql)) |> ignore
}

///|
pub fn NodeDatabaseSync::prepare(
  self : NodeDatabaseSync,
  sql : String,
) -> NodeStatementSync {
  from_any_stmt(js_call1(to_any_node_db(self), "prepare", to_any_string(sql)))
}

///|
extern "js" fn to_any_node_db(v : NodeDatabaseSync) -> JsAny =
  #| (v) => v

///|
#borrow(v)
extern "js" fn from_any_stmt(v : JsAny) -> NodeStatementSync =
  #| (v) => v

///|
#external
pub type NodeStatementSync

///|
extern "js" fn to_any_stmt(v : NodeStatementSync) -> JsAny =
  #| (v) => v

///|
#borrow(v)
extern "js" fn from_any_array(v : JsAny) -> Array[JsAny] =
  #| (v) => v

///|
pub fn NodeStatementSync::run(
  self : NodeStatementSync,
  anonymous_parameters? : Array[JsAny] = [],
) -> JsAny {
  let args = js_new_array()
  for param in anonymous_parameters {
    js_array_push(args, param)
  }
  js_apply(to_any_stmt(self), "run", args)
}

///|
pub fn NodeStatementSync::all(
  self : NodeStatementSync,
  anonymous_parameters? : Array[JsAny] = [],
) -> Array[JsAny] {
  let args = js_new_array()
  for param in anonymous_parameters {
    js_array_push(args, param)
  }
  from_any_array(js_apply(to_any_stmt(self), "all", args))
}

///|
pub fn NodeStatementSync::columns(self : NodeStatementSync) -> Array[JsAny] {
  from_any_array(js_call0(to_any_stmt(self), "columns"))
}

// High-level API compatible with native

///|
pub fn sql_value_to_any(value : SqlValue) -> JsAny {
  match value {
    Null => js_null()
    Int(v) => to_any_int(v)
    // Node.js SQLite doesn't support BigInt as bind parameter, convert to Number
    Int64(v) => int64_to_number(v)
    Double(v) => to_any_double(v)
    Text(v) => to_any_string(bytes_to_string(v))
    Blob(v) => to_any_bytes(v)
  }
}

///|
pub fn any_to_sql_value(value : JsAny) -> SqlValue {
  if is_nullish(value) {
    Null
  } else {
    let kind = typeof_(value)
    if kind == "number" {
      if is_integer(value) {
        Int(from_any_int(value))
      } else {
        Double(from_any_double(value))
      }
    } else if kind == "bigint" {
      Int64(from_any_int64(value))
    } else if kind == "string" {
      Text(string_to_bytes(from_any_string(value)))
    } else if is_uint8array(value) {
      Blob(from_any_bytes(value))
    } else {
      Null
    }
  }
}

///|
fn any_to_bytes(value : JsAny) -> Bytes {
  if is_nullish(value) {
    string_to_bytes("")
  } else {
    let kind = typeof_(value)
    if kind == "string" {
      string_to_bytes(from_any_string(value))
    } else if is_uint8array(value) {
      from_any_bytes(value)
    } else {
      string_to_bytes("")
    }
  }
}

///|
priv struct StatementState {
  stmt : NodeStatementSync
  mut bound : Array[SqlValue]
  mut rows : Array[JsAny]
  mut row_index : Int
  mut current_row : JsAny?
  mut done : Bool
}

///|
fn statement_state_new(stmt : NodeStatementSync) -> StatementState {
  { stmt, bound: [], rows: [], row_index: 0, current_row: None, done: false }
}

///|
fn statement_bound_params(state : StatementState) -> Array[JsAny] {
  let params : Array[JsAny] = []
  for value in state.bound {
    params.push(sql_value_to_any(value))
  }
  params
}

///|
fn statement_reset_state(state : StatementState) -> Unit {
  state.rows = []
  state.row_index = 0
  state.current_row = None
  state.done = false
}

///|
pub struct Database {
  priv db : NodeDatabaseSync
}

///|
pub fn Database::open(path : String) -> Database? {
  Some({ db: NodeDatabaseSync::new(path, returnArrays=true) })
}

///|
pub fn Database::close(self : Database) -> Unit {
  self.db.close()
}

///|
pub fn Database::exec(self : Database, sql : String) -> Bool {
  self.db.exec(sql)
  true
}

///|
pub fn Database::prepare(self : Database, sql : String) -> Statement? {
  Some({ state: statement_state_new(self.db.prepare(sql)) })
}

///|
pub fn Database::query(self : Database, sql : String) -> Statement? {
  self.prepare(sql)
}

///|
pub fn Database::errcode(self : Database) -> Int {
  let _ = self
  0
}

///|
pub fn Database::errmsg(self : Database) -> Bytes {
  let _ = self
  string_to_bytes("")
}

///|
pub fn Database::extended_errcode(self : Database) -> Int {
  let _ = self
  0
}

///|
pub fn Database::changes(self : Database) -> Int {
  match self.prepare("SELECT changes()") {
    Some(stmt) => {
      let mut result = 0
      if stmt.step() {
        result = stmt.column_int(0)
      }
      stmt.finalize()
      result
    }
    None => 0
  }
}

///|
pub fn Database::last_insert_rowid(self : Database) -> Int64 {
  match self.prepare("SELECT last_insert_rowid()") {
    Some(stmt) => {
      let mut result : Int64 = 0L
      if stmt.step() {
        result = stmt.column_int(0).to_int64()
      }
      stmt.finalize()
      result
    }
    None => 0L
  }
}

///|
pub fn Database::busy_timeout(self : Database, ms : Int) -> Bool {
  let _ = self
  let _ = ms
  false
}

///|
pub fn Database::get_autocommit(self : Database) -> Bool {
  let _ = self
  true
}

///|
pub fn Database::total_changes(self : Database) -> Int {
  match self.prepare("SELECT total_changes()") {
    Some(stmt) => {
      let mut result = 0
      if stmt.step() {
        result = stmt.column_int(0)
      }
      stmt.finalize()
      result
    }
    None => 0
  }
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
  priv state : StatementState
}

///|
pub fn Statement::step(self : Statement) -> Bool {
  if self.state.done {
    return false
  }
  if self.state.row_index == 0 && self.state.rows.length() == 0 {
    self.state.rows = self.state.stmt.all(
      anonymous_parameters=statement_bound_params(self.state),
    )
  }
  if self.state.row_index < self.state.rows.length() {
    let row = self.state.rows[self.state.row_index]
    self.state.row_index = self.state.row_index + 1
    self.state.current_row = Some(row)
    true
  } else {
    self.state.done = true
    self.state.current_row = None
    false
  }
}

///|
pub fn Statement::execute(self : Statement) -> Bool {
  self.state.stmt.run(anonymous_parameters=statement_bound_params(self.state))
  |> ignore
  statement_reset_state(self.state)
  true
}

///|
extern "js" fn to_any_js(v : JsAny) -> JsAny =
  #| (v) => v

///|
pub fn Statement::column_int(self : Statement, col : Int) -> Int {
  match self.state.current_row {
    Some(row) => {
      let value = js_get_index(to_any_js(row), col)
      let kind = typeof_(value)
      if kind == "number" {
        from_any_int(value)
      } else if kind == "bigint" {
        bigint_to_number(value)
      } else {
        0
      }
    }
    None => 0
  }
}

///|
pub fn Statement::column_text(self : Statement, col : Int) -> Bytes {
  match self.state.current_row {
    Some(row) => any_to_bytes(js_get_index(to_any_js(row), col))
    None => string_to_bytes("")
  }
}

///|
pub fn Statement::column_count(self : Statement) -> Int {
  self.state.stmt.columns().length()
}

///|
pub fn Statement::bind(self : Statement, idx : Int, value : SqlValue) -> Bool {
  if idx <= 0 {
    return false
  }
  let target = idx - 1
  while self.state.bound.length() <= target {
    self.state.bound.push(Null)
  }
  self.state.bound[target] = value
  true
}

///|
pub fn Statement::bind_all(self : Statement, values : Array[SqlValue]) -> Bool {
  self.state.bound = values
  true
}

///|
pub fn Statement::column(self : Statement, col : Int) -> SqlValue {
  match self.state.current_row {
    Some(row) => any_to_sql_value(js_get_index(to_any_js(row), col))
    None => Null
  }
}

///|
pub fn Statement::reset(self : Statement) -> Unit {
  statement_reset_state(self.state)
}

///|
pub fn Statement::finalize(self : Statement) -> Unit {
  statement_reset_state(self.state)
}

///|
pub fn Statement::iter(self : Statement) -> Iter[Statement] {
  self.reset()
  Iter::new(fn() { if self.step() { Some(self) } else { None } })
}
