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
});
