import { randomBytes } from "node:crypto";
import { test, expect } from "vitest";
import {
  DIGEST_PASSWORD,
  DIGEST_REALM,
  DIGEST_USERNAME,
  REFRESHED_ACCESS_TOKEN,
  REFRESH_TOKEN,
  computeDigestAuthorization,
  parseDigestChallenge,
  startAuthServer,
} from "./auth-server.ts";

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

test("GET /api/protected returns 200 + JSON with correct Bearer token", async () => {
  const { url, stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const ok = await fetch(`${apiUrl}/api/protected`, {
      headers: {
        // secretlint-disable-next-line @secretlint/secretlint-rule-pattern
        authorization: "Bearer test-jwt-token",
        origin: url,
      },
    });
    expect(ok.status).toBe(200);
    expect(ok.headers.get("content-type")).toContain("application/json");
    expect(ok.headers.get("access-control-allow-origin")).toBe(url);
    const body = (await ok.json()) as { user: string; protected: boolean };
    expect(body).toEqual({ user: "alice", protected: true });
  } finally {
    await stop();
    await apiStop();
  }
});

test("GET /api/protected returns 401 without Authorization header", async () => {
  const { stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const res = await fetch(`${apiUrl}/api/protected`);
    expect(res.status).toBe(401);
    expect(await res.text()).toContain("missing or invalid token");
  } finally {
    await stop();
    await apiStop();
  }
});

test("GET /api/protected returns 401 with wrong Bearer token", async () => {
  const { stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const res = await fetch(`${apiUrl}/api/protected`, {
      // secretlint-disable-next-line @secretlint/secretlint-rule-pattern
      headers: { authorization: "Bearer wrong-token" },
    });
    expect(res.status).toBe(401);
    expect(await res.text()).toContain("missing or invalid token");
  } finally {
    await stop();
    await apiStop();
  }
});

test("recordExpiredToken makes /api/protected return 401 token_expired", async () => {
  const { url, stop, apiUrl, apiStop, recordExpiredToken, forgetExpiredToken } =
    await startAuthServer({ port: 0, apiPort: 0 });
  try {
    // secretlint-disable-next-line @secretlint/secretlint-rule-pattern
    const token = "Bearer test-jwt-token";
    recordExpiredToken(token);

    const expired = await fetch(`${apiUrl}/api/protected`, {
      headers: { authorization: token, origin: url },
    });
    expect(expired.status).toBe(401);
    expect(expired.headers.get("www-authenticate")).toContain("invalid_token");
    expect(expired.headers.get("content-type")).toContain("application/json");
    const body = (await expired.json()) as { error: string };
    expect(body).toEqual({ error: "token_expired" });

    // After forgetting the expired marker, the same token works again.
    forgetExpiredToken(token);
    const ok = await fetch(`${apiUrl}/api/protected`, {
      headers: { authorization: token, origin: url },
    });
    expect(ok.status).toBe(200);
  } finally {
    await stop();
    await apiStop();
  }
});

test("/api/echo-auth returns received Cookie and Authorization headers", async () => {
  const { url, stop, apiUrl, apiStop } = await startAuthServer({
    port: 0,
    apiPort: 0,
  });
  try {
    const res = await fetch(`${apiUrl}/api/echo-auth`, {
      headers: {
        // secretlint-disable-next-line @secretlint/secretlint-rule-pattern
        authorization: "Bearer test-jwt-token",
        cookie: "session=s_abc",
        origin: url,
      },
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("access-control-allow-origin")).toBe(url);
    const body = (await res.json()) as { cookie: string | null; authorization: string | null };
    expect(body.cookie).toBe("session=s_abc");
    // secretlint-disable-next-line @secretlint/secretlint-rule-pattern
    expect(body.authorization).toBe("Bearer test-jwt-token");
  } finally {
    await stop();
    await apiStop();
  }
});

test("shadow API on optional 3rd port gates on its own Bearer token", async () => {
  const fixture = await startAuthServer({ port: 0, apiPort: 0, shadowPort: 0 });
  try {
    expect(fixture.shadowUrl).not.toBeNull();
    const ok = await fetch(`${fixture.shadowUrl}/api/v2/data`, {
      headers: {
        // secretlint-disable-next-line @secretlint/secretlint-rule-pattern
        authorization: "Bearer shadow-token-v2",
        origin: fixture.url,
      },
    });
    expect(ok.status).toBe(200);
    expect(ok.headers.get("access-control-allow-origin")).toBe(fixture.url);
    expect(await ok.json()).toEqual({ shadow: true, source: "v2" });

    // The main /api/protected token must NOT unlock the shadow endpoint
    // — that's the entire point of "multi-origin routing".
    const wrong = await fetch(`${fixture.shadowUrl}/api/v2/data`, {
      headers: {
        // secretlint-disable-next-line @secretlint/secretlint-rule-pattern
        authorization: "Bearer test-jwt-token",
        origin: fixture.url,
      },
    });
    expect(wrong.status).toBe(401);
  } finally {
    await fixture.stop();
    await fixture.apiStop();
    await fixture.shadowStop();
  }
});

test("shadowStop is a no-op when shadowPort was not requested", async () => {
  const fixture = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    expect(fixture.shadowUrl).toBeNull();
    await fixture.shadowStop(); // must not throw
  } finally {
    await fixture.stop();
    await fixture.apiStop();
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

test("cross-origin redirect strips Authorization per Fetch spec", async () => {
  // Per https://fetch.spec.whatwg.org/#http-redirect-fetch step 13: when a
  // redirect crosses origins, CORS non-wildcard request-header names —
  // including Authorization — must be deleted from the request before the
  // follow-up fetch. Node's undici implementation follows this.
  //
  // Setup: app server's /redirect-cross-origin returns 302 to the api
  // server's /api/echo-auth. The echo endpoint reports back the headers
  // it actually saw, so we can assert that Authorization was dropped on
  // the redirect hop.
  const { url, stop, apiStop } = await startAuthServer();
  try {
    const response = await fetch(`${url}/redirect-cross-origin`, {
      headers: { authorization: "Bearer should-be-stripped" },
      redirect: "follow",
    });
    expect(response.status).toBe(200);
    const echoed = (await response.json()) as { authorization: string | null };
    // The api server saw no Authorization — Node/undici stripped it across origins.
    expect(echoed.authorization).toBeNull();
  } finally {
    await stop();
    await apiStop();
  }
});

test("/oauth/token rejects bogus refresh_token with invalid_grant", async () => {
  const { stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const res = await fetch(`${apiUrl}/oauth/token`, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token: "not-the-real-token",
      }),
    });
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: "invalid_grant" });
  } finally {
    await stop();
    await apiStop();
  }
});

