import { describe, expect, it } from "vitest";
import {
  CraterBrowser,
  CraterBrowserType,
  chromium,
} from "../webdriver/playwright/adapter.ts";

describe("CraterBrowserType", () => {
  it("exposes a chromium.launch-compatible entrypoint without starting a server when disabled", async () => {
    const browser = await chromium.launch({
      autoStartBidi: false,
      url: "ws://127.0.0.1:9222/session/test",
    });

    expect(browser).toBeInstanceOf(CraterBrowser);
    await browser.close();
  });

  it("closes the managed BiDi server when a launched browser closes", async () => {
    let closed = false;
    const browserType = new CraterBrowserType("chromium", {
      ensureBidiServer: async () => ({
        url: "ws://127.0.0.1:9222/session/managed",
        process: null,
        close: async () => {
          closed = true;
        },
      }),
    });

    const browser = await browserType.launch();
    expect(browser).toBeInstanceOf(CraterBrowser);

    await browser.close();
    expect(closed).toBe(true);
  });

  it("starts and closes a managed BiDi server for each isolated browser context", async () => {
    let starts = 0;
    let nextPort = 19330;
    const closed: string[] = [];
    const serverOptions: Array<{ envPort?: string; statusUrl?: string; readUrlFile?: boolean }> = [];
    const browserType = new CraterBrowserType("chromium", {
      allocateBidiPort: async () => {
        nextPort += 1;
        return nextPort;
      },
      ensureBidiServer: async (options) => {
        starts += 1;
        const id = `ctx-${starts}`;
        serverOptions.push({
          envPort: options?.env?.CRATER_BIDI_PORT,
          statusUrl: options?.statusUrl,
          readUrlFile: options?.readUrlFile,
        });
        return {
          url: `ws://127.0.0.1:${options?.env?.CRATER_BIDI_PORT}/session/${id}`,
          process: null,
          close: async () => {
            closed.push(id);
          },
        };
      },
    });

    const browser = await browserType.launch({ isolateContexts: true });
    expect(browser).toBeInstanceOf(CraterBrowser);
    expect(starts).toBe(0);

    const contextA = await browser.newContext();
    const contextB = await browser.newContext();
    expect(starts).toBe(2);
    expect(serverOptions).toEqual([
      {
        envPort: "19331",
        statusUrl: "http://127.0.0.1:19331/",
        readUrlFile: false,
      },
      {
        envPort: "19332",
        statusUrl: "http://127.0.0.1:19332/",
        readUrlFile: false,
      },
    ]);

    await contextA.close();
    expect(closed).toEqual(["ctx-1"]);

    await browser.close();
    expect(closed).toEqual(["ctx-1", "ctx-2"]);
  });
});
