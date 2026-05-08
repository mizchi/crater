import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { deflateSync } from "node:zlib";
import { describe, expect, it } from "vitest";
import {
  ComponentVrtAssetCache,
  captureComponentScreenshot,
  cropPngToClip,
  installComponentVrtAssetCache,
  normalizeComponentClip,
  parseComponentVrtArgs,
  runComponentVrtScenario,
  runComponentVrtSuite,
} from "./component-vrt";

class FakeRoutePage {
  handler: ((route: FakeRoute) => Promise<void> | void) | null = null;
  matcher: unknown = null;
  unrouteCalls: Array<{ matcher: unknown; handler?: unknown }> = [];

  async route(matcher: unknown, handler: (route: FakeRoute) => Promise<void> | void): Promise<void> {
    this.matcher = matcher;
    this.handler = handler;
  }

  async unroute(matcher: unknown, handler?: unknown): Promise<void> {
    this.unrouteCalls.push({ matcher, handler });
  }

  async request(url: string, method = "GET"): Promise<FakeRoute> {
    if (!this.handler) {
      throw new Error("route handler is not installed");
    }
    const route = new FakeRoute(url, method);
    await this.handler(route);
    return route;
  }
}

class FakeRoute {
  actions: Array<{ action: string; options?: unknown }> = [];

  constructor(
    private readonly requestUrl: string,
    private readonly requestMethod: string,
  ) {}

  request(): { url: () => string; method: () => string } {
    return {
      method: () => this.requestMethod,
      url: () => this.requestUrl,
    };
  }

  async fulfill(options: unknown): Promise<void> {
    this.actions.push({ action: "fulfill", options });
  }

  async continue(): Promise<void> {
    this.actions.push({ action: "continue" });
  }
}

class FakeComponentPage {
  viewport: { width: number; height: number } | null = null;
  html: string | null = null;
  gotoUrl: string | null = null;
  waitSelectors: string[] = [];
  locatorCalls: string[] = [];
  screenshotOptions: unknown[] = [];

  async setViewport(width: number, height: number): Promise<void> {
    this.viewport = { width, height };
  }

  async setContent(html: string): Promise<void> {
    this.html = html;
  }

  async goto(url: string): Promise<void> {
    this.gotoUrl = url;
  }

  locator(selector: string): { waitFor: () => Promise<void>; scrollIntoViewIfNeeded: () => Promise<void> } {
    this.locatorCalls.push(selector);
    return {
      scrollIntoViewIfNeeded: async () => {},
      waitFor: async () => {},
    };
  }

  async waitForSelector(selector: string): Promise<void> {
    this.waitSelectors.push(selector);
  }

  async waitForTimeout(_timeout: number): Promise<void> {}

  async evaluate<T>(): Promise<T> {
    return {
      height: 40,
      width: 120,
      x: 8,
      y: 16,
    } as T;
  }

  async screenshot(options: unknown): Promise<Buffer> {
    this.screenshotOptions.push(options);
    return Buffer.from("png");
  }
}

class FakeComputedStylePage extends FakeComponentPage {
  override async evaluate<T>(): Promise<T> {
    return {
      height: 3,
      width: 3,
      x: 10,
      y: 5,
    } as T;
  }

  async getComputedStylesForElement(): Promise<Record<string, string>> {
    return {
      height: "80px",
      padding: "8px",
      width: "160px",
    };
  }
}

class FakeComputedStyleAtViewportOriginPage extends FakeComputedStylePage {
  override async evaluate<T>(): Promise<T> {
    return {
      height: 3,
      viewport: {
        height: 220,
        width: 360,
      },
      width: 3,
      x: 0,
      y: 0,
    } as T;
  }
}

function pngChunk(type: string, data: Buffer): Buffer {
  const typeBytes = Buffer.from(type, "ascii");
  const chunk = Buffer.alloc(12 + data.length);
  chunk.writeUInt32BE(data.length, 0);
  typeBytes.copy(chunk, 4);
  data.copy(chunk, 8);
  chunk.writeUInt32BE(crc32(Buffer.concat([typeBytes, data])), 8 + data.length);
  return chunk;
}

