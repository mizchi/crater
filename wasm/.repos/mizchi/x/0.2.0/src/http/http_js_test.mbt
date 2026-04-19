///|
async test "server: run_forever GET" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((req, _body, conn) => {
        let headers : Map[String, String] = { "X-Serve": "ok" }
        conn.send_response(200, "OK", extra_headers=headers)
        conn.write(req.meth.to_string() + " " + req.path)
        conn.end_response()
      })
    })
    @async.sleep(20)
    let (resp, body) = @http.get("http://127.0.0.1:\{port}/hello?name=moon")
    assert_eq(resp.code, 200)
    assert_eq(resp.headers.get("x-serve").unwrap_or(""), "ok")
    assert_eq(body.text(), "Get /hello?name=moon")
    server.close()
  })
}

///|
async test "server: run_forever POST body and headers" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((req, body, conn) => {
        let token = req.headers.get("x-token").unwrap_or("")
        let payload = body.read_all()
        conn.send_response(201, "Created")
        conn.write(payload.text() + "|" + token)
        conn.end_response()
      })
    })
    @async.sleep(20)
    let headers : Map[String, String] = { "X-Token": "abc123" }
    let (resp, body) = @http.post(
      "http://127.0.0.1:\{port}/submit",
      "payload",
      headers~,
    )
    assert_eq(resp.code, 201)
    assert_eq(resp.reason, "Created")
    assert_eq(body.text(), "payload|abc123")
    server.close()
  })
}

///|
async test "server: run_forever SSE flush chunked" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, _body, conn) => {
        let headers : Map[String, String] = {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
        }
        conn.send_response(200, "OK", extra_headers=headers)
        conn.write("data: first\n\n")
        conn.flush()
        @async.sleep(150)
        conn.write("data: second\n\n")
        conn.end_response()
      })
    })
    @async.sleep(20)
    let (resp, stream) = @http.get_stream("http://127.0.0.1:\{port}/events")
    defer stream.close()
    assert_eq(resp.code, 200)
    assert_eq(
      resp.headers.get("content-type").unwrap_or(""),
      "text/event-stream",
    )
    let first = match stream.read_some() {
      Some(chunk) => chunk
      None => fail("expected first chunk")
    }
    let first_data : &@io.Data = first
    let first_text = first_data.text()
    assert_true(first_text.contains("data: first"))
    assert_true(!first_text.contains("data: second"))

    let rest = stream.read_all()
    let rest_data : &@io.Data = rest
    let merged = first_text + rest_data.text()
    assert_true(merged.contains("data: second"))
  })
}

///|
async test "server: addr and client_addr" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let listen_addr = server.addr()
    assert_eq(listen_addr.port, server.port())
    let seen_client_ports : Array[Int] = []
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever(
        (_req, _body, conn) => {
          seen_client_ports.push(conn.client_addr().port)
          conn.send_response(200, "OK")
          conn.write("ok")
          conn.end_response()
        },
        max_connections=1,
      )
    })
    @async.sleep(20)
    let (resp, body) = @http.get("http://127.0.0.1:\{server.port()}/addr")
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "ok")
    assert_eq(seen_client_ports.length(), 1)
    assert_true(seen_client_ports[0] > 0)
  })
}

///|
async test "server: accept GET" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      let (conn, peer) = server.accept()
      let req = conn.read_request()
      conn.skip_request_body()
      conn.send_response(200, "OK")
      conn.write(req.path + "|" + peer.port.to_string())
      conn.end_response()
    })
    @async.sleep(20)
    let (resp, body) = @http.get("http://127.0.0.1:\{port}/accept-path")
    assert_eq(resp.code, 200)
    let text = body.text()
    assert_true(text.has_prefix("/accept-path|"))
  })
}
