///|
fn[T] is_err(result : Result[T, V8Error]) -> Bool {
  match result {
    Ok(_) => false
    Err(_) => true
  }
}

///|
fn promise_state_name(state : PromiseState) -> String {
  match state {
    PromiseState::Pending => "Pending"
    PromiseState::Fulfilled => "Fulfilled"
    PromiseState::Rejected => "Rejected"
  }
}

///|
test "version is exposed" {
  inspect(version().length() > 0, content="true")
}

///|
test "runtime can start from snapshot" {
  let result = match snapshot_create("globalThis.answer = 41;") {
    Ok(snapshot) =>
      with_runtime_with_snapshot(snapshot, fn(runtime) {
        runtime.eval_string("globalThis.answer + 1")
      })
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"42\")")
}

///|
test "snapshot can be extended from existing snapshot" {
  let result = match snapshot_create("globalThis.base = 40;") {
    Ok(snapshot) =>
      match
        snapshot_extend(snapshot, "globalThis.answer = globalThis.base + 2;") {
        Ok(extended) =>
          with_runtime_with_snapshot(extended, fn(runtime) {
            runtime.eval_string("globalThis.answer")
          })
        Err(err) => Err(err)
      }
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"42\")")
}

///|
test "invalid snapshot surfaces as err" {
  inspect(
    is_err(runtime_new_with_snapshot(@utf8.encode("not a snapshot"))),
    content="true",
  )
}

///|
test "multiple runtimes can coexist" {
  let result = match (runtime_new(), runtime_new()) {
    (Ok(left), Ok(right)) => {
      let left_value = left.eval_string(
        "globalThis.answer = 1; globalThis.answer",
      )
      let right_value = right.eval_string(
        "globalThis.answer = 2; globalThis.answer",
      )
      let pair = match (left_value, right_value) {
        (Ok(left_value), Ok(right_value)) => Ok(left_value + ":" + right_value)
        (Err(err), _) => Err(err)
        (_, Err(err)) => Err(err)
      }
      left.dispose()
      right.dispose()
      pair
    }
    (Err(err), _) => Err(err)
    (_, Err(err)) => Err(err)
  }
  inspect(result, content="Ok(\"1:2\")")
}

///|
test "runtime builder preloads modules before build" {
  let builder = runtime_builder_new().load_module(
    "dep", "export const answer = 41;",
  )
  let result = builder.with_runtime(fn(runtime) {
    runtime.eval_async_string(
      "(async () => { let mod = await import('dep'); return mod.answer + 1 })()",
    )
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "runtime can set and get global json" {
  let result = with_runtime(fn(runtime) {
    let set = runtime.set_global_json(
      "config", "{\"answer\":42,\"items\":[1,2]}",
    )
    guard set is Ok(_) else { return Err(set.unwrap_err()) }
    runtime.get_global_json("config")
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42,\\\"items\\\":[1,2]}\")")
}

///|
test "runtime can call global function with json args" {
  let result = with_runtime(fn(runtime) {
    let prepared = runtime.eval_string(
      "globalThis.add = (a, b) => ({ answer: a + b })",
    )
    guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
    runtime.call_global_json("add", "[20,22]")
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}\")")
}

///|
test "runtime can call async global function with json args" {
  let result = with_runtime(fn(runtime) {
    let prepared = runtime.eval_string(
      "globalThis.load = async (base) => ({ answer: base + 2 })",
    )
    guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
    runtime.call_global_json("load", "[40]")
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}\")")
}

///|
test "runtime can set and get global bytes" {
  let result = with_runtime(fn(runtime) {
    let set = runtime.set_global_bytes("buf", @utf8.encode("ABC"))
    guard set is Ok(_) else { return Err(set.unwrap_err()) }
    let got = runtime.get_global_bytes("buf")
    guard got is Ok(_) else { return Err(got.unwrap_err()) }
    Ok(@utf8.decode_lossy(got.unwrap()))
  })
  inspect(result, content="Ok(\"ABC\")")
}

///|
test "runtime can call global function with bytes" {
  let result = with_runtime(fn(runtime) {
    let prepared = runtime.eval_string(
      "globalThis.reverse_buf = (buf) => new Uint8Array([buf[2], buf[1], buf[0]])",
    )
    guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
    let called = runtime.call_global_bytes("reverse_buf", @utf8.encode("ABC"))
    guard called is Ok(_) else { return Err(called.unwrap_err()) }
    Ok(@utf8.decode_lossy(called.unwrap()))
  })
  inspect(result, content="Ok(\"CBA\")")
}

///|
test "runtime can call async global function with bytes" {
  let result = with_runtime(fn(runtime) {
    let prepared = runtime.eval_string(
      "globalThis.decorate_buf = async (buf) => new Uint8Array([buf[0], buf[1], 33]).buffer",
    )
    guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
    let called = runtime.call_global_bytes("decorate_buf", @utf8.encode("AB"))
    guard called is Ok(_) else { return Err(called.unwrap_err()) }
    Ok(@utf8.decode_lossy(called.unwrap()))
  })
  inspect(result, content="Ok(\"AB!\")")
}

///|
test "runtime can manage resource table" {
  let closed_count = Ref::new(0)
  let result = with_runtime(fn(runtime) {
    let stdin = runtime.add_resource("stdin")
    guard stdin is Ok(_) else { return Err(stdin.unwrap_err()) }
    let stdout = runtime.add_resource_with_close("stdout", fn() {
      closed_count.val = closed_count.val + 1
    })
    guard stdout is Ok(_) else { return Err(stdout.unwrap_err()) }
    let listed = runtime.list_resources()
    guard listed is Ok(_) else { return Err(listed.unwrap_err()) }
    let entries = listed.unwrap()
    let first_name = runtime.get_resource_name(stdin.unwrap())
    guard first_name is Ok(_) else { return Err(first_name.unwrap_err()) }
    let unrefed = runtime.unref_resource(stdin.unwrap())
    guard unrefed is Ok(_) else { return Err(unrefed.unwrap_err()) }
    let after_unref = runtime.list_resources()
    guard after_unref is Ok(_) else { return Err(after_unref.unwrap_err()) }
    let refed = runtime.ref_resource(stdin.unwrap())
    guard refed is Ok(_) else { return Err(refed.unwrap_err()) }
    let closed = runtime.try_close_resource(stdout.unwrap())
    guard closed is Ok(_) else { return Err(closed.unwrap_err()) }
    let missing = runtime.try_close_resource(stdout.unwrap())
    guard missing is Ok(_) else { return Err(missing.unwrap_err()) }
    let remaining = runtime.list_resources()
    guard remaining is Ok(_) else { return Err(remaining.unwrap_err()) }
    Ok(
      entries.length().to_string() +
      ":" +
      entries[0].rid.to_string() +
      ":" +
      entries[0].name +
      ":" +
      entries[1].rid.to_string() +
      ":" +
      entries[1].name +
      ":" +
      first_name.unwrap().unwrap_or("") +
      ":" +
      unrefed.unwrap().to_string() +
      ":" +
      after_unref.unwrap()[0].is_ref.to_string() +
      ":" +
      refed.unwrap().to_string() +
      ":" +
      closed.unwrap().to_string() +
      ":" +
      missing.unwrap().to_string() +
      ":" +
      remaining.unwrap().length().to_string() +
      ":" +
      closed_count.val.to_string(),
    )
  })
  inspect(
    result,
    content="Ok(\"2:1:stdin:2:stdout:stdin:true:false:true:true:false:1:1\")",
  )
}

///|
test "runtime dispose closes remaining resources" {
  let closed_count = Ref::new(0)
  let runtime = runtime_new()
  let result = match runtime {
    Ok(runtime) => {
      let added = runtime.add_resource_with_close("stdin", fn() {
        closed_count.val = closed_count.val + 1
      })
      guard added is Ok(_) else { Err(added.unwrap_err()) }
      runtime.dispose()
      Ok(closed_count.val.to_string() + ":" + runtime.is_closed().to_string())
    }
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"1:true\")")
}

///|
test "runtime can install deno core compat for sync json ops" {
  let result = with_runtime(fn(runtime) {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    let registered = runtime.register_sync_json_result_callback("add", fn(
      payload,
    ) {
      if payload == "[20,22]" {
        Ok("{\"answer\":42}")
      } else {
        Err("blocked")
      }
    })
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    runtime.eval_json("Deno.core.opSync('add', [20, 22])")
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}\")")
}

///|
test "runtime can install deno core compat for async json ops via proxy" {
  let result = with_runtime(fn(runtime) {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    let registered = runtime.register_async_json_result_callback("add", fn(
      payload,
    ) {
      if payload == "[20,22]" {
        Ok("{\"answer\":42}")
      } else {
        Err("blocked")
      }
    })
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    runtime.eval_async_json("Deno.core.opAsync(Deno.core.ops.add, [20, 22])")
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}\")")
}

///|
test "runtime can install deno core compat for sync bytes ops" {
  let result = with_runtime(fn(runtime) {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    let registered = runtime.register_sync_bytes_result_callback("reverse", fn(
      payload,
    ) {
      if @utf8.decode_lossy(payload) == "ABC" {
        Ok(@utf8.encode("CBA"))
      } else {
        Err("blocked")
      }
    })
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let value = runtime.eval_bytes(
      "Deno.core.opSyncBytes(Deno.core.opsBytes.reverse, new Uint8Array([65, 66, 67]))",
    )
    guard value is Ok(_) else { return Err(value.unwrap_err()) }
    Ok(@utf8.decode_lossy(value.unwrap()))
  })
  inspect(result, content="Ok(\"CBA\")")
}

///|
test "runtime can install deno core compat metadata" {
  let result = with_runtime(fn(runtime) {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    runtime.eval_json(
      "({ argsOk: Array.isArray(Deno.args) && Deno.args.length === 0, buildOk: typeof Deno.build.os === 'string' && typeof Deno.build.arch === 'string', versionOk: typeof Deno.version.v8 === 'string' && Deno.version.v8.length > 0 })",
    )
  })
  inspect(
    result,
    content="Ok(\"{\\\"argsOk\\\":true,\\\"buildOk\\\":true,\\\"versionOk\\\":true}\")",
  )
}

///|
test "runtime can install deno core compat utility helpers" {
  let result = with_runtime(fn(runtime) {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    let stdin = runtime.add_resource("stdin")
    guard stdin is Ok(_) else { return Err(stdin.unwrap_err()) }
    let stdout = runtime.add_resource("stdout")
    guard stdout is Ok(_) else { return Err(stdout.unwrap_err()) }
    runtime.eval_async_json(
      "(async () => { const before = Deno.core.resources(); const promise = Deno.core.unrefOpPromise(Promise.resolve({ answer: 42 })); Deno.core.close(1); const closedAgain = Deno.core.tryClose(1); return { text: Deno.core.decode(Deno.core.encode('AB')), before, after: Deno.core.resources(), closedAgain, answer: (await promise).answer, inspect: Deno.inspect({ answer: 42 }), cwd: Deno.cwd(), execPath: Deno.execPath(), pid: Deno.pid, noColor: Deno.noColor, exitCode: Deno.exitCode }; })()",
    )
  })
  inspect(
    result,
    content="Ok(\"{\\\"text\\\":\\\"AB\\\",\\\"before\\\":{\\\"1\\\":\\\"stdin\\\",\\\"2\\\":\\\"stdout\\\"},\\\"after\\\":{\\\"2\\\":\\\"stdout\\\",\\\"3\\\":\\\"promise\\\"},\\\"closedAgain\\\":false,\\\"answer\\\":42,\\\"inspect\\\":\\\"{\\\\\\\"answer\\\\\\\":42}\\\",\\\"cwd\\\":\\\"/\\\",\\\"execPath\\\":\\\"/mizchi-v8/deno\\\",\\\"pid\\\":0,\\\"noColor\\\":false,\\\"exitCode\\\":0}\")",
  )
}

///|
test "runtime can install deno core compat for async bytes ops via proxy" {
  let result = with_runtime(fn(runtime) {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    let registered = runtime.register_async_bytes_result_callback("decorate", fn(
      payload,
    ) {
      if @utf8.decode_lossy(payload) == "AB" {
        Ok(@utf8.encode("AB!"))
      } else {
        Err("blocked")
      }
    })
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let value = runtime.eval_async_bytes(
      "Deno.core.opAsyncBytes(Deno.core.opsBytes.decorate, new Uint8Array([65, 66]))",
    )
    guard value is Ok(_) else { return Err(value.unwrap_err()) }
    Ok(@utf8.decode_lossy(value.unwrap()))
  })
  inspect(result, content="Ok(\"AB!\")")
}

///|
test "runtime can install node compat globals and buffer" {
  let result = with_runtime(fn(runtime) {
    let installed = runtime.install_node_compat()
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    runtime.eval_json(
      "({ sameGlobal: global === globalThis, versionOk: typeof process.versions.v8 === 'string' && process.versions.v8.length > 0, text: Buffer.from([65, 66]).toString(), size: Buffer.from('AB').length, concat: Buffer.concat([Buffer.from('A'), Buffer.from('B')]).toString() })",
    )
  })
  inspect(
    result,
    content="Ok(\"{\\\"sameGlobal\\\":true,\\\"versionOk\\\":true,\\\"text\\\":\\\"AB\\\",\\\"size\\\":2,\\\"concat\\\":\\\"AB\\\"}\")",
  )
}

///|
test "runtime can install node compat next tick" {
  let result = with_runtime(fn(runtime) {
    let installed = runtime.install_node_compat()
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    runtime.eval_async_json(
      "(async () => { let value = 'A'; await new Promise((resolve) => process.nextTick(() => { value = 'B'; resolve(null); })); return { value }; })()",
    )
  })
  inspect(result, content="Ok(\"{\\\"value\\\":\\\"B\\\"}\")")
}

///|
test "runtime async json op queue is empty by default" {
  let result = with_runtime(fn(runtime) {
    let op = runtime.take_async_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    match op.unwrap() {
      None => Ok(true)
      Some(_) => Ok(false)
    }
  })
  inspect(result, content="Ok(true)")
}

///|
test "runtime can resolve async json op from host" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_json_op("add")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsync('add', [20, 22])",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let op = runtime.take_async_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    let resolved = runtime.resolve_async_json_op(op.id, "{\"answer\":42}")
    guard resolved is Ok(_) else { return Err(resolved.unwrap_err()) }
    let value = promise.unwrap().await_json()
    guard value is Ok(_) else { return Err(value.unwrap_err()) }
    Ok(op.name + ":" + op.payload_json + ":" + value.unwrap())
  })
  inspect(result, content="Ok(\"add:[20,22]:{\\\"answer\\\":42}\")")
}

///|
test "runtime can reject async json op from host" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_json_op("fail")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsync('fail', { answer: 40 })",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let op = runtime.take_async_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    let rejected = runtime.reject_async_json_op(op.id, "boom")
    guard rejected is Ok(_) else { return Err(rejected.unwrap_err()) }
    Ok(
      op.name +
      ":" +
      op.payload_json +
      ":" +
      is_err(promise.unwrap().await_json()).to_string(),
    )
  })
  inspect(result, content="Ok(\"fail:{\\\"answer\\\":40}:true\")")
}

