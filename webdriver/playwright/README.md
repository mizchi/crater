# Crater Playwright Adapter

This package boundary contains the TypeScript adapter used by Playwright tests
to drive the Crater WebDriver BiDi server.

It is not a browserType replacement for Chromium/Firefox/WebKit yet. It exposes
a Playwright-like page and locator surface for headless Crater tests:

```ts
import { CraterBidiPage } from "../webdriver/playwright/adapter.ts";

const page = new CraterBidiPage();
await page.connect();
await page.setContentWithScripts("<button id='save'>Save</button>");
await page.click("#save");
await page.close();
```

URL-based loading is available through `loadPage(url)`. It fetches the document
in Crater's runtime, parses the returned HTML, and executes supported script
tags with the loaded URL as the base URL:

```ts
await page.loadPage("http://127.0.0.1:3000/fixture.html");
await page.getByText("Ready").click();
```

Top-level page loads are treated as navigation and are not blocked by the
same-origin request sandbox. Subresource requests, including external scripts,
still go through Crater's request sandbox/CORS policy.

## Expected User Scenarios

The adapter is expected to support headless test flows where a user:

- Loads fixture HTML with `setContentWithScripts()` for component-level tests.
- Loads a local fixture URL with `loadPage()` when relative assets matter.
- Uses locator-first interactions such as `getByLabel(...).check()`,
  `locator(...).selectOption(...)`, and `getByRole(...).click()`.
- Reads page state through `url()`, `title()`, `content()`, and waits for URL
  state with `waitForURL(...)`.
- Inspects element collections with `locator.evaluate(...)`,
  `locator.evaluateAll(...)`, `allTextContents()`, and `allInnerTexts()`.
- Uses common locator actions and state checks such as `clear()`, `focus()`,
  `press()`, `type()`, `dispatchEvent()`, `isChecked()`, and `isEditable()`.
- Uses Playwright-style page aliases such as `$`, `$$`, `$eval`,
  `selectOption()`, and `screenshot()` where Crater can provide equivalent
  headless behavior.
- Injects setup scripts and fixture assets with `addInitScript()`,
  `addScriptTag()`, and `addStyleTag()`.
- Waits for app state through `waitForFunction()`, `waitForText()`, and
  `waitForLoadState()`, with `setDefaultTimeout()` for polling defaults.
- Stubs fixture network calls with `route(...)` and waits for Crater runtime
  `fetch()` traffic with `waitForRequest()` / `waitForResponse()`.
- Inspects Crater-specific rendering/debug data through the documented extension
  APIs when Playwright's browser-native semantics are not available.

The supported API contract is maintained in `supported-apis.ts` and checked by
CI via `scripts/playwright-adapter-support.test.ts`. Entries marked `partial`
are intentionally narrower than Playwright's browser-grade semantics.
