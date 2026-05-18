/**
 * TEST FIXTURE ONLY — do not import from production code.
 *
 * - Uses `Math.random()` for session ids (non-cryptographic).
 * - Hardcoded credentials `alice / wonderland`.
 * - Mismatched-origin /me handler intentionally returns 200 to
 *   exercise Crater's CORS gate (M5 in PR #131 security review).
 */

import { createHash, randomBytes } from "node:crypto";
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
      // App-side echo: only reachable via same-origin redirect from
      // /redirect-same-origin, but emit ACA headers anyway so the response
      // posture matches the api-side /api/echo-auth (its sibling diagnostic
      // endpoint). Test-fixture endpoints that reflect Authorization/Cookie
      // must NOT have permissive CORS — they're high-value for a malicious
      // page to coerce.
      const reqOrigin = req.headers.origin ?? "";
      const selfOrigin = `http://${req.headers.host}`;
      const corsHeaders = corsHeadersForOrigin(reqOrigin, selfOrigin);
      const auth = req.headers["authorization"] ?? "";
      const cookie = req.headers["cookie"] ?? "";
      res.writeHead(200, { "content-type": "application/json", ...corsHeaders });
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

// Models a single canonical refresh token mapped to a single fresh access
// token. Tests should mark `PROTECTED_BEARER_TOKEN` as expired (via
// `recordExpiredToken`) and exchange this refresh token through
// `/oauth/token` to drive the refresh flow.
// secretlint-disable-next-line @secretlint/secretlint-rule-pattern
export const REFRESH_TOKEN = "rt-test-refresh"; // test fixture only
// secretlint-disable-next-line @secretlint/secretlint-rule-pattern
export const REFRESHED_ACCESS_TOKEN = "Bearer test-jwt-token-refreshed"; // test fixture only

// HTTP Digest fixture credentials. Both algorithms (MD5 and SHA-256) accept
// the same username/password pair — the algorithm only changes which hash
// function is used to compute HA1, HA2 and the response per RFC 7616.
export const DIGEST_REALM = "crater-digest-fixture";
export const DIGEST_USERNAME = "alice";
// secretlint-disable-next-line @secretlint/secretlint-rule-pattern
export const DIGEST_PASSWORD = "wonderland"; // test fixture only

function parseDigestAuthorization(header: string): Map<string, string> | null {
  // Strip leading "Digest " scheme token.
  if (!header.startsWith("Digest ")) return null;
  const params = header.slice("Digest ".length).trim();
  const out = new Map<string, string>();
  // RFC 7616 §3.4: parameters are auth-param "name=value" pairs separated
  // by commas; values may be quoted-strings or tokens. We scan
  // character-by-character to handle commas inside quoted values.
  let i = 0;
  while (i < params.length) {
    while (i < params.length && /[\s,]/.test(params[i])) i++;
    const nameStart = i;
    while (i < params.length && params[i] !== "=") i++;
    if (i >= params.length) break;
    const name = params.slice(nameStart, i).trim();
    i++; // consume '='
    let value: string;
    if (params[i] === '"') {
      i++; // consume opening quote
      const valStart = i;
      while (i < params.length && params[i] !== '"') {
        if (params[i] === "\\" && i + 1 < params.length) i += 2;
        else i++;
      }
      // RFC 7230 §3.2.6 quoted-pair: a backslash escapes the following
      // octet inside a quoted-string. Strip the escape so the consumer
      // sees the literal value rather than the on-the-wire form.
      value = params.slice(valStart, i).replace(/\\(.)/g, "$1");
      if (i < params.length) i++; // consume closing quote
    } else {
      const valStart = i;
      while (i < params.length && params[i] !== ",") i++;
      value = params.slice(valStart, i).trim();
    }
    out.set(name.toLowerCase(), value);
  }
  return out;
}

// Allowlist of Digest algorithms this fixture supports — clients MUST pick
// one of these. A real RFC 7616 server pins the algorithm at challenge time
// and rejects any other value on the response; this fixture is stateless and
// accepts either of the two advertised algorithms but nothing else (no
// arbitrary client-supplied algorithm string).
const DIGEST_SUPPORTED_ALGORITHMS = new Set(["MD5", "SHA-256"]);

function normalizeDigestAlgorithm(raw: string): string | null {
  // RFC 7616 §3.3: hash function H() depends on the algorithm directive.
  // The "-sess" variants alter how HA1 is computed but use the same base
  // digest, so the underlying hash selection is the same. We canonicalize
  // the algorithm string to its uppercase form for the allowlist check.
  const stripped = raw.replace(/-sess$/i, "");
  const upper = stripped.toUpperCase();
  return DIGEST_SUPPORTED_ALGORITHMS.has(upper) ? upper : null;
}

