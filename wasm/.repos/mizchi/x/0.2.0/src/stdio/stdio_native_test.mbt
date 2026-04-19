///|
async test "write stdout" {
  stdout.write("stdio test: stdout\n")
}

///|
async test "write stderr" {
  stderr.write("stdio test: stderr\n")
}

///|
test "fd values" {
  inspect(stdin.fd(), content="0")
  inspect(stdout.fd(), content="1")
  inspect(stderr.fd(), content="2")
}
