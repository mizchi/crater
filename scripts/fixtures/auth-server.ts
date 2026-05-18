/**
 * TEST FIXTURE ONLY — do not import from production code.
 *
 * - Uses `Math.random()` for session ids (non-cryptographic).
 * - Hardcoded credentials `alice / wonderland`.
 * - Mismatched-origin /me handler intentionally returns 200 to
 *   exercise Crater's CORS gate (M5 in PR #131 security review).
 */

import http, { IncomingMessage, ServerResponse } from "node:http";
import { AddressInfo } from "node:net";

type StartOptions = {
  port?: number;
  apiPort?: number;
  /**
   * Optional 3rd port for a "shadow" API origin. When supplied (including
   * `0` for an ephemeral port), an additional HTTP server is started that
   * exposes `GET /api/v2/data` gated on `Authorization: Bearer shadow-token-v2`.
   * Used by the multi-origin Authorization routing e2e (`tests/auth-flow-via-bidi.test.ts`).
   */
  shadowPort?: number;
};
type StartResult = {
  url: string;
  stop: () => Promise<void>;
  apiUrl: string;
  apiStop: () => Promise<void>;
  /**
   * URL of the optional shadow API origin. `null` when `shadowPort` was not
   * supplied. `shadowStop` is a no-op in that case so test cleanup can call
   * it unconditionally.
   */
  shadowUrl: string | null;
  shadowStop: () => Promise<void>;
  /**
   * Seed the in-memory session table directly. Used by BiDi flow tests that
   * inject a cookie via `storage.setCookie` rather than driving the login form
   * (Crater currently lacks `HTMLFormElement.submit` / `document.forms`).
   */
  recordSession: (sid: string, user: string) => void;
  /** Drop a previously-seeded session id. */
  forgetSession: (sid: string) => void;
  /**
   * Mark a Bearer token (including the `Bearer ` prefix, as it appears in
   * the `Authorization` header) as expired. Subsequent `/api/protected`
   * requests with that header value return 401 + `WWW-Authenticate: Bearer
   * error="invalid_token"` and a JSON body `{ "error": "token_expired" }`.
   * Used by the token-expiration e2e to drive the "re-register on 401" path.
   */
  recordExpiredToken: (token: string) => void;
  /** Reverse `recordExpiredToken`. */
  forgetExpiredToken: (token: string) => void;
};

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on("data", c => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function parseCookies(header: string | undefined): Map<string, string> {
  const out = new Map<string, string>();
  if (!header) return out;
  for (const piece of header.split(";")) {
    const [k, v] = piece.trim().split("=");
    if (k && v) out.set(k, v);
  }
  return out;
}

function loginPageHtml(): string {
  return `<!DOCTYPE html><html><body>
<form id="loginForm" method="POST" action="/login">
  <input id="user" name="user" />
  <input id="pass" name="pass" type="password" />
  <button id="submit" type="submit">Login</button>
</form></body></html>`;
}

function handleApp(
  req: IncomingMessage,
  res: ServerResponse,
  sessions: Map<string, string>,
  apiUrl: string,
): Promise<void> {
  return (async () => {
    const url = new URL(req.url ?? "/", `http://${req.headers.host}`);
    if (url.pathname === "/login" && req.method === "GET") {
      res.writeHead(200, { "content-type": "text/html" });
      res.end(loginPageHtml());
      return;
    }
    if (url.pathname === "/redirect-cross-origin") {
      res.writeHead(302, { location: `${apiUrl}/api/echo-auth` });
      res.end();
      return;
    }
    if (url.pathname === "/redirect-same-origin") {
      res.writeHead(302, { location: "/app-echo-auth" });
      res.end();
      return;
    }
    if (url.pathname === "/app-echo-auth") {
      const auth = req.headers["authorization"] ?? "";
      const cookie = req.headers["cookie"] ?? "";
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ authorization: String(auth), cookie: String(cookie) }));
      return;
    }
    if (url.pathname === "/login" && req.method === "POST") {
      const body = await readBody(req);
      const params = new URLSearchParams(body);
      // secretlint-disable-next-line no-credentials
      if (params.get("user") === "alice" && params.get("pass") === "wonderland") {
        const id = `s_${Math.random().toString(36).slice(2)}`;
        sessions.set(id, "alice");
        res.writeHead(302, {
          "set-cookie": `session=${id}; Path=/; HttpOnly; SameSite=Lax`,
          location: "/dashboard",
        });
        res.end();
      } else {
        res.writeHead(401);
        res.end("bad credentials");
      }
      return;
    }
    if (url.pathname === "/dashboard") {
      const cookies = parseCookies(req.headers.cookie);
      const sid = cookies.get("session");
      const who = sid ? sessions.get(sid) : undefined;
      if (who) {
        res.writeHead(200, { "content-type": "text/html" });
        res.end(`<html><body>welcome ${who}</body></html>`);
      } else {
        res.writeHead(401);
        res.end("unauthenticated");
      }
      return;
    }
    res.writeHead(404);
    res.end();
  })();
}

