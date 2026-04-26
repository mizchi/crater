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
