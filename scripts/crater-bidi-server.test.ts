import { describe, expect, it } from "vitest";
import {
  buildCraterBidiServerCommand,
  waitForCraterBidiUrl,
} from "./crater-bidi-server";

describe("buildCraterBidiServerCommand", () => {
  it("builds a Deno start-with-font command rooted at the Crater repository", () => {
    const command = buildCraterBidiServerCommand({
      craterRoot: "/repo/crater",
      denoBin: "deno2",
      env: { PATH: "/bin" },
    });

    expect(command).toEqual({
      command: "deno2",
      args: ["run", "-A", "/repo/crater/webdriver/bidi_main/start-with-font.ts"],
      cwd: "/repo/crater",
      env: { PATH: "/bin" },
    });
  });
});

describe("waitForCraterBidiUrl", () => {
  it("polls until a discovered websocket URL is available", async () => {
    let attempts = 0;

    const url = await waitForCraterBidiUrl({
      timeoutMs: 100,
      pollIntervalMs: 1,
      discoverBidiUrlImpl: async () => {
        attempts += 1;
        return attempts < 3 ? null : "ws://127.0.0.1:9222/session/ready";
      },
    });

    expect(url).toBe("ws://127.0.0.1:9222/session/ready");
    expect(attempts).toBe(3);
  });

  it("fails when no websocket URL appears before the timeout", async () => {
    await expect(
      waitForCraterBidiUrl({
        timeoutMs: 5,
        pollIntervalMs: 1,
        discoverBidiUrlImpl: async () => null,
      }),
    ).rejects.toThrow(/Timed out waiting for Crater BiDi server/);
  });
});
