import { test, expect } from "vitest";
import { startAuthServer } from "./auth-server.ts";

test("login + dashboard round-trip", async () => {
  const { url, stop } = await startAuthServer({ port: 0 });
  try {
    const login = await fetch(`${url}/login`, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ user: "alice", pass: "wonderland" }),
      redirect: "manual",
    });
    expect(login.status).toBe(302);
    const cookie = login.headers.get("set-cookie")!;
    expect(cookie).toContain("session=");

    const dashboard = await fetch(`${url}/dashboard`, {
      headers: { cookie },
    });
    expect(dashboard.status).toBe(200);
    expect(await dashboard.text()).toContain("welcome alice");

    const noCookie = await fetch(`${url}/dashboard`);
    expect(noCookie.status).toBe(401);
  } finally {
    await stop();
  }
});

test("recordSession seeds a session id that /dashboard accepts", async () => {
  const { url, stop, recordSession, forgetSession } = await startAuthServer({ port: 0 });
  try {
    recordSession("s_seeded", "alice");
    const ok = await fetch(`${url}/dashboard`, { headers: { cookie: "session=s_seeded" } });
    expect(ok.status).toBe(200);
    expect(await ok.text()).toContain("welcome alice");

    forgetSession("s_seeded");
    const gone = await fetch(`${url}/dashboard`, { headers: { cookie: "session=s_seeded" } });
    expect(gone.status).toBe(401);
  } finally {
    await stop();
  }
});

test("cross-origin /api/me requires ACA-Origin and ACA-Credentials", async () => {
  const { url, stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const preflight = await fetch(`${apiUrl}/me`, {
      method: "OPTIONS",
      headers: {
        origin: url,
        "access-control-request-method": "GET",
        "access-control-request-headers": "x-csrf",
      },
    });
    expect(preflight.headers.get("access-control-allow-origin")).toBe(url);
    expect(preflight.headers.get("access-control-allow-credentials")).toBe("true");
  } finally {
    await stop();
    await apiStop();
  }
});
