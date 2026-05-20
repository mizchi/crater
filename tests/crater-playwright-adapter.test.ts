import { access, mkdtemp, readFile, rm } from "node:fs/promises";
import { once } from "node:events";
import { createServer, type Server } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { expect, test } from "@playwright/test";
import {
  CraterBidiPage,
  createCraterBrowser,
} from "../webdriver/playwright/adapter.ts";
import { decodePng } from "./helpers/crater-vrt.ts";

type LocalFixtureResponse = {
  body: string;
  contentType?: string;
  headers?: Record<string, string>;
  status?: number;
};

type LocalFixtureServer = {
  origin: string;
  serve(path: string, response: LocalFixtureResponse | string): string;
  close(): Promise<void>;
};

async function createLocalFixtureServer(): Promise<LocalFixtureServer> {
  const fixtures = new Map<string, LocalFixtureResponse>();
  const server: Server = createServer((req, res) => {
    const url = new URL(req.url ?? "/", "http://127.0.0.1");
    const fixture = fixtures.get(url.pathname);
    if (!fixture) {
      res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
      res.end(`fixture not found: ${url.pathname}`);
      return;
    }
    res.writeHead(fixture.status ?? 200, {
      "content-type": fixture.contentType ?? "text/html; charset=utf-8",
      ...(fixture.headers ?? {}),
    });
    res.end(fixture.body);
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  if (!address || typeof address === "string") {
    throw new Error("failed to start local fixture server");
  }
  const origin = `http://127.0.0.1:${address.port}`;
  return {
    origin,
    serve(path, response) {
      const normalizedPath = path.startsWith("/") ? path : `/${path}`;
      fixtures.set(normalizedPath, typeof response === "string" ? { body: response } : response);
      return `${origin}${normalizedPath}`;
    },
    close() {
      return new Promise<void>((resolve, reject) => {
        server.close((error) => {
          if (error) {
            reject(error);
            return;
          }
          resolve();
        });
      });
    },
  };
}

test.describe("Crater Playwright adapter package", () => {
  let page: CraterBidiPage;

  test.beforeEach(async () => {
    page = new CraterBidiPage();
    await page.connect();
  });

  test.afterEach(async () => {
    await page.close();
  });

  test("supports page and locator basics through the exported adapter", async () => {
    await page.setContent(`
      <html>
        <body>
          <button role="button" data-testid="save">Save</button>
          <input id="name" placeholder="Name" />
          <ul id="items">
            <li>one</li>
            <li>two</li>
          </ul>
        </body>
      </html>
    `);

    await expect(page.getByRole("button", { name: "Save" }).textContent()).resolves.toBe("Save");
    await expect(page.getByTestId("save").getAttribute("role")).resolves.toBe("button");
    await expect(page.locator("#items").locator("li").nth(1).textContent()).resolves.toBe("two");
    await expect(page.locator("#items").getByText("two").textContent()).resolves.toBe("two");

    await page.fill("#name", "crater");
    await expect(page.locator("#name").inputValue()).resolves.toBe("crater");

    const items = await page.$$eval("li", (elements) =>
      elements.map((element) => element.textContent).join(","),
    );
    expect(items).toBe("one,two");
  });

  test("preserves inline sibling whitespace in loaded HTML textContent", async () => {
    await page.setContentWithScripts(`<div id="x"><a>foo</a> <span>bar</span></div>`);

    await expect(page.locator("#x").textContent()).resolves.toBe("foo bar");

    await page.setContentWithScripts(`<a>foo</a> <span>bar</span>`);
    await expect(page.locator("body").textContent()).resolves.toBe("foo bar");
  });

  test("exposes WebMCP modelContext tools to the browser-side adapter", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <script>
            navigator.modelContext.registerTool({
              name: "summarize_selection",
              description: "Summarize selected text.",
              inputSchema: {
                type: "object",
                properties: {
                  text: { type: "string" }
                },
                required: ["text"]
              },
              annotations: {
                readOnlyHint: true,
                untrustedContentHint: true
              },
              execute: async ({ text }) => ({
                summary: String(text).toUpperCase(),
                href: location.href
              })
            });
          </script>
        </body>
      </html>
    `);

    await expect(page.modelContextTools()).resolves.toEqual([
      {
        name: "summarize_selection",
        description: "Summarize selected text.",
        inputSchema: {
          type: "object",
          properties: {
            text: { type: "string" },
          },
          required: ["text"],
        },
        annotations: {
          readOnlyHint: true,
          untrustedContentHint: true,
        },
      },
    ]);
    await expect(
      page.callModelContextTool("summarize_selection", { text: "crater" }),
    ).resolves.toEqual({
      summary: "CRATER",
      href: "about:blank",
    });
  });

  test("validates WebMCP tool registration and unregisters on abort", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <script>
            const signal = {
              aborted: false,
              addEventListener(type, listener) {
                if (type === "abort") this.abortListener = listener;
              },
              removeEventListener(type, listener) {
                if (type === "abort" && this.abortListener === listener) {
                  this.abortListener = null;
                }
              }
            };
            globalThis.__webMcpAbortSignal = signal;
            navigator.modelContext.registerTool({
              name: "temporary_tool",
              description: "Temporary tool.",
              inputSchema: { type: "object" },
              execute: () => "alive"
            }, { signal });
          </script>
        </body>
      </html>
    `);

    await expect(page.evaluate<boolean>("navigator.modelContext === navigator.modelContext")).resolves.toBe(true);
    await expect(page.modelContextTools()).resolves.toMatchObject([
      { name: "temporary_tool", description: "Temporary tool." },
    ]);
    await expect(
      page.evaluate<string>(`
        (() => {
          try {
            navigator.modelContext.registerTool({
              name: "temporary_tool",
              description: "Duplicate tool.",
              execute: () => null
            });
            return "missing-error";
          } catch (error) {
            return error.name + ":" + error.message;
          }
        })()
      `),
    ).resolves.toContain("InvalidStateError");

    await page.evaluate(`
      (() => {
        const signal = globalThis.__webMcpAbortSignal;
        signal.aborted = true;
        signal.abortListener();
      })()
    `);
    await expect(page.modelContextTools()).resolves.toEqual([]);
  });

  test("isolates WebMCP tool registries across browser contexts", async () => {
    const browser = createCraterBrowser();
    try {
      const firstContext = await browser.newContext();
      const secondContext = await browser.newContext();
      const firstPage = await firstContext.newPage();
      const secondPage = await secondContext.newPage();

      await firstPage.setContentWithScripts(`
        <script>
          navigator.modelContext.registerTool({
            name: "context_tool",
            description: "First context tool.",
            execute: () => "first"
          });
        </script>
      `);
      await secondPage.setContentWithScripts(`
        <script>
          navigator.modelContext.registerTool({
            name: "context_tool",
            description: "Second context tool.",
            execute: () => "second"
          });
        </script>
      `);

      await expect(firstPage.modelContextTools()).resolves.toMatchObject([
        { name: "context_tool", description: "First context tool." },
      ]);
      await expect(secondPage.modelContextTools()).resolves.toMatchObject([
        { name: "context_tool", description: "Second context tool." },
      ]);
      await expect(firstPage.callModelContextTool("context_tool")).resolves.toBe("first");
      await expect(secondPage.callModelContextTool("context_tool")).resolves.toBe("second");
    } finally {
      await browser.close();
    }
  });

  test("captures live DOM after page-level scripted interactions", async () => {
    await page.setViewport(120, 80);
    await page.setContent(`
      <html>
        <body style="margin:0">
          <div id="box" style="width:60px;height:60px;background:#000"></div>
          <button id="save" type="button">Save</button>
          <script>
            document.getElementById("save").addEventListener("click", () => {
              document.getElementById("box").setAttribute("style", "width:60px;height:60px;background:#fff");
            });
          </script>
        </body>
      </html>
    `);

    await page.click("#save");
    const image = await page.capturePaintData();
    const offset = (10 * image.width + 10) * 4;

    expect(Array.from(image.data.slice(offset, offset + 4))).toEqual([255, 255, 255, 255]);
  });

  test("capture paint tree serializes live form control property state", async () => {
    await page.setViewport(240, 100);
    await page.setContent(`
      <html>
        <body>
          <input id="name" type="text" value="" style="font:14px Arial" />
          <input id="notify" type="checkbox" />
        </body>
      </html>
    `);

    await page.type("#name", "Crater Team");
    await page.check("#notify");
    const result = await page.capturePaintTree();

    expect(result.paintTree).toContain("Crater Team");
  });

  test("capture paint tree accepts document origin", async () => {
    await page.setViewport(120, 80);
    await page.setContent(`
      <html>
        <body style="margin:0">
          <div style="width:120px;height:260px;background:#000"></div>
        </body>
      </html>
    `);

    await expect(page.capturePaintTree()).resolves.toMatchObject({
      width: 120,
      height: 80,
    });
    const documentTree = await page.capturePaintTree({ origin: "document" });

    expect(documentTree.width).toBe(120);
    expect(documentTree.height).toBeGreaterThan(80);
  });

  test("supports frameLocator traversal for fixture iframe contentDocument roots", async () => {
    await page.setContent(`
      <html>
        <body>
          <iframe id="fixture"></iframe>
          <section id="frame-root">
            <button id="inside">Inside</button>
            <input id="result" />
          </section>
        </body>
      </html>
    `);
    await page.evaluate(() => {
      const frame = document.querySelector("#fixture") as unknown as {
        contentDocument?: Document | Element;
      };
      const root = document.querySelector("#frame-root");
      frame.contentDocument = root ?? undefined;
      document.querySelector("#inside")?.addEventListener("click", () => {
        const result = document.querySelector("#result") as HTMLInputElement | null;
        if (result) {
          result.value = "clicked";
        }
      });
    });

    const frame = page.frameLocator("#fixture");
    await expect(frame.locator("#inside").textContent()).resolves.toBe("Inside");
    await frame.locator("#inside").click();
    await expect(frame.locator("#result").inputValue()).resolves.toBe("clicked");
  });

  test("waitForFunction accepts Playwright-style arg and options overload", async () => {
    page.setDefaultTimeout(2000);
    await page.setContentWithScripts(`
      <html>
        <body data-ready="no">
          <script>
            setTimeout(() => {
              document.body.setAttribute("data-ready", "yes");
            }, 20);
          </script>
        </body>
      </html>
    `);

    await expect(
      page.waitForFunction(
        ({ attr }) => document.body.getAttribute(attr) === "yes",
        { attr: "data-ready" },
        { timeout: 1000 },
      ),
    ).resolves.toBe(true);
  });

  test("locator scrollIntoViewIfNeeded and action options use locator timeout", async () => {
    await page.setContent(`
      <html>
        <body>
          <input id="name" />
          <button id="save">Save</button>
          <output id="events"></output>
        </body>
      </html>
    `);
    await page.evaluate(() => {
      const events = document.querySelector("#events")!;
      const save = document.querySelector("#save") as HTMLElement & {
        scrollIntoView(options?: unknown): void;
      };
      save.scrollIntoView = (options?: unknown) => {
        events.textContent = JSON.stringify({
          called: true,
          options,
        });
      };
      save.addEventListener("click", () => {
        document.body.setAttribute("data-clicked", "yes");
      });
      save.addEventListener("mouseover", () => {
        document.body.setAttribute("data-hovered", "yes");
      });
    });

    await page.locator("#save").scrollIntoViewIfNeeded({ timeout: 1000 });
    await page.locator("#save").click({ timeout: 1000 });
    await page.locator("#save").hover({ timeout: 1000 });
    await page.locator("#name").fill("Crater", { timeout: 1000 });

    await expect(page.locator("#events").textContent()).resolves.toContain("\"called\":true");
    await expect(page.getAttribute("body", "data-clicked")).resolves.toBe("yes");
    await expect(page.getAttribute("body", "data-hovered")).resolves.toBe("yes");
    await expect(page.locator("#name").inputValue()).resolves.toBe("Crater");
    await expect(page.locator("#missing").click({ timeout: 80 })).rejects.toThrow(
      /Timeout waiting for actionable selector/,
    );
  });

  test("screenshot accepts fullPage, timeout, clip, and type options", async () => {
    await page.setViewport(200, 100);
    await page.setContent(`
      <html>
        <body style="margin:0">
          <div style="width:200px;height:260px;background:#000"></div>
        </body>
      </html>
    `);

    const dimensions = (png: Buffer) => ({
      width: png.readUInt32BE(16),
      height: png.readUInt32BE(20),
    });

    await expect(page.screenshot({ timeout: 1000, type: "png" })).resolves.toEqual(
      expect.any(Buffer),
    );
    const actualViewport = await page.captureScreenshot({ timeout: 1000 });
    expect(dimensions(actualViewport)).toEqual({ width: 200, height: 100 });

    const viewport = await page.screenshot({ timeout: 1000, type: "png" });
    expect(dimensions(viewport)).toEqual({ width: 200, height: 100 });

    const fullPage = await page.screenshot({ fullPage: true, timeout: 1000, type: "png" });
    expect(dimensions(fullPage).height).toBeGreaterThan(100);
    const fullPageImage = await decodePng(fullPage);
    const lowerPixelOffset = (200 * fullPageImage.width + 20) * 4;
    expect(fullPageImage.data[lowerPixelOffset]).toBeLessThan(50);
    expect(fullPageImage.data[lowerPixelOffset + 1]).toBeLessThan(50);
    expect(fullPageImage.data[lowerPixelOffset + 2]).toBeLessThan(50);

    const clipped = await page.screenshot({
      clip: { x: 0, y: 0, width: 50, height: 40 },
      timeout: 1000,
      type: "png",
    });
    expect(dimensions(clipped)).toEqual({ width: 50, height: 40 });
  });

  test("fullPage screenshot keeps viewport layout when document is horizontally scrollable", async () => {
    await page.setViewport(320, 180);
    const blocks = Array.from(
      { length: 18 },
      (_, index) =>
        `<span style="display:inline-block;width:100px;height:40px;background:${
          ["#ff0000", "#00ff00", "#0000ff"][index % 3]
        }"></span>`,
    ).join("");
    await page.setContent(`
      <html>
        <body style="margin:0;background:#fff">
          <div style="width:800px;height:20px;background:#000"></div>
          <div>${blocks}</div>
        </body>
      </html>
    `);

    const screenshot = await page.screenshot({ fullPage: true, timeout: 1000, type: "png" });

    expect({
      width: screenshot.readUInt32BE(16),
      height: screenshot.readUInt32BE(20),
    }).toEqual({
      width: 800,
      height: expect.any(Number),
    });
    expect(screenshot.readUInt32BE(20)).toBeGreaterThan(180);
  });

  test("fullPage screenshot caps very tall documents without moving scroll position", async () => {
    await page.setViewport(320, 180);
    await page.setContent(`
      <html>
        <body style="margin:0;background:#fff">
          <div style="width:320px;height:18000px;background:#fff"></div>
          <div style="width:320px;height:20px;background:#000"></div>
        </body>
      </html>
    `);
    await page.evaluate(() => {
      window.scrollTo(0, 640);
    });

    const before = await page.evaluate(() => ({
      x: window.scrollX,
      y: window.scrollY,
      top: document.scrollingElement?.scrollTop ?? 0,
      left: document.scrollingElement?.scrollLeft ?? 0,
    }));
    const screenshot = await page.screenshot({ fullPage: true, timeout: 1000, type: "png" });
    const after = await page.evaluate(() => ({
      x: window.scrollX,
      y: window.scrollY,
      top: document.scrollingElement?.scrollTop ?? 0,
      left: document.scrollingElement?.scrollLeft ?? 0,
    }));

    expect({
      width: screenshot.readUInt32BE(16),
      height: screenshot.readUInt32BE(20),
    }).toEqual({
      width: 320,
      height: 16384,
    });
    expect(after).toEqual(before);
  });

  test("fullPage screenshot observes lazy images loaded by scroll stabilization", async () => {
    const server = await createLocalFixtureServer();
    try {
      await page.setViewport(320, 180);
      const observedEvents: string[] = [];
      const pageUrl = server.serve(
        "/capture/lazy-fullpage.html",
        `<!doctype html>
        <html>
          <body style="margin:0;background:#fff">
            <div style="height:260px;background:#fff"></div>
            <img
              id="lazy"
              loading="lazy"
              alt="lazy"
              width="320"
              height="80"
              style="display:block;width:320px;height:80px"
            />
            <div style="height:220px;background:#fff"></div>
            <script>
              window.addEventListener("scroll", () => {
                const image = document.getElementById("lazy");
                if (image && !image.getAttribute("src") && window.scrollY >= 180) {
                  image.src = "/assets/lazy.svg?from=scroll";
                }
              });
            </script>
          </body>
        </html>`,
      );
      await page.route(/\/assets\/lazy\.svg(?:\?.*)?$/, async (route) => {
        observedEvents.push(`route:${new URL(route.request().url()).pathname}`);
        await route.fulfill({
          contentType: "image/svg+xml",
          body: `<svg xmlns="http://www.w3.org/2000/svg" width="320" height="80"><rect width="320" height="80" fill="#111"/></svg>`,
        });
      });
      page.on("request", (request) => {
        if (request.url().includes("/assets/lazy.svg")) {
          observedEvents.push(`request:${new URL(request.url()).pathname}`);
        }
      });
      page.on("response", (response) => {
        if (response.url().includes("/assets/lazy.svg")) {
          observedEvents.push(`response:${new URL(response.url()).pathname}:${response.status()}`);
        }
      });

      await page.loadPage(pageUrl);
      const lazyResponse = page.waitForResponse(
        (response) => response.url().includes("/assets/lazy.svg"),
        { timeout: 1000 },
      );

      await page.evaluate(async () => {
        const scrollHeight = document.scrollingElement?.scrollHeight ?? document.documentElement.scrollHeight;
        const maxY = Math.max(0, scrollHeight - window.innerHeight);
        for (let y = 0; y <= maxY; y += window.innerHeight) {
          window.scrollTo(0, y);
          await new Promise((resolve) => setTimeout(resolve, 0));
        }
        window.scrollTo(0, 0);
        await new Promise((resolve) => setTimeout(resolve, 0));
      });

      const response = await lazyResponse;
      const screenshot = await page.screenshot({ fullPage: true, timeout: 1000, type: "png" });
      const snapshot = await page.evaluate(() => {
        const image = document.querySelector("#lazy") as HTMLImageElement;
        return JSON.stringify({
          complete: image.complete,
          loading: image.loading,
          scrollY: window.scrollY,
          src: image.getAttribute("src"),
        });
      });

      expect(response.status()).toBe(200);
      expect({
        width: screenshot.readUInt32BE(16),
        height: screenshot.readUInt32BE(20),
      }).toEqual({
        width: 320,
        height: expect.any(Number),
      });
      expect(screenshot.readUInt32BE(20)).toBeGreaterThan(180);
      expect(JSON.parse(snapshot)).toEqual({
        complete: true,
        loading: "lazy",
        scrollY: 0,
        src: "/assets/lazy.svg?from=scroll",
      });
      expect(observedEvents).toEqual(
        expect.arrayContaining([
          "request:/assets/lazy.svg",
          "route:/assets/lazy.svg",
          "response:/assets/lazy.svg:200",
        ]),
      );
    } finally {
      await server.close();
    }
  });

  test("loadPage screenshot reflects script-mutated live DOM", async () => {
    const server = await createLocalFixtureServer();
    try {
      await page.setViewport(200, 100);
      const url = server.serve(
        "/mutated-live-dom.html",
        `<!doctype html>
        <html>
          <body style="margin:0;background:#fff">
            <div id="initial" style="width:200px;height:100px;background:#fff"></div>
            <script>
              document.getElementById("initial").setAttribute("style", "width:200px;height:100px;background:#000");
            </script>
          </body>
        </html>`,
      );

      await page.loadPage(url);
      const screenshot = await page.screenshot({ timeout: 1000, type: "png" });
      const image = await decodePng(screenshot);
      const pixelOffset = (20 * image.width + 20) * 4;

      expect(image.data[pixelOffset]).toBeLessThan(50);
      expect(image.data[pixelOffset + 1]).toBeLessThan(50);
      expect(image.data[pixelOffset + 2]).toBeLessThan(50);
    } finally {
      await server.close();
    }
  });

  test("loadPage fullPage screenshot ignores live style and script text", async () => {
    const server = await createLocalFixtureServer();
    try {
      await page.setViewport(320, 180);
      const url = server.serve(
        "/live-style-script-text.html",
        `<!doctype html>
        <html>
          <body style="margin:0;background:#fff">
            <div id="box" class="box"></div>
            <script>
              const style = document.createElement("style");
              style.textContent = ".box{width:120px;height:90px;background:#000}" + "/*" + "x".repeat(8000) + "*/";
              document.body.insertBefore(style, document.body.firstChild);
              const script = document.createElement("script");
              script.textContent = "globalThis.__ignored_script_text = '" + "y".repeat(8000) + "'";
              document.body.insertBefore(script, document.body.firstChild);
            </script>
          </body>
        </html>`,
      );

      await page.loadPage(url);
      const screenshot = await page.screenshot({ fullPage: true, timeout: 1000, type: "png" });
      const image = await decodePng(screenshot);
      const pixelOffset = (20 * image.width + 20) * 4;

      expect({
        width: screenshot.readUInt32BE(16),
        height: screenshot.readUInt32BE(20),
      }).toEqual({
        width: 320,
        height: 180,
      });
      expect(image.data[pixelOffset]).toBeLessThan(50);
      expect(image.data[pixelOffset + 1]).toBeLessThan(50);
      expect(image.data[pixelOffset + 2]).toBeLessThan(50);
    } finally {
      await server.close();
    }
  });

  test("location stringifies like browser Location objects", async () => {
    await page.setContent("<html><body>Location</body></html>");

    const location = await page.evaluate(() => ({
      href: window.location.href,
      stringified: String(window.location),
      templated: `${window.location}`,
      urlHref: new URL(window.location as unknown as string).href,
      documentLocationSame: document.location === window.location,
    }));

    expect(location).toEqual({
      href: "about:blank",
      stringified: "about:blank",
      templated: "about:blank",
      urlHref: "about:blank",
      documentLocationSame: true,
    });
  });

  test("document.cookie defaults to a browser-like string", async () => {
    await page.setContent("<html><body>Cookie</body></html>");

    const initial = await page.evaluate(() => ({
      cookie: document.cookie,
      type: typeof document.cookie,
      cookieEnabled: navigator.cookieEnabled,
    }));
    expect(initial).toEqual({
      cookie: "",
      type: "string",
      cookieEnabled: true,
    });

    const updated = await page.evaluate(() => {
      document.cookie = "sid=abc; Path=/";
      document.cookie = "theme=dark; Path=/";
      return document.cookie;
    });
    expect(updated).toContain("sid=abc");
    expect(updated).toContain("theme=dark");
  });

  test("goto commit returns final responses for redirects and HTTP errors", async () => {
    const server = await createLocalFixtureServer();
    try {
      const finalUrl = server.serve(
        "/redirect-target.html",
        "<!doctype html><html><body><main id='status'>redirected</main></body></html>",
      );
      const redirectUrl = server.serve("/redirect.html", {
        body: "",
        status: 302,
        headers: {
          location: "/redirect-target.html",
        },
      });
      const errorUrl = server.serve(
        "/server-error.html",
        {
          body: "<!doctype html><html><body><main id='error'>server error</main></body></html>",
          status: 500,
        },
      );

      const redirectResponse = await page.goto(redirectUrl, {
        waitUntil: "commit",
        timeout: 1000,
      });

      expect(redirectResponse?.url()).toBe(finalUrl);
      expect(redirectResponse?.status()).toBe(200);
      expect(redirectResponse?.ok()).toBe(true);
      expect(page.url()).toBe(finalUrl);
      await expect(page.locator("#status").textContent()).resolves.toBe("redirected");

      const errorResponse = await page.goto(errorUrl, {
        waitUntil: "commit",
        timeout: 1000,
      });

      expect(errorResponse?.url()).toBe(errorUrl);
      expect(errorResponse?.status()).toBe(500);
      expect(errorResponse?.ok()).toBe(false);
      expect(page.url()).toBe(errorUrl);
      await expect(page.locator("#error").textContent()).resolves.toBe("server error");
    } finally {
      await server.close();
    }
  });

  test("page scripts can fetch CORS-allowed cross-origin resources", async () => {
    const pageServer = await createLocalFixtureServer();
    const apiServer = await createLocalFixtureServer();
    try {
      const dataUrl = apiServer.serve("/data.json", {
        body: JSON.stringify({ ok: true }),
        contentType: "application/json; charset=utf-8",
        headers: {
          "access-control-allow-origin": pageServer.origin,
        },
      });
      const pageUrl = pageServer.serve(
        "/cors-fetch.html",
        "<!doctype html><html><body><main>CORS fetch</main></body></html>",
      );

      await page.loadPage(pageUrl);
      const result = await page.evaluate(async (url) => {
        const response = await fetch(url);
        return `${response.status}:${await response.text()}`;
      }, dataUrl);

      expect(result).toBe('200:{"ok":true}');
    } finally {
      await Promise.all([pageServer.close(), apiServer.close()]);
    }
  });

  test("routes RegExp subresources and waits for networkidle across scripts styles images and fetch", async () => {
    const server = await createLocalFixtureServer();
    try {
      const styleUrl = server.serve(
        "/capture/style.css",
        {
          body: "body { background: rgb(255, 255, 255); }",
          contentType: "text/css; charset=utf-8",
        },
      );
      const imageUrl = server.serve(
        "/capture/logo.svg",
        {
          body: `<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2"></svg>`,
          contentType: "image/svg+xml",
        },
      );
      const continuedScriptUrl = server.serve(
        "/capture/continued-script.js",
        {
          body: `document.body.setAttribute("data-continued-script", "yes");`,
          contentType: "text/javascript; charset=utf-8",
        },
      );
      const fulfilledScriptUrl = `${server.origin}/capture/fulfilled-script.js`;
      const blockedApiUrl = `${server.origin}/capture/blocked-api`;
      const pageUrl = server.serve(
        "/capture/studio-smoke.html",
        `<!doctype html>
        <html>
          <head>
            <link rel="stylesheet" href="/capture/style.css">
          </head>
          <body>
            <main id="status">pending</main>
            <img id="logo" src="/capture/logo.svg" alt="logo">
            <script src="/capture/fulfilled-script.js"></script>
            <script src="/capture/continued-script.js"></script>
            <script>
              fetch("/capture/blocked-api")
                .then(() => {
                  document.body.setAttribute("data-blocked-api", "unexpected");
                })
                .catch((error) => {
                  document.body.setAttribute("data-blocked-api", error.message);
                });
            </script>
          </body>
        </html>`,
      );

      await page.route(/\/capture\/fulfilled-script\.js$/, async (route) => {
        await route.fulfill({
          contentType: "text/javascript; charset=utf-8",
          body: `
            document.body.setAttribute("data-fulfilled-script", "yes");
            document.getElementById("status").textContent = "fulfilled";
          `,
        });
      });
      await page.route(/\/capture\/continued-script\.js$/, async (route) => {
        await route.continue();
      });
      await page.route(/\/capture\/blocked-api$/, async (route) => {
        await route.abort("blocked-by-test");
      });

      const observedEvents: string[] = [];
      page.on("request", (request) => {
        observedEvents.push(`request:${new URL(request.url()).pathname}`);
      });
      page.on("response", (response) => {
        observedEvents.push(`response:${new URL(response.url()).pathname}:${response.status()}`);
      });
      page.on("requestfailed", (failure) => {
        observedEvents.push(`requestfailed:${new URL(failure.request().url()).pathname}:${failure.errorText()}`);
      });

      const styleResponse = page.waitForResponse(styleUrl);
      const imageResponse = page.waitForResponse(imageUrl);
      const fulfilledResponse = page.waitForResponse(fulfilledScriptUrl);
      const continuedResponse = page.waitForResponse(continuedScriptUrl);
      const blockedFailure = page.waitForEvent("requestfailed", {
        predicate: (failure) => failure.request().url() === blockedApiUrl,
        timeout: 3000,
      });

      const response = await page.goto(pageUrl, {
        waitUntil: "networkidle",
        timeout: 3000,
      });
      await page.waitForLoadState("networkidle", { timeout: 3000 });

      const [style, image, fulfilled, continued, blocked] = await Promise.all([
        styleResponse,
        imageResponse,
        fulfilledResponse,
        continuedResponse,
        blockedFailure,
      ]);

      expect(response?.status()).toBe(200);
      expect(style.status()).toBe(200);
      expect(image.status()).toBe(200);
      expect(fulfilled.status()).toBe(200);
      expect(continued.status()).toBe(200);
      expect(blocked.errorText()).toBe("blocked-by-test");
      await expect(page.locator("#status").textContent()).resolves.toBe("fulfilled");
      await expect(page.locator("body").getAttribute("data-fulfilled-script")).resolves.toBe("yes");
      await expect(page.locator("body").getAttribute("data-continued-script")).resolves.toBe("yes");
      await expect(page.locator("body").getAttribute("data-blocked-api")).resolves.toBe("blocked-by-test");

      expect(observedEvents).toEqual(
        expect.arrayContaining([
          "request:/capture/style.css",
          "response:/capture/style.css:200",
          "request:/capture/logo.svg",
          "response:/capture/logo.svg:200",
          "request:/capture/fulfilled-script.js",
          "response:/capture/fulfilled-script.js:200",
          "request:/capture/continued-script.js",
          "response:/capture/continued-script.js:200",
          "request:/capture/blocked-api",
          "requestfailed:/capture/blocked-api:blocked-by-test",
        ]),
      );
    } finally {
      await server.close();
    }
  });

  test("loads linked stylesheets before layout capture", async () => {
    const server = await createLocalFixtureServer();
    try {
      server.serve(
        "/assets/theme.css",
        {
          body: `
            #hero {
              width: 96px;
              height: 32px;
              left: 14px;
              top: 9px;
            }
          `,
          contentType: "text/css; charset=utf-8",
        },
      );
      const pageUrl = server.serve(
        "/stylesheet-page.html",
        `<!doctype html>
        <html>
          <head>
            <link rel="stylesheet" href="/assets/theme.css">
          </head>
          <body>
            <main id="hero">styled</main>
          </body>
        </html>`,
      );

      await page.loadPage(pageUrl);

      const snapshot = await page.evaluate(() => {
        const hero = document.querySelector("#hero") as HTMLElement;
        const rect = hero.getBoundingClientRect();
        return JSON.stringify({
          height: rect.height,
          left: rect.left,
          top: rect.top,
          width: rect.width,
        });
      });

      expect(JSON.parse(snapshot)).toEqual({
        height: 32,
        left: 14,
        top: 9,
        width: 96,
      });
    } finally {
      await server.close();
    }
  });

  test("loads font URLs from linked stylesheets through route hooks", async () => {
    const server = await createLocalFixtureServer();
    try {
      server.serve(
        "/assets/theme.css",
        {
          body: `
            @font-face {
              font-family: "StudioFixture";
              src: url("./studio-fixture.woff2") format("woff2");
            }
            #hero {
              font-family: "StudioFixture";
              width: 96px;
              height: 32px;
            }
          `,
          contentType: "text/css; charset=utf-8",
        },
      );
      const pageUrl = server.serve(
        "/capture/font-page.html",
        `<!doctype html>
        <html>
          <head>
            <link rel="stylesheet" href="/assets/theme.css">
          </head>
          <body>
            <main id="hero">font</main>
          </body>
        </html>`,
      );

      const observedEvents: string[] = [];
      page.on("request", (request) => {
        observedEvents.push(`request:${new URL(request.url()).pathname}`);
      });
      page.on("response", (response) => {
        observedEvents.push(`response:${new URL(response.url()).pathname}:${response.status()}`);
      });
      await page.route(/\/assets\/studio-fixture\.woff2$/, async (route) => {
        await route.fulfill({
          contentType: "font/woff2",
          body: "fixture-font",
        });
      });

      const styleResponse = page.waitForResponse(`${server.origin}/assets/theme.css`);
      const fontResponse = page.waitForResponse(`${server.origin}/assets/studio-fixture.woff2`);
      await page.goto(pageUrl, { waitUntil: "networkidle", timeout: 3000 });
      const [style, font] = await Promise.all([styleResponse, fontResponse]);

      expect(style.status()).toBe(200);
      expect(font.status()).toBe(200);
      expect(observedEvents).toEqual(
        expect.arrayContaining([
          "request:/assets/theme.css",
          "response:/assets/theme.css:200",
          "request:/assets/studio-fixture.woff2",
          "response:/assets/studio-fixture.woff2:200",
        ]),
      );
    } finally {
      await server.close();
    }
  });

  test("executes module scripts with static and dynamic imports during page load", async () => {
    const server = await createLocalFixtureServer();
    try {
      server.serve(
        "/assets/nested/value.js",
        {
          body: `export const value = "static-value";`,
          contentType: "text/javascript; charset=utf-8",
        },
      );
      server.serve(
        "/assets/dynamic.js",
        {
          body: `export default "dynamic-value";`,
          contentType: "text/javascript; charset=utf-8",
        },
      );
      server.serve(
        "/assets/app.js",
        {
          body: `
            import { value } from "./nested/value.js";
            const dynamic = await import("./dynamic.js");
            document.body.setAttribute("data-module", value + ":" + dynamic.default);
          `,
          contentType: "text/javascript; charset=utf-8",
        },
      );
      const pageUrl = server.serve(
        "/capture/module-page.html",
        `<!doctype html>
        <html>
          <body>
            <main id="hero">module</main>
            <script type="module" src="/assets/app.js"></script>
          </body>
        </html>`,
      );

      const observedEvents: string[] = [];
      page.on("request", (request) => {
        observedEvents.push(`request:${new URL(request.url()).pathname}`);
      });
      page.on("response", (response) => {
        observedEvents.push(`response:${new URL(response.url()).pathname}:${response.status()}`);
      });
      await page.route(/\/assets\/.*\.js(?:\?.*)?$/, async (route) => {
        await route.continue();
      });

      const appResponse = page.waitForResponse(`${server.origin}/assets/app.js`);
      const staticResponse = page.waitForResponse((response) =>
        new URL(response.url()).pathname === "/assets/nested/value.js"
      );
      const dynamicResponse = page.waitForResponse((response) =>
        new URL(response.url()).pathname === "/assets/dynamic.js"
      );

      await page.goto(pageUrl, { waitUntil: "networkidle", timeout: 3000 });
      const [app, staticImport, dynamicImport] = await Promise.all([
        appResponse,
        staticResponse,
        dynamicResponse,
      ]);

      expect(app.status()).toBe(200);
      expect(staticImport.status()).toBe(200);
      expect(dynamicImport.status()).toBe(200);
      await expect(page.locator("body").getAttribute("data-module")).resolves.toBe(
        "static-value:dynamic-value",
      );
      expect(observedEvents).toEqual(
        expect.arrayContaining([
          "request:/assets/app.js",
          "response:/assets/app.js:200",
          "request:/assets/nested/value.js",
          "response:/assets/nested/value.js:200",
          "request:/assets/dynamic.js",
          "response:/assets/dynamic.js:200",
        ]),
      );
    } finally {
      await server.close();
    }
  });

  test("ariaSnapshot returns a lightweight accessibility tree for inspection parity", async () => {
    await page.setContent(`
      <html>
        <head><title>Inspection</title></head>
        <body>
          <main>
            <h1>Dashboard</h1>
            <nav aria-label="Main nav"><a href="/home">Home</a></nav>
            <label for="email">Email</label>
            <input id="email" value="mizchi@example.test" />
            <label><input id="accept" type="checkbox" checked />Accept terms</label>
            <button aria-expanded="false">Menu</button>
            <button aria-label="Save" disabled>Ignored text</button>
          </main>
        </body>
      </html>
    `);

    const snapshot = await page.ariaSnapshot({ depth: 8, timeout: 1000 });
    const nodes: Array<Record<string, unknown>> = [];
    const visit = (node: Record<string, unknown> | null | undefined) => {
      if (!node) return;
      nodes.push(node);
      for (const child of (node.children as Array<Record<string, unknown>> | undefined) || []) {
        visit(child);
      }
    };
    visit(snapshot as Record<string, unknown> | null);
    const lines = nodes.map((node) =>
      [
        node.role,
        node.name,
        node.value,
        node.expanded === false ? "expanded=false" : "",
        node.checked === true ? "checked=true" : "",
        node.disabled === true ? "disabled=true" : "",
      ].filter((part) => part !== undefined && part !== "").join("|")
    );

    expect(lines).toContain("document");
    expect(lines).toContain("heading|Dashboard");
    expect(lines).toContain("navigation|Main nav");
    expect(lines).toContain("link|Home");
    expect(lines).toContain("textbox|Email|mizchi@example.test");
    expect(lines).toContain("checkbox|Accept terms|checked=true");
    expect(lines).toContain("button|Menu|expanded=false");
    expect(lines).toContain("button|Save|disabled=true");
  });

  test("provides browser-side stabilization stubs used by capture scripts", async () => {
    await page.setContent("<html><body><main>ready</main></body></html>");

    const snapshot = await page.evaluate(async () => {
      const observed: number[] = [];
      const observer = new PerformanceObserver((list) => {
        observed.push(list.getEntries().length);
      });
      observer.observe({ type: "largest-contentful-paint", buffered: true });
      const records = observer.takeRecords();
      observer.disconnect();
      const ready = await document.fonts.ready.then(() => document.fonts.status);
      return JSON.stringify({
        animations: document.getAnimations().length,
        fontCheck: document.fonts.check("12px Arial"),
        fontReady: ready,
        observer: typeof PerformanceObserver,
        observed,
        records: records.length,
        supported: PerformanceObserver.supportedEntryTypes.includes("largest-contentful-paint"),
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      animations: 0,
      fontCheck: true,
      fontReady: "loaded",
      observer: "function",
      observed: [],
      records: 0,
      supported: true,
    });
  });

  test("exposes timer APIs on the page window for loaded scripts", async () => {
    await page.setContent(`
      <html>
        <body>
          <script>
            window.__timerProbe = {};
            try {
              window.__timerProbe = {
                setTimeout: typeof window.setTimeout,
                clearTimeout: typeof window.clearTimeout,
                setInterval: typeof window.setInterval,
                clearInterval: typeof window.clearInterval,
                requestAnimationFrame: typeof window.requestAnimationFrame,
                cancelAnimationFrame: typeof window.cancelAnimationFrame,
                selfIsWindow: window.self === window,
              };
              window.setTimeout(() => {
                document.body.dataset.timer = "done";
              }, 0);
            } catch (error) {
              window.__timerProbe.error = String(error);
            }
          </script>
        </body>
      </html>
    `);

    await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 0)));

    const snapshot = await page.evaluate(() => {
      const win = window as typeof window & { __timerProbe?: unknown };
      return JSON.stringify({
        probe: win.__timerProbe,
        timer: document.body.dataset.timer ?? "",
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      probe: {
        setTimeout: "function",
        clearTimeout: "function",
        setInterval: "function",
        clearInterval: "function",
        requestAnimationFrame: "function",
        cancelAnimationFrame: "function",
        selfIsWindow: true,
      },
      timer: "done",
    });
  });

  test("runs hydration microtasks before timer callbacks", async () => {
    await page.setContent(`
      <html>
        <body>
          <script>
            const order = [];
            Promise.resolve().then(() => order.push("promise"));
            queueMicrotask(() => order.push("microtask"));
            setTimeout(() => {
              order.push("timeout");
              document.body.dataset.order = order.join(",");
            }, 0);
            document.body.dataset.syncOrder = order.join(",");
          </script>
        </body>
      </html>
    `);

    await page.waitForFunction(() => document.body.dataset.order === "promise,microtask,timeout", {
      timeout: 1000,
    });

    const snapshot = await page.evaluate(() => JSON.stringify({
      order: document.body.dataset.order,
      syncOrder: document.body.dataset.syncOrder,
    }));

    expect(JSON.parse(snapshot)).toEqual({
      order: "promise,microtask,timeout",
      syncOrder: "",
    });
  });

  test("normalizes existing PerformanceObserver entry type support", async () => {
    await page.evaluate(() => {
      class ExistingPerformanceObserver {
        static supportedEntryTypes = ["mark"];
        constructor(_callback: PerformanceObserverCallback) {}
        observe() {}
        takeRecords() {
          return [];
        }
        disconnect() {}
      }
      (globalThis as unknown as { PerformanceObserver: typeof PerformanceObserver }).PerformanceObserver =
        ExistingPerformanceObserver as unknown as typeof PerformanceObserver;
    });
    await page.setContent("<html><body><main>ready</main></body></html>");

    const supported = await page.evaluate(() => PerformanceObserver.supportedEntryTypes.slice());

    expect(supported).toContain("mark");
    expect(supported).toContain("largest-contentful-paint");
  });

  test("provides browser-side scrolling primitives used by capture scripts", async () => {
    await page.setViewport(320, 200);
    await page.setContent(`
      <html>
        <body style="margin:0">
          <main style="height:1200px">
            <div id="target" style="position:absolute;top:480px;left:24px;width:40px;height:20px">target</div>
          </main>
        </body>
      </html>
    `);

    const snapshot = await page.evaluate(() => {
      const target = document.querySelector("#target") as HTMLElement;
      const scroller = document.scrollingElement as HTMLElement;
      window.scrollTo(10, 20);
      const afterScrollTo = {
        x: window.scrollX,
        y: window.scrollY,
        pageXOffset: window.pageXOffset,
        pageYOffset: window.pageYOffset,
        scrollLeft: scroller.scrollLeft,
        scrollTop: scroller.scrollTop,
      };
      window.scrollBy({ left: 5, top: 30 });
      const afterScrollBy = {
        x: window.scrollX,
        y: window.scrollY,
        scrollLeft: scroller.scrollLeft,
        scrollTop: scroller.scrollTop,
      };
      window.scrollTo(0, 0);
      target.scrollIntoView();
      return JSON.stringify({
        afterScrollBy,
        afterScrollTo,
        innerHeight: window.innerHeight,
        innerWidth: window.innerWidth,
        scrollingElement: scroller === document.documentElement,
        scrollIntoView: {
          type: typeof target.scrollIntoView,
          x: window.scrollX,
          y: window.scrollY,
        },
      });
    });

    const result = JSON.parse(snapshot);
    expect(result).toEqual({
      afterScrollBy: {
        x: 15,
        y: 50,
        scrollLeft: 15,
        scrollTop: 50,
      },
      afterScrollTo: {
        x: 10,
        y: 20,
        pageXOffset: 10,
        pageYOffset: 20,
        scrollLeft: 10,
        scrollTop: 20,
      },
      innerHeight: 200,
      innerWidth: 320,
      scrollingElement: true,
      scrollIntoView: {
        type: "function",
        x: 24,
        y: 480,
      },
    });
  });

  test("provides browser-side image loading stubs used by capture scripts", async () => {
    await page.setContent(`
      <html>
        <body>
          <img id="hero" loading="lazy" src="https://example.test/hero.png" alt="hero" />
          <img id="logo" src="https://example.test/logo.png" alt="logo" />
        </body>
      </html>
    `);

    const snapshot = await page.evaluate(async () => {
      const image = document.querySelector("#hero") as HTMLImageElement;
      const events: string[] = [];
      image.addEventListener("load", () => events.push("load"));
      for (const lazyImage of Array.from(document.querySelectorAll("img[loading='lazy']")) as HTMLImageElement[]) {
        lazyImage.loading = "eager";
      }
      image.src = "https://example.test/hero-2.png";
      await image.decode();
      const constructed = new Image(32, 24);
      let constructedOnload = false;
      constructed.addEventListener("load", () => events.push("constructed-load"));
      constructed.onload = () => {
        constructedOnload = true;
      };
      constructed.src = "data:image/webp;base64,stub";
      const probe = new Image();
      let probeOnload = false;
      probe.onload = () => {
        probeOnload = true;
      };
      probe.src = "data:image/webp;base64,stub";
      await new Promise((resolve) => setTimeout(resolve, 0));
      return JSON.stringify({
        complete: image.complete,
        constructed: {
          height: constructed.height,
          instance: constructed instanceof HTMLImageElement,
          naturalHeight: constructed.naturalHeight,
          naturalWidth: constructed.naturalWidth,
          onload: constructedOnload,
          width: constructed.width,
        },
        decode: typeof image.decode,
        events,
        imagesLength: document.images.length,
        loading: image.loading,
        loadingAttr: image.getAttribute("loading"),
        probe: {
          height: probe.height,
          onload: probeOnload,
          width: probe.width,
        },
        src: image.src,
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      complete: true,
      constructed: {
        height: 24,
        instance: true,
        naturalHeight: 24,
        naturalWidth: 32,
        onload: true,
        width: 32,
      },
      decode: "function",
      events: ["load", "constructed-load"],
      imagesLength: 2,
      loading: "eager",
      loadingAttr: "eager",
      probe: {
        height: 1,
        onload: true,
        width: 1,
      },
      src: "https://example.test/hero-2.png",
    });
  });

  test("provides browser-side media stabilization stubs used by capture scripts", async () => {
    await page.setContent(`
      <html>
        <body>
          <video id="clip" src="https://example.test/clip.mp4"></video>
        </body>
      </html>
    `);

    const snapshot = await page.evaluate(() => {
      const video = document.querySelector("#clip") as HTMLVideoElement;
      const events: string[] = [];
      video.addEventListener("pause", () => events.push("pause"));
      video.currentTime = 12.5;
      video.pause();
      return JSON.stringify({
        currentTime: video.currentTime,
        events,
        pause: typeof video.pause,
        paused: video.paused,
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      currentTime: 12.5,
      events: ["pause"],
      pause: "function",
      paused: true,
    });
  });

  test("provides IntersectionObserver callbacks for page hydration code", async () => {
    await page.setViewport(240, 120);
    await page.setContent(`
      <html>
        <body style="margin:0">
          <div id="hero" style="width:120px;height:60px"></div>
        </body>
      </html>
    `);

    const snapshot = await page.evaluate(async () => {
      return await new Promise<string>((resolve) => {
        const target = document.querySelector("#hero")!;
        const observer = new IntersectionObserver((entries) => {
          const entry = entries[0];
          const pending = observer.takeRecords();
          observer.unobserve(target);
          observer.disconnect();
          resolve(JSON.stringify({
            callbackCount: entries.length,
            ctor: typeof IntersectionObserver,
            isIntersecting: entry.isIntersecting,
            ratio: entry.intersectionRatio,
            targetMatches: entry.target === target,
            width: entry.boundingClientRect.width,
            pending: pending.length,
            rootMargin: observer.rootMargin,
            thresholds: observer.thresholds,
          }));
        }, { threshold: [0, 0.5], rootMargin: "0px" });
        observer.observe(target);
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      callbackCount: 1,
      ctor: "function",
      isIntersecting: true,
      ratio: 1,
      targetMatches: true,
      width: 120,
      pending: 0,
      rootMargin: "0px",
      thresholds: [0, 0.5],
    });
  });

  test("provides ResizeObserver callbacks for layout hydration code", async () => {
    await page.setContent(`
      <html>
        <body style="margin:0">
          <div id="hero" style="width:120px;height:60px"></div>
        </body>
      </html>
    `);

    const snapshot = await page.evaluate(async () => {
      return await new Promise<string>((resolve) => {
        const target = document.querySelector("#hero")!;
        const observer = new ResizeObserver((entries) => {
          const entry = entries[0];
          const pending = observer.takeRecords();
          observer.unobserve(target);
          observer.disconnect();
          resolve(JSON.stringify({
            callbackCount: entries.length,
            ctor: typeof ResizeObserver,
            contentHeight: entry.contentRect.height,
            contentWidth: entry.contentRect.width,
            targetMatches: entry.target === target,
            borderInline: entry.borderBoxSize[0].inlineSize,
            borderBlock: entry.borderBoxSize[0].blockSize,
            contentInline: entry.contentBoxSize[0].inlineSize,
            devicePixelInline: entry.devicePixelContentBoxSize[0].inlineSize,
            pending: pending.length,
          }));
        });
        observer.observe(target);
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      callbackCount: 1,
      ctor: "function",
      contentHeight: 60,
      contentWidth: 120,
      targetMatches: true,
      borderInline: 120,
      borderBlock: 60,
      contentInline: 120,
      devicePixelInline: 120,
      pending: 0,
    });
  });

  test("provides DOMParser text/html documents for rich text hydration", async () => {
    await page.setContent("<html><body>DOMParser host</body></html>");

    const snapshot = await page.evaluate(() => {
      const parsed = new DOMParser().parseFromString(
        '<!doctype html><html><head><title>Parsed</title></head><body><p id="lead">Hello <strong>Crater</strong></p></body></html>',
        "text/html",
      );
      const lead = parsed.querySelector("#lead");
      const strong = parsed.querySelector("strong");
      return JSON.stringify({
        ctor: typeof DOMParser,
        contentType: parsed.contentType,
        documentElement: parsed.documentElement.tagName,
        title: parsed.querySelector("title")?.textContent,
        leadText: lead?.textContent,
        strongText: strong?.textContent,
        bodyChildCount: parsed.body.children.length,
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      ctor: "function",
      contentType: "text/html",
      documentElement: "HTML",
      title: "Parsed",
      leadText: "Hello Crater",
      strongText: "Crater",
      bodyChildCount: 1,
    });
  });

  test("provides browser-side element constructors used by capture scripts", async () => {
    await page.setContent(`
      <html>
        <body>
          <div id="box"></div>
          <input id="name" />
          <textarea id="bio"></textarea>
          <select id="mode"></select>
          <dialog id="confirm"></dialog>
        </body>
      </html>
    `);

    const snapshot = await page.evaluate(() => {
      const box = document.querySelector("#box")!;
      const input = document.querySelector("#name")!;
      const textarea = document.querySelector("#bio")!;
      const select = document.querySelector("#mode")!;
      const dialog = document.querySelector("#confirm")!;
      const text = document.createTextNode("text");
      const comment = document.createComment("comment");
      return JSON.stringify({
        bodyIsDocumentNode: document instanceof Document,
        boxIsHTMLElement: box instanceof HTMLElement,
        boxIsElement: box instanceof Element,
        boxIsNode: box instanceof Node,
        commentIsComment: comment instanceof Comment,
        commentIsNode: comment instanceof Node,
        constructors: {
          Comment: typeof Comment,
          Document: typeof Document,
          Element: typeof Element,
          HTMLDialogElement: typeof HTMLDialogElement,
          HTMLElement: typeof HTMLElement,
          HTMLInputElement: typeof HTMLInputElement,
          HTMLSelectElement: typeof HTMLSelectElement,
          HTMLTextAreaElement: typeof HTMLTextAreaElement,
          Node: typeof Node,
          Text: typeof Text,
        },
        dialogIsDialog: dialog instanceof HTMLDialogElement,
        inputIsHTMLElement: input instanceof HTMLElement,
        inputIsInput: input instanceof HTMLInputElement,
        nodeConstants: {
          element: Node.ELEMENT_NODE,
          text: Node.TEXT_NODE,
          comment: Node.COMMENT_NODE,
          document: Node.DOCUMENT_NODE,
        },
        selectIsSelect: select instanceof HTMLSelectElement,
        textIsNode: text instanceof Node,
        textIsText: text instanceof Text,
        textareaIsInput: textarea instanceof HTMLInputElement,
        textareaIsTextarea: textarea instanceof HTMLTextAreaElement,
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      bodyIsDocumentNode: true,
      boxIsHTMLElement: true,
      boxIsElement: true,
      boxIsNode: true,
      commentIsComment: true,
      commentIsNode: true,
      constructors: {
        Comment: "function",
        Document: "function",
        Element: "function",
        HTMLDialogElement: "function",
        HTMLElement: "function",
        HTMLInputElement: "function",
        HTMLSelectElement: "function",
        HTMLTextAreaElement: "function",
        Node: "function",
        Text: "function",
      },
      dialogIsDialog: true,
      inputIsHTMLElement: true,
      inputIsInput: true,
      nodeConstants: {
        element: 1,
        text: 3,
        comment: 8,
        document: 9,
      },
      selectIsSelect: true,
      textIsNode: true,
      textIsText: true,
      textareaIsInput: false,
      textareaIsTextarea: true,
    });
  });

  test("supports autonomous customElements lifecycle used by hydration code", async () => {
    await page.setContent(`
      <html>
        <body>
          <x-studio-card id="existing" data-mode="initial"></x-studio-card>
        </body>
      </html>
    `);

    const snapshot = await page.evaluate(async () => {
      const events: string[] = [];

      class StudioCard extends HTMLElement {
        static get observedAttributes() {
          return ["data-mode"];
        }

        connectedCallback() {
          events.push(`connected:${this.id || "new"}:${this.getAttribute("data-mode") || ""}`);
        }

        disconnectedCallback() {
          events.push(`disconnected:${this.id || "new"}:${String(this.isConnected)}`);
        }

        attributeChangedCallback(name: string, oldValue: string | null, newValue: string | null) {
          events.push(`attr:${name}:${oldValue || ""}->${newValue || ""}`);
        }
      }

      const definedPromise = customElements.whenDefined("x-studio-card")
        .then((ctor) => ctor === StudioCard);
      customElements.define("x-studio-card", StudioCard);
      const defined = await definedPromise;

      const existing = document.querySelector("#existing") as HTMLElement;
      existing.setAttribute("data-mode", "hydrated");

      const created = document.createElement("x-studio-card") as HTMLElement;
      created.id = "created";
      document.body.appendChild(created);
      document.body.removeChild(created);

      return JSON.stringify({
        ctor: typeof customElements,
        defined,
        getMatches: customElements.get("x-studio-card") === StudioCard,
        existingInstance: existing instanceof StudioCard,
        createdInstance: created instanceof StudioCard,
        events,
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      ctor: "object",
      defined: true,
      getMatches: true,
      existingInstance: true,
      createdInstance: true,
      events: [
        "attr:data-mode:->initial",
        "connected:existing:initial",
        "attr:data-mode:initial->hydrated",
        "connected:created:",
        "disconnected:created:false",
      ],
    });
  });

  test("applies appended style elements for browser-side stabilization scripts", async () => {
    await page.setContent(`
      <html>
        <body>
          <div id="box" class="capture-target disabled"></div>
        </body>
      </html>
    `);

    const snapshot = await page.evaluate(() => {
      const box = document.querySelector("#box") as HTMLElement;
      const style = document.createElement("style");
      style.textContent = `
        .capture-target {
          width: 80px;
          height: 24px;
        }
        #box {
          left: 12px;
          top: 8px;
        }
      `;
      document.head.appendChild(style);
      box.classList.remove("disabled");
      const rect = box.getBoundingClientRect();
      return JSON.stringify({
        className: box.className,
        height: rect.height,
        left: rect.left,
        top: rect.top,
        width: rect.width,
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      className: "capture-target",
      height: 24,
      left: 12,
      top: 8,
      width: 80,
    });
  });

  test("supports Element.remove used by Vite-injected CSS modules", async () => {
    await page.setContentWithScripts(`
      <html>
        <head>
          <link href="/_nuxt/assets/css/_transition.scss">
          <link href="/_nuxt/assets/css/_variables.scss">
        </head>
        <body>
          <script>
            document
              .querySelectorAll('link[href="/_nuxt/assets/css/_transition.scss"]')
              .forEach((item) => item.remove());
            const lastInsertedStyle = document.querySelector('link[href="/_nuxt/assets/css/_variables.scss"]');
            const style = document.createElement("style");
            style.id = "vite-css-module";
            lastInsertedStyle.insertAdjacentElement("afterend", style);
            document.body.setAttribute("data-links", String(document.querySelectorAll("link").length));
            document.body.setAttribute(
              "data-head-order",
              Array.from(document.head.children).map((item) => item.id || item.tagName).join(",")
            );
            let windowEventCount = 0;
            const listener = () => windowEventCount += 1;
            window.addEventListener("vite:css-ready", listener);
            window.dispatchEvent(new Event("vite:css-ready"));
            window.removeEventListener("vite:css-ready", listener);
            window.dispatchEvent(new Event("vite:css-ready"));
            document.body.setAttribute("data-window-events", String(windowEventCount));
          </script>
        </body>
      </html>
    `);

    await expect(page.locator("body").getAttribute("data-links")).resolves.toBe("1");
    await expect(page.locator("body").getAttribute("data-head-order")).resolves.toBe("LINK,vite-css-module");
    await expect(page.locator("body").getAttribute("data-window-events")).resolves.toBe("1");
  });

  test("preserves window event target APIs after navigation document reset", async () => {
    await page.route("https://example.test/vite-window-events.html", async (route) => {
      await route.fulfill({
        contentType: "text/html; charset=utf-8",
        body: `
          <html>
            <body>
              <script>
                let count = 0;
                const listener = () => count += 1;
                window.addEventListener("vite:css-ready", listener);
                window.dispatchEvent(new Event("vite:css-ready"));
                window.removeEventListener("vite:css-ready", listener);
                window.dispatchEvent(new Event("vite:css-ready"));
                document.body.setAttribute("data-window-events", String(count));
              </script>
            </body>
          </html>
        `,
      });
    });

    await page.goto("https://example.test/vite-window-events.html", {
      waitUntil: "commit",
      timeout: 1000,
    });

    await expect(page.locator("body").getAttribute("data-window-events")).resolves.toBe("1");
  });

  test("provides CSS and SVG DOM APIs needed by Nuxt preview startup", async () => {
    await page.route("https://example.test/nuxt-preview-apis.html", async (route) => {
      await route.fulfill({
        contentType: "text/html; charset=utf-8",
        body: `
          <html>
            <body>
              <script>
                const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
                const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
                const start = document.createComment("[");
                const middle = document.createElement("span");
                const end = document.createComment("]");
                path.setAttribute("d", "M0 0L1 1");
                svg.setAttribute("data-probe", "yes");
                svg.appendChild(path);
                document.body.appendChild(start);
                document.body.appendChild(middle);
                document.body.appendChild(end);
                document.body.appendChild(svg);
                document.body.setAttribute("data-css-supports", String(CSS.supports("animation-timeline", "scroll()")));
                document.body.setAttribute("data-css-escape", CSS.escape("a b#c"));
                document.body.setAttribute("data-svg-instance", String(svg instanceof SVGElement));
                document.body.setAttribute("data-svg-ns", svg.namespaceURI);
                document.body.setAttribute("data-path-tag", path.tagName);
                document.body.setAttribute("data-comment-next", String(start.nextSibling === middle && middle.nextSibling === end));
                document.body.setAttribute("data-has-children", String(document.body.hasChildNodes()));
                document.body.setAttribute("data-attr-names", JSON.stringify(svg.getAttributeNames()));
                class PreviewInspector extends HTMLElement {
                  constructor() {
                    super();
                    this._dirty = false;
                  }
                }
                const inspector = new PreviewInspector();
                inspector.setAttribute("id", "preview-inspector");
                document.body.appendChild(inspector);
                document.body.setAttribute(
                  "data-custom-element",
                  String(inspector instanceof HTMLElement) + ":" + String(inspector._dirty) + ":" + typeof inspector.attachShadow
                );
              </script>
            </body>
          </html>
        `,
      });
    });

    await page.goto("https://example.test/nuxt-preview-apis.html", {
      waitUntil: "commit",
      timeout: 1000,
    });

    await expect(page.locator("body").getAttribute("data-css-supports")).resolves.toBe("true");
    await expect(page.locator("body").getAttribute("data-css-escape")).resolves.toBe("a\\ b\\#c");
    await expect(page.locator("body").getAttribute("data-svg-instance")).resolves.toBe("true");
    await expect(page.locator("body").getAttribute("data-svg-ns")).resolves.toBe("http://www.w3.org/2000/svg");
    await expect(page.locator("body").getAttribute("data-path-tag")).resolves.toBe("path");
    await expect(page.locator("body").getAttribute("data-comment-next")).resolves.toBe("true");
    await expect(page.locator("body").getAttribute("data-has-children")).resolves.toBe("true");
    await expect(page.locator("body").getAttribute("data-attr-names")).resolves.toBe("[\"data-probe\"]");
    await expect(page.locator("body").getAttribute("data-custom-element")).resolves.toBe("true:false:function");
  });

  test("supports page and locator setInputFiles for file inputs", async () => {
    await page.setContent(`
      <html>
        <body>
          <input id="avatar" type="file" />
          <script>
            window.__adapterFileEvents = [];
            const input = document.querySelector("#avatar");
            for (const type of ["input", "change", "cancel"]) {
              input.addEventListener(type, () => {
                window.__adapterFileEvents.push({
                  type,
                  names: Array.from(input.files || []).map((file) => file.name),
                });
              });
            }
          </script>
        </body>
      </html>
    `);

    await page.setInputFiles("#avatar", "fixtures/avatar.png");
    await expect(page.evaluate(() => {
      const input = document.querySelector("#avatar") as HTMLInputElement;
      return JSON.stringify({
        names: Array.from(input.files || []).map((file) => file.name),
        events: (window as unknown as {
          __adapterFileEvents: Array<{ type: string; names: string[] }>;
        }).__adapterFileEvents,
      });
    })).resolves.toBe(JSON.stringify({
      names: ["avatar.png"],
      events: [
        { type: "input", names: ["avatar.png"] },
        { type: "change", names: ["avatar.png"] },
      ],
    }));

    await page.locator("#avatar").setInputFiles("fixtures/avatar.png");
    await expect(page.evaluate(() => {
      const input = document.querySelector("#avatar") as HTMLInputElement;
      return JSON.stringify({
        names: Array.from(input.files || []).map((file) => file.name),
        events: (window as unknown as {
          __adapterFileEvents: Array<{ type: string; names: string[] }>;
        }).__adapterFileEvents,
      });
    })).resolves.toContain("\"cancel\"");

    await page.setInputFiles("#avatar", {
      name: "inline-avatar.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("hello"),
    });
    await expect(page.evaluate(() => {
      const file = Array.from((document.querySelector("#avatar") as HTMLInputElement).files || [])[0];
      return JSON.stringify({
        name: file.name,
        type: file.type,
        size: file.size,
      });
    })).resolves.toBe(JSON.stringify({
      name: "inline-avatar.txt",
      type: "text/plain",
      size: 5,
    }));

    const chooserPromise = page.waitForEvent("filechooser");
    await page.locator("#avatar").click();
    const chooser = await chooserPromise;
    expect(chooser.isMultiple()).toBe(false);
    await chooser.setFiles({
      name: "chooser-avatar.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("chooser"),
    });
    await expect(page.evaluate(() => {
      const file = Array.from((document.querySelector("#avatar") as HTMLInputElement).files || [])[0];
      return JSON.stringify({
        name: file.name,
        type: file.type,
        size: file.size,
      });
    })).resolves.toBe(JSON.stringify({
      name: "chooser-avatar.txt",
      type: "text/plain",
      size: 7,
    }));
  });

  test("supports page event listeners and waitForEvent for common Playwright events", async () => {
    await page.setContent("<html><body><output id='status'>idle</output></body></html>");
    await page.route(/\/adapter-event\.json$/, async (route) => {
      await route.fulfill({
        contentType: "application/json",
        body: JSON.stringify({ ok: true }),
      });
    });

    const observedRequests: string[] = [];
    const observedResponses: number[] = [];
    page.on("request", (request) => {
      observedRequests.push(request.url());
    });
    page.on("response", (response) => {
      observedResponses.push(response.status());
    });

    const requestPromise = page.waitForEvent("request", {
      predicate: (request) => request.url().endsWith("/adapter-event.json"),
    });
    const responsePromise = page.waitForEvent("response", {
      predicate: (response) => response.url().endsWith("/adapter-event.json"),
    });

    await page.evaluate(async () => {
      const response = await fetch("https://example.test/adapter-event.json");
      document.querySelector("#status")!.textContent = String(response.status);
    });

    const request = await requestPromise;
    const response = await responsePromise;
    expect(request.url()).toBe("https://example.test/adapter-event.json");
    expect(response.status()).toBe(200);
    expect(observedRequests).toContain("https://example.test/adapter-event.json");
    expect(observedResponses).toContain(200);
    await expect(page.locator("#status").textContent()).resolves.toBe("200");

    const loadPromise = page.waitForEvent("load");
    await page.setContent("<html><body><p>loaded</p></body></html>");
    await expect(loadPromise).resolves.toBe(page);

    const closePromise = page.waitForEvent("close");
    await page.close();
    await expect(closePromise).resolves.toBe(page);
  });

  test("supports dialog events backed by BiDi user prompts", async () => {
    const observedDialogs: string[] = [];
    page.on("dialog", (dialog) => {
      observedDialogs.push(dialog.message());
    });

    const dialogPromise = page.waitForEvent("dialog");
    const valuePromise = page.evaluate<string>("window.prompt('Name?', 'crater')");

    const dialog = await dialogPromise;
    expect(observedDialogs).toEqual(["Name?"]);
    expect(dialog.type()).toBe("prompt");
    expect(dialog.message()).toBe("Name?");
    expect(dialog.defaultValue()).toBe("crater");
    expect(dialog.page()).toBe(page);

    await dialog.accept("accepted");
    await expect(valuePromise).resolves.toBe("accepted");
  });

  test("supports download events backed by BiDi download lifecycle", async () => {
    await page.setContent(`
      <html>
        <body>
          <a id="download_link" href="data:text/plain,hello" download="hello.txt">download</a>
        </body>
      </html>
    `);
    const observedDownloads: string[] = [];
    page.on("download", (download) => {
      observedDownloads.push(download.suggestedFilename());
    });

    const downloadPromise = page.waitForEvent("download");
    await page.evaluate("download_link.click()");

    const download = await downloadPromise;
    expect(observedDownloads).toEqual(["hello.txt"]);
    expect(download.url()).toBe("data:text/plain,hello");
    expect(download.suggestedFilename()).toBe("hello.txt");
    await expect(download.failure()).resolves.toBeNull();
    const downloadPath = await download.path();
    expect(downloadPath).toContain("hello.txt");
    expect(download.page()).toBe(page);

    const outputDir = await mkdtemp(join(tmpdir(), "crater-download-"));
    try {
      const savedPath = join(outputDir, "saved.txt");
      await download.saveAs(savedPath);
      await expect(readFile(savedPath, "utf8")).resolves.toBe("hello");

      await download.cancel();
      await expect(download.failure()).resolves.toBeNull();

      await download.delete();
      await expect(access(downloadPath!)).rejects.toThrow();
    } finally {
      await rm(outputDir, { force: true, recursive: true });
    }
  });

  test("supports console events from evaluated page code", async () => {
    const observed: string[] = [];
    page.on("console", (message) => {
      observed.push(`${message.type()}:${message.text()}`);
    });

    const consolePromise = page.waitForEvent("console", {
      predicate: (message) => message.text().includes("ready"),
    });
    await page.evaluate(() => {
      console.log("adapter", "ready");
    });

    const message = await consolePromise;
    expect(message.type()).toBe("log");
    expect(message.text()).toBe("adapter ready");
    expect(message.page()).toBe(page);
    expect(observed).toEqual(["log:adapter ready"]);
  });

  test("supports pageerror events from evaluated page exceptions", async () => {
    const observed: string[] = [];
    page.on("pageerror", (error) => {
      observed.push(error.message);
    });

    const errorPromise = page.waitForEvent("pageerror", {
      predicate: (error) => error.message.includes("adapter boom"),
    });

    await expect(page.evaluate(() => {
      throw new Error("adapter boom");
    })).rejects.toThrow("adapter boom");

    const error = await errorPromise;
    expect(error).toBeInstanceOf(Error);
    expect(error.message).toContain("adapter boom");
    expect(observed.some((message) => message.includes("adapter boom"))).toBe(true);
  });

  test("supports pageerror events from executed script tags", async () => {
    const pageErrorPromise = page.waitForEvent("pageerror", {
      predicate: (error) => error.message.includes("script boom"),
    });

    await page.setContent(`
      <html>
        <body>
          <script>throw new Error("script boom")</script>
        </body>
      </html>
    `);

    const error = await pageErrorPromise;
    expect(error).toBeInstanceOf(Error);
    expect(error.message).toContain("script boom");
  });
});

test.describe("Crater browser/context wrapper", () => {
  test("supports browser/context style isolated pages", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext();
    try {
      const first = await context.newPage();
      const second = await context.newPage();

      await first.setContent("<html><head><title>First</title></head><body><div id='value'>one</div></body></html>");
      await expect(first.content()).resolves.toContain("one");
      await second.setContent("<html><head><title>Second</title></head><body><div id='value'>two</div></body></html>");

      expect(context.pages()).toEqual([first, second]);
      await expect(first.content()).resolves.toContain("one");
      await expect(first.title()).resolves.toBe("First");
      await expect(second.title()).resolves.toBe("Second");
      await expect(first.locator("#value").textContent()).resolves.toBe("one");
      await expect(second.locator("#value").textContent()).resolves.toBe("two");
    } finally {
      await browser.close();
    }
  });

  test("keeps sibling pages usable after the first user page closes", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext();
    try {
      const first = await context.newPage();
      const second = await context.newPage();

      await first.setContent("<html><body><div id='value'>first</div></body></html>");
      await second.setContent("<html><body><div id='value'>second</div></body></html>");

      await first.close();
      expect(context.pages()).toEqual([second]);
      await expect(second.locator("#value").textContent()).resolves.toBe("second");

      const third = await context.newPage();
      await third.setContent("<html><body><div id='value'>third</div></body></html>");
      expect(context.pages()).toEqual([second, third]);
      await expect(third.locator("#value").textContent()).resolves.toBe("third");
    } finally {
      await browser.close();
    }
  });

  test("updates wrapper lists and rejects work after idempotent close", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext();
    const page = await context.newPage();

    expect(browser.contexts()).toEqual([context]);
    expect(context.pages()).toEqual([page]);

    await context.close();
    await context.close();

    expect(context.pages()).toEqual([]);
    expect(browser.contexts()).toEqual([]);
    await expect(page.title()).rejects.toThrow(/closed|No browsing context|Not connected/);
    await expect(context.newPage()).rejects.toThrow(/closed/);

    await browser.close();
    await browser.close();
    await expect(browser.newContext()).rejects.toThrow(/closed/);
  });

  test("snapshots localStorage through context.storageState", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext();
    try {
      const page = await context.newPage();
      await page.setContent("<html><body>storage</body></html>");
      await page.evaluate(() => {
        localStorage.setItem("theme", "dark");
        localStorage.setItem("token", "abc");
        sessionStorage.setItem("ephemeral", "ignored");
      });

      const state = await context.storageState();

      expect(state.cookies).toEqual([]);
      expect(state.origins).toContainEqual({
        origin: "about:blank",
        localStorage: [
          { name: "theme", value: "dark" },
          { name: "token", value: "abc" },
        ],
      });
    } finally {
      await browser.close();
    }
  });

  test("isolates localStorage between browser contexts", async () => {
    const browser = createCraterBrowser();
    try {
      const firstContext = await browser.newContext();
      const firstPage = await firstContext.newPage();
      await firstPage.setContent("<html><body>first</body></html>");
      await firstPage.evaluate(() => {
        localStorage.setItem("__VUE_DEVTOOLS_NEXT_PLUGIN_SETTINGS__dev.esm.pinia__", "{}");
      });
      await firstContext.close();

      const secondContext = await browser.newContext();
      const secondPage = await secondContext.newPage();
      await secondPage.setContent("<html><body>second</body></html>");
      await secondPage.evaluate(() => {
        localStorage.setItem("theme", "dark");
      });
      const state = await secondContext.storageState();

      expect(state.origins).toContainEqual({
        origin: "about:blank",
        localStorage: [{ name: "theme", value: "dark" }],
      });
    } finally {
      await browser.close();
    }
  });

  test("keeps multiple live browser contexts on one shared BiDi session", async () => {
    const browser = createCraterBrowser();
    try {
      const previewContext = await browser.newContext();
      const hrcContext = await browser.newContext();
      const previewPage = await previewContext.newPage();
      const hrcPage = await hrcContext.newPage();

      await Promise.all([
        previewPage.route(/blocked-preview/, (route) => route.abort()),
        hrcPage.route(/blocked-hrc/, (route) => route.abort()),
      ]);

      await Promise.all([
        previewPage.setContent("<html><body><main id='value'>preview</main></body></html>"),
        hrcPage.setContent("<html><body><main id='value'>hrc</main></body></html>"),
      ]);

      const [previewText, hrcText] = await Promise.all([
        previewPage.evaluate(async () => {
          await new Promise((resolve) => setTimeout(resolve, 25));
          return document.querySelector("#value")?.textContent ?? "";
        }),
        hrcPage.evaluate(async () => {
          await new Promise((resolve) => setTimeout(resolve, 5));
          return document.querySelector("#value")?.textContent ?? "";
        }),
      ]);

      expect(previewText).toBe("preview");
      expect(hrcText).toBe("hrc");
      await expect(previewPage.locator("#value").textContent()).resolves.toBe("preview");
      await expect(hrcPage.locator("#value").textContent()).resolves.toBe("hrc");
    } finally {
      await browser.close();
    }
  });

  test("captures paint data from the requested shared context after another context is current", async () => {
    const browser = createCraterBrowser();
    try {
      const previewContext = await browser.newContext();
      const hrcContext = await browser.newContext();
      const previewPage = await previewContext.newPage();
      const hrcPage = await hrcContext.newPage();

      await previewPage.setViewport(96, 64);
      await hrcPage.setViewport(96, 64);
      await previewPage.setContent(`
        <html>
          <body style="margin:0;background:#000">
            <main id="value" style="width:96px;height:64px;background:#000;color:#fff">preview-context</main>
          </body>
        </html>
      `);
      await hrcPage.setContent(`
        <html>
          <body style="margin:0;background:#fff">
            <main id="value" style="width:96px;height:64px;background:#fff;color:#000">hrc-context</main>
          </body>
        </html>
      `);

      const previewTree = await previewPage.capturePaintTree();
      expect(previewTree.paintTree).toContain("preview-context");
      expect(previewTree.paintTree).not.toContain("hrc-context");

      const previewPng = await previewPage.screenshot({ timeout: 1000, type: "png" });
      const previewImage = await decodePng(previewPng);
      const pixelOffset = (50 * previewImage.width + 80) * 4;
      expect(previewImage.data[pixelOffset]).toBeLessThan(50);
      expect(previewImage.data[pixelOffset + 1]).toBeLessThan(50);
      expect(previewImage.data[pixelOffset + 2]).toBeLessThan(50);

      const hrcTree = await hrcPage.capturePaintTree();
      expect(hrcTree.paintTree).toContain("hrc-context");
      expect(hrcTree.paintTree).not.toContain("preview-context");
    } finally {
      await browser.close();
    }
  });

  test("keeps page URLs isolated across concurrent shared-context navigations", async () => {
    const server = await createLocalFixtureServer();
    const browser = createCraterBrowser();
    try {
      const previewUrl = server.serve(
        "/preview-context.html",
        "<html><body><main id='value'>preview-url</main></body></html>",
      );
      const hrcUrl = server.serve(
        "/hrc-context.html",
        "<html><body><main id='value'>hrc-url</main></body></html>",
      );
      const previewContext = await browser.newContext();
      const hrcContext = await browser.newContext();
      const previewPage = await previewContext.newPage();
      const hrcPage = await hrcContext.newPage();

      await Promise.all([
        previewPage.goto(previewUrl),
        hrcPage.goto(hrcUrl),
      ]);

      expect(previewPage.url()).toBe(previewUrl);
      expect(hrcPage.url()).toBe(hrcUrl);
      await expect(previewPage.locator("#value").textContent()).resolves.toBe("preview-url");
      await expect(hrcPage.locator("#value").textContent()).resolves.toBe("hrc-url");
      expect(previewPage.url()).toBe(previewUrl);
      expect(hrcPage.url()).toBe(hrcUrl);
    } finally {
      await browser.close();
      await server.close();
    }
  });

  test("supports context cookies through the storage backend", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext();
    try {
      const page = await context.newPage();
      await page.setContent("<html><body>cookies</body></html>");
      await page.evaluate(() => {
        history.pushState({}, "", "https://example.test/app");
      });

      await context.addCookies([
        {
          name: "sid",
          value: "abc",
          domain: "example.test",
          path: "/",
          expires: -1,
          httpOnly: false,
          secure: true,
          sameSite: "Lax",
        },
        {
          name: "scoped",
          value: "from-url",
          url: "https://example.test/app/page",
          sameSite: "Lax",
        },
      ]);

      await expect(context.cookies()).resolves.toMatchObject([
        {
          name: "sid",
          value: "abc",
          domain: "example.test",
          path: "/",
          secure: true,
          sameSite: "Lax",
        },
        {
          name: "scoped",
          value: "from-url",
          domain: "example.test",
          path: "/app",
          secure: true,
          sameSite: "Lax",
        },
      ]);
      await expect(context.cookies("https://example.test/app/page")).resolves.toMatchObject([
        { name: "sid" },
        { name: "scoped" },
      ]);
      await expect(context.cookies("https://example.test/other")).resolves.toMatchObject([
        { name: "sid" },
      ]);
      await expect(page.evaluate<string>("document.cookie")).resolves.toContain("sid=abc");

      await context.clearCookies({ name: "sid" });
      await expect(context.cookies()).resolves.toMatchObject([
        { name: "scoped", value: "from-url" },
      ]);

      await context.clearCookies({ domain: /example\.test/, path: "/app" });
      await expect(context.cookies()).resolves.toEqual([]);
    } finally {
      await browser.close();
    }
  });

  test("preloads storageState when creating a browser context", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext({
      storageState: {
        cookies: [
          {
            name: "sid",
            value: "from-state",
            domain: "example.test",
            path: "/",
            expires: -1,
            httpOnly: false,
            secure: true,
            sameSite: "Lax",
          },
        ],
        origins: [
          {
            origin: "about:blank",
            localStorage: [{ name: "theme", value: "dark" }],
          },
        ],
      },
    });
    try {
      const page = await context.newPage();
      await page.setContent("<html><body>storage preload</body></html>");

      await expect(page.evaluate<string>("localStorage.getItem('theme')")).resolves.toBe("dark");

      await page.evaluate(() => {
        history.pushState({}, "", "https://example.test/app");
      });
      await expect(page.evaluate<string>("document.cookie")).resolves.toContain("sid=from-state");
    } finally {
      await browser.close();
    }
  });

  test("round-trips storageState through a file path", async () => {
    const dir = await mkdtemp(join(tmpdir(), "crater-storage-state-"));
    const storagePath = join(dir, "state.json");
    const browser = createCraterBrowser();
    try {
      const context = await browser.newContext({
        storageState: {
          cookies: [
            {
              name: "sid",
              value: "file-state",
              domain: "example.test",
              path: "/",
              expires: -1,
              httpOnly: false,
              secure: true,
              sameSite: "Lax",
            },
          ],
          origins: [
            {
              origin: "about:blank",
              localStorage: [{ name: "theme", value: "file" }],
            },
          ],
        },
      });
      await context.storageState({ path: storagePath });
      await context.close();

      const saved = JSON.parse(await readFile(storagePath, "utf8"));
      expect(saved.cookies).toMatchObject([{ name: "sid", value: "file-state" }]);
      expect(saved.origins).toContainEqual({
        origin: "about:blank",
        localStorage: [{ name: "theme", value: "file" }],
      });

      const restoredContext = await browser.newContext({ storageState: storagePath });
      const page = await restoredContext.newPage();
      await page.setContent("<html><body>storage path</body></html>");
      await expect(page.evaluate<string>("localStorage.getItem('theme')")).resolves.toBe("file");
      await page.evaluate(() => {
        history.pushState({}, "", "https://example.test/app");
      });
      await expect(page.evaluate<string>("document.cookie")).resolves.toContain("sid=file-state");
    } finally {
      await browser.close();
      await rm(dir, { recursive: true, force: true });
    }
  });

  test("supports context route for existing and future pages", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext();
    const renderFetchResult = async (page: CraterBidiPage, selector: string) => {
      const id = selector.slice(1);
      await page.setContentWithScripts(`
        <html>
          <body>
            <div id="${id}">pending</div>
            <script>
              const setResult = (text) => {
                const target = document.getElementById(${JSON.stringify(id)});
                if (target) target.textContent = text;
              };
              fetch("/api/context-route")
                .then((response) => response.text())
                .then(setResult)
                .catch((error) => setResult("error:" + error.message));
            </script>
          </body>
        </html>
      `);
      await page.waitForText(selector, "context-routed");
      return page.locator(selector).textContent();
    };

    try {
      const firstPage = await context.newPage();
      await context.route("/api/context-route", async (route) => {
        await route.fulfill({
          contentType: "text/plain",
          body: "context-routed",
        });
      });

      await expect(renderFetchResult(firstPage, "#first")).resolves.toBe("context-routed");
      await firstPage.close();

      const secondPage = await context.newPage();
      await expect(renderFetchResult(secondPage, "#second")).resolves.toBe("context-routed");
    } finally {
      await browser.close();
    }
  });

  test("applies viewport and userAgent options to context pages", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext({
      viewport: { width: 360, height: 240 },
      userAgent: "CraterTest/1.0",
    });
    try {
      const page = await context.newPage();
      await expect(page.evaluate<number>("window.innerWidth")).resolves.toBe(360);
      await expect(page.evaluate<number>("window.innerHeight")).resolves.toBe(240);
      await expect(page.evaluate<string>("navigator.userAgent")).resolves.toBe("CraterTest/1.0");
    } finally {
      await browser.close();
    }
  });

  test("isolates viewport options across concurrent capture contexts", async () => {
    const browser = createCraterBrowser();
    try {
      const previewContext = await browser.newContext({
        viewport: { width: 360, height: 240 },
      });
      const hrcContext = await browser.newContext({
        viewport: { width: 640, height: 360 },
      });
      const previewPage = await previewContext.newPage();
      const hrcPage = await hrcContext.newPage();

      await Promise.all([
        previewPage.setContent("<html><body><main id='value'>preview</main></body></html>"),
        hrcPage.setContent("<html><body><main id='value'>hrc</main></body></html>"),
      ]);

      const [previewViewport, hrcViewport] = await Promise.all([
        previewPage.evaluate(() => ({ width: window.innerWidth, height: window.innerHeight })),
        hrcPage.evaluate(() => ({ width: window.innerWidth, height: window.innerHeight })),
      ]);

      expect(previewViewport).toEqual({ width: 360, height: 240 });
      expect(hrcViewport).toEqual({ width: 640, height: 360 });
      await expect(previewPage.locator("#value").textContent()).resolves.toBe("preview");
      await expect(hrcPage.locator("#value").textContent()).resolves.toBe("hrc");

      const [previewScreenshot, hrcScreenshot] = await Promise.all([
        previewPage.screenshot({ timeout: 1000, type: "png" }),
        hrcPage.screenshot({ timeout: 1000, type: "png" }),
      ]);

      expect({
        width: previewScreenshot.readUInt32BE(16),
        height: previewScreenshot.readUInt32BE(20),
      }).toEqual({ width: 360, height: 240 });
      expect({
        width: hrcScreenshot.readUInt32BE(16),
        height: hrcScreenshot.readUInt32BE(20),
      }).toEqual({ width: 640, height: 360 });

      await expect(previewPage.evaluate<number>("window.innerWidth")).resolves.toBe(360);
    } finally {
      await browser.close();
    }
  });

  test("supports context addInitScript for existing and future pages", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext();
    try {
      const existingPage = await context.newPage();
      await context.addInitScript("globalThis.__contextInit = 'ready'");

      await existingPage.setContentWithScripts(`
        <html>
          <body>
            <output id="status">pending</output>
            <script>
              document.getElementById("status").textContent = globalThis.__contextInit || "missing";
            </script>
          </body>
        </html>
      `);
      await expect(existingPage.locator("#status").textContent()).resolves.toBe("ready");

      const futurePage = await context.newPage();
      await futurePage.setContentWithScripts(`
        <html>
          <body>
            <output id="status">pending</output>
            <script>
              document.getElementById("status").textContent = globalThis.__contextInit || "missing";
            </script>
          </body>
        </html>
      `);
      await expect(futurePage.locator("#status").textContent()).resolves.toBe("ready");
    } finally {
      await browser.close();
    }
  });

  test("propagates context default timeout to existing and future pages", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext();
    try {
      const existingPage = await context.newPage();
      context.setDefaultTimeout(50);

      const startedExisting = Date.now();
      await expect(existingPage.waitForText("#missing", "ready")).rejects.toThrow(/Timeout/);
      expect(Date.now() - startedExisting).toBeLessThan(1000);

      const futurePage = await context.newPage();
      const startedFuture = Date.now();
      await expect(futurePage.waitForText("#missing", "ready")).rejects.toThrow(/Timeout/);
      expect(Date.now() - startedFuture).toBeLessThan(1000);
    } finally {
      await browser.close();
    }
  });

  test("applies locale option to context pages", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext({ locale: "fr-ca" });
    try {
      const page = await context.newPage();
      await expect(page.evaluate<string>("navigator.language")).resolves.toBe("fr-CA");
      await expect(page.evaluate<string>("navigator.languages[0]")).resolves.toBe("fr-CA");
      await expect(
        page.evaluate<string>("new Intl.DateTimeFormat().resolvedOptions().locale"),
      ).resolves.toBe("fr-CA");
    } finally {
      await browser.close();
    }
  });

  test("supports context offline override for existing and future pages", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext({ offline: true });
    try {
      const firstPage = await context.newPage();
      await expect(firstPage.evaluate<boolean>("navigator.onLine")).resolves.toBe(false);

      await context.setOffline(false);
      await expect(firstPage.evaluate<boolean>("navigator.onLine")).resolves.toBe(true);

      await context.setOffline(true);
      const secondPage = await context.newPage();
      await expect(secondPage.evaluate<boolean>("navigator.onLine")).resolves.toBe(false);
    } finally {
      await browser.close();
    }
  });

  test("supports context permissions and geolocation for existing and future pages", async () => {
    const browser = createCraterBrowser();
    const context = await browser.newContext({
      geolocation: { latitude: 35.1, longitude: 139.2, accuracy: 7 },
      permissions: ["geolocation"],
    });
    const queryGeolocationPermission = (target: CraterBidiPage) =>
      target.evaluate<string>(
        "navigator.permissions.query({ name: 'geolocation' }).then((status) => status.state)",
        { awaitPromise: true },
      );
    const currentPosition = (target: CraterBidiPage) =>
      target.evaluate<Record<string, number>>(
        `new Promise((resolve) => navigator.geolocation.getCurrentPosition(
          (position) => resolve(position.coords.toJSON()),
          (error) => resolve({ code: error.code }),
          { timeout: 500 }
        ))`,
        { awaitPromise: true },
      );
    try {
      const firstPage = await context.newPage();
      await firstPage.goto("data:text/html,geolocation");
      await expect(queryGeolocationPermission(firstPage)).resolves.toBe("granted");
      await expect(currentPosition(firstPage)).resolves.toMatchObject({
        latitude: 35.1,
        longitude: 139.2,
        accuracy: 7,
      });

      await context.clearPermissions();
      await expect(queryGeolocationPermission(firstPage)).resolves.toBe("prompt");
      await expect(currentPosition(firstPage)).resolves.toMatchObject({ code: 1 });

      await context.grantPermissions(["geolocation"], { origin: "http://localhost:8000" });
      await context.setGeolocation({ latitude: 10, longitude: 20, accuracy: 3 });
      await expect(currentPosition(firstPage)).resolves.toMatchObject({
        latitude: 10,
        longitude: 20,
        accuracy: 3,
      });

      const secondPage = await context.newPage();
      await secondPage.goto("data:text/html,geolocation-future");
      await expect(queryGeolocationPermission(secondPage)).resolves.toBe("granted");
      await expect(currentPosition(secondPage)).resolves.toMatchObject({
        latitude: 10,
        longitude: 20,
        accuracy: 3,
      });
    } finally {
      await browser.close();
    }
  });
});
