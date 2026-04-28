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

URL-based loading is available through `goto(url)` and `loadPage(url)`. Both
fetch the document in Crater's runtime, parse the returned HTML, run
`addInitScript()` setup before page scripts, and execute supported script tags
with the loaded URL as the base URL:

```ts
const response = await page.goto("http://127.0.0.1:3000/fixture.html");
console.log(response?.status());
await page.getByText("Ready").click();
```

Top-level page loads are treated as navigation and are not blocked by the
same-origin request sandbox. Subresource requests, including external scripts,
still go through Crater's request sandbox/CORS policy.
`goto()` follows the runtime `fetch()` redirect behavior and returns a
response-like object with final URL, status, status text, headers, `ok()`, and
request metadata. HTTP 4xx/5xx responses do not throw; their response body is
loaded into the Crater document like Chromium.
Basic in-page navigation through `location.assign()`, `location.replace()`,
`location.reload()`, and URL-only history updates through `history.pushState()`
and `history.replaceState()` are also bridged into the adapter's navigation
pipeline.

A minimal browser/context wrapper is available for tests that want the common
`browser.newContext().newPage()` shape without launching Chromium:

```ts
import { createCraterBrowser } from "../webdriver/playwright/adapter.ts";

const browser = createCraterBrowser();
const context = await browser.newContext();
const page = await context.newPage();
await page.setContent("<h1>Ready</h1>");
const state = await context.storageState();
await browser.close();
```

## Expected User Scenarios

The adapter is expected to support headless test flows where a user:

- Loads fixture HTML with `setContentWithScripts()` for component-level tests.
- Loads a local fixture URL with `goto()` or `loadPage()` when relative assets
  matter.
- Creates lightweight isolated pages through `createCraterBrowser()`,
  `newContext()`, and `newPage()`, with partial context-level `viewport` and
  `userAgent`, `locale`, `offline`, `geolocation`, and `permissions` option
  support.
- Snapshots open-page localStorage and visible cookies through
  `context.storageState()` for simple fixture reuse, preloads that state with
  `browser.newContext({ storageState })`, and uses
  `context.addCookies()`, `context.cookies()`, and `context.clearCookies()` for
  BiDi-backed visible cookie setup with basic URL/filter support.
- Traverses fixture iframe roots with `frameLocator(...).locator(...)` when
  `iframe.contentDocument`, `contentWindow.document`, or a synthetic fixture root
  is available. Independent iframe navigation is not implemented.
- Uses locator-first interactions such as `getByLabel(...).check()`,
  `locator(...).selectOption(...)`, and `getByRole(...).click()`.
- Uses common Playwright locator matching forms including `exact` and `RegExp`
  for text, label, placeholder, title, alt text, and test id queries.
- Uses practical role locators with basic accessible-name matching,
  hidden-element exclusion by default, and `exact`, `includeHidden`, and
  `disabled` options.
- Locates elements through open shadow DOM for CSS, text, role, label,
  placeholder, title, alt, and test id selectors, while keeping closed shadow
  DOM hidden.
- Relies on locator action auto-wait for attached, visible, enabled, and stable
  targets before common interactions.
- Reads page state through `url()`, `title()`, `content()`, and waits for URL
  state with `waitForURL(...)`.
- Observes `console.*` calls with `page.on("console", ...)` or
  `page.waitForEvent("console")`.
- Inspects element collections with `locator.evaluate(...)`,
  `locator.evaluateAll(...)`, `allTextContents()`, and `allInnerTexts()`.
- Uses common locator actions and state checks such as `clear()`, `focus()`,
  `press()`, `type()`, `dispatchEvent()`, `isChecked()`, and `isEditable()`.
- Exercises practical keyboard editing through locator typing/pressing,
  including input selection replacement, Backspace/Delete, `beforeinput`
  cancellation, textarea newlines, and basic modifier chords.
- Inserts IME-like text through `page.keyboard.insertText()` for focused
  editable elements without synthesizing key events.