test("/oauth/token exchanges valid refresh_token for a fresh Bearer", async () => {
  const { stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const res = await fetch(`${apiUrl}/oauth/token`, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token: REFRESH_TOKEN,
      }),
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toContain("application/json");
    const body = (await res.json()) as {
      access_token: string;
      token_type: string;
      expires_in: number;
    };
    expect(body.token_type).toBe("Bearer");
    expect(`Bearer ${body.access_token}`).toBe(REFRESHED_ACCESS_TOKEN);
    expect(body.expires_in).toBeGreaterThan(0);
  } finally {
    await stop();
    await apiStop();
  }
});

test("refresh-token round-trip: expired Bearer -> refresh -> retry succeeds", async () => {
  // End-to-end shape: simulate a client whose Bearer was revoked. The
  // server marks the original token as expired, the client posts to
  // /oauth/token to get a fresh Bearer, and the retry succeeds with the
  // new header. Models the full "401 -> refresh -> 200" loop a real
  // OAuth client would run.
  const fixture = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    // secretlint-disable-next-line @secretlint/secretlint-rule-pattern
    const staleBearer = "Bearer test-jwt-token";
    fixture.recordExpiredToken(staleBearer);

    const stale = await fetch(`${fixture.apiUrl}/api/protected`, {
      headers: { authorization: staleBearer, origin: fixture.url },
    });
    expect(stale.status).toBe(401);
    expect(stale.headers.get("www-authenticate")).toContain("invalid_token");
    expect(await stale.json()).toEqual({ error: "token_expired" });

    const refreshed = await fetch(`${fixture.apiUrl}/oauth/token`, {
      method: "POST",
      headers: {
        "content-type": "application/x-www-form-urlencoded",
        origin: fixture.url,
      },
      body: new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token: REFRESH_TOKEN,
      }),
    });
    expect(refreshed.status).toBe(200);
    const refreshedBody = (await refreshed.json()) as { access_token: string };
    const freshBearer = `Bearer ${refreshedBody.access_token}`;
    expect(freshBearer).toBe(REFRESHED_ACCESS_TOKEN);

    const retry = await fetch(`${fixture.apiUrl}/api/protected`, {
      headers: { authorization: freshBearer, origin: fixture.url },
    });
    expect(retry.status).toBe(200);
    expect(await retry.json()).toEqual({ user: "alice", protected: true });
  } finally {
    await fixture.stop();
    await fixture.apiStop();
  }
});

test("same-origin redirect preserves Authorization", async () => {
  // Companion to the cross-origin strip test: when the redirect target is
  // on the SAME origin, Authorization must survive. Confirms the strip is
  // origin-scoped, not blanket.
  const { url, stop, apiStop } = await startAuthServer();
  try {
    const response = await fetch(`${url}/redirect-same-origin`, {
      headers: { authorization: "Bearer survives-same-origin" },
      redirect: "follow",
    });
    expect(response.status).toBe(200);
    const echoed = (await response.json()) as { authorization: string | null };
    expect(echoed.authorization).toBe("Bearer survives-same-origin");
  } finally {
    await stop();
    await apiStop();
  }
});

