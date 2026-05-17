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

type StartOptions = { port?: number; apiPort?: number };
type StartResult = {
  url: string;
  stop: () => Promise<void>;
  apiUrl: string;
  apiStop: () => Promise<void>;
  /**
   * Seed the in-memory session table directly. Used by BiDi flow tests that
   * inject a cookie via `storage.setCookie` rather than driving the login form
   * (Crater currently lacks `HTMLFormElement.submit` / `document.forms`).
   */
  recordSession: (sid: string, user: string) => void;
  /** Drop a previously-seeded session id. */
  forgetSession: (sid: string) => void;
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
): Promise<void> {
  return (async () => {
    const url = new URL(req.url ?? "/", `http://${req.headers.host}`);
    if (url.pathname === "/login" && req.method === "GET") {
      res.writeHead(200, { "content-type": "text/html" });
      res.end(loginPageHtml());
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

function handleApi(
  req: IncomingMessage,
  res: ServerResponse,
  appOrigin: string,
  sessions: Map<string, string>,
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
  void sessions; // sessions available for future authenticated /api/* routes
  res.writeHead(404);
  res.end();
}

export async function startAuthServer(opts: StartOptions = {}): Promise<StartResult> {
  // Scoped per startAuthServer call so vitest --pool=threads can't share state
  // across parallel test files. (M6 in PR #131 security review.)
  const sessions = new Map<string, string>();   // session-id → username

  const appServer = http.createServer((req, res) => {
    handleApp(req, res, sessions).catch(() => res.end());
  });
  await new Promise<void>(r => appServer.listen(opts.port ?? 0, "127.0.0.1", r));
  const appPort = (appServer.address() as AddressInfo).port;
  const appUrl = `http://127.0.0.1:${appPort}`;

  const apiServer = http.createServer((req, res) => handleApi(req, res, appUrl, sessions));
  await new Promise<void>(r => apiServer.listen(opts.apiPort ?? 0, "127.0.0.1", r));
  const apiPort = (apiServer.address() as AddressInfo).port;
  const apiUrl = `http://127.0.0.1:${apiPort}`;

  return {
    url: appUrl,
    apiUrl,
    stop: () => new Promise(r => appServer.close(() => r())),
    apiStop: () => new Promise(r => apiServer.close(() => r())),
    recordSession: (sid: string, user: string) => {
      if (!sid) throw new Error("sid required");
      sessions.set(sid, user);
    },
    forgetSession: (sid: string) => {
      sessions.delete(sid);
    },
  };
}
