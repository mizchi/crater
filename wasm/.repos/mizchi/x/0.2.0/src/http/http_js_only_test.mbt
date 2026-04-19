///|
extern "js" fn js_now_ms() -> Int =
  #| () => Date.now() | 0

///|
extern "js" fn js_probe_server_start() -> @js_async.Promise[Int] =
  #| async () => {
  #|   const http = await import('node:http');
  #|   if (!globalThis.__xhttpClientProbe) {
  #|     globalThis.__xhttpClientProbe = {
  #|       server: null,
  #|       firstToEndMs: -1,
  #|     };
  #|   }
  #|   const state = globalThis.__xhttpClientProbe;
  #|   if (state.server) {
  #|     await new Promise((resolve) => {
  #|       try { state.server.close(() => resolve()); } catch { resolve(); }
  #|     });
  #|     state.server = null;
  #|   }
  #|   state.firstToEndMs = -1;
  #|   const server = http.createServer((req, res) => {
  #|     let firstAt = -1;
  #|     req.on('data', (chunk) => {
  #|       if (firstAt >= 0) return;
  #|       if (!chunk || chunk.length <= 0) return;
  #|       firstAt = Date.now();
  #|     });
  #|     req.on('end', () => {
  #|       const endAt = Date.now();
  #|       state.firstToEndMs = firstAt < 0 ? 0 : (endAt - firstAt);
  #|       res.statusCode = 200;
  #|       res.end('ok');
  #|     });
  #|     req.on('error', () => {
  #|       try {
  #|         res.statusCode = 500;
  #|         res.end('error');
  #|       } catch {}
  #|     });
  #|   });
  #|   await new Promise((resolve, reject) => {
  #|     const onErr = (err) => reject(err);
  #|     server.once('error', onErr);
  #|     server.listen(0, '127.0.0.1', () => {
  #|       server.off('error', onErr);
  #|       resolve();
  #|     });
  #|   });
  #|   state.server = server;
  #|   const addr = server.address();
  #|   return typeof addr === 'object' && addr ? (addr.port | 0) : 0;
  #| }

///|
extern "js" fn js_probe_server_stop() -> @js_async.Promise[Unit] =
  #| async () => {
  #|   const state = globalThis.__xhttpClientProbe;
  #|   const server = state?.server;
  #|   if (!server) return;
  #|   state.server = null;
  #|   await new Promise((resolve) => {
  #|     try { server.close(() => resolve()); } catch { resolve(); }
  #|   });
  #| }

///|
extern "js" fn js_probe_server_first_to_end_ms() -> Int =
  #| () => {
  #|   const state = globalThis.__xhttpClientProbe;
  #|   if (!state) return -1;
  #|   return Number(state.firstToEndMs ?? -1) | 0;
  #| }

///|
extern "js" fn js_tunnel_probe_start() -> @js_async.Promise[Int] =
  #| async () => {
  #|   const http = await import('node:http');
  #|   if (!globalThis.__xhttpTunnelProbe) {
  #|     globalThis.__xhttpTunnelProbe = {
  #|       proxyServer: null,
  #|       lastPayload: '',
  #|     };
  #|   }
  #|   const state = globalThis.__xhttpTunnelProbe;
  #|   const closeServer = async (server) => {
  #|     if (!server) return;
  #|     await new Promise((resolve) => {
  #|       try { server.close(() => resolve()); } catch { resolve(); }
  #|     });
  #|   };
  #|   await closeServer(state.proxyServer);
  #|   state.proxyServer = null;
  #|   state.lastPayload = '';
  #|   const proxyServer = http.createServer((_, res) => {
  #|     res.statusCode = 405;
  #|     res.end('use CONNECT');
  #|   });
  #|   proxyServer.on('connect', (_req, clientSocket, _head) => {
  #|     try { clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n'); } catch {}
  #|     clientSocket.on('data', (chunk) => {
  #|       try {
  #|         state.lastPayload += Buffer.from(chunk).toString('utf8');
  #|       } catch {}
  #|       try { clientSocket.write(chunk); } catch {}
  #|       try { clientSocket.end(); } catch {}
  #|     });
  #|     clientSocket.on('error', () => {
  #|       try { clientSocket.destroy(); } catch {}
  #|     });
  #|   });
  #|   await new Promise((resolve, reject) => {
  #|     const onErr = (err) => reject(err);
  #|     proxyServer.once('error', onErr);
  #|     proxyServer.listen(0, '127.0.0.1', () => {
  #|       proxyServer.off('error', onErr);
  #|       resolve();
  #|     });
  #|   });
  #|   state.proxyServer = proxyServer;
  #|   const proxyAddr = proxyServer.address();
  #|   return typeof proxyAddr === 'object' && proxyAddr ? (proxyAddr.port | 0) : 0;
  #| }