function crc32(input: Buffer): number {
  let crc = 0xffffffff;
  for (const byte of input) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function tinyPalettePng(): Buffer {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(2, 0);
  ihdr.writeUInt32BE(1, 4);
  ihdr[8] = 8;
  ihdr[9] = 3;
  const palette = Buffer.from([
    255,
    0,
    0,
    0,
    128,
    0,
  ]);
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    pngChunk("IHDR", ihdr),
    pngChunk("PLTE", palette),
    pngChunk("IDAT", deflateSync(Buffer.from([0, 0, 1]))),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
}

describe("ComponentVrtAssetCache", () => {
  it("prefetches cacheable text assets", async () => {
    const cache = new ComponentVrtAssetCache();
    const result = await cache.prefetch(["https://example.test/assets/app.css"], {
      fetch: async () =>
        new Response("body { color: red; }", {
          headers: {
            "cache-control": "max-age=3600",
            "content-type": "text/css; charset=utf-8",
          },
          status: 200,
        }),
    });

    expect(result).toEqual({
      cached: 1,
      failed: 0,
      skipped: 0,
      total: 1,
    });
    expect(cache.get("https://example.test/assets/app.css")).toMatchObject({
      body: "body { color: red; }",
      contentType: "text/css; charset=utf-8",
      status: 200,
    });
  });

  it("skips no-store responses and binary content types", async () => {
    const cache = new ComponentVrtAssetCache();
    const result = await cache.prefetch([
      "https://example.test/private.css",
      "https://example.test/image.png",
    ], {
      fetch: async (input) => {
        const url = String(input);
        if (url.endsWith("private.css")) {
          return new Response("x", {
            headers: {
              "cache-control": "no-store",
              "content-type": "text/css",
            },
            status: 200,
          });
        }
        return new Response("png", {
          headers: { "content-type": "image/png" },
          status: 200,
        });
      },
    });

    expect(result).toEqual({
      cached: 0,
      failed: 0,
      skipped: 2,
      total: 2,
    });
    expect(cache.size).toBe(0);
  });

  it("persists and restores text assets from disk", async () => {
    const cacheDir = await mkdtemp(path.join(tmpdir(), "crater-component-vrt-cache-"));
    const url = "https://example.test/assets/app.css";
    const cache = new ComponentVrtAssetCache();
    cache.put(url, {
      body: "body { color: blue; }",
      contentType: "text/css",
      headers: { "cache-control": "max-age=3600" },
      status: 200,
      storedAt: 1000,
    });

    const persisted = await cache.persistToDisk([url], { cacheDir });
    expect(persisted).toEqual({
      failed: 0,
      skipped: 0,
      total: 1,
      written: 1,
    });

    const restored = new ComponentVrtAssetCache();
    const restoreResult = await restored.restoreFromDisk([url], {
      cacheDir,
      now: 2000,
      ttlMs: 10_000,
    });

    expect(restoreResult).toEqual({
      failed: 0,
      loaded: 1,
      skipped: 0,
      total: 1,
    });
    expect(restored.get(url)).toMatchObject({
      body: "body { color: blue; }",
      contentType: "text/css",
      status: 200,
      storedAt: 1000,
    });
  });

  it("skips stale disk entries", async () => {
    const cacheDir = await mkdtemp(path.join(tmpdir(), "crater-component-vrt-stale-cache-"));
    const url = "https://example.test/assets/app.css";
    const cache = new ComponentVrtAssetCache();
    cache.put(url, {
      body: "body{}",
      contentType: "text/css",
      storedAt: 1000,
    });
    await cache.persistToDisk([url], { cacheDir });

    const restored = new ComponentVrtAssetCache();
    expect(await restored.restoreFromDisk([url], {
      cacheDir,
      now: 20_000,
      ttlMs: 1000,
    })).toEqual({
      failed: 0,
      loaded: 0,
      skipped: 1,
      total: 1,
    });
    expect(restored.size).toBe(0);
  });
});

describe("installComponentVrtAssetCache", () => {
  it("fulfills cached GET requests and continues misses", async () => {
    const page = new FakeRoutePage();
    const cache = new ComponentVrtAssetCache();
    cache.put("https://example.test/assets/app.css", {
      body: "body{}",
      headers: { "cache-control": "max-age=3600" },
      status: 200,
    });

    const installed = await installComponentVrtAssetCache(page, cache);
    const hit = await page.request("https://example.test/assets/app.css");
    const miss = await page.request("https://example.test/assets/other.css");
    const post = await page.request("https://example.test/assets/app.css", "POST");

    expect(hit.actions).toEqual([
      {
        action: "fulfill",
        options: {
          body: "body{}",
          headers: {
            "cache-control": "max-age=3600",
            "x-crater-vrt-cache": "hit",
          },
          status: 200,
        },
      },
    ]);
    expect(miss.actions).toEqual([{ action: "continue" }]);
    expect(post.actions).toEqual([{ action: "continue" }]);
    expect(installed.stats).toMatchObject({ hits: 1, misses: 1, bypassed: 1 });

    await installed.uninstall();
    expect(page.unrouteCalls).toHaveLength(1);
  });
});

describe("component screenshot capture", () => {
  it("normalizes element clips with padding and viewport clamping", () => {
    expect(normalizeComponentClip({
      height: 30.2,
      width: 90.3,
      x: -4.4,
      y: 10.2,
    }, {
      height: 80,
      width: 120,
    }, 8)).toEqual({
      height: 47,
      width: 94,
      x: 0,
      y: 2,
    });
  });

  it("captures a component with a page screenshot clip", async () => {
    const page = new FakeComponentPage();
    const result = await captureComponentScreenshot(page, {
      id: "card",
      selector: "#card",
      timeoutMs: 1000,
    });

    expect(page.locatorCalls).toEqual(["#card"]);
    expect(page.screenshotOptions).toEqual([
      {
        clip: { height: 40, width: 120, x: 8, y: 16 },
        timeout: 1000,
        type: "png",
      },
    ]);
    expect(result).toMatchObject({
      bytes: 3,
      clip: { height: 40, width: 120, x: 8, y: 16 },
      id: "card",
    });
  });

  it("falls back to computed styles when DOM rect is a stub", async () => {
    const page = new FakeComputedStylePage();
    await captureComponentScreenshot(page, {
      id: "card",
      padding: 2,
      selector: "#card",
      timeoutMs: 1000,
    });

    expect(page.screenshotOptions).toEqual([
      {
        clip: { height: 100, width: 180, x: 8, y: 3 },
        timeout: 1000,
        type: "png",
      },
    ]);
  });

  it("clamps computed style fallback clips to the viewport like DOM rect clips", async () => {
    const page = new FakeComputedStyleAtViewportOriginPage();
    await captureComponentScreenshot(page, {
      id: "card",
      padding: 2,
      selector: "#card",
      timeoutMs: 1000,
    });

    expect(page.screenshotOptions).toEqual([
      {
        clip: { height: 98, width: 178, x: 0, y: 0 },
        timeout: 1000,
        type: "png",
      },
    ]);
  });

  it("normalizes cropped palette PNGs to RGB for comparable artifacts", () => {
    const cropped = cropPngToClip(tinyPalettePng(), {
      height: 1,
      width: 2,
      x: 0,
      y: 0,
    }, {
      colorType: "rgb",
    });

    expect({
      colorType: cropped[25],
      height: cropped.readUInt32BE(20),
      width: cropped.readUInt32BE(16),
    }).toEqual({
      colorType: 2,
      height: 1,
      width: 2,
    });
  });

  it("runs HTML and URL scenarios without framework-specific hooks", async () => {
    const htmlPage = new FakeComponentPage();
    await runComponentVrtScenario(htmlPage, {
      html: "<div id='root'>ok</div>",
      id: "html-fixture",
      selector: "#root",
      viewport: { height: 240, width: 320 },
      waitForSelector: "#ready",
    });

    expect(htmlPage.viewport).toEqual({ height: 240, width: 320 });
    expect(htmlPage.html).toBe("<div id='root'>ok</div>");
    expect(htmlPage.waitSelectors).toEqual(["#ready"]);

    const urlPage = new FakeComponentPage();
    await runComponentVrtScenario(urlPage, {
      id: "url-fixture",
      selector: "#root",
      url: "https://example.test/story",
    });
    expect(urlPage.gotoUrl).toBe("https://example.test/story");
  });

  it("uses restored disk assets without refetching preload URLs", async () => {
    const cacheDir = await mkdtemp(path.join(tmpdir(), "crater-component-vrt-suite-cache-"));
    const url = "https://example.test/assets/app.css";
    const seed = new ComponentVrtAssetCache();
    seed.put(url, {
      body: ".card { color: green; }",
      contentType: "text/css",
      headers: { "cache-control": "max-age=3600" },
      status: 200,
    });
    await seed.persistToDisk([url], { cacheDir });
    let fetches = 0;

    const page = new FakeComponentPage();
    const result = await runComponentVrtSuite(page, {
      assets: {
        cacheDir,
        preload: [url],
      },
      scenarios: [{
        html: "<div id='card'>ok</div>",
        id: "card",
        selector: "#card",
      }],
    }, {
      fetch: async () => {
        fetches += 1;
        return new Response("refetched", {
          headers: { "content-type": "text/css" },
          status: 200,
        });
      },
    });

    expect(fetches).toBe(0);
    expect(result.assetCache.restore).toEqual({
      failed: 0,
      loaded: 1,
      skipped: 0,
      total: 1,
    });
    expect(result.assetCache.persist).toMatchObject({
      failed: 0,
      written: 1,
    });
  });
});

describe("parseComponentVrtArgs", () => {
  it("parses CLI flags for the modular runner", () => {
    expect(parseComponentVrtArgs([
      "--config",
      "component-vrt.json",
      "--backend",
      "chromium",
      "--output-dir",
      "screenshots",
      "--asset-cache-dir",
      ".cache/component-vrt",
      "--timeout-ms",
      "30000",
      "--server-timeout-ms",
      "45000",
    ])).toEqual({
      backend: "chromium",
      backendOverride: "chromium",
      config: "component-vrt.json",
      assetCacheDir: ".cache/component-vrt",
      outputDir: "screenshots",
      serverTimeoutMs: 45000,
      timeoutMs: 30000,
    });
  });
});
