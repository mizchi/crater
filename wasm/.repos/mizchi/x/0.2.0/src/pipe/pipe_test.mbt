///|
async test "read_exactly" {
  let buf = StringBuilder::new()
  fn log(msg) {
    buf..write_string(msg).write_char('\n')
  }
  @async.with_task_group(root => {
    let (r, w) = pipe()
    root.spawn_bg(() => {
      defer r.close()
      let msg1 = r.read_exactly(4) |> @utf8.decode
      log("first message: \{msg1}")
      let msg2 = r.read_exactly(4) |> @utf8.decode
      log("second message: \{msg2}")
      let msg3 = r.read_exactly(4) |> @utf8.decode
      log("third message: \{msg3}")
    })
    root.spawn_bg(() => {
      defer w.close()
      log("first message sent")
      w.write("abcdef")
      @async.sleep(100)
      log("second message sent")
      w.write("ghijkl")
    })
  })
  inspect(
    buf.to_string(),
    content=(
      #|first message sent
      #|first message: abcd
      #|second message sent
      #|second message: efgh
      #|third message: ijkl
      #|
    ),
  )
}

///|
async test "read_exactly failure" {
  let buf = StringBuilder::new()
  fn log(msg) {
    buf..write_string(msg).write_char('\n')
  }
  @async.with_task_group(root => {
    let (r, w) = pipe()
    root.spawn_bg(() => {
      defer r.close()
      let msg1 = r.read_exactly(4) |> @utf8.decode
      log("first message: \{msg1}")
      let msg2 = r.read_exactly(4) |> @utf8.decode
      log("second message: \{msg2}")
      let msg3 = r.read_exactly(4) |> @utf8.decode
      log("third message: \{msg3}")
    })
    root.spawn_bg(() => {
      defer w.close()
      log("first message sent")
      w.write("abcdef")
    })
  }) catch {
    err => log(err.to_string())
  }
  inspect(
    buf.to_string(),
    content=(
      #|first message sent
      #|first message: abcd
      #|ReaderClosed
      #|
    ),
  )
}

///|
async test "reader closed" {
  let (r, w) = pipe()
  r.close()
  @async.sleep(100)
  assert_true((try? w.write("abcd")) is Err(_))
}