///|
extern "js" fn js_tunnel_probe_stop() -> @js_async.Promise[Unit] =
  #| async () => {
  #|   const state = globalThis.__xhttpTunnelProbe;
  #|   if (!state) return;
  #|   const closeServer = async (server) => {
  #|     if (!server) return;
  #|     await new Promise((resolve) => {
  #|       try { server.close(() => resolve()); } catch { resolve(); }
  #|     });
  #|   };
  #|   await closeServer(state.proxyServer);
  #|   state.proxyServer = null;
  #|   state.lastPayload = '';
  #| }

///|
extern "js" fn js_tunnel_probe_last_payload() -> String =
  #| () => {
  #|   const state = globalThis.__xhttpTunnelProbe;
  #|   return state?.lastPayload || '';
  #| }

///|
extern "js" fn js_server_streaming_probe_response_ms(
  port : Int,
  second_chunk_delay_ms : Int,
) -> @js_async.Promise[Int] =
  #| async (port, secondChunkDelayMs) => {
  #|   const http = await import('node:http');
  #|   const delay = Math.max(0, Number(secondChunkDelayMs || 0) | 0);
  #|   return await new Promise((resolve, reject) => {
  #|     const started = Date.now();
  #|     const req = http.request({
  #|       host: '127.0.0.1',
  #|       port: Number(port || 0),
  #|       method: 'POST',
  #|       path: '/stream-probe',
  #|       headers: {
  #|         'Content-Type': 'text/plain',
  #|         'Content-Length': '11',
  #|       },
  #|     }, (res) => {
  #|       const elapsed = Date.now() - started;
  #|       res.resume();
  #|       res.on('error', reject);
  #|       res.on('end', () => resolve(elapsed | 0));
  #|     });
  #|     req.on('error', reject);
  #|     req.write('hello');
  #|     setTimeout(() => {
  #|       try { req.write(' world'); } catch {}
  #|       try { req.end(); } catch {}
  #|     }, delay);
  #|   });
  #| }

///|
async test "server(js): max_request_body_bytes returns 413" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0, max_request_body_bytes=4)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, body, conn) => {
        let payload = body.read_all()
        conn.send_response(200, "OK")
        conn.write("ok:" + payload.text())
        conn.end_response()
      })
    })
    @async.sleep(20)
    let (resp, body) = @http.post("http://127.0.0.1:\{port}/limit", "abcdef")
    assert_eq(resp.code, 413)
    assert_true(body.text().contains("request body too large"))
  })
}

///|
async test "server(js): close_graceful closes listener" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, _body, conn) => {
        conn.send_response(200, "OK")
        conn.write("ok")
        conn.end_response()
      })
    })
    @async.sleep(20)
    let (resp, body) = @http.get("http://127.0.0.1:\{port}/before-close")
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "ok")

    server.close_graceful(timeout_ms=500)
    @async.sleep(20)

    let after_close : Result[(@http.Response, &@io.Data), @http.HttpError] = try? @http.get(
      "http://127.0.0.1:\{port}/after-close",
    )
    assert_true(after_close is Err(_))
  })
}

///|
async test "server(js): enter_passthrough_mode is callable after response end" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever(
        (_req, _body, conn) => {
          conn.send_response(200, "OK")
          conn.write("ok")
          conn.end_response()
          conn.enter_passthrough_mode()
          conn.close()
        },
        allow_failure=true,
      )
    })
    @async.sleep(20)
    let (resp, body) = @http.post(
      "http://127.0.0.1:\{port}/passthrough",
      "abcdef",
    )
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "ok")
  })
}

///|
async test "server(js): close_graceful finishes with active sse" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()

    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, _body, conn) => {
        let headers : Map[String, String] = {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          "Connection": "keep-alive",
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

    let _ = match stream.read_some() {
      Some(chunk) => chunk
      None => fail("expected first sse chunk")
    }

    let mut graceful_done = false
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.close_graceful(timeout_ms=1000)
      graceful_done = true
    })

    let rest = stream.read_all()
    let rest_data : &@io.Data = rest
    assert_true(rest_data.text().contains("data: second"))

    for _ in 0..<60 {
      if graceful_done {
        break
      }
      @async.sleep(20)
    }
    assert_true(graceful_done)

    let after_close : Result[(@http.Response, &@io.Data), @http.HttpError] = try? @http.get(
      "http://127.0.0.1:\{port}/after-close-sse",
    )
    assert_true(after_close is Err(_))
  })
}