- Synthesizes composition/input event shapes with `dispatchEvent()` for
  IME-style app tests that observe `CompositionEvent` and `InputEvent` data.
  Native browser/OS IME composition is not synthesized yet.
- Uses Playwright-style page aliases such as `$`, `$$`, `$eval`,
  `selectOption()`, and `screenshot()` where Crater can provide equivalent
  headless behavior.
- Injects setup scripts and fixture assets with `addInitScript()`,
  `context.addInitScript()`, `addScriptTag()`, and `addStyleTag()`.
- Waits for app state through `waitForFunction()`, `waitForText()`, and
  `waitForLoadState()`, with page/context `setDefaultTimeout()` for polling
  defaults.
- Toggles basic offline state with `context.setOffline()` and observes the
  resulting `navigator.onLine` state in Crater pages.
- Grants and clears synthetic `geolocation` / `storage-access` permissions with
  `context.grantPermissions()` and `context.clearPermissions()`, and overrides
  synthetic geolocation with `context.setGeolocation()`.
- Stubs fixture network calls with `route(...)` and waits for Crater runtime
  `fetch()`, document, external script, and best-effort style/image traffic with
  `waitForRequest()` / `waitForResponse()`.
- Registers fixture network stubs at context scope with `context.route(...)`
  for existing pages and later pages when only one routed page is active.
- Inspects Crater-specific rendering/debug data through the documented extension
  APIs when Playwright's browser-native semantics are not available.

## Support Matrix

`supported-apis.ts` is the source of truth for the adapter contract. The table is
checked in CI so every source-level public method on `CraterBrowser`,
`CraterBrowserContext`, `CraterBidiPage`, and `CraterLocator` is explicitly
classified. The `status` field describes Playwright compatibility scope; the
`implementation` field separates APIs with real adapter behavior from API mocks
that only provide a limited fixture-facing shape.

| Owner | Entries | Current scope |
|-------|---------|---------------|
| `browser` | 4 | Lightweight `newContext()`, `newPage()`, `contexts()`, idempotent `close()` wrapper, with partial `storageState`, `viewport`, `userAgent`, `locale`, `offline`, `geolocation`, and `permissions` option support on `newContext()`. |
| `context` | 15 | Lightweight `newPage()`, `pages()`, best-effort `storageState()` snapshot/path writing, visible cookie APIs, context init scripts/default timeout/offline/geolocation/permission overrides, delegated `route()`/`unroute()`, idempotent `close()` over a hidden transport page. |
| `page` | 73 | Core page, locator/frame-locator factory, navigation, keyboard, wait, partial event APIs, network, file input upload, and Crater render/debug helpers. |
| `locator` | 40 | Locator chaining, nested locator factories, actions, state checks, evaluation, text extraction, and file input upload. |

The supported API contract is maintained in `supported-apis.ts` and checked by
CI via `scripts/playwright-adapter-support.test.ts`. Entries marked `partial`
are intentionally narrower than Playwright's browser-grade semantics. Entries
marked `crater-extension` are available for Crater diagnostics/VRT, but are not
Playwright compatibility APIs.
Entries marked `implementation: "api-mock"` expose a Playwright-like API name
without a browser-equivalent implementation body. Currently this applies to
`page.frameLocator()`, which only roots locators at `iframe.contentDocument`,
`contentWindow.document`, or a synthetic fixture root.
`page.on()` and `page.waitForEvent()` currently cover request, response,
requestfailed, filechooser, dialog, download, console, load, domcontentloaded,
and close.
Dialogs are backed by WebDriver BiDi user prompts and support `type()`,
`message()`, `defaultValue()`, `page()`, `accept()`, and `dismiss()`. Downloads
are backed by WebDriver BiDi download lifecycle events and expose `url()`,
`suggestedFilename()`, `page()`, `path()`, `failure()`, `saveAs()`, `delete()`,
and completion-safe `cancel()`.
