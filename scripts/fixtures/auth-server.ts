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

const SESSIONS = new Map<string, string>();   // session-id → username

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

function handleApp(req: IncomingMessage, res: ServerResponse): Promise<void> {
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
        SESSIONS.set(id, "alice");
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
      const who = sid ? SESSIONS.get(sid) : undefined;
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

function handleApi(req: IncomingMessage, res: ServerResponse, appOrigin: string): void {
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
      // Deliberately omit ACA headers so Crater's CORS gate blocks.
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ user: "alice" }));
    }
    return;
  }
  res.writeHead(404);
  res.end();
}

export async function startAuthServer(opts: StartOptions = {}): Promise<StartResult> {
  const appServer = http.createServer((req, res) => { handleApp(req, res).catch(() => res.end()); });
  await new Promise<void>(r => appServer.listen(opts.port ?? 0, "127.0.0.1", r));
  const appPort = (appServer.address() as AddressInfo).port;
  const appUrl = `http://127.0.0.1:${appPort}`;

  const apiServer = http.createServer((req, res) => handleApi(req, res, appUrl));
  await new Promise<void>(r => apiServer.listen(opts.apiPort ?? 0, "127.0.0.1", r));
  const apiPort = (apiServer.address() as AddressInfo).port;
  const apiUrl = `http://127.0.0.1:${apiPort}`;

  return {
    url: appUrl,
    apiUrl,
    stop: () => new Promise(r => appServer.close(() => r())),
    apiStop: () => new Promise(r => apiServer.close(() => r())),
    recordSession: (sid: string, user: string) => {
      SESSIONS.set(sid, user);
    },
    forgetSession: (sid: string) => {
      SESSIONS.delete(sid);
    },
  };
}
