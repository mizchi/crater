///|
async test "run returns exit code" {
  let code = @process.run("true", [])
  assert_eq(code, 0)
}

///|
async test "run non-zero exit" {
  let code = @process.run("false", [])
  assert_true(code != 0)
}

///|
async test "collect_output" {
  let (exit_code, stdout, _stderr) = @process.collect_output("echo", ["hello"])
  assert_eq(exit_code, 0)
  assert_eq(stdout.text().trim_end(), "hello")
}
