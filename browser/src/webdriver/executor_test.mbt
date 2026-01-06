///|
/// Tests for Protocol-First Executor
/// Note: Async methods cannot be tested directly in synchronous tests
test "executor new" {
  let executor = Executor::new()
  assert_false(executor.logging_enabled)
  inspect(executor.operation_log.length(), content="0")
}

///|
test "executor with viewport" {
  let executor = Executor::new_with_viewport(1024, 768)
  assert_false(executor.logging_enabled)
}

///|
test "executor enable logging" {
  let executor = Executor::new()
  executor.enable_logging()
  assert_true(executor.logging_enabled)
  executor.disable_logging()
  assert_false(executor.logging_enabled)
}

///|
test "executor clear log" {
  let executor = Executor::new()
  executor.enable_logging()
  // Simulate some log entries
  executor.operation_log.push("test entry 1")
  executor.operation_log.push("test entry 2")
  inspect(executor.get_log().length(), content="2")
  executor.clear_log()
  inspect(executor.get_log().length(), content="0")
}

///|
test "executor get log returns reference" {
  let executor = Executor::new()
  executor.operation_log.push("entry")
  let log = executor.get_log()
  inspect(log.length(), content="1")
  inspect(log[0], content="entry")
}

///|
test "executor manager is accessible" {
  let executor = Executor::new()
  // Can access manager to verify it's properly initialized
  let ctx = executor.manager.create_context()
  assert_true(ctx.has_prefix("ctx-"))
}
