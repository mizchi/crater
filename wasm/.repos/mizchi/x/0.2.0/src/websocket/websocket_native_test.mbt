///|
async test "websocket text echo" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      for ;; {
        let msg = ws.recv() catch {
          @async_ws.ConnectionClosed(_) => break
          err => raise err
        }
        let content = msg.read_all()
        match msg.kind {
          @async_ws.Text => ws.send_text(content.text())
          @async_ws.Binary => ws.send_binary(content.binary()[:])
        }
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    client.send_text("hello")
    let msg = client.recv()
    guard msg is @websocket.Text(text) else { fail("expected Text message") }
    assert_eq(text, "hello")
    client.send_close()
  })
}

///|
async test "websocket binary echo" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      for ;; {
        let msg = ws.recv() catch {
          @async_ws.ConnectionClosed(_) => break
          err => raise err
        }
        let content = msg.read_all()
        match msg.kind {
          @async_ws.Text => ws.send_text(content.text())
          @async_ws.Binary => ws.send_binary(content.binary()[:])
        }
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    let data = Bytes::makei(4, fn(i) { (i + 65).to_byte() })
    client.send_binary(data[:])
    let msg = client.recv()
    guard msg is @websocket.Binary(received) else {
      fail("expected Binary message")
    }
    assert_eq(received.length(), 4)
    assert_eq(received[0], b'\x41')
    assert_eq(received[1], b'\x42')
    assert_eq(received[2], b'\x43')
    assert_eq(received[3], b'\x44')
    client.send_close()
  })
}

///|
async test "websocket multiple messages" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      for ;; {
        let msg = ws.recv() catch {
          @async_ws.ConnectionClosed(_) => break
          err => raise err
        }
        let content = msg.read_all()
        match msg.kind {
          @async_ws.Text => ws.send_text(content.text())
          @async_ws.Binary => ws.send_binary(content.binary()[:])
        }
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    client.send_text("first")
    let msg1 = client.recv()
    guard msg1 is @websocket.Text(t1) else { fail("expected Text") }
    assert_eq(t1, "first")
    client.send_text("second")
    let msg2 = client.recv()
    guard msg2 is @websocket.Text(t2) else { fail("expected Text") }
    assert_eq(t2, "second")
    client.send_text("third")
    let msg3 = client.recv()
    guard msg3 is @websocket.Text(t3) else { fail("expected Text") }
    assert_eq(t3, "third")
    client.send_close()
  })
}

///|
async test "smoke: text echo matches upstream" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      // Accept two connections sequentially
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        let request = conn.read_request()
        let ws = @async_ws.from_http_server(request, conn)
        for ;; {
          let msg = ws.recv() catch {
            @async_ws.ConnectionClosed(_) => break
            err => raise err
          }
          let content = msg.read_all()
          match msg.kind {
            @async_ws.Text => ws.send_text(content.text())
            @async_ws.Binary => ws.send_binary(content.binary()[:])
          }
        }
        ws.close()
        conn.close()
      }
    })
    let url = "ws://localhost:\{addr.port()}"
    // Upstream API
    let upstream = @async_ws.Conn::connect(url)
    defer upstream.close()
    upstream.send_text("hello")
    let upstream_msg = upstream.recv()
    let upstream_data = upstream_msg.read_all()
    let upstream_text = upstream_data.text()
    upstream.send_close()
    // Wrapper API
    let wrapper = @websocket.Conn::connect(url)
    defer wrapper.close()
    wrapper.send_text("hello")
    let wrapper_msg = wrapper.recv()
    guard wrapper_msg is @websocket.Text(wrapper_text) else {
      fail("expected Text message")
    }
    wrapper.send_close()
    // Compare
    assert_eq(upstream_text, wrapper_text)
    assert_eq(upstream_text, "hello")
  })
}

///|
async test "smoke: binary echo matches upstream" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        let request = conn.read_request()
        let ws = @async_ws.from_http_server(request, conn)
        for ;; {
          let msg = ws.recv() catch {
            @async_ws.ConnectionClosed(_) => break
            err => raise err
          }
          let content = msg.read_all()
          match msg.kind {
            @async_ws.Text => ws.send_text(content.text())
            @async_ws.Binary => ws.send_binary(content.binary()[:])
          }
        }
        ws.close()
        conn.close()
      }
    })
    let url = "ws://localhost:\{addr.port()}"
    let data = Bytes::makei(4, fn(i) { (i + 65).to_byte() })
    // Upstream API
    let upstream = @async_ws.Conn::connect(url)
    defer upstream.close()
    upstream.send_binary(data[:])
    let upstream_msg = upstream.recv()
    let upstream_bytes = upstream_msg.read_all().binary()
    upstream.send_close()
    // Wrapper API
    let wrapper = @websocket.Conn::connect(url)
    defer wrapper.close()
    wrapper.send_binary(data[:])
    let wrapper_msg = wrapper.recv()
    guard wrapper_msg is @websocket.Binary(wrapper_bytes) else {
      fail("expected Binary message")
    }
    wrapper.send_close()
    // Compare
    assert_eq(upstream_bytes.length(), wrapper_bytes.length())
    for i = 0; i < upstream_bytes.length(); i = i + 1 {
      assert_eq(upstream_bytes[i], wrapper_bytes[i])
    }
  })
}