///|
test "runtime can reject async json op from host with json reason" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_json_op("fail_json")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsync('fail_json', { answer: 40 }).catch((err) => ({ code: err.code, answer: err.answer }))",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let op = runtime.take_async_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    let rejected = runtime.reject_async_json_op_with_json(
      op.id,
      "{\"code\":\"blocked\",\"answer\":40}",
    )
    guard rejected is Ok(_) else { return Err(rejected.unwrap_err()) }
    let reason = promise.unwrap().await_json()
    guard reason is Ok(_) else { return Err(reason.unwrap_err()) }
    Ok(op.name + ":" + op.payload_json + ":" + reason.unwrap())
  })
  inspect(
    result,
    content="Ok(\"fail_json:{\\\"answer\\\":40}:{\\\"code\\\":\\\"blocked\\\",\\\"answer\\\":40}\")",
  )
}

///|
test "runtime can resolve async json op from callback" {
  let result = with_runtime(fn(runtime) {
    let base = 40
    let registered = runtime.register_async_json_callback("add", fn(payload) {
      if payload == "[20,22]" {
        "{\"answer\":" + (base + 2).to_string() + "}"
      } else {
        "{\"answer\":0}"
      }
    })
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsync('add', [20, 22])",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let op = runtime.take_async_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let queued = match op.unwrap() {
      None => "none"
      Some(request) => request.name
    }
    let value = promise.unwrap().await_json()
    guard value is Ok(_) else { return Err(value.unwrap_err()) }
    Ok(queued + ":" + value.unwrap())
  })
  inspect(result, content="Ok(\"none:{\\\"answer\\\":42}\")")
}

///|
test "runtime can resolve and reject async json op from result callback" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_json_result_callback(
      "add_or_fail",
      fn(payload) {
        if payload == "[20,22]" {
          Ok("{\"answer\":42}")
        } else {
          Err("blocked")
        }
      },
    )
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let ok_promise = runtime.eval_promise_string(
      "MoonBit.opAsync('add_or_fail', [20, 22])",
    )
    guard ok_promise is Ok(_) else { return Err(ok_promise.unwrap_err()) }
    let bad_promise = runtime.eval_promise_string(
      "MoonBit.opAsync('add_or_fail', [1])",
    )
    guard bad_promise is Ok(_) else { return Err(bad_promise.unwrap_err()) }
    let first = runtime.take_async_json_op()
    guard first is Ok(_) else { return Err(first.unwrap_err()) }
    let second = runtime.take_async_json_op()
    guard second is Ok(_) else { return Err(second.unwrap_err()) }
    let ok_value = ok_promise.unwrap().await_json()
    guard ok_value is Ok(_) else { return Err(ok_value.unwrap_err()) }
    Ok(
      match (first.unwrap(), second.unwrap()) {
        (None, None) =>
          ok_value.unwrap() +
          ":" +
          is_err(bad_promise.unwrap().await_json()).to_string()
        _ => "queued"
      },
    )
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}:true\")")
}

///|
test "runtime can resolve and reject async json op from result callback with json reason" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_json_result_callback_with_json_error(
      "add_or_fail_json",
      fn(payload) {
        if payload == "[20,22]" {
          Ok("{\"answer\":42}")
        } else {
          Err("{\"code\":\"blocked\",\"payload\":[1]}")
        }
      },
    )
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let ok_promise = runtime.eval_promise_string(
      "MoonBit.opAsync('add_or_fail_json', [20, 22])",
    )
    guard ok_promise is Ok(_) else { return Err(ok_promise.unwrap_err()) }
    let bad_promise = runtime.eval_promise_string(
      "MoonBit.opAsync('add_or_fail_json', [1]).catch((err) => ({ code: err.code, payload: err.payload[0] }))",
    )
    guard bad_promise is Ok(_) else { return Err(bad_promise.unwrap_err()) }
    let first = runtime.take_async_json_op()
    guard first is Ok(_) else { return Err(first.unwrap_err()) }
    let second = runtime.take_async_json_op()
    guard second is Ok(_) else { return Err(second.unwrap_err()) }
    let ok_value = ok_promise.unwrap().await_json()
    guard ok_value is Ok(_) else { return Err(ok_value.unwrap_err()) }
    let bad_value = bad_promise.unwrap().await_json()
    guard bad_value is Ok(_) else { return Err(bad_value.unwrap_err()) }
    Ok(
      match (first.unwrap(), second.unwrap()) {
        (None, None) => ok_value.unwrap() + ":" + bad_value.unwrap()
        _ => "queued"
      },
    )
  })
  inspect(
    result,
    content="Ok(\"{\\\"answer\\\":42}:{\\\"code\\\":\\\"blocked\\\",\\\"payload\\\":1}\")",
  )
}

