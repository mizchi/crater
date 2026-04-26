/**
 * Playwright-like adapter tests for Crater WebDriver BiDi.
 *
 * These tests intentionally exercise the exported adapter package instead of
 * keeping a test-local copy. The adapter boundary lives in webdriver/playwright.
 */

import { expect, test } from "@playwright/test";
import { CraterBidiPage as CraterPage } from "../webdriver/playwright/adapter.ts";

test.describe("Playwright Adapter Tests", () => {
  let page: CraterPage;

  test.beforeEach(async () => {
    page = new CraterPage();
    await page.connect();
  });

  test.afterEach(async () => {
    await page.close();
  });

  test("goto and evaluate work together", async () => {
    await page.setContent("<html><body><h1>Hello Playwright</h1></body></html>");
    const title = await page.evaluate(() => document.querySelector("h1")?.textContent);
    expect(title).toBe("Hello Playwright");
  });

  test("setContent creates DOM", async () => {
    await page.setContent(`
      <html>
        <body>
          <div id="app">
            <h1>Title</h1>
            <p class="content">Paragraph</p>
          </div>
        </body>
      </html>
    `);

    const h1Text = await page.textContent("h1");
    expect(h1Text).toBe("Title");

    const pText = await page.textContent(".content");
    expect(pText).toBe("Paragraph");
  });

  test("click triggers event handlers", async () => {
    await page.setContent(`
      <html>
        <body>
          <button id="btn">Click me</button>
          <div id="result">Not clicked</div>
        </body>
      </html>
    `);

    await page.evaluate(`
      const btn = document.getElementById("btn");
      const result = document.getElementById("result");
      if (btn && result) {
        btn.addEventListener("click", () => {
          result.textContent = "Clicked!";
        });
      }
    `);

    await page.click("#btn");
    const result = await page.textContent("#result");
    expect(result).toBe("Clicked!");
  });

  test("fill updates input value", async () => {
    await page.setContent(`
      <html>
        <body>
          <input type="text" id="name" />
        </body>
      </html>
    `);

    await page.fill("#name", "John Doe");
    const value = await page.inputValue("#name");
    expect(value).toBe("John Doe");
  });

  test("innerHTML returns element content", async () => {
    await page.setContent(`
      <html>
        <body>
          <div id="container">
            <span>Item 1</span>
            <span>Item 2</span>
          </div>
        </body>
      </html>
    `);

    const html = await page.innerHTML("#container");
    expect(html).toContain("<span>Item 1</span>");
    expect(html).toContain("<span>Item 2</span>");
  });

  test("$$eval processes multiple elements", async () => {
    await page.setContent(`
      <html>
        <body>
          <ul>
            <li>Apple</li>
            <li>Banana</li>
            <li>Cherry</li>
          </ul>
        </body>
      </html>
    `);

    const count = await page.$$eval("li", (elements) => elements.length);
    expect(count).toBe(3);
  });

  test("getAttribute returns attribute value", async () => {
    await page.setContent(`
      <html>
        <body>
          <a id="link" href="https://example.com" target="_blank">Link</a>
        </body>
      </html>
    `);

    const href = await page.getAttribute("#link", "href");
    expect(href).toBe("https://example.com");

    const target = await page.getAttribute("#link", "target");
    expect(target).toBe("_blank");
  });

  test("complex DOM operations", async () => {
    await page.setContent(`
      <html>
        <body>
          <div id="app">
            <header>My App</header>
            <nav>
              <a href="#home">Home</a>
              <a href="#about">About</a>
              <a href="#contact">Contact</a>
            </nav>
            <main id="main">Main content</main>
          </div>
        </body>
      </html>
    `);

    const headerText = await page.textContent("header");
    expect(headerText).toBe("My App");

    const linkCount = await page.evaluate(`
      document.querySelectorAll("a").length;
    `);
    expect(linkCount).toBe(3);

    const mainText = await page.textContent("#main");
    expect(mainText).toBe("Main content");
  });

  test("form interaction", async () => {
    await page.setContent(`
      <html>
        <body>
          <form id="form">
            <input type="text" name="username" id="username" />
            <input type="email" name="email" id="email" />
            <button type="button" id="submit">Submit</button>
          </form>
          <div id="output"></div>
        </body>
      </html>
    `);

    await page.fill("#username", "testuser");
    await page.fill("#email", "test@example.com");

    await page.evaluate(`
      const btn = document.getElementById("submit");
      btn.addEventListener("click", () => {
        const output = document.getElementById("output");
        const username = document.getElementById("username").value;
        const email = document.getElementById("email").value;
        output.textContent = JSON.stringify({ username: username, email: email });
      });
    `);
    await page.click("#submit");

    const output = await page.textContent("#output");
    expect(output).toContain("testuser");
    expect(output).toContain("test@example.com");
  });

  test("async evaluation with Promise", async () => {
    await page.setContent("<html><body></body></html>");

    const result = await page.evaluate(async () => {
      return new Promise<string>((resolve) => {
        setTimeout(() => resolve("delayed result"), 50);
      });
    });

    expect(result).toBe("delayed result");
  });

  test("error handling in evaluate", async () => {
    await page.setContent("<html><body></body></html>");

    await expect(page.evaluate(() => {
      throw new Error("Test error");
    })).rejects.toThrow("Test error");
  });

  test("nested element queries", async () => {
    await page.setContent(`
      <html>
        <body>
          <div class="container">
            <div class="item">
              <span class="label">Label 1</span>
              <span class="value">Value 1</span>
            </div>
            <div class="item">
              <span class="label">Label 2</span>
              <span class="value">Value 2</span>
            </div>
          </div>
        </body>
      </html>
    `);

    const itemCount = await page.evaluate(`
      document.querySelectorAll(".item").length;
    `);
    expect(itemCount).toBe(2);

    const labelCount = await page.evaluate(`
      document.querySelectorAll(".label").length;
    `);
    expect(labelCount).toBe(2);

    const valueCount = await page.evaluate(`
      document.querySelectorAll(".value").length;
    `);
    expect(valueCount).toBe(2);
  });

  test("locator basic usage", async () => {
    await page.setContent(`
      <html>
        <body>
          <div id="container">
            <button id="btn">Click me</button>
            <input id="input" type="text" />
            <p id="text">Hello World</p>
          </div>
        </body>
      </html>
    `);

    const text = await page.locator("#text").textContent();
    expect(text).toBe("Hello World");

    await page.locator("#input").fill("Test value");
    const value = await page.locator("#input").inputValue();
    expect(value).toBe("Test value");

    const type = await page.locator("#input").getAttribute("type");
    expect(type).toBe("text");
  });

  test("locator chaining with child locator", async () => {
    await page.setContent(`
      <html>
        <body>
          <div id="parent">
            <span class="item">Item 1</span>
            <span class="item">Item 2</span>
          </div>
        </body>
      </html>
    `);

    const container = page.locator("#parent");
    const items = container.locator(".item");
    const count = await items.count();
    expect(count).toBe(2);

    const firstItem = await items.nth(0).textContent();
    expect(firstItem).toBe("Item 1");
  });

  test("CSS descendant and sibling selectors match Chromium", async () => {
    await page.setContent(`
      <html>
        <body>
          <section id="panel">
            <h2>Panel</h2>
            <ul id="items">
              <li class="item">Alpha</li>
              <li class="item featured">Beta</li>
              <li class="item">Gamma</li>
            </ul>
          </section>
        </body>
      </html>
    `);

    await expect(
      page.evaluate(() => {
        const first = document.querySelector("li");
        return [
          document.querySelectorAll("li").length,
          document.querySelectorAll("#items li").length,
          first ? first.matches("#items li") : false,
          first?.parentElement?.matches("#items") ?? false,
        ].join("|");
      }),
    ).resolves.toBe("3|3|true|true");

    await expect(page.locator("#items li").count()).resolves.toBe(3);
    await expect(
      page.locator("#panel > ul > li.featured").textContent(),
    ).resolves.toBe("Beta");
    await expect(
      page.locator("#items li.featured + li").textContent(),
    ).resolves.toBe("Gamma");
    await expect(
      page.evaluate(() => document.querySelectorAll("#items li").length),
    ).resolves.toBe(3);
  });

  test("locator nth element", async () => {
    await page.setContent(`
      <html>
        <body>
          <ul>
            <li>First</li>
            <li>Second</li>
            <li>Third</li>
          </ul>
        </body>
      </html>
    `);

    const items = page.locator("li");

    const first = await items.nth(0).textContent();
    expect(first).toBe("First");

    const second = await items.nth(1).textContent();
    expect(second).toBe("Second");

    const third = await items.nth(2).textContent();
    expect(third).toBe("Third");
  });

  test("locator count", async () => {
    await page.setContent(`
      <html>
        <body>
          <div class="item">1</div>
          <div class="item">2</div>
          <div class="item">3</div>
          <div class="item">4</div>
        </body>
      </html>
    `);

    const count = await page.locator(".item").count();
    expect(count).toBe(4);
  });

  test("locator click with event handler", async () => {
    await page.setContent(`
      <html>
        <body>
          <button id="btn">Click</button>
          <div id="result">Not clicked</div>
        </body>
      </html>
    `);

    await page.evaluate(`
      document.getElementById("btn").addEventListener("click", () => {
        document.getElementById("result").textContent = "Clicked!";
      });
    `);

    await page.locator("#btn").click();
    const result = await page.locator("#result").textContent();
    expect(result).toBe("Clicked!");
  });

  test("locator isVisible", async () => {
    await page.setContent(`
      <html>
        <body>
          <div id="visible">Visible</div>
          <div id="hidden" style="display: none;">Hidden</div>
          <div id="invisible" style="visibility: hidden;">Invisible</div>
        </body>
      </html>
    `);

    const isVisible = await page.locator("#visible").isVisible();
    expect(isVisible).toBe(true);

    const isHidden = await page.locator("#hidden").isVisible();
    expect(isHidden).toBe(false);

    const isInvisible = await page.locator("#invisible").isVisible();
    expect(isInvisible).toBe(false);

    const notExists = await page.locator("#not-exists").isVisible();
    expect(notExists).toBe(false);
  });

  test("waitForLoadState", async () => {
    await page.setContent("<html><body><p>Ready</p></body></html>");

    await page.waitForLoadState("load");
    await page.waitForLoadState("domcontentloaded");

    const text = await page.locator("p").textContent();
    expect(text).toBe("Ready");
  });

  test("waitForNetworkIdle with no requests", async () => {
    await page.setContent("<html><body><p>Ready</p></body></html>");

    await page.waitForNetworkIdle({ idleTime: 100 });

    const text = await page.locator("p").textContent();
    expect(text).toBe("Ready");
  });

  test("waitForLoadState networkidle", async () => {
    await page.setContent("<html><body><p>Ready</p></body></html>");

    await page.waitForLoadState("networkidle0", { timeout: 5000 });
    await page.waitForLoadState("networkidle2", { timeout: 5000 });

    const text = await page.locator("p").textContent();
    expect(text).toBe("Ready");
  });

  test("network request tracking", async () => {
    await page.setContent("<html><body></body></html>");

    const initialCount = await page.evaluate(`globalThis.__activeNetworkRequests`);
    expect(initialCount).toBe(0);

    const hasIdle0 = await page.evaluate(`typeof globalThis.__waitForNetworkIdle0 === 'function'`);
    expect(hasIdle0).toBe(true);

    const hasIdle2 = await page.evaluate(`typeof globalThis.__waitForNetworkIdle2 === 'function'`);
    expect(hasIdle2).toBe(true);
  });

  test("getByText locator", async () => {
    await page.setContent(`
      <html>
        <body>
          <button>Click me</button>
          <p>Hello World</p>
          <span>Another text</span>
        </body>
      </html>
    `);

    const button = page.getByText("Click");
    const buttonText = await button.textContent();
    expect(buttonText).toBe("Click me");

    const para = page.getByText("Hello World", { exact: true });
    const paraText = await para.textContent();
    expect(paraText).toBe("Hello World");
  });

  test("getByText normalizes whitespace like Chromium", async () => {
    await page.setContent(`
      <html>
        <body>
          <p>Checkout
            complete</p>
          <button>Save
            draft</button>
        </body>
      </html>
    `);

    await expect(
      page.getByText("Checkout complete", { exact: true }).textContent(),
    ).resolves.toContain("Checkout");
    await expect(
      page.getByText("Save draft").textContent(),
    ).resolves.toContain("Save");
  });

  test("getByText matches nested composed text like Chromium", async () => {
    await page.setContent(`
      <html>
        <body>
          <button id="save"><span>Save</span> draft</button>
          <div id="status"><strong>Build</strong> passed</div>
        </body>
      </html>
    `);

    await expect(
      page.getByText("Save draft").getAttribute("id"),
    ).resolves.toBe("save");
    await expect(
      page.getByText("Build passed", { exact: true }).getAttribute("id"),
    ).resolves.toBe("status");
  });

  test("getByRole locator", async () => {
    await page.setContent(`
      <html>
        <body>
          <button role="button">Submit</button>
          <nav role="navigation">Menu</nav>
          <button role="button">Cancel</button>
        </body>
      </html>
    `);

    const buttons = page.getByRole("button");
    const count = await buttons.count();
    expect(count).toBe(2);

    const submitBtn = page.getByRole("button", { name: "Submit" });
    const submitText = await submitBtn.textContent();
    expect(submitText).toBe("Submit");
  });

  test("getByRole matches native implicit roles like Chromium", async () => {
    await page.setContent(`
      <html>
        <body>
          <button>Save</button>
          <a href="/docs">Docs</a>
        </body>
      </html>
    `);

    await expect(
      page.getByRole("button", { name: "Save" }).textContent(),
    ).resolves.toBe("Save");
    await expect(
      page.getByRole("link", { name: "Docs" }).getAttribute("href"),
    ).resolves.toBe("/docs");
  });

  test("getByRole matches accessible names like Chromium", async () => {
    await page.setContent(`
      <html>
        <body>
          <button aria-label="Save"></button>
          <span id="docs-label">Docs</span>
          <a href="/docs" aria-labelledby="docs-label"></a>
        </body>
      </html>
    `);

    await expect(
      page.getByRole("button", { name: "Save" }).getAttribute("aria-label"),
    ).resolves.toBe("Save");
    await expect(
      page.getByRole("link", { name: "Docs" }).getAttribute("href"),
    ).resolves.toBe("/docs");
  });

  test("getByRole matches common form and content implicit roles like Chromium", async () => {
    await page.setContent(`
      <html>
        <body>
          <h1>Settings</h1>
          <label for="name">Name</label>
          <input id="name" type="text" value="Ada" />
          <label for="enabled">Enabled</label>
          <input id="enabled" type="checkbox" />
          <label for="theme">Theme</label>
          <select id="theme"><option>Light</option></select>
          <label for="bio">Bio</label>
          <textarea id="bio">Hello</textarea>
          <img src="/logo.png" alt="Logo" />
          <ul><li>First</li></ul>
        </body>
      </html>
    `);

    await expect(
      page.getByRole("heading", { name: "Settings" }).textContent(),
    ).resolves.toBe("Settings");
    await expect(
      page.getByRole("textbox", { name: "Name" }).getAttribute("id"),
    ).resolves.toBe("name");
    await expect(
      page.getByRole("checkbox", { name: "Enabled" }).getAttribute("id"),
    ).resolves.toBe("enabled");
    await expect(
      page.getByRole("combobox", { name: "Theme" }).getAttribute("id"),
    ).resolves.toBe("theme");
    await expect(
      page.getByRole("textbox", { name: "Bio" }).getAttribute("id"),
    ).resolves.toBe("bio");
    await expect(
      page.getByRole("img", { name: "Logo" }).getAttribute("src"),
    ).resolves.toBe("/logo.png");
    await expect(page.getByRole("list").count()).resolves.toBe(1);
    await expect(
      page.getByRole("listitem", { name: "First" }).textContent(),
    ).resolves.toBe("First");
  });

  test("getByPlaceholder locator", async () => {
    await page.setContent(`
      <html>
        <body>
          <input type="text" placeholder="Enter your name" />
          <input type="email" placeholder="Enter your email" />
        </body>
      </html>
    `);

    const nameInput = page.getByPlaceholder("Enter your name");
    await nameInput.fill("John");
    const value = await nameInput.inputValue();
    expect(value).toBe("John");
  });

  test("getByTestId locator", async () => {
    await page.setContent(`
      <html>
        <body>
          <button data-testid="submit-btn">Submit</button>
          <div data-testid="container">Content</div>
        </body>
      </html>
    `);

    const submitBtn = page.getByTestId("submit-btn");
    const text = await submitBtn.textContent();
    expect(text).toBe("Submit");

    const container = page.getByTestId("container");
    const containerText = await container.textContent();
    expect(containerText).toBe("Content");
  });

  test("getByLabel locator", async () => {
    await page.setContent(`
      <html>
        <body>
          <label for="username">Username</label>
          <input type="text" id="username" />
          <label>
            Password
            <input type="password" />
          </label>
        </body>
      </html>
    `);

    const usernameInput = page.getByLabel("Username");
    await usernameInput.fill("john_doe");
    const usernameValue = await usernameInput.inputValue();
    expect(usernameValue).toBe("john_doe");
  });

  test("getByLabel normalizes label whitespace like Chromium", async () => {
    await page.setContent(`
      <html>
        <body>
          <label for="full-name">Full
            name</label>
          <input type="text" id="full-name" />
          <label>
            Secret
            token
            <input type="password" id="token" />
          </label>
        </body>
      </html>
    `);

    await page.getByLabel("Full name").fill("Ada");
    await expect(page.locator("#full-name").inputValue()).resolves.toBe("Ada");
    await page.getByLabel("Secret token").fill("rosebud");
    await expect(page.locator("#token").inputValue()).resolves.toBe("rosebud");
  });

  test("getByAltText locator", async () => {
    await page.setContent(`
      <html>
        <body>
          <img alt="Company Logo" src="logo.png" />
          <img alt="User Avatar" src="avatar.png" />
        </body>
      </html>
    `);

    const logo = page.getByAltText("Company Logo");
    const src = await logo.getAttribute("src");
    expect(src).toBe("logo.png");
  });

  test("getByTitle locator", async () => {
    await page.setContent(`
      <html>
        <body>
          <button title="Close dialog">X</button>
          <span title="Help text">?</span>
        </body>
      </html>
    `);

    const closeBtn = page.getByTitle("Close dialog");
    const text = await closeBtn.textContent();
    expect(text).toBe("X");
  });

  test("locator filter", async () => {
    await page.setContent(`
      <html>
        <body>
          <button>Submit</button>
          <button>Cancel</button>
          <button>Reset</button>
        </body>
      </html>
    `);

    const submitBtn = page.locator("button").filter({ hasText: "Submit" });
    const submitText = await submitBtn.textContent();
    expect(submitText).toBe("Submit");

    const nonSubmitBtns = page.locator("button").filter({ hasNotText: "Submit" });
    const count = await nonSubmitBtns.count();
    expect(count).toBe(2);
  });

  test("locator text filters normalize whitespace like Chromium", async () => {
    await page.setContent(`
      <html>
        <body>
          <button>Submit
            order</button>
          <button>Cancel</button>
        </body>
      </html>
    `);

    await expect(
      page.locator("button").filter({ hasText: "Submit order" }).count(),
    ).resolves.toBe(1);
    await expect(
      page.locator("button").filter({ hasNotText: "Submit order" }).count(),
    ).resolves.toBe(1);
  });
});
