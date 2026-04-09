import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  BIDI_URL_ENV,
  BIDI_URL_FILE_NAME,
  DEFAULT_BIDI_WS_URL,
  readBidiUrlFile,
  resolveBidiUrl,
} from "./bidi-url";

const tempDirs: string[] = [];

function makeTempDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "crater-bidi-url-"));
  tempDirs.push(dir);
  return dir;
}

function createFetchImpl(payload: unknown, ok = true): typeof fetch {
  return (async () => ({
    ok,
    json: async () => payload,
  })) as typeof fetch;
}

afterEach(() => {
  while (tempDirs.length > 0) {
    const dir = tempDirs.pop();
    if (dir) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }
});

describe("readBidiUrlFile", () => {
  it("returns null when the file does not exist", () => {
    const cwd = makeTempDir();
    expect(readBidiUrlFile({ cwd })).toBeNull();
  });

  it("reads a websocket URL from the tracked file", () => {
    const cwd = makeTempDir();
    fs.writeFileSync(
      path.join(cwd, BIDI_URL_FILE_NAME),
      "ws://127.0.0.1:9222/session/from-file\n",
    );

    expect(readBidiUrlFile({ cwd })).toBe("ws://127.0.0.1:9222/session/from-file");
  });
});

describe("resolveBidiUrl", () => {
  it("prefers CRATER_BIDI_URL over status and file fallbacks", async () => {
    const cwd = makeTempDir();
    fs.writeFileSync(
      path.join(cwd, BIDI_URL_FILE_NAME),
      "ws://127.0.0.1:9222/session/stale",
    );

    const url = await resolveBidiUrl({
      cwd,
      env: { [BIDI_URL_ENV]: "ws://127.0.0.1:9222/session/from-env" },
      fetchImpl: createFetchImpl({ webSocketUrl: "ws://127.0.0.1:9222/session/from-status" }),
    });

    expect(url).toBe("ws://127.0.0.1:9222/session/from-env");
  });

  it("prefers the live status endpoint over a stale bidi url file", async () => {
    const cwd = makeTempDir();
    fs.writeFileSync(
      path.join(cwd, BIDI_URL_FILE_NAME),
      "ws://127.0.0.1:9222/session/stale",
    );

    const url = await resolveBidiUrl({
      cwd,
      fetchImpl: createFetchImpl({ webSocketUrl: "ws://127.0.0.1:9222/session/live" }),
    });

    expect(url).toBe("ws://127.0.0.1:9222/session/live");
  });

  it("uses the default websocket URL when an older ready endpoint has no tokenized url", async () => {
    const cwd = makeTempDir();
    fs.writeFileSync(
      path.join(cwd, BIDI_URL_FILE_NAME),
      "ws://127.0.0.1:9222/session/stale",
    );

    const url = await resolveBidiUrl({
      cwd,
      fetchImpl: createFetchImpl({ ready: true, message: "legacy server" }),
    });

    expect(url).toBe(DEFAULT_BIDI_WS_URL);
  });

  it("falls back to the tracked file when the status endpoint is unavailable", async () => {
    const cwd = makeTempDir();
    fs.writeFileSync(
      path.join(cwd, BIDI_URL_FILE_NAME),
      "ws://127.0.0.1:9222/session/from-file",
    );

    const url = await resolveBidiUrl({
      cwd,
      fetchImpl: (async () => {
        throw new Error("connection refused");
      }) as typeof fetch,
    });

    expect(url).toBe("ws://127.0.0.1:9222/session/from-file");
  });

  it("falls back to the default websocket URL when no discovery source succeeds", async () => {
    const cwd = makeTempDir();

    const url = await resolveBidiUrl({
      cwd,
      fetchImpl: (async () => {
        throw new Error("connection refused");
      }) as typeof fetch,
    });

    expect(url).toBe(DEFAULT_BIDI_WS_URL);
  });
});