///|
test "unknown async json op rejects without queueing" {
  let result = with_runtime(fn(runtime) {
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsync('missing', { answer: 1 })",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let op = runtime.take_async_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let queued = match op.unwrap() {
      None => "none"
      Some(request) => request.name
    }
    Ok(queued + ":" + is_err(promise.unwrap().await_json()).to_string())
  })
  inspect(result, content="Ok(\"none:true\")")
}

///|
test "runtime async bytes op queue is empty by default" {
  let result = with_runtime(fn(runtime) {
    let op = runtime.take_async_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    match op.unwrap() {
      None => Ok(true)
      Some(_) => Ok(false)
    }
  })
  inspect(result, content="Ok(true)")
}

///|
test "runtime can resolve async bytes op from host" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_bytes_op("reverse")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsyncBytes('reverse', new Uint8Array([65, 66, 67]))",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let op = runtime.take_async_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    let resolved = runtime.resolve_async_bytes_op(op.id, @utf8.encode("CBA"))
    guard resolved is Ok(_) else { return Err(resolved.unwrap_err()) }
    let value = promise.unwrap().await_bytes()
    guard value is Ok(_) else { return Err(value.unwrap_err()) }
    Ok(
      op.name +
      ":" +
      @utf8.decode_lossy(op.payload) +
      ":" +
      @utf8.decode_lossy(value.unwrap()),
    )
  })
  inspect(result, content="Ok(\"reverse:ABC:CBA\")")
}

///|
test "runtime can reject async bytes op from host" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_bytes_op("fail_bytes")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsyncBytes('fail_bytes', new Uint8Array([65, 66]))",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let op = runtime.take_async_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    let rejected = runtime.reject_async_bytes_op(op.id, "boom")
    guard rejected is Ok(_) else { return Err(rejected.unwrap_err()) }
    Ok(
      op.name +
      ":" +
      @utf8.decode_lossy(op.payload) +
      ":" +
      is_err(promise.unwrap().await_bytes()).to_string(),
    )
  })
  inspect(result, content="Ok(\"fail_bytes:AB:true\")")
}

///|
test "runtime can reject async bytes op from host with json reason" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_bytes_op("fail_bytes_json")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsyncBytes('fail_bytes_json', new Uint8Array([65, 66])).catch((err) => ({ code: err.code, detail: err.detail }))",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let op = runtime.take_async_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    let rejected = runtime.reject_async_bytes_op_with_json(
      op.id,
      "{\"code\":\"blocked\",\"detail\":\"AB\"}",
    )
    guard rejected is Ok(_) else { return Err(rejected.unwrap_err()) }
    let reason = promise.unwrap().await_json()
    guard reason is Ok(_) else { return Err(reason.unwrap_err()) }
    Ok(op.name + ":" + @utf8.decode_lossy(op.payload) + ":" + reason.unwrap())
  })
  inspect(
    result,
    content="Ok(\"fail_bytes_json:AB:{\\\"code\\\":\\\"blocked\\\",\\\"detail\\\":\\\"AB\\\"}\")",
  )
}

///|
test "runtime can resolve async bytes op from callback" {
  let result = with_runtime(fn(runtime) {
    let suffix = @utf8.encode("!")
    let registered = runtime.register_async_bytes_callback("decorate", fn(
      payload,
    ) {
      @utf8.encode(@utf8.decode_lossy(payload) + @utf8.decode_lossy(suffix))
    })
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsyncBytes('decorate', new Uint8Array([65, 66]))",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let op = runtime.take_async_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let queued = match op.unwrap() {
      None => "none"
      Some(request) => request.name
    }
    let value = promise.unwrap().await_bytes()
    guard value is Ok(_) else { return Err(value.unwrap_err()) }
    Ok(queued + ":" + @utf8.decode_lossy(value.unwrap()))
  })
  inspect(result, content="Ok(\"none:AB!\")")
}

///|
test "runtime can resolve and reject async bytes op from result callback" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_bytes_result_callback(
      "decorate_or_fail",
      fn(payload) {
        if @utf8.decode_lossy(payload) == "AB" {
          Ok(@utf8.encode("AB!"))
        } else {
          Err("blocked")
        }
      },
    )
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let ok_promise = runtime.eval_promise_string(
      "MoonBit.opAsyncBytes('decorate_or_fail', new Uint8Array([65, 66]))",
    )
    guard ok_promise is Ok(_) else { return Err(ok_promise.unwrap_err()) }
    let bad_promise = runtime.eval_promise_string(
      "MoonBit.opAsyncBytes('decorate_or_fail', new Uint8Array([90]))",
    )
    guard bad_promise is Ok(_) else { return Err(bad_promise.unwrap_err()) }
    let first = runtime.take_async_bytes_op()
    guard first is Ok(_) else { return Err(first.unwrap_err()) }
    let second = runtime.take_async_bytes_op()
    guard second is Ok(_) else { return Err(second.unwrap_err()) }
    let ok_value = ok_promise.unwrap().await_bytes()
    guard ok_value is Ok(_) else { return Err(ok_value.unwrap_err()) }
    Ok(
      match (first.unwrap(), second.unwrap()) {
        (None, None) =>
          @utf8.decode_lossy(ok_value.unwrap()) +
          ":" +
          is_err(bad_promise.unwrap().await_bytes()).to_string()
        _ => "queued"
      },
    )
  })
  inspect(result, content="Ok(\"AB!:true\")")
}

///|
test "runtime can resolve and reject async bytes op from result callback with json reason" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_bytes_result_callback_with_json_error(
      "decorate_or_fail_json",
      fn(payload) {
        if @utf8.decode_lossy(payload) == "AB" {
          Ok(@utf8.encode("AB!"))
        } else {
          Err("{\"code\":\"blocked\",\"detail\":\"Z\"}")
        }
      },
    )
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let ok_promise = runtime.eval_promise_string(
      "MoonBit.opAsyncBytes('decorate_or_fail_json', new Uint8Array([65, 66]))",
    )
    guard ok_promise is Ok(_) else { return Err(ok_promise.unwrap_err()) }
    let bad_promise = runtime.eval_promise_string(
      "MoonBit.opAsyncBytes('decorate_or_fail_json', new Uint8Array([90])).catch((err) => ({ code: err.code, detail: err.detail }))",
    )
    guard bad_promise is Ok(_) else { return Err(bad_promise.unwrap_err()) }
    let first = runtime.take_async_bytes_op()
    guard first is Ok(_) else { return Err(first.unwrap_err()) }
    let second = runtime.take_async_bytes_op()
    guard second is Ok(_) else { return Err(second.unwrap_err()) }
    let ok_value = ok_promise.unwrap().await_bytes()
    guard ok_value is Ok(_) else { return Err(ok_value.unwrap_err()) }
    let bad_value = bad_promise.unwrap().await_json()
    guard bad_value is Ok(_) else { return Err(bad_value.unwrap_err()) }
    Ok(
      match (first.unwrap(), second.unwrap()) {
        (None, None) =>
          @utf8.decode_lossy(ok_value.unwrap()) + ":" + bad_value.unwrap()
        _ => "queued"
      },
    )
  })
  inspect(
    result,
    content="Ok(\"AB!:{\\\"code\\\":\\\"blocked\\\",\\\"detail\\\":\\\"Z\\\"}\")",
  )
}

///|
test "unknown async bytes op rejects without queueing" {
  let result = with_runtime(fn(runtime) {
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsyncBytes('missing_bytes', new Uint8Array([65]))",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let op = runtime.take_async_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let queued = match op.unwrap() {
      None => "none"
      Some(request) => request.name
    }
    Ok(queued + ":" + is_err(promise.unwrap().await_bytes()).to_string())
  })
  inspect(result, content="Ok(\"none:true\")")
}

///|
test "runtime sync json op queue is empty by default" {
  let result = with_runtime(fn(runtime) {
    let op = runtime.take_sync_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    match op.unwrap() {
      None => Ok(true)
      Some(_) => Ok(false)
    }
  })
  inspect(result, content="Ok(true)")
}

///|
test "runtime can resolve sync json op from preloaded response" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_sync_json_op("add")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let prepared = runtime.push_sync_json_op_response(
      "add", "[20,22]", "{\"answer\":42}",
    )
    guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
    let value = runtime.eval_json("MoonBit.opSync('add', [20, 22])")
    guard value is Ok(_) else { return Err(value.unwrap_err()) }
    let op = runtime.take_sync_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    Ok(value.unwrap() + ":" + op.name + ":" + op.payload_json)
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}:add:[20,22]\")")
}

///|
test "runtime can resolve sync json op from callback" {
  let result = with_runtime(fn(runtime) {
    let base = 40
    let registered = runtime.register_sync_json_callback("add", fn(payload) {
      if payload == "[20,22]" {
        "{\"answer\":" + (base + 2).to_string() + "}"
      } else {
        "{\"answer\":0}"
      }
    })
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let value = runtime.eval_json("MoonBit.opSync('add', [20, 22])")
    guard value is Ok(_) else { return Err(value.unwrap_err()) }
    let op = runtime.take_sync_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    Ok(value.unwrap() + ":" + op.name + ":" + op.payload_json)
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}:add:[20,22]\")")
}