///|
async test "server(js): trust_proxy uses x-forwarded-for and x-forwarded-port" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0, trust_proxy=true)
    defer server.close()
    let port = server.port()
    let seen : Array[@http.Addr] = []
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, _body, conn) => {
        seen.push(conn.client_addr())
        conn.send_response(200, "OK")
        conn.write("ok")
        conn.end_response()
      })
    })
    @async.sleep(20)
    let headers : Map[String, String] = {
      "X-Forwarded-For": "203.0.113.99, 10.0.0.1",
      "X-Forwarded-Port": "443",
    }
    let (resp, body) = @http.get("http://127.0.0.1:\{port}/trusted", headers~)
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "ok")
    assert_eq(seen.length(), 1)
    assert_eq(seen[0].text, "203.0.113.99:443")
    assert_eq(seen[0].port, 443)
  })
}

///|
async test "server(js): handler error response does not leak internals" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, _body, _conn) => abort("secret-handler-error"))
    })
    @async.sleep(20)
    let (resp, body) = @http.get("http://127.0.0.1:\{port}/error")
    assert_eq(resp.code, 500)
    assert_eq(body.text(), "internal server error")
  })
}

///|
async test "bench(js): graceful close time under concurrent sse" {
  @async.with_task_group(group => {
    let clients = 24
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    let accepted_conns : Array[@http.ServerConnection] = []
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      let headers : Map[String, String] = {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
      }
      for _ in 0..<(clients + 8) {
        let accepted : Result[
          (@http.ServerConnection, @http.Addr),
          @http.HttpError,
        ] = try? server.accept()
        match accepted {
          Ok((conn, _peer)) => {
            ignore(conn.read_request())
            conn.skip_request_body()
            conn.send_response(200, "OK", extra_headers=headers)
            conn.write("data: bench-start\n\n")
            conn.flush()
            accepted_conns.push(conn)
          }
          Err(_) => break
        }
      }
    })

    let streams : Array[@http.Stream] = []
    for _ in 0..<clients {
      let (resp, stream) = @http.get_stream("http://127.0.0.1:\{port}/bench")
      assert_eq(resp.code, 200)
      let first = stream.read_some()
      assert_true(first is Some(_))
      streams.push(stream)
    }
    assert_true(accepted_conns.length() >= clients)

    let started = js_now_ms()
    server.close_graceful(timeout_ms=1500)
    let elapsed = js_now_ms() - started
    println("bench(js): sse_clients=\{clients} graceful_close_ms=\{elapsed}")
    assert_true(elapsed >= 0)
    assert_true(elapsed < 2500)

    for stream in streams {
      stream.close()
    }
  })
}

///|
async test "client(js): generic request via Client::request" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((req, body, conn) => {
        assert_eq(req.meth, @http.RequestMethod::Patch)
        assert_eq(req.path, "/generic")
        let payload = body.read_all()
        conn.send_response(200, "OK")
        conn.write("seen:" + payload.text())
        conn.end_response()
      })
    })
    @async.sleep(20)
    let client = @http.Client::new("http://127.0.0.1:\{port}")
    defer client.close()
    client.request(@http.RequestMethod::Patch, "/generic", extra_headers={
      "Content-Type": "text/plain",
    })
    client.write("payload")
    let resp = client.end_request()
    let body = client.read_all()
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "seen:payload")
  })
}

///|
async test "client(js): get and post shortcuts" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((req, body, conn) => {
        let payload = body.read_all()
        conn.send_response(200, "OK")
        conn.write(req.meth.to_string() + "|" + req.path + "|" + payload.text())
        conn.end_response()
      })
    })
    @async.sleep(20)
    let client = @http.Client::new("http://127.0.0.1:\{port}")
    defer client.close()

    let get_resp = client.get("/g", body="b1")
    let get_body = client.read_all()
    assert_eq(get_resp.code, 200)
    assert_eq(get_body.text(), "Get|/g|b1")

    let post_resp = client.post("/p", "b2")
    let post_body = client.read_all()
    assert_eq(post_resp.code, 200)
    assert_eq(post_body.text(), "Post|/p|b2")
  })
}