function digestHash(algorithm: string, input: string): string {
  const normalized = normalizeDigestAlgorithm(algorithm);
  // The caller is expected to have validated `algorithm` against the
  // supported set before calling. Fall back to MD5 only as a defensive
  // default — production code paths route through `normalizeDigestAlgorithm`
  // first and surface a 401 on unsupported algorithms.
  const nodeAlgo = normalized === "SHA-256" ? "sha256" : "md5";
  return createHash(nodeAlgo).update(input).digest("hex");
}

function verifyDigestAuthorization(
  header: string,
  method: string,
): { username: string } | null {
  const parsed = parseDigestAuthorization(header);
  if (!parsed) return null;
  const username = parsed.get("username");
  const realm = parsed.get("realm");
  const nonce = parsed.get("nonce");
  const uri = parsed.get("uri");
  const response = parsed.get("response");
  const qop = parsed.get("qop");
  const nc = parsed.get("nc");
  const cnonce = parsed.get("cnonce");
  const rawAlgorithm = parsed.get("algorithm") ?? "MD5";
  if (!username || !realm || !nonce || !uri || !response) return null;
  if (username !== DIGEST_USERNAME || realm !== DIGEST_REALM) return null;

  // Reject any algorithm string outside the supported allowlist. A real RFC
  // 7616 server compares against the algorithm IT advertised on the
  // challenge; this stateless fixture instead accepts either of the two
  // algorithms it would advertise (MD5 / SHA-256) and rejects anything
  // else, which is sufficient to prevent a "unknown algo silently downgrades
  // to MD5" footgun.
  const algorithm = normalizeDigestAlgorithm(rawAlgorithm);
  if (!algorithm) return null;

  const ha1 = digestHash(
    algorithm,
    `${DIGEST_USERNAME}:${DIGEST_REALM}:${DIGEST_PASSWORD}`,
  );
  const ha2 = digestHash(algorithm, `${method}:${uri}`);
  // qop=auth uses the extended response: HASH(HA1:nonce:nc:cnonce:qop:HA2).
  // Without qop, the bare RFC 2069 form HASH(HA1:nonce:HA2) is used.
  const expected = qop
    ? digestHash(algorithm, `${ha1}:${nonce}:${nc}:${cnonce}:${qop}:${ha2}`)
    : digestHash(algorithm, `${ha1}:${nonce}:${ha2}`);
  if (expected !== response) return null;
  return { username };
}

/**
 * RFC 7616 client-side response computation. Builds the Authorization header
 * value a real Digest client would send after receiving a 401 challenge.
 * Used by the fixture vitest and by Playwright e2e to drive the round-trip
 * without depending on a userland Digest client library.
 */