///|
test "runtime can resolve and throw sync json op from result callback" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_sync_json_result_callback("add_or_fail", fn(
      payload,
    ) {
      if payload == "[20,22]" {
        Ok("{\"answer\":42}")
      } else {
        Err("blocked")
      }
    })
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let ok_value = runtime.eval_json("MoonBit.opSync('add_or_fail', [20, 22])")
    guard ok_value is Ok(_) else { return Err(ok_value.unwrap_err()) }
    let bad_value = runtime.eval_json("MoonBit.opSync('add_or_fail', [1])")
    let first = runtime.take_sync_json_op()
    guard first is Ok(_) else { return Err(first.unwrap_err()) }
    let second = runtime.take_sync_json_op()
    guard second is Ok(_) else { return Err(second.unwrap_err()) }
    Ok(
      match (first.unwrap(), second.unwrap()) {
        (Some(first), Some(second)) =>
          ok_value.unwrap() +
          ":" +
          first.name +
          ":" +
          second.payload_json +
          ":" +
          is_err(bad_value).to_string()
        _ => "missing"
      },
    )
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}:add_or_fail:[1]:true\")")
}

///|
test "runtime can resolve and throw structured json error from sync json result callback" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_sync_json_result_callback_with_json_error(
      "add_or_fail_json",
      fn(payload) {
        if payload == "[20,22]" {
          Ok("{\"answer\":42}")
        } else {
          Err("{\"code\":\"blocked\",\"payload\":[1]}")
        }
      },
    )
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let ok_value = runtime.eval_json(
      "MoonBit.opSync('add_or_fail_json', [20, 22])",
    )
    guard ok_value is Ok(_) else { return Err(ok_value.unwrap_err()) }
    let thrown = runtime.eval_json(
      "(() => { try { MoonBit.opSync('add_or_fail_json', [1]) } catch (err) { return { code: err.code, payload: err.payload[0] } } })()",
    )
    guard thrown is Ok(_) else { return Err(thrown.unwrap_err()) }
    Ok(ok_value.unwrap() + ":" + thrown.unwrap())
  })
  inspect(
    result,
    content="Ok(\"{\\\"answer\\\":42}:{\\\"code\\\":\\\"blocked\\\",\\\"payload\\\":1}\")",
  )
}

///|
test "unknown sync json op throws without queueing" {
  let result = with_runtime(fn(runtime) {
    let value = runtime.eval_json("MoonBit.opSync('missing', { answer: 1 })")
    let op = runtime.take_sync_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let queued = match op.unwrap() {
      None => "none"
      Some(request) => request.name
    }
    Ok(queued + ":" + is_err(value).to_string())
  })
  inspect(result, content="Ok(\"none:true\")")
}

///|
test "missing sync json response still records request" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_sync_json_op("missing_response")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let value = runtime.eval_json(
      "MoonBit.opSync('missing_response', { answer: 1 })",
    )
    let op = runtime.take_sync_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    Ok(op.name + ":" + op.payload_json + ":" + is_err(value).to_string())
  })
  inspect(result, content="Ok(\"missing_response:{\\\"answer\\\":1}:true\")")
}

///|
test "runtime sync bytes op queue is empty by default" {
  let result = with_runtime(fn(runtime) {
    let op = runtime.take_sync_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    match op.unwrap() {
      None => Ok(true)
      Some(_) => Ok(false)
    }
  })
  inspect(result, content="Ok(true)")
}

///|
test "runtime can resolve sync bytes op from preloaded response" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_sync_bytes_op("reverse")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let prepared = runtime.push_sync_bytes_op_response(
      "reverse",
      @utf8.encode("ABC"),
      @utf8.encode("CBA"),
    )
    guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
    let value = runtime.eval_bytes(
      "MoonBit.opSyncBytes('reverse', new Uint8Array([65, 66, 67]))",
    )
    guard value is Ok(_) else { return Err(value.unwrap_err()) }
    let op = runtime.take_sync_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    Ok(
      @utf8.decode_lossy(value.unwrap()) +
      ":" +
      op.name +
      ":" +
      @utf8.decode_lossy(op.payload),
    )
  })
  inspect(result, content="Ok(\"CBA:reverse:ABC\")")
}

///|
test "runtime can resolve sync bytes op from callback" {
  let result = with_runtime(fn(runtime) {
    let suffix = @utf8.encode("!")
    let registered = runtime.register_sync_bytes_callback("decorate", fn(
      payload,
    ) {
      @utf8.encode(@utf8.decode_lossy(payload) + @utf8.decode_lossy(suffix))
    })
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let value = runtime.eval_bytes(
      "MoonBit.opSyncBytes('decorate', new Uint8Array([65, 66]))",
    )
    guard value is Ok(_) else { return Err(value.unwrap_err()) }
    let op = runtime.take_sync_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    Ok(
      @utf8.decode_lossy(value.unwrap()) +
      ":" +
      op.name +
      ":" +
      @utf8.decode_lossy(op.payload),
    )
  })
  inspect(result, content="Ok(\"AB!:decorate:AB\")")
}

///|
test "runtime can resolve and throw sync bytes op from result callback" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_sync_bytes_result_callback(
      "decorate_or_fail",
      fn(payload) {
        if @utf8.decode_lossy(payload) == "AB" {
          Ok(@utf8.encode("AB!"))
        } else {
          Err("blocked")
        }
      },
    )
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let ok_value = runtime.eval_bytes(
      "MoonBit.opSyncBytes('decorate_or_fail', new Uint8Array([65, 66]))",
    )
    guard ok_value is Ok(_) else { return Err(ok_value.unwrap_err()) }
    let bad_value = runtime.eval_bytes(
      "MoonBit.opSyncBytes('decorate_or_fail', new Uint8Array([90]))",
    )
    let first = runtime.take_sync_bytes_op()
    guard first is Ok(_) else { return Err(first.unwrap_err()) }
    let second = runtime.take_sync_bytes_op()
    guard second is Ok(_) else { return Err(second.unwrap_err()) }
    Ok(
      match (first.unwrap(), second.unwrap()) {
        (Some(first), Some(second)) =>
          @utf8.decode_lossy(ok_value.unwrap()) +
          ":" +
          first.name +
          ":" +
          @utf8.decode_lossy(second.payload) +
          ":" +
          is_err(bad_value).to_string()
        _ => "missing"
      },
    )
  })
  inspect(result, content="Ok(\"AB!:decorate_or_fail:Z:true\")")
}

///|
test "runtime can resolve and throw structured json error from sync bytes result callback" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_sync_bytes_result_callback_with_json_error(
      "decorate_or_fail_json",
      fn(payload) {
        if @utf8.decode_lossy(payload) == "AB" {
          Ok(@utf8.encode("AB!"))
        } else {
          Err("{\"code\":\"blocked\",\"detail\":\"Z\"}")
        }
      },
    )
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let ok_value = runtime.eval_bytes(
      "MoonBit.opSyncBytes('decorate_or_fail_json', new Uint8Array([65, 66]))",
    )
    guard ok_value is Ok(_) else { return Err(ok_value.unwrap_err()) }
    let thrown = runtime.eval_json(
      "(() => { try { MoonBit.opSyncBytes('decorate_or_fail_json', new Uint8Array([90])) } catch (err) { return { code: err.code, detail: err.detail } } })()",
    )
    guard thrown is Ok(_) else { return Err(thrown.unwrap_err()) }
    Ok(@utf8.decode_lossy(ok_value.unwrap()) + ":" + thrown.unwrap())
  })
  inspect(
    result,
    content="Ok(\"AB!:{\\\"code\\\":\\\"blocked\\\",\\\"detail\\\":\\\"Z\\\"}\")",
  )
}

///|
test "unknown sync bytes op throws without queueing" {
  let result = with_runtime(fn(runtime) {
    let value = runtime.eval_bytes(
      "MoonBit.opSyncBytes('missing_bytes', new Uint8Array([65]))",
    )
    let op = runtime.take_sync_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let queued = match op.unwrap() {
      None => "none"
      Some(request) => request.name
    }
    Ok(queued + ":" + is_err(value).to_string())
  })
  inspect(result, content="Ok(\"none:true\")")
}

///|
test "missing sync bytes response still records request" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_sync_bytes_op("missing_bytes_response")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let value = runtime.eval_bytes(
      "MoonBit.opSyncBytes('missing_bytes_response', new Uint8Array([65, 66]))",
    )
    let op = runtime.take_sync_bytes_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    Ok(
      op.name +
      ":" +
      @utf8.decode_lossy(op.payload) +
      ":" +
      is_err(value).to_string(),
    )
  })
  inspect(result, content="Ok(\"missing_bytes_response:AB:true\")")
}