// secretlint-disable-next-line @secretlint/secretlint-rule-pattern
const PROTECTED_BEARER_TOKEN = "Bearer test-jwt-token"; // test fixture only

function corsHeadersForOrigin(
  origin: string,
  appOrigin: string,
): Record<string, string> {
  if (origin === appOrigin) {
    return {
      "access-control-allow-origin": appOrigin,
      "access-control-allow-credentials": "true",
    };
  }
  return {};
}

function handleApi(
  req: IncomingMessage,
  res: ServerResponse,
  appOrigin: string,
  sessions: Map<string, string>,
  expiredTokens: Set<string>,
): void {
  const origin = req.headers.origin ?? "";
  const url = new URL(req.url ?? "/", `http://${req.headers.host}`);
  if (url.pathname === "/me") {
    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "access-control-allow-origin": appOrigin,
        "access-control-allow-methods": "GET, POST",
        "access-control-allow-headers": "x-csrf, content-type",
        "access-control-allow-credentials": "true",
        "access-control-max-age": "600",
      });
      res.end();
      return;
    }
    if (origin === appOrigin) {
      res.writeHead(200, {
        "content-type": "application/json",
        "access-control-allow-origin": appOrigin,
        "access-control-allow-credentials": "true",
      });
      res.end(JSON.stringify({ user: "alice" }));
    } else {
      // SECURITY: Mismatched-origin branch intentionally returns 200 with user
      // data but omits ACA headers. This is a negative-path fixture so tests can
      // verify that Crater's CORS gate blocks the response before JS reads it,
      // even though the server itself responded successfully. Do not "fix" this.
      // (M5 in PR #131 security review.)
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ user: "alice" }));
    }
    return;
  }
  if (url.pathname === "/api/protected") {
    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "access-control-allow-origin": appOrigin,
        "access-control-allow-methods": "GET",
        "access-control-allow-headers": "authorization, content-type",
        "access-control-allow-credentials": "true",
        "access-control-max-age": "600",
      });
      res.end();
      return;
    }
    const auth = req.headers["authorization"];
    const corsHeaders = corsHeadersForOrigin(origin, appOrigin);
    // Expired-token check runs first — even a structurally valid Bearer is
    // rejected once recorded as expired. Models a server that has rotated
    // signing keys or revoked the token without re-issuing.
    if (typeof auth === "string" && expiredTokens.has(auth)) {
      res.writeHead(401, {
        "content-type": "application/json",
        "www-authenticate": 'Bearer error="invalid_token"',
        ...corsHeaders,
      });
      res.end(JSON.stringify({ error: "token_expired" }));
      return;
    }
    if (auth === PROTECTED_BEARER_TOKEN) {
      res.writeHead(200, {
        "content-type": "application/json",
        ...corsHeaders,
      });
      res.end(JSON.stringify({ user: "alice", protected: true }));
    } else {
      res.writeHead(401, {
        "content-type": "text/plain",
        ...corsHeaders,
      });
      res.end("missing or invalid token");
    }
    return;
  }
  // Diagnostic endpoint: echo received Cookie + Authorization back as JSON.
  // Used by the "Cookie and Authorization both attach" e2e to assert that
  // both headers reach the server on a single fetch through Crater's
  // runtime fetch shim. Does NOT authenticate — the only thing it proves
  // is wire-level header propagation.
  if (url.pathname === "/api/echo-auth") {
    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "access-control-allow-origin": appOrigin,
        "access-control-allow-methods": "GET",
        "access-control-allow-headers": "authorization, content-type, cookie",
        "access-control-allow-credentials": "true",
        "access-control-max-age": "600",
      });
      res.end();
      return;
    }
    const corsHeaders = corsHeadersForOrigin(origin, appOrigin);
    const cookieHeader = req.headers["cookie"] ?? null;
    const authHeader = req.headers["authorization"] ?? null;
    res.writeHead(200, {
      "content-type": "application/json",
      ...corsHeaders,
    });
    res.end(
      JSON.stringify({
        cookie: typeof cookieHeader === "string" ? cookieHeader : null,
        authorization: typeof authHeader === "string" ? authHeader : null,
      }),
    );
    return;
  }
  void sessions; // sessions available for future authenticated /api/* routes
  res.writeHead(404);
  res.end();
}