// RFC 7230 §3.2.6 quoted-pair escape for an `auth-param` value. Backslash
// and double-quote must be \-escaped inside a quoted-string. Used by
// `computeDigestAuthorization` so values containing those characters don't
// produce a header the server's `parseDigestAuthorization` can't recover.
function escapeDigestQuotedValue(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

export function computeDigestAuthorization(opts: {
  username: string;
  password: string;
  realm: string;
  nonce: string;
  uri: string;
  method: string;
  qop?: string;
  nc?: string;
  cnonce?: string;
  algorithm?: string;
  opaque?: string;
}): string {
  const algorithm = opts.algorithm ?? "MD5";
  const ha1 = digestHash(
    algorithm,
    `${opts.username}:${opts.realm}:${opts.password}`,
  );
  const ha2 = digestHash(algorithm, `${opts.method}:${opts.uri}`);
  const response = opts.qop
    ? digestHash(
        algorithm,
        `${ha1}:${opts.nonce}:${opts.nc}:${opts.cnonce}:${opts.qop}:${ha2}`,
      )
    : digestHash(algorithm, `${ha1}:${opts.nonce}:${ha2}`);
  const q = escapeDigestQuotedValue;
  const parts = [
    `username="${q(opts.username)}"`,
    `realm="${q(opts.realm)}"`,
    `nonce="${q(opts.nonce)}"`,
    `uri="${q(opts.uri)}"`,
    `response="${response}"`,
    `algorithm=${algorithm}`,
  ];
  if (opts.qop) {
    parts.push(`qop=${opts.qop}`);
    if (opts.nc) parts.push(`nc=${opts.nc}`);
    if (opts.cnonce) parts.push(`cnonce="${q(opts.cnonce)}"`);
  }
  if (opts.opaque) parts.push(`opaque="${q(opts.opaque)}"`);
  return `Digest ${parts.join(", ")}`;
}

/**
 * Parses a Digest challenge from the server's WWW-Authenticate header.
 * Returns the directive map (realm/nonce/qop/etc.) for a client to feed
 * into `computeDigestAuthorization`.
 */
export function parseDigestChallenge(header: string): Map<string, string> | null {
  return parseDigestAuthorization(header);
}

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
    if (auth === PROTECTED_BEARER_TOKEN || auth === REFRESHED_ACCESS_TOKEN) {
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
  // OAuth-style refresh token exchange.
  //
  // Request:  POST /oauth/token   application/x-www-form-urlencoded
  //           grant_type=refresh_token&refresh_token=<token>
  // Response: 200 application/json { access_token, token_type, expires_in }
  //           or 400 { error: "invalid_grant" } on bad refresh_token.
  //
  // The fresh access token is `REFRESHED_ACCESS_TOKEN` — `/api/protected`
  // accepts BOTH `PROTECTED_BEARER_TOKEN` and `REFRESHED_ACCESS_TOKEN`, so
  // a test driving the "expired token → refresh → retry" flow can:
  //   1. recordExpiredToken(PROTECTED_BEARER_TOKEN)
  //   2. fetch /api/protected with PROTECTED_BEARER_TOKEN  → 401 token_expired
  //   3. POST /oauth/token with REFRESH_TOKEN              → 200 access_token
  //   4. fetch /api/protected with REFRESHED_ACCESS_TOKEN  → 200
  // This is *not* a full OAuth implementation — there's no client_id, no
  // PKCE, no token rotation, no scope handling. It's the minimum surface
  // that makes the refresh round-trip exerciseable end-to-end.
  if (url.pathname === "/oauth/token") {
    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "access-control-allow-origin": appOrigin,
        "access-control-allow-methods": "POST",
        "access-control-allow-headers": "content-type",
        "access-control-allow-credentials": "true",
        "access-control-max-age": "600",
      });
      res.end();
      return;
    }
    if (req.method !== "POST") {
      res.writeHead(405);
      res.end();
      return;
    }
    const corsHeaders = corsHeadersForOrigin(origin, appOrigin);
    readBody(req).then(body => {
      const params = new URLSearchParams(body);
      const grant = params.get("grant_type");
      const refresh = params.get("refresh_token");
      if (grant !== "refresh_token" || refresh !== REFRESH_TOKEN) {
        res.writeHead(400, {
          "content-type": "application/json",
          ...corsHeaders,
        });
        res.end(JSON.stringify({ error: "invalid_grant" }));
        return;
      }
      // Strip the "Bearer " prefix in the response body — clients reattach
      // it themselves when setting the Authorization header. This mirrors
      // RFC 6749 §5.1.
      const access = REFRESHED_ACCESS_TOKEN.replace(/^Bearer /, "");
      res.writeHead(200, {
        "content-type": "application/json",
        ...corsHeaders,
      });
      res.end(
        JSON.stringify({
          access_token: access,
          token_type: "Bearer",
          expires_in: 3600,
        }),
      );
    });
    return;
  }
  // RFC 7616 §3 HTTP Digest Access Authentication.
  //
  // Endpoint: GET /digest/protected
  //
  // Without a matching Authorization header, returns:
  //   401 + WWW-Authenticate: Digest realm="...", qop="auth",
  //                                  nonce="<server nonce>", algorithm=MD5
  // With a valid Authorization: Digest header (correct response per
  // RFC 7616 §3.4.1) returns 200 + JSON.
  //
  // !! NOT A REFERENCE IMPLEMENTATION FOR DIGEST !!
  //
  // This fixture deliberately omits replay protection so tests can recompute
  // a response with whatever nonce/nc/cnonce values they want. Specifically:
  //   - The server does not remember the nonces it has issued, so any
  //     well-formed Authorization that hashes correctly against ITS OWN
  //     supplied nonce is accepted. A response computed against an old
  //     captured nonce is indistinguishable from a fresh one.
  //   - `nc` (nonce-count) is read but not enforced for monotonic increase.
  //   - `opaque` is issued but ignored on the response.
  //   - `cnonce` is read but not constrained for uniqueness.
  // A production server MUST cycle nonces with a server-managed validity
  // window, remember the (nonce, nc) pairs it has seen, and require the
  // client to echo back the exact `opaque` it issued — none of which this
  // fixture does. Do NOT model production Digest code after this endpoint.
  //
  // Algorithms: both MD5 (RFC 7616 baseline) and SHA-256 are accepted.
  // Unknown algorithm strings are rejected (see `normalizeDigestAlgorithm`).
  if (url.pathname === "/digest/protected") {
    const corsHeaders = corsHeadersForOrigin(origin, appOrigin);
    const auth = req.headers["authorization"];
    if (typeof auth === "string" && auth.startsWith("Digest ")) {
      const verified = verifyDigestAuthorization(auth, req.method ?? "GET");
      if (verified) {
        res.writeHead(200, {
          "content-type": "application/json",
          ...corsHeaders,
        });
        res.end(JSON.stringify({ user: verified.username, digest: true }));
        return;
      }
    }
    // No Authorization or verification failed: issue a fresh challenge.
    const nonce = randomBytes(16).toString("hex");
    const opaque = randomBytes(8).toString("hex");
    res.writeHead(401, {
      "content-type": "text/plain",
      "www-authenticate":
        `Digest realm="${DIGEST_REALM}", qop="auth", nonce="${nonce}", ` +
        `opaque="${opaque}", algorithm=MD5`,
      ...corsHeaders,
    });
    res.end("digest authentication required");
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