///|
test "runtime can eval json result" {
  let result = with_runtime(fn(runtime) {
    runtime.eval_json("({ answer: 42, ok: true })")
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42,\\\"ok\\\":true}\")")
}

///|
test "runtime can eval async json result" {
  let result = with_runtime(fn(runtime) {
    runtime.eval_async_json("(async () => ({ answer: 42, ok: true }))()")
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42,\\\"ok\\\":true}\")")
}

///|
test "runtime can eval bytes result" {
  let result = with_runtime(fn(runtime) {
    let bytes = runtime.eval_bytes("new Uint8Array([65, 66, 67])")
    guard bytes is Ok(_) else { return Err(bytes.unwrap_err()) }
    Ok(@utf8.decode_lossy(bytes.unwrap()))
  })
  inspect(result, content="Ok(\"ABC\")")
}

///|
test "runtime can eval async bytes result" {
  let result = with_runtime(fn(runtime) {
    let bytes = runtime.eval_async_bytes(
      "(async () => new Uint8Array([65, 66, 67]).buffer)()",
    )
    guard bytes is Ok(_) else { return Err(bytes.unwrap_err()) }
    Ok(@utf8.decode_lossy(bytes.unwrap()))
  })
  inspect(result, content="Ok(\"ABC\")")
}

///|
test "runtime can eval named async json with relative dynamic import" {
  let result = with_runtime(fn(runtime) {
    let dep = runtime.load_module(
      "file:///feature/dep.mjs", "export const answer = 42;",
    )
    guard dep is Ok(_) else { return Err(dep.unwrap_err()) }
    runtime.eval_async_json_with_name(
      "file:///feature/bootstrap.js", "(async () => { let mod = await import('./dep.mjs'); return { answer: mod.answer } })()",
    )
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}\")")
}

///|
test "runtime builder combines snapshot and modules" {
  let result = match snapshot_create("globalThis.base = 40;") {
    Ok(snapshot) => {
      let builder = runtime_builder_new()
        .with_snapshot(snapshot)
        .load_module("dep", "export const answer = globalThis.base + 2;")
      builder.with_runtime(fn(runtime) {
        let evaluated = runtime.eval_module_string(
          "import { answer } from 'dep'; globalThis.__builder_answer = answer",
        )
        guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
        runtime.eval_string("globalThis.__builder_answer")
      })
    }
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"42\")")
}

///|
test "runtime builder evaluates snapshot init before loading modules" {
  let result = runtime_builder_new()
    .eval_snapshot("globalThis.base = 40;")
    .load_module("dep", "export const answer = globalThis.base + 2;")
    .with_runtime(fn(runtime) {
      let evaluated = runtime.eval_module_string(
        "import { answer } from 'dep'; globalThis.__builder_snapshot_answer = answer",
      )
      guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
      runtime.eval_string("globalThis.__builder_snapshot_answer")
    })
  inspect(result, content="Ok(\"42\")")
}

///|
test "runtime builder consumes snapshot builder state" {
  let snapshot_builder = snapshot_builder_new()
    .eval("globalThis.base = 40;")
    .eval("globalThis.bump = 1;")
  let result = runtime_builder_new()
    .with_snapshot_builder(snapshot_builder)
    .load_module(
      "dep", "export const answer = globalThis.base + globalThis.bump + 1;",
    )
    .with_runtime(fn(runtime) {
      let evaluated = runtime.eval_module_string(
        "import { answer } from 'dep'; globalThis.__builder_snapshot_builder_answer = answer",
      )
      guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
      runtime.eval_string("globalThis.__builder_snapshot_builder_answer")
    })
  inspect(result, content="Ok(\"42\")")
}

///|
test "runtime builder can preload deno core compat" {
  let result = runtime_builder_new()
    .with_deno_core_compat()
    .with_runtime(fn(runtime) {
      let registered = runtime.register_sync_json_result_callback("add", fn(
        payload,
      ) {
        if payload == "[20,22]" {
          Ok("{\"answer\":42}")
        } else {
          Err("blocked")
        }
      })
      guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
      runtime.eval_json("Deno.core.opSync(Deno.core.ops.add, [20, 22])")
    })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}\")")
}

///|
test "runtime builder can preload node compat" {
  let result = runtime_builder_new()
    .with_node_compat()
    .with_runtime(fn(runtime) {
      runtime.eval_json(
        "({ sameGlobal: global === globalThis, versionOk: typeof process.version === 'string', text: Buffer.from('AB').toString() })",
      )
    })
  inspect(
    result,
    content="Ok(\"{\\\"sameGlobal\\\":true,\\\"versionOk\\\":true,\\\"text\\\":\\\"AB\\\"}\")",
  )
}

///|
test "runtime builder builds reusable runtime image" {
  let result = match
    runtime_builder_new()
    .eval_snapshot("globalThis.base = 40;")
    .load_module("dep", "export const answer = globalThis.base + 2;")
    .build_image() {
    Ok(image) => {
      let first = image.with_runtime(fn(runtime) {
        let evaluated = runtime.eval_module_string(
          "import { answer } from 'dep'; globalThis.__image_answer = answer",
        )
        guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
        runtime.eval_string("globalThis.__image_answer")
      })
      guard first is Ok(_) else { Err(first.unwrap_err()) }
      let second = image.with_runtime(fn(runtime) {
        runtime.eval_string("globalThis.base + 2")
      })
      guard second is Ok(_) else { Err(second.unwrap_err()) }
      Ok(first.unwrap() + ":" + second.unwrap())
    }
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"42:42\")")
}

///|
test "snapshot builder builds runtime image that can preload modules later" {
  let result = match
    snapshot_builder_new().eval("globalThis.base = 40;").build_image() {
    Ok(image) => {
      let image = image.load_module(
        "dep", "export const answer = globalThis.base + 2;",
      )
      image.with_runtime(fn(runtime) {
        let evaluated = runtime.eval_module_string(
          "import { answer } from 'dep'; globalThis.__snapshot_image_answer = answer",
        )
        guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
        runtime.eval_string("globalThis.__snapshot_image_answer")
      })
    }
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"42\")")
}

///|
test "snapshot builder combines multiple init scripts" {
  let result = snapshot_builder_new()
    .eval("globalThis.base = 40;")
    .eval("globalThis.answer = globalThis.base + 2;")
    .with_runtime(fn(runtime) { runtime.eval_string("globalThis.answer") })
  inspect(result, content="Ok(\"42\")")
}

///|
test "snapshot builder can preload deno core compat" {
  let result = snapshot_builder_new()
    .with_deno_core_compat()
    .with_runtime(fn(runtime) {
      let registered = runtime.register_async_json_result_callback("add", fn(
        payload,
      ) {
        if payload == "[20,22]" {
          Ok("{\"answer\":42}")
        } else {
          Err("blocked")
        }
      })
      guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
      runtime.eval_async_json("Deno.core.opAsync(Deno.core.ops.add, [20, 22])")
    })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}\")")
}

///|
async test "runtime builder deno compat can await deno sleep" {
  let result = match runtime_builder_new().with_deno_core_compat().build() {
    Ok(runtime) => {
      defer runtime.dispose()
      runtime.eval_promise_json_async(
        "(async () => { await Deno.sleep(1); return { ok: true }; })()",
      )
    }
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"{\\\"ok\\\":true}\")")
}

///|
async test "snapshot builder deno compat can run timeout callback" {
  let result = match
    snapshot_builder_new().with_deno_core_compat().build_runtime() {
    Ok(runtime) => {
      defer runtime.dispose()
      runtime.eval_promise_json_async(
        "(async () => { let values = ['start']; setTimeout((label) => { values.push(label); }, 0, 'timer'); values.push('queued'); await Deno.sleep(5); values.push('after'); return { values }; })()",
      )
    }
    Err(err) => Err(err)
  }
  inspect(
    result,
    content="Ok(\"{\\\"values\\\":[\\\"start\\\",\\\"queued\\\",\\\"timer\\\",\\\"after\\\"]}\")",
  )
}

///|
test "snapshot builder can preload node compat" {
  let result = snapshot_builder_new()
    .with_node_compat()
    .with_runtime(fn(runtime) {
      runtime.eval_async_json(
        "(async () => { let value = Buffer.alloc(2); value[0] = 65; value[1] = 66; await new Promise((resolve) => process.nextTick(resolve)); return { text: value.toString() }; })()",
      )
    })
  inspect(result, content="Ok(\"{\\\"text\\\":\\\"AB\\\"}\")")
}

///|
test "snapshot builder extends existing snapshot" {
  let result = match snapshot_create("globalThis.base = 40;") {
    Ok(snapshot) => {
      let builder = snapshot_builder_new()
        .with_snapshot(snapshot)
        .eval("globalThis.answer = globalThis.base + 2;")
      builder.with_runtime(fn(runtime) {
        runtime.eval_string("globalThis.answer")
      })
    }
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"42\")")
}

///|
test "eval string concatenation" {
  inspect(
    eval_string("'Hello' + ', MoonBit!'"),
    content="Ok(\"Hello, MoonBit!\")",
  )
}

///|
test "eval arithmetic" {
  inspect(eval_string("1 + 2"), content="Ok(\"3\")")
}

///|
test "syntax error surfaces as err" {
  inspect(is_err(eval_string("let = ;")), content="true")
}

///|
test "eval async string resolves promise" {
  inspect(
    eval_async_string(
      "(async () => { return (await Promise.resolve(39)) + 3 })()",
    ),
    content="Ok(\"42\")",
  )
}