// secretlint-disable-next-line @secretlint/secretlint-rule-pattern
const SHADOW_BEARER_TOKEN = "Bearer shadow-token-v2"; // test fixture only

function handleShadow(
  req: IncomingMessage,
  res: ServerResponse,
  appOrigin: string,
): void {
  const origin = req.headers.origin ?? "";
  const url = new URL(req.url ?? "/", `http://${req.headers.host}`);
  if (url.pathname === "/api/v2/data") {
    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "access-control-allow-origin": appOrigin,
        "access-control-allow-methods": "GET",
        "access-control-allow-headers": "authorization, content-type",
        "access-control-allow-credentials": "true",
        "access-control-max-age": "600",
      });
      res.end();
      return;
    }
    const auth = req.headers["authorization"];
    const corsHeaders = corsHeadersForOrigin(origin, appOrigin);
    if (auth === SHADOW_BEARER_TOKEN) {
      res.writeHead(200, {
        "content-type": "application/json",
        ...corsHeaders,
      });
      res.end(JSON.stringify({ shadow: true, source: "v2" }));
    } else {
      res.writeHead(401, {
        "content-type": "text/plain",
        ...corsHeaders,
      });
      res.end("missing or invalid shadow token");
    }
    return;
  }
  res.writeHead(404);
  res.end();
}

export async function startAuthServer(opts: StartOptions = {}): Promise<StartResult> {
  // Scoped per startAuthServer call so vitest --pool=threads can't share state
  // across parallel test files. (M6 in PR #131 security review.)
  const sessions = new Map<string, string>();   // session-id → username
  // Per-server expired-token set; lives only for the lifetime of this
  // startAuthServer call so parallel tests can't leak revocation state.
  const expiredTokens = new Set<string>();

  // Start the API server FIRST so its URL is known before the app server's
  // /redirect-cross-origin handler is wired up.
  const expiredTokensRef = expiredTokens;
  let appUrlForApi = ""; // bound after appServer listens
  const apiServer = http.createServer((req, res) =>
    handleApi(req, res, appUrlForApi, sessions, expiredTokensRef),
  );
  await new Promise<void>(r => apiServer.listen(opts.apiPort ?? 0, "127.0.0.1", r));
  const apiPort = (apiServer.address() as AddressInfo).port;
  const apiUrl = `http://127.0.0.1:${apiPort}`;

  const appServer = http.createServer((req, res) => {
    handleApp(req, res, sessions, apiUrl).catch(() => res.end());
  });
  await new Promise<void>(r => appServer.listen(opts.port ?? 0, "127.0.0.1", r));
  const appPort = (appServer.address() as AddressInfo).port;
  const appUrl = `http://127.0.0.1:${appPort}`;
  appUrlForApi = appUrl;

  // The shadow server is only spun up when a test passes `shadowPort`
  // (including `0` for ephemeral). Tests that don't need a 3rd origin get
  // `shadowUrl: null` and a no-op `shadowStop`, so cleanup stays uniform.
  let shadowServer: http.Server | null = null;
  let shadowUrl: string | null = null;
  if (typeof opts.shadowPort === "number") {
    shadowServer = http.createServer((req, res) => handleShadow(req, res, appUrl));
    await new Promise<void>(r => shadowServer!.listen(opts.shadowPort, "127.0.0.1", r));
    const shadowPort = (shadowServer.address() as AddressInfo).port;
    shadowUrl = `http://127.0.0.1:${shadowPort}`;
  }

  return {
    url: appUrl,
    apiUrl,
    shadowUrl,
    stop: () => new Promise(r => appServer.close(() => r())),
    apiStop: () => new Promise(r => apiServer.close(() => r())),
    shadowStop: () =>
      shadowServer
        ? new Promise(r => shadowServer!.close(() => r()))
        : Promise.resolve(),
    recordSession: (sid: string, user: string) => {
      if (!sid) throw new Error("sid required");
      sessions.set(sid, user);
    },
    forgetSession: (sid: string) => {
      sessions.delete(sid);
    },
    recordExpiredToken: (token: string) => {
      if (!token) throw new Error("token required");
      expiredTokens.add(token);
    },
    forgetExpiredToken: (token: string) => {
      expiredTokens.delete(token);
    },
  };
}
