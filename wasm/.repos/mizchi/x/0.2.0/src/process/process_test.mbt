///|
async test "run exit code 0" {
  let code = @process.run("node", ["-e", "process.exit(0)"])
  inspect(code, content="0")
}

///|
async test "run exit code 42" {
  let code = @process.run("node", ["-e", "process.exit(42)"])
  inspect(code, content="42")
}

///|
async test "collect_stdout" {
  let (code, stdout) = @process.collect_stdout("node", [
    "-e", "console.log('hello')",
  ])
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="hello")
}

///|
async test "collect_error" {
  let (code, stderr) = @process.collect_stderr("node", [
    "-e", "console.error('oops')",
  ])
  inspect(code, content="0")
  inspect(stderr.text().trim_end(), content="oops")
}

///|
async test "collect_output" {
  let (code, stdout, stderr) = @process.collect_output("node", [
    "-e", "console.log('out'); console.error('err')",
  ])
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="out")
  inspect(stderr.text().trim_end(), content="err")
}

///|
async test "collect_output_merged" {
  let (code, output) = @process.collect_output_merged("node", [
    "-e", "console.log('merged_out')",
  ])
  inspect(code, content="0")
  inspect(output.text().trim_end(), content="merged_out")
}

///|
async test "basic_ls" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    ["-e", "require('fs').readdirSync('.').sort().forEach(f=>console.log(f))"],
    cwd="/tmp",
  )
  inspect(code, content="0")
  inspect(stdout.text().length() > 0, content="true")
}

///|
async test "basic wait" {
  let code = @process.run("node", ["-e", "setTimeout(()=>process.exit(0),100)"])
  inspect(code, content="0")
}

///|
async test "wait exitcode" {
  let code = @process.run("node", ["-e", "process.exit(42)"])
  inspect(code, content="42")
}

///|
async test "set cwd" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    ["-e", "console.log(require('path').basename(process.cwd()))"],
    cwd="/tmp",
  )
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="tmp")
}

///|
async test "set_env" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    ["-e", "console.log(process.env.MAGIC_VAR)"],
    extra_env={ "MAGIC_VAR": "MAGIC_VALUE" },
  )
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="MAGIC_VALUE")
}

///|
async test "set_env no inherit" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    [
      "-e", "const e=process.env;const ks=Object.keys(e).filter(k=>k.startsWith('MAGIC_')).sort();ks.forEach(k=>console.log(k+'='+e[k]))",
    ],
    extra_env={ "MAGIC_VAR_1": "MAGIC_VALUE_1", "MAGIC_VAR_2": "MAGIC_VALUE_2" },
    inherit_env=false,
  )
  inspect(code, content="0")
  inspect(
    stdout.text().trim_end(),
    content="MAGIC_VAR_1=MAGIC_VALUE_1\nMAGIC_VAR_2=MAGIC_VALUE_2",
  )
}
