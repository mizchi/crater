# mizchi/x

Node.js backend compatibility layer for `moonbitlang/async` in [MoonBit](https://docs.moonbitlang.com).

`mizchi/x` keeps native behavior by delegating to `moonbitlang/async`, and provides JS FFI implementations so the same async-style code can run on `--target js` (Node.js) with minimal changes.

## Primary Goal

- Run code written against `moonbitlang/async` on Node.js (`--target js`).
- Keep native (`--target native`) semantics close by forwarding to upstream implementations.

## Related Package

- `mizchi/x`: API is aligned with `moonbitlang/async` contracts (native-compatible surface).
- `mizchi/js/node`: API is aligned with raw Node.js/JavaScript style APIs.

## Dependencies

| Dependency | Version |
|---|---|
| `moonbitlang/async` | 0.16.6 |
| `moonbitlang/x` | 0.4.40 |

## Packages

| Package | Description |
|---|---|
| `mizchi/x/process` | Command execution (`run`, `collect_output`, `collect_stdout`, `collect_stderr`, `collect_output_merged`) |
| `mizchi/x/fs` | File system operations (`read_file`, `write_file`, `exists`, `mkdir`, `readdir`, `remove`, `rmdir`) |
| `mizchi/x/http` | HTTP client (`get`, `post`, `put`, `get_stream`, `post_stream`, `put_stream`) |
| `mizchi/x/websocket` | WebSocket client (`connect`, `Conn::send_text`, `Conn::send_binary`, `Conn::recv`, `Conn::close`) |
| `mizchi/x/stdio` | Standard I/O (`stdin`, `stdout`, `stderr` with `@io.Reader`/`@io.Writer`) |
| `mizchi/x/pipe` | In-memory pipes (`pipe()` → `PipeRead`/`PipeWrite` with `@io.Reader`/`@io.Writer`) |
| `mizchi/x/sys` | Environment variables and CLI args (`get_env_var`, `get_cli_args`, `exit`) |

## Platform Support

| Package | native | js | wasm | wasm-gc |
|---|---|---|---|---|
| `process` | Yes | Yes | stub | stub |
| `fs` | Yes | Yes | WASI P1 | stub |
| `http` | Yes | Yes | stub | stub |
| `websocket` | Yes | Yes | stub | stub |
| `stdio` | Yes | Yes | stub | stub |
| `pipe` | Yes | Yes | stub | stub |
| `sys` | Yes | Yes | Yes | stub |

- **Yes** — Full implementation.
- **stub** — Compiles but aborts at runtime with "not supported" message.
- **WASI P1** — Partial implementation using WASI Preview 1 syscalls.

## Upstream Compatibility

Compatibility with `moonbitlang/async` 0.16.6 / `moonbitlang/x` 0.4.40.

The wrapper re-exports upstream types and APIs with matching signatures. On native, each function delegates directly to the upstream implementation. On JS, equivalent behavior is provided via `extern "js"` FFI (Node.js).

#### http (`moonbitlang/async/http`)

Upstream tests: 20 | Covered: 2 | Skipped: 18

| Upstream test | Status | Notes |
|---|---|---|
| `http request` | Covered | |
| `https request` | Covered | |
| Other 18 tests | Skip | Internal parser/sender/proxy tests |

#### websocket (`moonbitlang/async/websocket`)

Upstream tests: 24 | Covered: 0 | Skipped: 24

All upstream tests are internal (frame handling, ping/pong, UTF-8 validation) and not applicable to the wrapper's high-level API. The wrapper has 24 independent tests covering its own API.

#### pipe (`moonbitlang/async/pipe`)

Upstream tests: 3 | Covered: 3 | Skipped: 0

All upstream pipe tests are fully covered.

#### stdio (`moonbitlang/async/stdio`)

Upstream tests: 3 | Covered: 0 | Skipped: 3

All upstream tests require process piping/redirect features (`@process.run` with redirect options).

## Quick Start

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
```

### Upstream test coverage by package

Coverage is verified by `scripts/sync-upstream-tests.sh`, which extracts test names from the upstream packages and checks that each is either covered by a wrapper test or explicitly excluded in `scripts/upstream-exclude.conf`.

#### process (`moonbitlang/async/process`)

Upstream tests: 28 | Covered: 10 | Skipped: 18

| Upstream test | Status | Notes |
|---|---|---|
| `basic wait` | Covered | |
| `basic_ls` | Covered | |
| `collect_stdout` | Covered | |
| `collect_error` | Covered | |
| `collect_output` | Covered | |
| `collect_output_merged` | Covered | |
| `wait exitcode` | Covered | |
| `set cwd` | Covered | |
| `set_env` | Covered | |
| `set_env no inherit` | Covered | |
| `basic_cat` | Skip | stdin pipe not yet exposed |
| `wait_pid` | Skip | spawn_orphan not yet exposed |
| `cancel process` | Skip | cancellation not yet exposed |
| `cancel process hard` | Skip | cancellation not yet exposed |
| `cancel process timeout` | Skip | cancellation not yet exposed |
| `orphan process` | Skip | spawn_orphan not yet exposed |
| `collect_output blocked` | Skip | stdin param not yet exposed |
| `spawn_in_group wait` | Skip | spawn not yet exposed |
| `spawn_in_group cancel` | Skip | spawn not yet exposed |
| `Process::wait` | Skip | Process type not yet exposed |
| `Process::try_wait` | Skip | Process type not yet exposed |
| `Process:cancel` | Skip | Process type not yet exposed |
| `merge stdout and stderr` | Skip | stdout/stderr redirect not yet exposed |
| `merge multiple` | Skip | spawn + pipe redirect not yet exposed |
| `redirect to file` | Skip | file redirect not yet exposed |
| `kill children on hard cancel` | Skip | requires custom test program + Windows |
| `do not kill orphan children on hard cancel` | Skip | requires custom test program + Windows |
| `windows command line arg escape` | Skip | Windows-specific |

## HTTP Server Operations (Node.js)

### Reverse proxy / TLS termination

When running `@http.Server` behind a reverse proxy (Nginx/Caddy/ALB), terminate TLS at the proxy and forward plain HTTP to the MoonBit process.

- Enable proxy-aware client address resolution with:
  - `@http.Server::new(..., trust_proxy=true)`
- Current JS behavior:
  - `client_addr()` uses `x-forwarded-for` (first hop) and `x-forwarded-port`
  - falls back to `x-forwarded-host` port when `x-forwarded-port` is absent

Security note: set `trust_proxy=true` only when requests are guaranteed to come from trusted proxy hops.

### SSE shutdown benchmark

Run this JS-only benchmark test to check concurrent SSE shutdown behavior:

```bash
moon test --target js src/http --filter 'bench(js): graceful close time under concurrent sse'
```

The test prints a measurement line like:

```text
bench(js): sse_clients=24 graceful_close_ms=1507
```

### k6 benchmark (default: JS vs Native)

Use the dedicated benchmark server package and k6 scenarios.
By default, this runs both `js` and `native` targets and prints a comparison summary.

```bash
./scripts/k6/run_http_bench.sh
```

Environment variables:

- `PORT` (default `18080`)
- `VUS` (default `128`)
- `DURATION` (default `20s`)
- `BODY_SIZE` (default `16384`) for `POST /consume`
- `TARGETS` (default `"js native"`)
  - e.g. `TARGETS=js` to run JS only
  - e.g. `TARGETS=native` to run Native only

Individual scenarios:

```bash
BASE_URL=http://127.0.0.1:18080 k6 run scripts/k6/http_ping.js
BASE_URL=http://127.0.0.1:18080 BODY_SIZE=16384 k6 run scripts/k6/http_consume.js
BASE_URL=http://127.0.0.1:18080 BODY_SIZE=16384 k6 run scripts/k6/http_discard.js
```

## License

Apache-2.0