///|
async test "smoke: close code matches upstream" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      // Server sends close with GoingAway code to each client
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        let request = conn.read_request()
        let ws = @async_ws.from_http_server(request, conn)
        ws.send_close(code=@async_ws.GoingAway)
        // Wait for client close response
        try ws.recv() catch {
          @async_ws.ConnectionClosed(_) => ()
          err => raise err
        } noraise {
          _ => ()
        }
        ws.close()
        conn.close()
      }
    })
    let url = "ws://localhost:\{addr.port()}"
    // Upstream: receive close code
    let upstream = @async_ws.Conn::connect(url)
    defer upstream.close()
    let upstream_code = try {
      ignore(upstream.recv())
      ""
    } catch {
      @async_ws.ConnectionClosed(code, _) => @debug.to_string(code)
      _ => "error"
    }
    // Wrapper: receive close code
    let wrapper = @websocket.Conn::connect(url)
    defer wrapper.close()
    let wrapper_code = try {
      ignore(wrapper.recv())
      ""
    } catch {
      @websocket.ConnectionClosed(code, _) => code.to_string()
      _ => "error"
    }
    // Both should see the same close code
    assert_eq(upstream_code, "GoingAway")
    assert_eq(upstream_code, wrapper_code)
  })
}

///|
async test "smoke: multiple messages match upstream" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        let request = conn.read_request()
        let ws = @async_ws.from_http_server(request, conn)
        for ;; {
          let msg = ws.recv() catch {
            @async_ws.ConnectionClosed(_) => break
            err => raise err
          }
          let content = msg.read_all()
          match msg.kind {
            @async_ws.Text => ws.send_text(content.text())
            @async_ws.Binary => ws.send_binary(content.binary()[:])
          }
        }
        ws.close()
        conn.close()
      }
    })
    let url = "ws://localhost:\{addr.port()}"
    let messages = ["alpha", "beta", "gamma"]
    // Upstream
    let upstream_results : Array[String] = []
    let upstream = @async_ws.Conn::connect(url)
    defer upstream.close()
    for m in messages {
      upstream.send_text(m)
      let msg = upstream.recv()
      upstream_results.push(msg.read_all().text())
    }
    upstream.send_close()
    // Wrapper
    let wrapper_results : Array[String] = []
    let wrapper = @websocket.Conn::connect(url)
    defer wrapper.close()
    for m in messages {
      wrapper.send_text(m)
      let msg = wrapper.recv()
      guard msg is @websocket.Text(t) else { fail("expected Text") }
      wrapper_results.push(t)
    }
    wrapper.send_close()
    // Compare
    assert_eq(upstream_results.length(), wrapper_results.length())
    for i = 0; i < upstream_results.length(); i = i + 1 {
      assert_eq(upstream_results[i], wrapper_results[i])
    }
  })
}

///|
async test "smoke: mixed text and binary match upstream" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        let request = conn.read_request()
        let ws = @async_ws.from_http_server(request, conn)
        for ;; {
          let msg = ws.recv() catch {
            @async_ws.ConnectionClosed(_) => break
            err => raise err
          }
          let content = msg.read_all()
          match msg.kind {
            @async_ws.Text => ws.send_text(content.text())
            @async_ws.Binary => ws.send_binary(content.binary()[:])
          }
        }
        ws.close()
        conn.close()
      }
    })
    let url = "ws://localhost:\{addr.port()}"
    let bin_data = Bytes::makei(3, fn(i) { (i + 0x10).to_byte() })
    // Upstream: text → binary → text
    let upstream = @async_ws.Conn::connect(url)
    defer upstream.close()
    upstream.send_text("one")
    let u1 = upstream.recv().read_all().text()
    upstream.send_binary(bin_data[:])
    let u2 = upstream.recv().read_all().binary()
    upstream.send_text("two")
    let u3 = upstream.recv().read_all().text()
    upstream.send_close()
    // Wrapper: text → binary → text
    let wrapper = @websocket.Conn::connect(url)
    defer wrapper.close()
    wrapper.send_text("one")
    let w1 = wrapper.recv()
    guard w1 is @websocket.Text(wt1) else { fail("expected Text") }
    wrapper.send_binary(bin_data[:])
    let w2 = wrapper.recv()
    guard w2 is @websocket.Binary(wb2) else { fail("expected Binary") }
    wrapper.send_text("two")
    let w3 = wrapper.recv()
    guard w3 is @websocket.Text(wt3) else { fail("expected Text") }
    wrapper.send_close()
    // Compare
    assert_eq(u1, wt1)
    assert_eq(u3, wt3)
    assert_eq(u2.length(), wb2.length())
    for i = 0; i < u2.length(); i = i + 1 {
      assert_eq(u2[i], wb2[i])
    }
  })
}

