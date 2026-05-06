import { access, mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { expect, test } from "@playwright/test";
import {
  CraterBidiPage,
  createCraterBrowser,
} from "../webdriver/playwright/adapter.ts";

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

    const clipped = await page.screenshot({
      clip: { x: 0, y: 0, width: 50, height: 40 },
      timeout: 1000,
      type: "png",
    });
    expect(dimensions(clipped)).toEqual({ width: 50, height: 40 });
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
      for (const lazyImage of Array.from(document.images).filter((candidate) => candidate.loading === "lazy")) {
        lazyImage.loading = "eager";
      }
      image.src = "https://example.test/hero-2.png";
      await image.decode();
      await new Promise((resolve) => setTimeout(resolve, 0));
      return JSON.stringify({
        complete: image.complete,
        decode: typeof image.decode,
        events,
        imagesLength: document.images.length,
        loading: image.loading,
        loadingAttr: image.getAttribute("loading"),
        src: image.src,
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      complete: true,
      decode: "function",
      events: ["load"],
      imagesLength: 2,
      loading: "eager",
      loadingAttr: "eager",
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

  test("provides browser-side element constructors used by capture scripts", async () => {
    await page.setContent(`
      <html>
        <body>
          <div id="box"></div>
          <input id="name" />
          <textarea id="bio"></textarea>
        </body>
      </html>
    `);

    const snapshot = await page.evaluate(() => {
      const box = document.querySelector("#box")!;
      const input = document.querySelector("#name")!;
      const textarea = document.querySelector("#bio")!;
      return JSON.stringify({
        boxIsHTMLElement: box instanceof HTMLElement,
        constructors: {
          HTMLElement: typeof HTMLElement,
          HTMLInputElement: typeof HTMLInputElement,
          HTMLTextAreaElement: typeof HTMLTextAreaElement,
        },
        inputIsHTMLElement: input instanceof HTMLElement,
        inputIsInput: input instanceof HTMLInputElement,
        textareaIsInput: textarea instanceof HTMLInputElement,
        textareaIsTextarea: textarea instanceof HTMLTextAreaElement,
      });
    });

    expect(JSON.parse(snapshot)).toEqual({
      boxIsHTMLElement: true,
      constructors: {
        HTMLElement: "function",
        HTMLInputElement: "function",
        HTMLTextAreaElement: "function",
      },
      inputIsHTMLElement: true,
      inputIsInput: true,
      textareaIsInput: false,
      textareaIsTextarea: true,
    });
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
