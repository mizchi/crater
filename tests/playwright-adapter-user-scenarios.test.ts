import { expect, test } from "@playwright/test";
import { CraterBidiPage } from "../webdriver/playwright/adapter.ts";

test.describe("Crater Playwright adapter user scenarios", () => {
  let page: CraterBidiPage;

  test.beforeEach(async () => {
    page = new CraterBidiPage();
    await page.connect();
  });

  test.afterEach(async () => {
    await page.close();
  });

  test("settings form: use locator-first Playwright style interactions", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <form id="settings">
            <label for="newsletter">Newsletter</label>
            <input id="newsletter" type="checkbox" />
            <label for="theme">Theme</label>
            <select id="theme">
              <option value="light">Light</option>
              <option value="dark">Dark</option>
              <option value="system">System</option>
            </select>
            <button type="button" role="button" id="save">Save</button>
          </form>
          <output id="preview">newsletter:off theme:light</output>
          <output id="status">idle</output>
          <script>
            const newsletter = document.getElementById("newsletter");
            const theme = document.getElementById("theme");
            const preview = document.getElementById("preview");
            const status = document.getElementById("status");
            const renderPreview = () => {
              preview.textContent = "newsletter:" + (newsletter.checked ? "on" : "off") + " theme:" + theme.value;
            };
            newsletter.addEventListener("change", renderPreview);
            theme.addEventListener("change", renderPreview);
            document.getElementById("save").addEventListener("click", () => {
              status.textContent = "saved " + preview.textContent;
            });
          </script>
        </body>
      </html>
    `);

    await page.getByLabel("Newsletter").check();
    await page.locator("#theme").selectOption("dark");
    await page.waitForText("#preview", "newsletter:on theme:dark");

    await page.getByRole("button", { name: "Save" }).click();
    await expect(page.locator("#status").textContent()).resolves.toBe(
      "saved newsletter:on theme:dark",
    );
  });

  test("dashboard inspection: read page and locator state like Playwright", async () => {
    await page.setContentWithScripts(`
      <html>
        <head>
          <title>Crater Dashboard</title>
        </head>
        <body>
          <main id="dashboard">
            <h1>Dashboard</h1>
            <ul id="items">
              <li data-score="2"><span>alpha</span></li>
              <li data-score="3"><span>beta</span></li>
              <li data-score="5"><span>gamma</span></li>
            </ul>
            <output id="summary">pending</output>
          </main>
          <script>
            const scores = Array.from(document.getElementById("items").querySelectorAll("li"))
              .map((item) => Number(item.dataset.score));
            document.getElementById("summary").textContent = "total:" + scores.reduce((a, b) => a + b, 0);
          </script>
        </body>
      </html>
    `);

    await page.waitForURL(/data:text\/html/);
    await expect(page.title()).resolves.toBe("Crater Dashboard");
    await expect(page.url()).resolves.toContain("data:text/html");
    await expect(page.content()).resolves.toContain("<title>Crater Dashboard</title>");

    const items = page.locator("#items").locator("li");
    await expect(
      page.evaluate(
        (options: { prefix: string }) =>
          options.prefix + document.getElementById("items")!.querySelectorAll("li").length,
        { prefix: "count:" },
      ),
    ).resolves.toBe("count:3");
    await expect(items.allTextContents()).resolves.toEqual([
      "alpha",
      "beta",
      "gamma",
    ]);
    await expect(items.allInnerTexts()).resolves.toEqual([
      "alpha",
      "beta",
      "gamma",
    ]);
    await expect(
      items.first().evaluate((element, multiplier: number) =>
        Number(element.getAttribute("data-score")) * multiplier,
      2,
      ),
    ).resolves.toBe(4);
    await expect(
      items.evaluateAll((elements, separator: string) =>
        elements.map((element) => element.textContent?.trim()).join(separator),
      "|",
      ),
    ).resolves.toBe("alpha|beta|gamma");
    await expect(page.locator("#summary").textContent()).resolves.toBe("total:10");
  });

  test("editor controls: use locator actions and state predicates", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <input id="name" type="text" value="initial" />
          <input id="disabled" type="text" value="locked" disabled />
          <input id="readonly" type="text" value="stable" readonly />
          <input id="accepted" type="checkbox" />
          <button id="action" type="button">Action</button>
          <div id="hidden" hidden>Hidden</div>
          <output id="log">idle</output>
          <script>
            const name = document.getElementById("name");
            const action = document.getElementById("action");
            const log = document.getElementById("log");
            name.addEventListener("focus", () => {
              log.textContent = "focused";
            });
            name.addEventListener("input", () => {
              log.textContent = "value:" + name.value;
            });
            name.addEventListener("keydown", (event) => {
              if (event.key === "Enter") log.textContent = "submitted:" + name.value;
            });
            action.addEventListener("pointerenter", () => {
              log.textContent = "hovered";
            });
            action.addEventListener("custom-save", (event) => {
              log.textContent = "custom:" + event.detail.value;
            });
          </script>
        </body>
      </html>
    `);

    const name = page.locator("#name");
    await name.focus();
    await expect(page.locator("#log").textContent()).resolves.toBe("focused");

    await name.clear();
    await expect(name.inputValue()).resolves.toBe("");

    await name.type("crater");
    await expect(name.inputValue()).resolves.toBe("crater");
    await expect(page.locator("#log").textContent()).resolves.toBe("value:crater");

    await name.press("Enter");
    await expect(page.locator("#log").textContent()).resolves.toBe("submitted:crater");

    await page.locator("#action").hover();
    await expect(page.locator("#log").textContent()).resolves.toBe("hovered");

    await page.locator("#action").dispatchEvent("custom-save", { detail: { value: "ok" } });
    await expect(page.locator("#log").textContent()).resolves.toBe("custom:ok");

    await page.locator("#accepted").check();
    await expect(page.locator("#accepted").isChecked()).resolves.toBe(true);
    await expect(page.locator("#disabled").isDisabled()).resolves.toBe(true);
    await expect(page.locator("#name").isEnabled()).resolves.toBe(true);
    await expect(page.locator("#name").isEditable()).resolves.toBe(true);
    await expect(page.locator("#readonly").isEditable()).resolves.toBe(false);
    await expect(page.locator("#hidden").isHidden()).resolves.toBe(true);
  });

  test("page aliases: use Playwright-style selectors and screenshot", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <select id="mode">
            <option value="basic">Basic</option>
            <option value="advanced">Advanced</option>
          </select>
          <ul id="rows">
            <li class="row" data-id="a">Alpha</li>
            <li class="row" data-id="b">Beta</li>
          </ul>
          <output id="selected">mode:basic</output>
          <script>
            const mode = document.getElementById("mode");
            const selected = document.getElementById("selected");
            mode.addEventListener("change", () => {
              selected.textContent = "mode:" + mode.value;
            });
          </script>
        </body>
      </html>
    `);

    const rows = await page.$$(".row");
    expect(rows).toHaveLength(2);
    await expect(rows[1].textContent()).resolves.toBe("Beta");

    const firstRow = await page.$(".row");
    await expect(firstRow?.getAttribute("data-id")).resolves.toBe("a");
    await expect(
      page.$eval("#rows", (element) => element.textContent?.replace(/\\s+/g, " ").trim()),
    ).resolves.toBe("AlphaBeta");

    await page.selectOption("#mode", "advanced");
    await expect(page.locator("#selected").textContent()).resolves.toBe("mode:advanced");

    const screenshot = await page.screenshot();
    expect(Buffer.isBuffer(screenshot)).toBe(true);
    expect(screenshot.length).toBeGreaterThan(0);
  });

  test("script and style injection: run init scripts before page scripts", async () => {
    await page.addInitScript(() => {
      globalThis.__craterInitValue = "ready";
    });

    await page.setContentWithScripts(`
      <html>
        <head></head>
        <body>
          <div id="status">pending</div>
          <script>
            document.getElementById("status").textContent = globalThis.__craterInitValue || "missing";
          </script>
        </body>
      </html>
    `);

    await expect(page.locator("#status").textContent()).resolves.toBe("ready");

    await page.addScriptTag({
      content: `
        document.getElementById("status").textContent = "script-tag";
        document.body.setAttribute("data-script-tag", "executed");
      `,
    });
    await expect(page.locator("#status").textContent()).resolves.toBe("script-tag");
    await expect(page.getAttribute("body", "data-script-tag")).resolves.toBe("executed");

    await page.addStyleTag({
      content: "#status { color: rgb(1, 2, 3); }",
    });
    await expect(page.locator("style").textContent()).resolves.toContain(
      "rgb(1, 2, 3)",
    );
  });

  test("async waits: wait for function state without fixed sleeps", async () => {
    page.setDefaultTimeout(1000);

    await page.setContentWithScripts(`
      <html>
        <body data-ready="no">
          <output id="status">pending</output>
          <script>
            setTimeout(() => {
              document.body.setAttribute("data-ready", "yes");
              document.getElementById("status").textContent = "ready";
            }, 20);
          </script>
        </body>
      </html>
    `);

    await expect(
      page.waitForFunction(() => document.body.getAttribute("data-ready") === "yes"),
    ).resolves.toBe(true);
    await expect(page.locator("#status").textContent()).resolves.toBe("ready");

    await page.waitForTimeout(1);
  });

  test("network routing: fulfill fixture requests and wait for request/response", async () => {
    await page.route("/api/config", async (route) => {
      await route.fulfill({
        status: 201,
        contentType: "application/json",
        body: JSON.stringify({ name: "crater", routed: true }),
      });
    });

    const requestPromise = page.waitForRequest("/api/config");
    const responsePromise = page.waitForResponse((response) =>
      response.url().includes("/api/config") && response.status() === 201
    );

    await page.setContentWithScripts(`
      <html>
        <body>
          <output id="status">pending</output>
          <script>
            fetch("/api/config")
              .then(async (response) => {
                const data = await response.json();
                document.getElementById("status").textContent =
                  response.status + ":" + data.name + ":" + data.routed;
              })
              .catch((error) => {
                document.getElementById("status").textContent = "error:" + error.message;
              });
          </script>
        </body>
      </html>
    `);

    const request = await requestPromise;
    expect(request.url()).toContain("/api/config");
    expect(request.method()).toBe("GET");

    const response = await responsePromise;
    expect(response.ok()).toBe(true);
    expect(response.request().url()).toContain("/api/config");
    await expect(page.locator("#status").textContent()).resolves.toBe(
      "201:crater:true",
    );
  });
});
