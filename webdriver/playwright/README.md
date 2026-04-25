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

The supported API contract is maintained in `supported-apis.ts` and checked by
CI via `scripts/playwright-adapter-support.test.ts`. Entries marked `partial`
are intentionally narrower than Playwright's browser-grade semantics.