test("/digest/protected issues a Digest challenge without Authorization", async () => {
  const { stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const res = await fetch(`${apiUrl}/digest/protected`);
    expect(res.status).toBe(401);
    const www = res.headers.get("www-authenticate");
    expect(www).not.toBeNull();
    expect(www).toContain("Digest ");
    expect(www).toContain(`realm="${DIGEST_REALM}"`);
    expect(www).toContain('qop="auth"');
    expect(www).toMatch(/nonce="[a-f0-9]+"/);
    expect(www).toMatch(/algorithm=MD5/);
  } finally {
    await stop();
    await apiStop();
  }
});

test("/digest/protected accepts a correctly computed MD5 Digest response", async () => {
  const { stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    // First request: trigger the challenge so we get a fresh nonce.
    const challengeRes = await fetch(`${apiUrl}/digest/protected`);
    expect(challengeRes.status).toBe(401);
    const www = challengeRes.headers.get("www-authenticate")!;
    const challenge = parseDigestChallenge(www)!;
    expect(challenge.get("realm")).toBe(DIGEST_REALM);

    const uri = "/digest/protected";
    const authHeader = computeDigestAuthorization({
      username: DIGEST_USERNAME,
      password: DIGEST_PASSWORD,
      realm: challenge.get("realm")!,
      nonce: challenge.get("nonce")!,
      uri,
      method: "GET",
      qop: challenge.get("qop"),
      nc: "00000001",
      cnonce: randomBytes(8).toString("hex"),
      algorithm: challenge.get("algorithm") ?? "MD5",
      opaque: challenge.get("opaque"),
    });

    const ok = await fetch(`${apiUrl}${uri}`, {
      headers: { authorization: authHeader },
    });
    expect(ok.status).toBe(200);
    expect(ok.headers.get("content-type")).toContain("application/json");
    const body = (await ok.json()) as { user: string; digest: boolean };
    expect(body).toEqual({ user: DIGEST_USERNAME, digest: true });
  } finally {
    await stop();
    await apiStop();
  }
});

test("/digest/protected accepts SHA-256 algorithm", async () => {
  const { stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const challengeRes = await fetch(`${apiUrl}/digest/protected`);
    const www = challengeRes.headers.get("www-authenticate")!;
    const challenge = parseDigestChallenge(www)!;
    const uri = "/digest/protected";
    const authHeader = computeDigestAuthorization({
      username: DIGEST_USERNAME,
      password: DIGEST_PASSWORD,
      realm: challenge.get("realm")!,
      nonce: challenge.get("nonce")!,
      uri,
      method: "GET",
      qop: challenge.get("qop"),
      nc: "00000001",
      cnonce: randomBytes(8).toString("hex"),
      algorithm: "SHA-256", // override the server-advertised MD5
    });

    const ok = await fetch(`${apiUrl}${uri}`, {
      headers: { authorization: authHeader },
    });
    expect(ok.status).toBe(200);
  } finally {
    await stop();
    await apiStop();
  }
});

test("/digest/protected rejects a Digest response with wrong password", async () => {
  const { stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const challengeRes = await fetch(`${apiUrl}/digest/protected`);
    const www = challengeRes.headers.get("www-authenticate")!;
    const challenge = parseDigestChallenge(www)!;
    const uri = "/digest/protected";
    const authHeader = computeDigestAuthorization({
      username: DIGEST_USERNAME,
      password: "wrong-password",
      realm: challenge.get("realm")!,
      nonce: challenge.get("nonce")!,
      uri,
      method: "GET",
      qop: challenge.get("qop"),
      nc: "00000001",
      cnonce: randomBytes(8).toString("hex"),
      algorithm: "MD5",
    });

    const denied = await fetch(`${apiUrl}${uri}`, {
      headers: { authorization: authHeader },
    });
    expect(denied.status).toBe(401);
    // Server should re-issue a fresh challenge so the client knows to retry
    // with corrected credentials. (Real servers might emit `stale=true` to
    // distinguish nonce-stale vs credential-wrong; the fixture doesn't.)
    expect(denied.headers.get("www-authenticate")).toContain("Digest ");
  } finally {
    await stop();
    await apiStop();
  }
});

test("/digest/protected rejects RFC 2069 (no-qop) form with wrong response", async () => {
  // RFC 2069 backward-compat shape: HASH(HA1:nonce:HA2) without qop/nc/cnonce.
  // The server accepts the no-qop response form when qop is omitted by the
  // client; this case proves the verification still rejects a bogus response
  // string, not just qop-mode requests.
  const { stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const challengeRes = await fetch(`${apiUrl}/digest/protected`);
    const challenge = parseDigestChallenge(challengeRes.headers.get("www-authenticate")!)!;
    const uri = "/digest/protected";
    // Craft a header that LOOKS valid but with a hand-rolled (wrong) response.
    const bogus =
      `Digest username="${DIGEST_USERNAME}", realm="${challenge.get("realm")}", ` +
      `nonce="${challenge.get("nonce")}", uri="${uri}", ` +
      `response="0000000000000000000000000000000000000000000000000000000000000000", ` +
      `algorithm=MD5`;
    const denied = await fetch(`${apiUrl}${uri}`, {
      headers: { authorization: bogus },
    });
    expect(denied.status).toBe(401);
  } finally {
    await stop();
    await apiStop();
  }
});