///|
async test "websocket empty string" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      for ;; {
        let msg = ws.recv() catch {
          @async_ws.ConnectionClosed(_) => break
          err => raise err
        }
        let content = msg.read_all()
        match msg.kind {
          @async_ws.Text => ws.send_text(content.text())
          @async_ws.Binary => ws.send_binary(content.binary()[:])
        }
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    client.send_text("")
    let msg = client.recv()
    guard msg is @websocket.Text(text) else { fail("expected Text") }
    assert_eq(text, "")
    client.send_close()
  })
}

///|
async test "websocket unicode text" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      for ;; {
        let msg = ws.recv() catch {
          @async_ws.ConnectionClosed(_) => break
          err => raise err
        }
        let content = msg.read_all()
        match msg.kind {
          @async_ws.Text => ws.send_text(content.text())
          @async_ws.Binary => ws.send_binary(content.binary()[:])
        }
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    let test_strings = [
      "\u{3053}\u{3093}\u{306B}\u{3061}\u{306F}", "\u{1F600}\u{1F680}\u{2764}", "hello \u{4E16}\u{754C}",
    ]
    for s in test_strings {
      client.send_text(s)
      let msg = client.recv()
      guard msg is @websocket.Text(text) else { fail("expected Text") }
      assert_eq(text, s)
    }
    client.send_close()
  })
}

///|
async test "websocket empty binary" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      for ;; {
        let msg = ws.recv() catch {
          @async_ws.ConnectionClosed(_) => break
          err => raise err
        }
        let content = msg.read_all()
        match msg.kind {
          @async_ws.Text => ws.send_text(content.text())
          @async_ws.Binary => ws.send_binary(content.binary()[:])
        }
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    let empty = Bytes::new(0)
    client.send_binary(empty[:])
    let msg = client.recv()
    guard msg is @websocket.Binary(received) else { fail("expected Binary") }
    assert_eq(received.length(), 0)
    client.send_close()
  })
}

///|
async test "websocket large binary" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      for ;; {
        let msg = ws.recv() catch {
          @async_ws.ConnectionClosed(_) => break
          err => raise err
        }
        let content = msg.read_all()
        match msg.kind {
          @async_ws.Text => ws.send_text(content.text())
          @async_ws.Binary => ws.send_binary(content.binary()[:])
        }
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    let size = 4096
    let data = Bytes::makei(size, fn(i) { (i % 256).to_byte() })
    client.send_binary(data[:])
    let msg = client.recv()
    guard msg is @websocket.Binary(received) else { fail("expected Binary") }
    assert_eq(received.length(), size)
    assert_eq(received[0], b'\x00')
    assert_eq(received[255], b'\xFF')
    assert_eq(received[256], b'\x00')
    client.send_close()
  })
}

///|
async test "websocket close with reason" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      try ws.recv() catch {
        @async_ws.ConnectionClosed(code, reason) => {
          inspect(@debug.to_string(code), content="Normal")
          inspect(reason, content="Some(\"goodbye\")")
        }
        err => raise err
      } noraise {
        _ => ()
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    client.send_close(code=@websocket.Normal, reason="goodbye")
  })
}

///|
async test "websocket close with custom code" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      try ws.recv() catch {
        @async_ws.ConnectionClosed(code, _) =>
          inspect(@debug.to_string(code), content="Other(4000)")
        err => raise err
      } noraise {
        _ => ()
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    client.send_close(code=@websocket.Other(4000))
  })
}

///|
async test "websocket invalid handshake" {
  // Connecting to a non-WebSocket HTTP endpoint should raise InvalidHandshake
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      // Read request but don't upgrade - just close
      ignore(conn.read_request())
    })
    try {
      let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
      client.close()
      fail("expected InvalidHandshake error")
    } catch {
      @websocket.InvalidHandshake(_) => () // expected
      err => fail("unexpected error: \{err}")
    }
  })
}

///|
async test "websocket server-initiated close" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      // Echo one message, then server initiates close
      let msg = ws.recv() catch {
        @async_ws.ConnectionClosed(_) => return
        err => raise err
      }
      let content = msg.read_all()
      ws.send_text(content.text())
      ws.send_close(code=@async_ws.PolicyViolation, reason="policy")
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    client.send_text("test")
    let msg = client.recv()
    guard msg is @websocket.Text(text) else { fail("expected Text") }
    assert_eq(text, "test")
    // Next recv should get ConnectionClosed from server
    try {
      ignore(client.recv())
      fail("expected ConnectionClosed")
    } catch {
      @websocket.ConnectionClosed(code, reason) => {
        inspect(code, content="PolicyViolation")
        inspect(reason, content="Some(\"policy\")")
      }
      err => fail("unexpected error: \{err}")
    }
  })
}

///|
async test "websocket close with code" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      try ws.recv() catch {
        @async_ws.ConnectionClosed(code, _) =>
          inspect(@debug.to_string(code), content="Normal")
        err => raise err
      } noraise {
        _ => ()
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    client.send_close(code=@websocket.Normal)
  })
}