///|
async test "client(js): invalid url returns HttpError::InvalidUrl" {
  let bad_url = "bad://example"
  let result : Result[@http.Client, @http.HttpError] = try? @http.Client::new(
    bad_url,
  )
  match result {
    Ok(client) => {
      client.close()
      fail("expected InvalidUrl")
    }
    Err(err) =>
      match err {
        @http.HttpError::InvalidUrl(url) => assert_eq(url, bad_url)
        _ => fail("expected InvalidUrl")
      }
  }
}

///|
async test "client(js): request rejects absolute url path" {
  let client = @http.Client::new("http://127.0.0.1:8080")
  defer client.close()
  let absolute_result : Result[Unit, @http.HttpError] = try? client.request(
    @http.RequestMethod::Get,
    "http://203.0.113.1/pwn",
  )
  assert_true(absolute_result is Err(_))
  let scheme_relative_result : Result[Unit, @http.HttpError] = try? client.request(
    @http.RequestMethod::Get,
    "//203.0.113.1/pwn",
  )
  assert_true(scheme_relative_result is Err(_))
}

///|
async test "client(js): flush streams request body before end_request" {
  let start_controller = @js_async.AbortController::new()
  let port = @js_async.Promise::wait(
    js_probe_server_start(),
    abort_controller=start_controller,
  ) catch {
    err => fail("probe server start failed: \{err.to_string()}")
  }
  let client = @http.Client::new("http://127.0.0.1:\{port}")
  defer client.close()

  client.request(@http.RequestMethod::Post, "/stream")
  client.write("first")
  client.flush()
  @async.sleep(120)
  client.write("second")

  let resp = client.end_request()
  let body = client.read_all()
  assert_eq(resp.code, 200)
  assert_eq(body.text(), "ok")

  let first_to_end_ms = js_probe_server_first_to_end_ms()
  assert_true(first_to_end_ms >= 60)

  let stop_controller = @js_async.AbortController::new()
  ignore(
    @js_async.Promise::wait(
      js_probe_server_stop(),
      abort_controller=stop_controller,
    ) catch {
      _ => ()
    },
  )
}

///|
async test "client(js): request API is rejected in passthrough mode" {
  let mut success = false
  for _ in 0..<4 {
    let start_controller = @js_async.AbortController::new()
    let proxy_port = @js_async.Promise::wait(
      js_tunnel_probe_start(),
      abort_controller=start_controller,
    ) catch {
      _ => continue
    }
    let client_result : Result[@http.Client, @http.HttpError] = try? @http.Client::new(
      "http://127.0.0.1:\{proxy_port}",
    )
    let mut ready = false
    match client_result {
      Ok(client) => {
        let connect_result : Result[@http.Response, @http.HttpError] = try? ({
          client.request(@http.RequestMethod::Connect, "example.test:443")
          client.end_request()
        })
        match connect_result {
          Ok(resp) =>
            if resp.code == 200 {
              let enter_result : Result[Unit, @http.HttpError] = try? client.enter_passthrough_mode()
              if enter_result is Ok(_) {
                client.write("ping")
                @async.sleep(20)
                ready = js_tunnel_probe_last_payload() == "ping"
                if ready {
                  let next_req : Result[Unit, @http.HttpError] = try? client.request(
                    @http.RequestMethod::Get,
                    "/after-tunnel",
                  )
                  success = next_req is Err(_)
                }
              }
            }
          Err(_) => ()
        }
        client.close()
      }
      Err(_) => ()
    }
    let stop_controller = @js_async.AbortController::new()
    ignore(
      @js_async.Promise::wait(
        js_tunnel_probe_stop(),
        abort_controller=stop_controller,
      ) catch {
        _ => ()
      },
    )
    if success {
      break
    }
    @async.sleep(20)
  }
  assert_true(success)
}

///|
async test "server(js): request body is readable before full upload completes" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, body, conn) => {
        let first = body.read_exactly(5)
        let first_data : &@io.Data = first
        conn.send_response(200, "OK")
        conn.write("first:" + first_data.text())
        conn.end_response()
      })
    })
    @async.sleep(20)

    let controller = @js_async.AbortController::new()
    let elapsed = @js_async.Promise::wait(
      js_server_streaming_probe_response_ms(port, 240),
      abort_controller=controller,
    ) catch {
      err => fail("streaming probe failed: \{err.to_string()}")
    }
    assert_true(elapsed >= 0)
    assert_true(
      elapsed < 200,
      msg="expected early response before second chunk, elapsed=\{elapsed}ms",
    )
  })
}
