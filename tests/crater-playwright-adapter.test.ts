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
    await expect(download.path()).resolves.toContain("hello.txt");
    expect(download.page()).toBe(page);
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
});