///|
test "named async script resolves relative dynamic import" {
  let result = with_runtime(fn(runtime) {
    let dep = runtime.load_module(
      "file:///feature/dep.mjs", "export const answer = 42;",
    )
    guard dep is Ok(_) else { return Err(dep.unwrap_err()) }
    runtime.eval_async_string_with_name(
      "file:///feature/bootstrap.js", "(async () => { let mod = await import('./dep.mjs'); return mod.answer })()",
    )
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "rejected promise surfaces as err" {
  inspect(
    is_err(eval_async_string("Promise.reject(new Error('boom'))")),
    content="true",
  )
}

///|
test "dynamic import resolves preloaded module in async script" {
  let result = with_runtime(fn(runtime) {
    let loaded = runtime.load_module("dep", "export const answer = 41;")
    guard loaded is Ok(_) else { return Err(loaded.unwrap_err()) }
    runtime.eval_async_string(
      "(async () => { let mod = await import('dep'); return mod.answer + 1 })()",
    )
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "microtask checkpoint drains scheduled jobs" {
  let result = with_runtime(fn(runtime) {
    let scheduled = runtime.eval_string(
      "globalThis.__x = 0; Promise.resolve().then(() => { globalThis.__x = 42 }); 'scheduled'",
    )
    guard scheduled is Ok(_) else { return Err(scheduled.unwrap_err()) }
    let flushed = runtime.perform_microtask_checkpoint()
    guard flushed is Ok(_) else { return Err(flushed.unwrap_err()) }
    runtime.eval_string("globalThis.__x")
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "runtime can observe pending promise state and result" {
  let result = with_runtime(fn(runtime) {
    let prepared = runtime.eval_string(
      "globalThis.__resolve_later = null; globalThis.__tracked_promise = new Promise((resolve) => { globalThis.__resolve_later = resolve })",
    )
    guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
    let promise = runtime.eval_promise_string("globalThis.__tracked_promise")
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let promise = promise.unwrap()
    let initial_state = promise.state()
    guard initial_state is Ok(_) else { return Err(initial_state.unwrap_err()) }
    let resolved = runtime.eval_string("globalThis.__resolve_later(42); 'ok'")
    guard resolved is Ok(_) else { return Err(resolved.unwrap_err()) }
    let flushed = runtime.perform_microtask_checkpoint()
    guard flushed is Ok(_) else { return Err(flushed.unwrap_err()) }
    let settled_state = promise.state()
    guard settled_state is Ok(_) else { return Err(settled_state.unwrap_err()) }
    let settled_value = promise.result_string()
    guard settled_value is Ok(_) else { return Err(settled_value.unwrap_err()) }
    Ok(
      promise_state_name(initial_state.unwrap()) +
      ":" +
      promise_state_name(settled_state.unwrap()) +
      ":" +
      settled_value.unwrap(),
    )
  })
  inspect(result, content="Ok(\"Pending:Fulfilled:42\")")
}

///|
test "runtime can observe named promise script with relative dynamic import" {
  let result = with_runtime(fn(runtime) {
    let loaded = runtime.load_module(
      "file:///feature/dep.mjs", "export const answer = 42;",
    )
    guard loaded is Ok(_) else { return Err(loaded.unwrap_err()) }
    let promise = runtime.eval_promise_string_with_name(
      "file:///feature/bootstrap.js", "(async () => { let mod = await import('./dep.mjs'); return mod.answer })()",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let promise = promise.unwrap()
    let flushed = runtime.perform_microtask_checkpoint()
    guard flushed is Ok(_) else { return Err(flushed.unwrap_err()) }
    promise.result_string()
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "disposing promise handle surfaces as err" {
  let result = with_runtime(fn(runtime) {
    let promise = runtime.eval_promise_string("Promise.resolve(42)")
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let promise = promise.unwrap()
    promise.dispose()
    Ok(is_err(promise.state()))
  })
  inspect(result, content="Ok(true)")
}

///|
test "promise handle can read fulfilled json result" {
  let result = with_runtime(fn(runtime) {
    let promise = runtime.eval_promise_string(
      "(async () => ({ answer: 42, ok: true }))()",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let promise = promise.unwrap()
    let flushed = runtime.perform_microtask_checkpoint()
    guard flushed is Ok(_) else { return Err(flushed.unwrap_err()) }
    promise.result_json()
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42,\\\"ok\\\":true}\")")
}

///|
test "promise handle can read fulfilled bytes result" {
  let result = with_runtime(fn(runtime) {
    let promise = runtime.eval_promise_string(
      "(async () => new Uint8Array([65, 66, 67]).buffer)()",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let promise = promise.unwrap()
    let flushed = runtime.perform_microtask_checkpoint()
    guard flushed is Ok(_) else { return Err(flushed.unwrap_err()) }
    let bytes = promise.result_bytes()
    guard bytes is Ok(_) else { return Err(bytes.unwrap_err()) }
    Ok(@utf8.decode_lossy(bytes.unwrap()))
  })
  inspect(result, content="Ok(\"ABC\")")
}

///|
test "promise handle can await json result" {
  let result = with_runtime(fn(runtime) {
    let promise = runtime.eval_promise_string(
      "(async () => ({ answer: 42, ok: true }))()",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    promise.unwrap().await_json()
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42,\\\"ok\\\":true}\")")
}

///|
test "promise handle can await bytes result" {
  let result = with_runtime(fn(runtime) {
    let promise = runtime.eval_promise_string(
      "(async () => new Uint8Array([65, 66, 67]).buffer)()",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    let bytes = promise.unwrap().await_bytes()
    guard bytes is Ok(_) else { return Err(bytes.unwrap_err()) }
    Ok(@utf8.decode_lossy(bytes.unwrap()))
  })
  inspect(result, content="Ok(\"ABC\")")
}

///|
test "promise handle can await named promise script with relative dynamic import" {
  let result = with_runtime(fn(runtime) {
    let loaded = runtime.load_module(
      "file:///feature/dep.mjs", "export const answer = 42;",
    )
    guard loaded is Ok(_) else { return Err(loaded.unwrap_err()) }
    let promise = runtime.eval_promise_string_with_name(
      "file:///feature/bootstrap.js", "(async () => { let mod = await import('./dep.mjs'); return mod.answer })()",
    )
    guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
    promise.unwrap().await_string()
  })
  inspect(result, content="Ok(\"42\")")
}

///|
async test "promise handle can await json through moonbit async event loop with deno core ops" {
  let result = match runtime_new() {
    Ok(runtime) => {
      defer runtime.dispose()
      let installed = runtime.install_deno_core_compat()
      guard installed is Ok(_) else { Err(installed.unwrap_err()) }
      let registered = runtime.register_async_json_task_result_callback("add", payload => {
        @async.sleep(10)
        if payload == "{\"base\":40}" {
          Ok("{\"answer\":42}")
        } else {
          Err("blocked")
        }
      })
      guard registered is Ok(_) else { Err(registered.unwrap_err()) }
      let promise = runtime.eval_promise_string(
        "(async () => { const payload = await Deno.core.opAsync(Deno.core.ops.add, { base: 40 }); return payload.answer; })()",
      )
      guard promise is Ok(_) else { Err(promise.unwrap_err()) }
      promise.unwrap().await_json_async()
    }
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"42\")")
}

///|
async test "promise handle can await bytes through moonbit async event loop with deno core ops" {
  let result = match runtime_new() {
    Ok(runtime) => {
      defer runtime.dispose()
      let installed = runtime.install_deno_core_compat()
      guard installed is Ok(_) else { Err(installed.unwrap_err()) }
      let registered = runtime.register_async_bytes_task_result_callback(
        "decorate",
        payload => {
          @async.sleep(10)
          if @utf8.decode_lossy(payload) == "AB" {
            Ok(@utf8.encode("AB!"))
          } else {
            Err("blocked")
          }
        },
      )
      guard registered is Ok(_) else { Err(registered.unwrap_err()) }
      let promise = runtime.eval_promise_string(
        "(async () => { const bytes = await Deno.core.opAsyncBytes(Deno.core.opsBytes.decorate, new Uint8Array([65, 66])); return Deno.core.decode(bytes); })()",
      )
      guard promise is Ok(_) else { Err(promise.unwrap_err()) }
      promise.unwrap().await_json_async()
    }
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"\\\"AB!\\\"\")")
}

///|
async test "with_runtime_async can evaluate deno style promise json" {
  let result = with_runtime_async(runtime => {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { Err(installed.unwrap_err()) }
    let registered = runtime.register_async_json_task_result_callback("add", payload => {
      @async.sleep(10)
      if payload == "{\"base\":40}" {
        Ok("{\"answer\":42}")
      } else {
        Err("blocked")
      }
    })
    guard registered is Ok(_) else { Err(registered.unwrap_err()) }
    runtime.eval_promise_json_async(
      "(async () => { const payload = await Deno.core.opAsync(Deno.core.ops.add, { base: 40 }); return { answer: payload.answer }; })()",
    )
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}\")")
}

///|
async test "with_runtime_async can await deno sleep and timeout callback" {
  let result = with_runtime_async(runtime => {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { Err(installed.unwrap_err()) }
    runtime.eval_promise_json_async(
      "(async () => { let values = ['start']; setTimeout((label) => { values.push(label); }, 0, 'timer'); values.push('queued'); await Deno.sleep(5); values.push('after'); return { values, hasSleep: typeof Deno.sleep === 'function' }; })()",
    )
  })
  inspect(
    result,
    content="Ok(\"{\\\"values\\\":[\\\"start\\\",\\\"queued\\\",\\\"timer\\\",\\\"after\\\"],\\\"hasSleep\\\":true}\")",
  )
}

///|
async test "with_runtime_async can clear timeout in deno compat" {
  let result = with_runtime_async(runtime => {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { Err(installed.unwrap_err()) }
    runtime.eval_promise_json_async(
      "(async () => { let value = 'A'; const id = setTimeout(() => { value = 'B'; }, 0); clearTimeout(id); await Deno.sleep(5); return { value }; })()",
    )
  })
  inspect(result, content="Ok(\"{\\\"value\\\":\\\"A\\\"}\")")
}

///|
async test "runtime can run event loop until idle after sync script schedules timeout" {
  let result = with_runtime_async(runtime => {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { Err(installed.unwrap_err()) }
    let prepared = runtime.eval_string(
      "globalThis.__ticks = []; setTimeout((label) => { globalThis.__ticks.push(label); }, 0, 'tick')",
    )
    guard prepared is Ok(_) else { Err(prepared.unwrap_err()) }
    let drained = runtime.run_event_loop_until_idle_async()
    guard drained is Ok(_) else { Err(drained.unwrap_err()) }
    runtime.eval_json("({ ticks: globalThis.__ticks })")
  })
  inspect(result, content="Ok(\"{\\\"ticks\\\":[\\\"tick\\\"]}\")")
}

///|
async test "with_runtime_async deno sleep resource tracks ref and settles" {
  let result = match runtime_new() {
    Ok(runtime) => {
      defer runtime.dispose()
      let installed = runtime.install_deno_core_compat()
      guard installed is Ok(_) else { Err(installed.unwrap_err()) }
      let prepared = runtime.eval_promise_json_async(
        "(async () => { globalThis.__sleep_promise = Deno.sleep(20); Deno.core.unrefOpPromise(globalThis.__sleep_promise); return { resourceCount: Object.keys(Deno.core.resources()).length }; })()",
      )
      guard prepared is Ok(_) else { Err(prepared.unwrap_err()) }
      let after_unref = runtime.list_resources()
      guard after_unref is Ok(_) else { Err(after_unref.unwrap_err()) }
      let reffed = runtime.eval_promise_json_async(
        "(async () => { Deno.core.refOpPromise(globalThis.__sleep_promise); return { resourceCount: Object.keys(Deno.core.resources()).length }; })()",
      )
      guard reffed is Ok(_) else { Err(reffed.unwrap_err()) }
      let after_ref = runtime.list_resources()
      guard after_ref is Ok(_) else { Err(after_ref.unwrap_err()) }
      let settled = runtime.eval_promise_json_async(
        "(async () => { await globalThis.__sleep_promise; return { resourceCount: Object.keys(Deno.core.resources()).length }; })()",
      )
      guard settled is Ok(_) else { Err(settled.unwrap_err()) }
      Ok(
        prepared.unwrap() +
        ":" +
        after_unref.unwrap()[0].name +
        ":" +
        after_unref.unwrap()[0].is_ref.to_string() +
        ":" +
        reffed.unwrap() +
        ":" +
        after_ref.unwrap()[0].is_ref.to_string() +
        ":" +
        settled.unwrap(),
      )
    }
    Err(err) => Err(err)
  }
  inspect(
    result,
    content="Ok(\"{\\\"resourceCount\\\":1}:sleep:false:{\\\"resourceCount\\\":1}:true:{\\\"resourceCount\\\":0}\")",
  )
}

///|
async test "with_runtime_async deno close can cancel timeout resource" {
  let result = with_runtime_async(runtime => {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { Err(installed.unwrap_err()) }
    runtime.eval_promise_json_async(
      "(async () => { let value = 'A'; const rid = setTimeout(() => { value = 'B'; }, 20); const before = Deno.core.resources(); const closed = Deno.core.tryClose(rid); await Deno.sleep(30); return { value, closed, before, after: Deno.core.resources() }; })()",
    )
  })
  inspect(
    result,
    content="Ok(\"{\\\"value\\\":\\\"A\\\",\\\"closed\\\":true,\\\"before\\\":{\\\"1\\\":\\\"timeout\\\"},\\\"after\\\":{}}\")",
  )
}

///|
async test "with_runtime_async deno op promise ref and unref toggle resource state" {
  let result = match runtime_new() {
    Ok(runtime) => {
      defer runtime.dispose()
      let installed = runtime.install_deno_core_compat()
      guard installed is Ok(_) else { Err(installed.unwrap_err()) }
      let registered = runtime.register_async_json_task_result_callback("add", payload => {
        @async.sleep(20)
        if payload == "{\"base\":40}" {
          Ok("{\"answer\":42}")
        } else {
          Err("blocked")
        }
      })
      guard registered is Ok(_) else { Err(registered.unwrap_err()) }
      let prepared = runtime.eval_promise_json_async(
        "(async () => { globalThis.__op_promise = Deno.core.opAsync(Deno.core.ops.add, { base: 40 }); Deno.core.unrefOpPromise(globalThis.__op_promise); return { resourceCount: Object.keys(Deno.core.resources()).length }; })()",
      )
      guard prepared is Ok(_) else { Err(prepared.unwrap_err()) }
      let after_unref = runtime.list_resources()
      guard after_unref is Ok(_) else { Err(after_unref.unwrap_err()) }
      let settled = runtime.eval_promise_json_async(
        "(async () => { Deno.core.refOpPromise(globalThis.__op_promise); const payload = await globalThis.__op_promise; return { answer: payload.answer, resourceCount: Object.keys(Deno.core.resources()).length }; })()",
      )
      guard settled is Ok(_) else { Err(settled.unwrap_err()) }
      Ok(
        prepared.unwrap() +
        ":" +
        after_unref.unwrap()[0].name +
        ":" +
        after_unref.unwrap()[0].is_ref.to_string() +
        ":" +
        settled.unwrap(),
      )
    }
    Err(err) => Err(err)
  }
  inspect(
    result,
    content="Ok(\"{\\\"resourceCount\\\":1}:promise:false:{\\\"answer\\\":42,\\\"resourceCount\\\":0}\")",
  )
}

///|
async test "with_runtime_async can run and cancel interval in deno compat" {
  let result = with_runtime_async(runtime => {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { Err(installed.unwrap_err()) }
    runtime.eval_promise_json_async(
      "(async () => { let ticks = []; let id = 0; id = setInterval((label) => { ticks.push(label + ':' + ticks.length); if (ticks.length >= 3) clearInterval(id); }, 0, 'tick'); await Deno.sleep(8); return { ticks }; })()",
    )
  })
  inspect(
    result,
    content="Ok(\"{\\\"ticks\\\":[\\\"tick:0\\\",\\\"tick:1\\\",\\\"tick:2\\\"]}\")",
  )
}

///|
async test "with_runtime_async can cancel interval before first tick" {
  let result = with_runtime_async(runtime => {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { Err(installed.unwrap_err()) }
    runtime.eval_promise_json_async(
      "(async () => { let count = 0; const id = setInterval(() => { count += 1; }, 0); clearInterval(id); await Deno.sleep(5); return { count }; })()",
    )
  })
  inspect(result, content="Ok(\"{\\\"count\\\":0}\")")
}

///|
async test "runtime can eval named promise string async with relative dynamic import" {
  let result = with_runtime_async(runtime => {
    let loaded = runtime.load_module(
      "file:///feature/dep.mjs", "export const answer = 42;",
    )
    guard loaded is Ok(_) else { Err(loaded.unwrap_err()) }
    runtime.eval_promise_string_async_with_name(
      "file:///feature/bootstrap.js", "(async () => { let mod = await import('./dep.mjs'); return String(mod.answer); })()",
    )
  })
  inspect(result, content="Ok(\"42\")")
}

///|
async test "top level eval_promise_json_async can await plain promise" {
  let result = eval_promise_json_async(
    "(async () => ({ answer: 42, ok: true }))()",
  )
  inspect(result, content="Ok(\"{\\\"answer\\\":42,\\\"ok\\\":true}\")")
}

///|
test "module evaluation runs top-level code" {
  let result = with_runtime(fn(runtime) {
    let evaluated = runtime.eval_module_string(
      "globalThis.__module_value = 6 * 7; export default globalThis.__module_value",
    )
    guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
    runtime.eval_string("globalThis.__module_value")
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "runtime can inspect module json exports" {
  let result = with_runtime(fn(runtime) {
    let module_handle = runtime.eval_module_handle_string(
      "export const answer = 42; export const nested = { ok: true }",
    )
    guard module_handle is Ok(_) else { return Err(module_handle.unwrap_err()) }
    let module_handle = module_handle.unwrap()
    let answer = module_handle.get_export_json("answer")
    guard answer is Ok(_) else { return Err(answer.unwrap_err()) }
    let nested = module_handle.get_export_json("nested")
    guard nested is Ok(_) else { return Err(nested.unwrap_err()) }
    Ok(answer.unwrap() + ":" + nested.unwrap())
  })
  inspect(result, content="Ok(\"42:{\\\"ok\\\":true}\")")
}

///|
test "runtime can list module export names" {
  let result = with_runtime(fn(runtime) {
    let module_handle = runtime.eval_module_handle_string(
      "export const answer = 42; export const nested = { ok: true }",
    )
    guard module_handle is Ok(_) else { return Err(module_handle.unwrap_err()) }
    let names = module_handle.unwrap().export_names()
    guard names is Ok(_) else { return Err(names.unwrap_err()) }
    let names = names.unwrap()
    Ok(names.length() == 2 && names[0] == "answer" && names[1] == "nested")
  })
  inspect(result, content="Ok(true)")
}

///|
test "runtime can inspect named module exports with relative imports" {
  let result = with_runtime(fn(runtime) {
    let dep = runtime.load_module(
      "file:///feature/dep.mjs", "export const value = 42;",
    )
    guard dep is Ok(_) else { return Err(dep.unwrap_err()) }
    let module_handle = runtime.eval_module_handle_string_with_specifier(
      "file:///feature/main.mjs", "import { value } from './dep.mjs'; export const answer = value",
    )
    guard module_handle is Ok(_) else { return Err(module_handle.unwrap_err()) }
    module_handle.unwrap().get_export_json("answer")
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "disposing module handle surfaces as err" {
  let result = with_runtime(fn(runtime) {
    let module_handle = runtime.eval_module_handle_string(
      "export const answer = 42;",
    )
    guard module_handle is Ok(_) else { return Err(module_handle.unwrap_err()) }
    let module_handle = module_handle.unwrap()
    module_handle.dispose()
    Ok(is_err(module_handle.get_export_json("answer")))
  })
  inspect(result, content="Ok(true)")
}

///|
test "runtime can get module bytes export" {
  let result = with_runtime(fn(runtime) {
    let module_handle = runtime.eval_module_handle_string(
      "export const data = new Uint8Array([65, 66, 67])",
    )
    guard module_handle is Ok(_) else { return Err(module_handle.unwrap_err()) }
    let bytes = module_handle.unwrap().get_export_bytes("data")
    guard bytes is Ok(_) else { return Err(bytes.unwrap_err()) }
    Ok(@utf8.decode_lossy(bytes.unwrap()))
  })
  inspect(result, content="Ok(\"ABC\")")
}

///|
test "runtime can call module export function with json args" {
  let result = with_runtime(fn(runtime) {
    let module_handle = runtime.eval_module_handle_string(
      "export const add = (a, b) => ({ answer: a + b })",
    )
    guard module_handle is Ok(_) else { return Err(module_handle.unwrap_err()) }
    module_handle.unwrap().call_export_json("add", "[20,22]")
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}\")")
}

///|
test "runtime can call async module export function with json args" {
  let result = with_runtime(fn(runtime) {
    let module_handle = runtime.eval_module_handle_string(
      "export const load = async (base) => ({ answer: base + 2 })",
    )
    guard module_handle is Ok(_) else { return Err(module_handle.unwrap_err()) }
    module_handle.unwrap().call_export_json("load", "[40]")
  })
  inspect(result, content="Ok(\"{\\\"answer\\\":42}\")")
}

///|
test "runtime can call module export function with bytes arg" {
  let result = with_runtime(fn(runtime) {
    let module_handle = runtime.eval_module_handle_string(
      "export const reverse_buf = (buf) => new Uint8Array([buf[2], buf[1], buf[0]])",
    )
    guard module_handle is Ok(_) else { return Err(module_handle.unwrap_err()) }
    let called = module_handle
      .unwrap()
      .call_export_bytes("reverse_buf", @utf8.encode("ABC"))
    guard called is Ok(_) else { return Err(called.unwrap_err()) }
    Ok(@utf8.decode_lossy(called.unwrap()))
  })
  inspect(result, content="Ok(\"CBA\")")
}

///|
test "preloaded module imports are resolved" {
  let result = with_runtime(fn(runtime) {
    let loaded = runtime.load_module("dep", "export const answer = 41;")
    guard loaded is Ok(_) else { return Err(loaded.unwrap_err()) }
    let evaluated = runtime.eval_module_string(
      "import { answer } from 'dep'; globalThis.__preloaded_answer = answer + 1",
    )
    guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
    runtime.eval_string("globalThis.__preloaded_answer")
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "named module specifier resolves relative imports from nested base" {
  let result = with_runtime(fn(runtime) {
    let dep = runtime.load_module(
      "file:///feature/dep.mjs", "export const answer = 42;",
    )
    guard dep is Ok(_) else { return Err(dep.unwrap_err()) }
    let evaluated = runtime.eval_module_string_with_specifier(
      "file:///feature/main.mjs", "import { answer } from './dep.mjs'; globalThis.__named_module_answer = answer",
    )
    guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
    runtime.eval_string("globalThis.__named_module_answer")
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "relative module imports are resolved recursively" {
  let result = with_runtime(fn(runtime) {
    let nested = runtime.load_module(
      "file:///feature/constants.mjs", "export const base = 41;",
    )
    guard nested is Ok(_) else { return Err(nested.unwrap_err()) }
    let dep = runtime.load_module(
      "file:///feature/dep.mjs", "import { base } from './constants.mjs'; export const answer = base + 1;",
    )
    guard dep is Ok(_) else { return Err(dep.unwrap_err()) }
    let evaluated = runtime.eval_module_string(
      "import { answer } from './feature/dep.mjs'; globalThis.__relative_answer = answer",
    )
    guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
    runtime.eval_string("globalThis.__relative_answer")
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "dynamic import resolves relative module from module context" {
  let result = with_runtime(fn(runtime) {
    let dep = runtime.load_module(
      "file:///feature/dynamic.mjs", "export const answer = 42;",
    )
    guard dep is Ok(_) else { return Err(dep.unwrap_err()) }
    let evaluated = runtime.eval_module_string(
      "globalThis.__dynamic_relative = (await import('./feature/dynamic.mjs')).answer",
    )
    guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
    runtime.eval_string("globalThis.__dynamic_relative")
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "missing module imports surface as err" {
  inspect(
    is_err(eval_module_string("import 'dep'; export default 1")),
    content="true",
  )
}

///|
test "module evaluation resolves top-level await" {
  let result = with_runtime(fn(runtime) {
    let evaluated = runtime.eval_module_string(
      "globalThis.__module_async = 0; await Promise.resolve().then(() => { globalThis.__module_async = 42 })",
    )
    guard evaluated is Ok(_) else { return Err(evaluated.unwrap_err()) }
    runtime.eval_string("globalThis.__module_async")
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "runtime can await async module handle without top-level await" {
  let result = with_runtime(fn(runtime) {
    let module_eval = runtime.eval_module_handle_async_string(
      "export const answer = 42;",
    )
    guard module_eval is Ok(_) else { return Err(module_eval.unwrap_err()) }
    let module_handle = module_eval.unwrap().await_ready()
    guard module_handle is Ok(_) else { return Err(module_handle.unwrap_err()) }
    module_handle.unwrap().get_export_json("answer")
  })
  inspect(result, content="Ok(\"42\")")
}

///|
test "runtime can drive top-level await module through async json op" {
  let result = with_runtime(fn(runtime) {
    let registered = runtime.register_async_json_op("load_answer")
    guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
    let module_eval = runtime.eval_module_handle_async_string_with_specifier(
      "file:///feature/main.mjs", "const payload = await MoonBit.opAsync('load_answer', { base: 40 }); export const answer = payload.base + 2;",
    )
    guard module_eval is Ok(_) else { return Err(module_eval.unwrap_err()) }
    let module_eval = module_eval.unwrap()
    let promise = match module_eval.promise_handle() {
      Some(promise) => promise
      None => return Ok("missing")
    }
    let initial_state = promise.state()
    guard initial_state is Ok(_) else { return Err(initial_state.unwrap_err()) }
    let op = runtime.take_async_json_op()
    guard op is Ok(_) else { return Err(op.unwrap_err()) }
    let op = match op.unwrap() {
      Some(op) => op
      None => return Ok("missing")
    }
    let resolved = runtime.resolve_async_json_op(op.id, "{\"base\":40}")
    guard resolved is Ok(_) else { return Err(resolved.unwrap_err()) }
    let module_handle = module_eval.await_ready()
    guard module_handle is Ok(_) else { return Err(module_handle.unwrap_err()) }
    let answer = module_handle.unwrap().get_export_json("answer")
    guard answer is Ok(_) else { return Err(answer.unwrap_err()) }
    Ok(
      promise_state_name(initial_state.unwrap()) +
      ":" +
      op.name +
      ":" +
      op.payload_json +
      ":" +
      answer.unwrap(),
    )
  })
  inspect(result, content="Ok(\"Pending:load_answer:{\\\"base\\\":40}:42\")")
}

///|
async test "module eval handle can await ready through moonbit async event loop with deno core ops" {
  let result = match runtime_new() {
    Ok(runtime) => {
      defer runtime.dispose()
      let installed = runtime.install_deno_core_compat()
      guard installed is Ok(_) else { Err(installed.unwrap_err()) }
      let registered = runtime.register_async_json_task_result_callback(
        "load_answer",
        payload => {
          @async.sleep(10)
          if payload == "{\"base\":40}" {
            Ok("{\"base\":40}")
          } else {
            Err("blocked")
          }
        },
      )
      guard registered is Ok(_) else { Err(registered.unwrap_err()) }
      let module_eval = runtime.eval_module_handle_async_string_with_specifier(
        "file:///feature/main.mjs", "const payload = await Deno.core.opAsync(Deno.core.ops.load_answer, { base: 40 }); export const answer = payload.base + 2;",
      )
      guard module_eval is Ok(_) else { Err(module_eval.unwrap_err()) }
      let module_handle = module_eval.unwrap().await_ready_async()
      guard module_handle is Ok(_) else { Err(module_handle.unwrap_err()) }
      module_handle.unwrap().get_export_json("answer")
    }
    Err(err) => Err(err)
  }
  inspect(result, content="Ok(\"42\")")
}

///|
async test "runtime can eval module handle string async with specifier through deno core ops" {
  let result = with_runtime_async(runtime => {
    let installed = runtime.install_deno_core_compat()
    guard installed is Ok(_) else { Err(installed.unwrap_err()) }
    let registered = runtime.register_async_json_task_result_callback(
      "load_answer",
      payload => {
        @async.sleep(10)
        if payload == "{\"base\":40}" {
          Ok("{\"base\":40}")
        } else {
          Err("blocked")
        }
      },
    )
    guard registered is Ok(_) else { Err(registered.unwrap_err()) }
    let module_handle = runtime.eval_module_handle_string_async_with_specifier(
      "file:///feature/main.mjs", "const payload = await Deno.core.opAsync(Deno.core.ops.load_answer, { base: 40 }); export const answer = payload.base + 2;",
    )
    guard module_handle is Ok(_) else { Err(module_handle.unwrap_err()) }
    module_handle.unwrap().get_export_json("answer")
  })
  inspect(result, content="Ok(\"42\")")
}

///|
async test "runtime can eval module handle string async for plain top level await" {
  let result = with_runtime_async(runtime => {
    let module_handle = runtime.eval_module_handle_string_async(
      "export const answer = await Promise.resolve(42);",
    )
    guard module_handle is Ok(_) else { Err(module_handle.unwrap_err()) }
    module_handle.unwrap().get_export_json("answer")
  })
  inspect(result, content="Ok(\"42\")")
}
