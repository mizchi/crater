import { expect, test } from "@playwright/test";
import { CraterBidiPage } from "../webdriver/playwright/adapter.ts";

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
});
