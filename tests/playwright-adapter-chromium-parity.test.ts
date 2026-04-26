import { once } from "node:events";
import { createServer, type Server } from "node:http";
import { expect, test, type Browser, type Page } from "@playwright/test";
import { CraterBidiPage } from "../webdriver/playwright/adapter.ts";

type ChromiumOrCraterPage = Page | CraterBidiPage;
type FixtureResponse = {
  body: string;
  contentType: string;
  status?: number;
  headers?: Record<string, string>;
};

const fixtureResponses = new Map<string, FixtureResponse>();
let fixtureServer: Server | null = null;
let fixtureOrigin = "";

function serveFixture(
  path: string,
  body: string,
  contentTypeOrOptions:
    | string
    | {
      contentType?: string;
      status?: number;
      headers?: Record<string, string>;
    } = "text/html; charset=utf-8",
): string {
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  const options = typeof contentTypeOrOptions === "string"
    ? { contentType: contentTypeOrOptions }
    : contentTypeOrOptions;
  fixtureResponses.set(normalizedPath, {
    body,
    contentType: options.contentType ?? "text/html; charset=utf-8",
    status: options.status,
    headers: options.headers,
  });
  return `${fixtureOrigin}${normalizedPath}`;
}

function urlPath(value: string): string {
  const url = new URL(value);
  return `${url.pathname}${url.search}`;
}

async function runWithChromium<T>(
  browser: Browser,
  run: (page: Page) => Promise<T>,
): Promise<T> {
  const page = await browser.newPage();
  page.setDefaultTimeout(500);
  try {
    return await run(page);
  } finally {
    await page.close();
  }
}

async function runWithCrater<T>(
  run: (page: CraterBidiPage) => Promise<T>,
): Promise<T> {
  const page = new CraterBidiPage();
  page.setDefaultTimeout(500);
  await page.connect();
  try {
    return await run(page);
  } finally {
    await page.close();
  }
}

async function collectLocatorSnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <button id="save"><span>Save</span> Draft</button>
        <button id="cancel">Cancel</button>
        <label for="full-name">Full
          Name</label>
        <input id="full-name" />
        <label>
          Secret
          Token
          <input id="secret-token" />
        </label>
      </body>
    </html>
  `);

  return {
    textLower: await page.getByText("save draft").getAttribute("id"),
    roleNameLower: await page.getByRole("button", { name: "save draft" }).getAttribute("id"),
    labelForLower: await page.getByLabel("full name").getAttribute("id"),
    labelWrappedLower: await page.getByLabel("secret token").getAttribute("id"),
    hasTextLowerCount: await page.locator("button").filter({ hasText: "save draft" }).count(),
    hasNotTextLowerCount: await page.locator("button").filter({ hasNotText: "save draft" }).count(),
  };
}

async function collectSetContentSnapshot(page: ChromiumOrCraterPage) {
  await page.evaluate(() => {
    const globals = globalThis as typeof globalThis & Record<string, unknown>;
    globals.__setContentCount = 0;
    globals.__setContentMarker = null;
    const win = window as Window & Record<string, unknown>;
    win.__setContentCount = 0;
    win.__setContentMarker = null;
  });

  await page.setContent(`
    <html>
      <body>
        <output id="status">pending</output>
        <script>
          window.__setContentCount = (window.__setContentCount || 0) + 1;
          window.__setContentMarker = "executed";
          document.getElementById("status").textContent =
            window.__setContentMarker + ":" + window.__setContentCount;
        </script>
      </body>
    </html>
  `);

  return {
    status: await page.locator("#status").textContent(),
    marker: await page.evaluate(() => (window as Window & Record<string, unknown>).__setContentMarker ?? null),
    count: await page.evaluate(() => (window as Window & Record<string, unknown>).__setContentCount ?? 0),
    scriptCount: await page.locator("script").count(),
  };
}

async function collectFormInteractionSnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <form id="settings">
          <label for="name">Display Name</label>
          <input id="name" value="initial" />
          <label for="newsletter">Newsletter</label>
          <input id="newsletter" type="checkbox" />
          <label for="mode">Mode</label>
          <select id="mode">
            <option value="basic">Basic</option>
            <option value="advanced">Advanced</option>
          </select>
          <button id="save" type="button">Save</button>
          <output id="summary">pending</output>
        </form>
        <script>
          const name = document.getElementById("name");
          const newsletter = document.getElementById("newsletter");
          const mode = document.getElementById("mode");
          const summary = document.getElementById("summary");
          const render = () => {
            summary.textContent =
              name.value + ":" + (newsletter.checked ? "on" : "off") + ":" + mode.value;
          };
          name.addEventListener("input", render);
          newsletter.addEventListener("change", render);
          mode.addEventListener("change", render);
          document.getElementById("save").addEventListener("click", () => {
            summary.textContent = "saved:" + summary.textContent;
          });
        </script>
      </body>
    </html>
  `);

  await page.getByLabel("Display Name").fill("Ada");
  await page.getByLabel("Newsletter").check();
  await page.getByLabel("Mode").selectOption("advanced");
  await page.getByRole("button", { name: "Save" }).click();

  return {
    name: await page.locator("#name").inputValue(),
    checked: await page.locator("#newsletter").isChecked(),
    mode: await page.locator("#mode").inputValue(),
    summary: await page.locator("#summary").textContent(),
  };
}

async function collectStateSnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <button id="visible">Visible</button>
        <button id="hidden-attr" hidden>Hidden</button>
        <button id="display-none" style="display: none">Display None</button>
        <button id="visibility-hidden" style="visibility: hidden">Visibility Hidden</button>
        <div id="hidden-parent" style="display: none">
          <button id="hidden-child">Hidden Child</button>
        </div>
        <input id="disabled" disabled value="locked" />
        <input id="readonly" readonly value="stable" />
        <input id="editable" value="open" />
      </body>
    </html>
  `);

  return {
    visible: await page.locator("#visible").isVisible(),
    hiddenAttr: await page.locator("#hidden-attr").isHidden(),
    displayNone: await page.locator("#display-none").isHidden(),
    visibilityHidden: await page.locator("#visibility-hidden").isHidden(),
    hiddenChild: await page.locator("#hidden-child").isHidden(),
    disabled: await page.locator("#disabled").isDisabled(),
    readonlyEditable: await page.locator("#readonly").isEditable(),
    editable: await page.locator("#editable").isEditable(),
  };
}

async function collectRoutingSnapshot(page: ChromiumOrCraterPage) {
  await page.route(/\/api\/config$/, async (route) => {
    await route.fulfill({
      status: 201,
      contentType: "application/json",
      body: JSON.stringify({ name: "crater", routed: true }),
    });
  });

  const requestPromise = page.waitForRequest(/\/api\/config$/);
  const responsePromise = page.waitForResponse((response) =>
    response.url().endsWith("/api/config") && response.status() === 201
  );

  await page.setContent(`
    <html>
      <body>
        <output id="status">pending</output>
        <script>
          fetch("https://crater.test/api/config")
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
  const response = await responsePromise;
  await page.locator("#status").waitFor();

  return {
    requestUrl: request.url(),
    requestMethod: request.method(),
    responseUrl: response.url(),
    responseStatus: response.status(),
    responseOk: response.ok(),
    status: await page.locator("#status").textContent(),
  };
}

async function collectKeyboardSnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <label for="editor">Editor</label>
        <input id="editor" value="" />
        <script>
          window.__keyboardEvents = [];
          const editor = document.getElementById("editor");
          editor.addEventListener("keydown", (event) => {
            window.__keyboardEvents.push("down:" + event.key + ":" + editor.value);
          });
          editor.addEventListener("input", () => {
            window.__keyboardEvents.push("input:" + editor.value);
          });
          editor.addEventListener("keyup", (event) => {
            window.__keyboardEvents.push("up:" + event.key + ":" + editor.value);
          });
        </script>
      </body>
    </html>
  `);

  const editor = page.getByLabel("Editor");
  await editor.fill("abc");
  await page.evaluate(() => {
    (window as Window & Record<string, unknown>).__keyboardEvents = [];
  });
  await editor.press("Backspace");

  return {
    value: await editor.inputValue(),
    events: await page.evaluate(() =>
      (window as Window & Record<string, unknown>).__keyboardEvents
    ),
  };
}

type RoleOptions = {
  name?: string | RegExp;
  exact?: boolean;
  includeHidden?: boolean;
  disabled?: boolean;
};

type TextOptions = {
  exact?: boolean;
};

function role(page: ChromiumOrCraterPage, name: string, options: RoleOptions = {}) {
  return (page as unknown as {
    getByRole(role: string, options?: RoleOptions): ReturnType<Page["getByRole"]>;
  }).getByRole(name, options);
}

function locatorFactory(
  page: ChromiumOrCraterPage,
  method:
    | "getByText"
    | "getByLabel"
    | "getByPlaceholder"
    | "getByAltText"
    | "getByTitle"
    | "getByTestId",
  value: string | RegExp,
  options: TextOptions = {},
) {
  return (page as unknown as Record<
    typeof method,
    (value: string | RegExp, options?: TextOptions) => ReturnType<Page["locator"]>
  >)[method](value, options);
}

async function collectRoleOptionSnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <button id="save">Save</button>
        <button id="save-draft">Save draft</button>
        <button id="hidden-save" style="display: none">Hidden Save</button>
        <button id="disabled-save" disabled>Disabled Save</button>
        <button id="aria-exact" aria-label="Exact Save">Noisy label</button>
      </body>
    </html>
  `);

  return {
    partialSaveCount: await role(page, "button", { name: "Save" }).count(),
    exactSaveCount: await role(page, "button", { name: "Save", exact: true }).count(),
    hiddenDefaultCount: await role(page, "button", { name: "Hidden Save" }).count(),
    hiddenIncludedId: await role(page, "button", {
      name: "Hidden Save",
      includeHidden: true,
    }).getAttribute("id"),
    disabledTrueId: await role(page, "button", { disabled: true }).getAttribute("id"),
    disabledFalseSaveCount: await role(page, "button", {
      name: "Save",
      disabled: false,
    }).count(),
  };
}

// Reduced from upstream Playwright scenarios:
// - tests/page/selectors-get-by.spec.ts
// - tests/page/selectors-text.spec.ts
// The assertions stay Chromium-vs-Crater to avoid copying Playwright's fixture stack.
async function collectUpstreamGetBySnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <div id="scope">
          <label id="label-for-control" for="control">Hello my
          wo"rld</label>
          <input
            id="control"
            placeholder="hello my
            wo&quot;rld"
            title="hello my
            wo&quot;rld"
            alt="hello my
            wo&quot;rld"
          />
          <label for="nested-target">Last <span>Name</span></label>
          <input id="nested-target" />
          <label id="accessible-name">Accessible Name</label>
          <button id="labelled-button" aria-labelledby="accessible-name">Click me</button>
          <input id="aria-input" aria-label="Email Address" />
          <input id="hello" placeholder="Hello" alt="Hello" title="Hello" />
          <input id="hello-world" placeholder="Hello World" alt="Hello World" title="Hello World" />
          <div data-testid='He"llo'>Hello world</div>
        </div>
      </body>
    </html>
  `);

  return {
    labelForId: await locatorFactory(page, "getByLabel", `hello my\nwo"rld`).getAttribute("id"),
    labelWhitespaceId: await locatorFactory(page, "getByLabel", `hello       my     wo"rld`).getAttribute("id"),
    nestedPartialId: await locatorFactory(page, "getByLabel", "st na").getAttribute("id"),
    nestedExactId: await locatorFactory(page, "getByLabel", "Last Name", { exact: true }).getAttribute("id"),
    nestedRegexId: await locatorFactory(page, "getByLabel", /Last\s+Name/i).getAttribute("id"),
    ariaLabelledButton: await locatorFactory(page, "getByLabel", "Accessible Name").textContent(),
    ariaLabelInputId: await locatorFactory(page, "getByLabel", "Email Address").getAttribute("id"),
    placeholderDefaultCount: await locatorFactory(page, "getByPlaceholder", "hello").count(),
    placeholderExactCount: await locatorFactory(page, "getByPlaceholder", "Hello", { exact: true }).count(),
    placeholderRegexId: await locatorFactory(page, "getByPlaceholder", /world/i).getAttribute("id"),
    altDefaultCount: await locatorFactory(page, "getByAltText", "hello").count(),
    altExactCount: await locatorFactory(page, "getByAltText", "Hello", { exact: true }).count(),
    altRegexId: await locatorFactory(page, "getByAltText", /world/i).getAttribute("id"),
    titleDefaultCount: await locatorFactory(page, "getByTitle", "hello").count(),
    titleExactCount: await locatorFactory(page, "getByTitle", "Hello", { exact: true }).count(),
    titleRegexId: await locatorFactory(page, "getByTitle", /world/i).getAttribute("id"),
    testIdQuotedText: await locatorFactory(page, "getByTestId", `He"llo`).textContent(),
    testIdRegexText: await locatorFactory(page, "getByTestId", /He"llo/).textContent(),
  };
}

// Reduced from upstream Playwright scenarios:
// - tests/page/page-fill.spec.ts
// - tests/page/page-select-option.spec.ts
// - tests/page/page-check.spec.ts
async function collectUpstreamFormControlSnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <input id="input" />
        <textarea id="textarea"></textarea>
        <div id="editable" contenteditable="true"></div>
        <select id="select">
          <option value="">Choose</option>
          <option value="blue">Blue</option>
          <option value="green">Green</option>
        </select>
        <input id="checkbox" type="checkbox" />
        <input id="checked" type="checkbox" checked />
        <input id="radio-one" type="radio" name="group" />
        <input id="radio-two" type="radio" name="group" />
      </body>
    </html>
  `);

  await page.locator("#input").fill("input value");
  await page.locator("#textarea").fill("line one\nline two");
  await page.locator("#editable").fill("editable value");
  await page.locator("#select").selectOption("Blue");
  await page.locator("#checkbox").check();
  await page.locator("#checked").check();
  await page.locator("#checked").uncheck();
  await page.locator("#radio-one").check();
  await page.locator("#radio-two").check();

  return {
    input: await page.locator("#input").inputValue(),
    textarea: await page.locator("#textarea").inputValue(),
    editable: await page.locator("#editable").textContent(),
    select: await page.locator("#select").inputValue(),
    checkbox: await page.locator("#checkbox").isChecked(),
    checkedAfterUncheck: await page.locator("#checked").isChecked(),
    radioOne: await page.locator("#radio-one").isChecked(),
    radioTwo: await page.locator("#radio-two").isChecked(),
  };
}

// Reduced from upstream Playwright scenarios:
// - tests/page/page-keyboard.spec.ts
// - tests/page/elementhandle-type.spec.ts
// - tests/page/page-fill.spec.ts
async function collectUpstreamKeyboardInputSnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <input id="editor" value="hello" />
        <input id="guarded" />
        <input id="shifted" />
        <textarea id="notes"></textarea>
        <div id="editable" contenteditable="true"></div>
        <script>
          const guarded = document.getElementById("guarded");
          window.__guardedEvents = [];
          for (const type of ["keydown", "beforeinput", "input", "keyup"]) {
            guarded.addEventListener(type, (event) => {
              if (event.type === "beforeinput" && /\\d|\\s/.test(event.data || "")) {
                event.preventDefault();
              }
              window.__guardedEvents.push([
                event.type,
                event.key || "",
                event.data == null ? "" : event.data,
                event.inputType || "",
                guarded.value,
                event.defaultPrevented ? "blocked" : "ok",
              ].join(":"));
            });
          }
        </script>
      </body>
    </html>
  `);

  const editor = page.locator("#editor");
  await editor.focus();
  await editor.evaluate((element) => {
    (element as HTMLInputElement).setSelectionRange(2, 4);
  });
  await editor.type("x");
  const afterReplace = await editor.inputValue();
  const afterReplaceSelection = await editor.evaluate((element) => {
    const input = element as HTMLInputElement;
    return `${input.selectionStart}:${input.selectionEnd}`;
  });
  await editor.press("Backspace");
  const afterBackspace = await editor.inputValue();
  const afterBackspaceSelection = await editor.evaluate((element) => {
    const input = element as HTMLInputElement;
    return `${input.selectionStart}:${input.selectionEnd}`;
  });
  await editor.press("Delete");
  const afterDelete = await editor.inputValue();
  const afterDeleteSelection = await editor.evaluate((element) => {
    const input = element as HTMLInputElement;
    return `${input.selectionStart}:${input.selectionEnd}`;
  });

  await page.locator("#shifted").press("Shift+A");
  await page.locator("#guarded").type("ab1 c");
  await page.locator("#notes").type("one\ntwo");
  await page.locator("#editable").type("editable");

  return {
    afterReplace,
    afterReplaceSelection,
    afterBackspace,
    afterBackspaceSelection,
    afterDelete,
    afterDeleteSelection,
    shifted: await page.locator("#shifted").inputValue(),
    guarded: await page.locator("#guarded").inputValue(),
    guardedEvents: await page.evaluate(() =>
      (window as Window & Record<string, unknown>).__guardedEvents
    ),
    notes: await page.locator("#notes").inputValue(),
    editable: await page.locator("#editable").textContent(),
  };
}

// Reduced from upstream Playwright dispatchEvent coverage:
// - tests/page/page-dispatchevent.spec.ts
// Composition/IME itself is browser-originated, so the adapter contract here is
// that tests can synthesize the same composition/input event shapes apps observe.
async function collectCompositionDispatchSnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <input id="ime" />
        <script>
          const ime = document.getElementById("ime");
          window.__imeEvents = [];
          for (const type of ["compositionstart", "compositionupdate", "beforeinput", "input", "compositionend"]) {
            ime.addEventListener(type, (event) => {
              window.__imeEvents.push([
                event.type,
                event.constructor && event.constructor.name || "",
                event.data == null ? "" : event.data,
                event.inputType || "",
                event.isComposing ? "composing" : "stable",
                event.cancelable ? "cancelable" : "fixed",
                ime.value,
              ].join(":"));
              if (event.type === "input" && event.data) {
                ime.value += event.data;
              }
            });
          }
        </script>
      </body>
    </html>
  `);

  const ime = page.locator("#ime");
  await ime.dispatchEvent("compositionstart", { data: "あ" });
  await ime.dispatchEvent("compositionupdate", { data: "あい" });
  await ime.dispatchEvent("beforeinput", {
    data: "あい",
    inputType: "insertCompositionText",
    isComposing: true,
  });
  await ime.dispatchEvent("input", {
    data: "あい",
    inputType: "insertCompositionText",
    isComposing: true,
  });
  await ime.dispatchEvent("compositionend", { data: "あい" });

  return {
    value: await ime.inputValue(),
    events: await page.evaluate(() =>
      (window as Window & Record<string, unknown>).__imeEvents
    ),
  };
}

// Reduced from upstream Playwright keyboard coverage:
// - tests/page/page-keyboard.spec.ts
// `insertText()` is the closest Playwright keyboard API to IME text insertion:
// it should mutate the focused editable element and emit only input-like events.
async function collectKeyboardInsertTextSnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <input id="ime-text" />
        <script>
          const input = document.getElementById("ime-text");
          window.__insertTextEvents = [];
          for (const type of ["keydown", "keypress", "beforeinput", "input", "keyup"]) {
            input.addEventListener(type, (event) => {
              window.__insertTextEvents.push([
                event.type,
                event.key || "",
                event.data == null ? "" : event.data,
                event.inputType || "",
                input.value,
              ].join(":"));
            });
          }
        </script>
      </body>
    </html>
  `);

  await page.locator("#ime-text").focus();
  await (page as unknown as {
    keyboard: {
      insertText(text: string): Promise<void>;
    };
  }).keyboard.insertText("嗨a");

  return {
    value: await page.locator("#ime-text").inputValue(),
    events: await page.evaluate(() =>
      (window as Window & Record<string, unknown>).__insertTextEvents
    ),
  };
}

async function collectLocatorActionabilitySnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <output id="status"></output>
        <button id="hidden-ready" style="display: none">Hidden Ready</button>
        <button id="disabled-ready" disabled>Disabled Ready</button>
        <script>
          const status = document.getElementById("status");
          const append = (value) => {
            status.textContent = status.textContent ? status.textContent + "," + value : value;
          };
          const hiddenReady = document.getElementById("hidden-ready");
          const disabledReady = document.getElementById("disabled-ready");
          hiddenReady.addEventListener("click", () => append("hidden"));
          disabledReady.addEventListener("click", () => append("disabled"));
          setTimeout(() => {
            const delayed = document.createElement("button");
            delayed.id = "delayed-ready";
            delayed.textContent = "Delayed Ready";
            delayed.addEventListener("click", () => append("delayed"));
            document.body.appendChild(delayed);
          }, 20);
          setTimeout(() => {
            hiddenReady.style.display = "";
            disabledReady.disabled = false;
          }, 40);
        </script>
      </body>
    </html>
  `);

  await role(page, "button", { name: "Delayed Ready" }).click();
  await role(page, "button", { name: "Hidden Ready" }).click();
  await role(page, "button", { name: "Disabled Ready" }).click();

  return {
    status: await page.locator("#status").textContent(),
  };
}

async function collectShadowDomLocatorSnapshot(page: ChromiumOrCraterPage) {
  await page.setContent(`
    <html>
      <body>
        <output id="status">pending</output>
        <section id="host"></section>
        <section id="closed-host"></section>
      </body>
    </html>
  `);

  await page.evaluate(() => {
    const host = document.getElementById("host");
    if (!host) throw new Error("missing host");
    const shadow = host.attachShadow({ mode: "open" });
    shadow.innerHTML = `
      <style>#shadow-button { color: rgb(1, 2, 3); }</style>
      <p id="shadow-text">Shadow Visible Text</p>
      <label for="shadow-input">Shadow Name</label>
      <input
        id="shadow-input"
        data-testid="shadow-input"
        placeholder="Shadow Placeholder"
        title="Shadow Title"
      />
      <button id="shadow-button" data-testid="shadow-action" aria-label="Shadow Save">
        Shadow action
      </button>
    `;
    shadow.querySelector("#shadow-button")?.addEventListener("click", () => {
      const status = document.getElementById("status");
      if (status) status.textContent = "shadow-clicked";
    });

    const closedHost = document.getElementById("closed-host");
    if (!closedHost) throw new Error("missing closed host");
    const closedShadow = closedHost.attachShadow({ mode: "closed" });
    closedShadow.innerHTML = `<button id="closed-button">Closed Shadow</button>`;
  });

  await role(page, "button", { name: "Shadow Save" }).click();
  await page.getByLabel("Shadow Name").fill("Ada");

  return {
    cssId: await page.locator("#shadow-button").getAttribute("id"),
    chainedCssId: await page.locator("#host").locator("#shadow-button").getAttribute("id"),
    textId: await page.getByText("Shadow Visible Text").getAttribute("id"),
    roleId: await role(page, "button", { name: "Shadow Save" }).getAttribute("id"),
    labelValue: await page.getByLabel("Shadow Name").inputValue(),
    placeholderId: await page.getByPlaceholder("Shadow Placeholder").getAttribute("id"),
    testId: await page.getByTestId("shadow-action").getAttribute("id"),
    titleId: await page.getByTitle("Shadow Title").getAttribute("id"),
    status: await page.locator("#status").textContent(),
    closedCount: await page.getByText("Closed Shadow").count(),
  };
}

test.describe("Crater Playwright adapter Chromium parity", () => {
  test.beforeAll(async () => {
    fixtureServer = createServer((req, res) => {
      const url = new URL(req.url || "/", "http://127.0.0.1");
      const fixture = fixtureResponses.get(`${url.pathname}${url.search}`)
        ?? fixtureResponses.get(url.pathname);
      if (!fixture) {
        res.writeHead(404, { "content-type": "text/plain" });
        res.end(`fixture not found: ${url.pathname}`);
        return;
      }
      res.writeHead(fixture.status ?? 200, {
        "content-type": fixture.contentType,
        ...(fixture.headers ?? {}),
      });
      res.end(fixture.body);
    });
    fixtureServer.listen(0, "127.0.0.1");
    await once(fixtureServer, "listening");
    const address = fixtureServer.address();
    if (!address || typeof address === "string") {
      throw new Error("failed to start fixture server");
    }
    fixtureOrigin = `http://127.0.0.1:${address.port}`;
  });

  test.afterAll(async () => {
    if (!fixtureServer) {
      return;
    }
    await new Promise<void>((resolve, reject) => {
      fixtureServer!.close((error) => {
        if (error) reject(error);
        else resolve();
      });
    });
    fixtureServer = null;
    fixtureOrigin = "";
    fixtureResponses.clear();
  });

  test("locator text/name matching follows Chromium defaults", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectLocatorSnapshot);
    const crater = await runWithCrater(collectLocatorSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("setContent executes inline scripts like Chromium", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectSetContentSnapshot);
    const crater = await runWithCrater(collectSetContentSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("form interactions produce Chromium-equivalent user-visible state", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectFormInteractionSnapshot);
    const crater = await runWithCrater(collectFormInteractionSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("locator state predicates match Chromium for common controls", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectStateSnapshot);
    const crater = await runWithCrater(collectStateSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("fetch routing and request/response waits match Chromium", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectRoutingSnapshot);
    const crater = await runWithCrater(collectRoutingSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("keyboard editing matches Chromium for basic key presses", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectKeyboardSnapshot);
    const crater = await runWithCrater(collectKeyboardSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("getByRole options match Chromium for hidden disabled and exact names", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectRoleOptionSnapshot);
    const crater = await runWithCrater(collectRoleOptionSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("upstream getBy locator scenarios match Chromium", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectUpstreamGetBySnapshot);
    const crater = await runWithCrater(collectUpstreamGetBySnapshot);

    expect(crater).toEqual(chromium);
  });

  test("upstream form control scenarios match Chromium", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectUpstreamFormControlSnapshot);
    const crater = await runWithCrater(collectUpstreamFormControlSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("upstream keyboard input scenarios match Chromium", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectUpstreamKeyboardInputSnapshot);
    const crater = await runWithCrater(collectUpstreamKeyboardInputSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("composition and input dispatch events match Chromium", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectCompositionDispatchSnapshot);
    const crater = await runWithCrater(collectCompositionDispatchSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("keyboard insertText scenarios match Chromium", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectKeyboardInsertTextSnapshot);
    const crater = await runWithCrater(collectKeyboardInsertTextSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("locator click waits for attached visible and enabled targets like Chromium", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectLocatorActionabilitySnapshot);
    const crater = await runWithCrater(collectLocatorActionabilitySnapshot);

    expect(crater).toEqual(chromium);
  });

  test("locators pierce open shadow DOM like Chromium", async ({ browser }) => {
    const chromium = await runWithChromium(browser, collectShadowDomLocatorSnapshot);
    const crater = await runWithCrater(collectShadowDomLocatorSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("goto loads URL content, init scripts, and relative scripts like Chromium", async ({ browser }) => {
    serveFixture(
      "/assets/goto-page.js",
      `
        window.__externalScriptSeen = true;
        document.body.setAttribute("data-external", "loaded");
      `,
      "text/javascript; charset=utf-8",
    );
    const pageUrl = serveFixture(
      "/goto-page.html",
      `
        <html>
          <head><title>Goto Fixture</title></head>
          <body>
            <output id="status">pending</output>
            <script src="/assets/goto-page.js"></script>
            <script>
              document.getElementById("status").textContent =
                window.__gotoInit + ":" + window.__externalScriptSeen + ":" + location.pathname;
            </script>
          </body>
        </html>
      `,
    );
    const collectGotoSnapshot = async (page: ChromiumOrCraterPage) => {
      await page.addInitScript(() => {
        (window as Window & Record<string, unknown>).__gotoInit = "ready";
      });
      const response = await page.goto(pageUrl);
      await page.waitForURL(pageUrl);
      await page.locator("#status").waitFor();
      return {
        url: await page.url(),
        title: await page.title(),
        responseUrl: response?.url() ?? null,
        responseStatus: response?.status() ?? null,
        responseOk: response?.ok() ?? null,
        status: await page.locator("#status").textContent(),
        external: await page.locator("body").getAttribute("data-external"),
      };
    };

    const chromium = await runWithChromium(browser, collectGotoSnapshot);
    const crater = await runWithCrater(collectGotoSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("goto exposes Chromium-equivalent response metadata for redirects and HTTP errors", async ({ browser }) => {
    const finalUrl = serveFixture(
      "/navigation/final.html",
      `
        <html>
          <head><title>Final Fixture</title></head>
          <body><output id="status">final</output></body>
        </html>
      `,
      {
        headers: {
          "x-fixture": "final",
        },
      },
    );
    const redirectUrl = serveFixture("/navigation/redirect.html", "", {
      status: 302,
      headers: {
        location: finalUrl,
        "x-fixture": "redirect",
      },
    });
    const notFoundUrl = serveFixture(
      "/navigation/not-found.html",
      `
        <html>
          <head><title>Missing Fixture</title></head>
          <body><output id="status">missing</output></body>
        </html>
      `,
      {
        status: 404,
        headers: {
          "x-fixture": "not-found",
        },
      },
    );
    const serverErrorUrl = serveFixture(
      "/navigation/server-error.html",
      `
        <html>
          <head><title>Error Fixture</title></head>
          <body><output id="status">error</output></body>
        </html>
      `,
      {
        status: 500,
        headers: {
          "x-fixture": "server-error",
        },
      },
    );
    const collectNavigationResponseSnapshot = async (page: ChromiumOrCraterPage) => {
      const redirectResponse = await page.goto(redirectUrl);
      await page.locator("#status").waitFor();
      const redirectHeaders = redirectResponse?.headers() ?? {};
      const redirectSnapshot = {
        pageUrl: await page.url(),
        title: await page.title(),
        statusText: await page.locator("#status").textContent(),
        responseUrl: redirectResponse?.url() ?? null,
        responseStatus: redirectResponse?.status() ?? null,
        responseStatusText: redirectResponse?.statusText() ?? null,
        responseOk: redirectResponse?.ok() ?? null,
        responseHeader: redirectHeaders["x-fixture"] ?? null,
        requestUrl: redirectResponse?.request().url() ?? null,
      };

      const notFoundResponse = await page.goto(notFoundUrl);
      await page.locator("#status").waitFor();
      const notFoundHeaders = notFoundResponse?.headers() ?? {};
      const notFoundSnapshot = {
        pageUrl: await page.url(),
        title: await page.title(),
        statusText: await page.locator("#status").textContent(),
        responseUrl: notFoundResponse?.url() ?? null,
        responseStatus: notFoundResponse?.status() ?? null,
        responseStatusText: notFoundResponse?.statusText() ?? null,
        responseOk: notFoundResponse?.ok() ?? null,
        responseHeader: notFoundHeaders["x-fixture"] ?? null,
      };

      const serverErrorResponse = await page.goto(serverErrorUrl);
      await page.locator("#status").waitFor();
      const serverErrorHeaders = serverErrorResponse?.headers() ?? {};
      const serverErrorSnapshot = {
        pageUrl: await page.url(),
        title: await page.title(),
        statusText: await page.locator("#status").textContent(),
        responseUrl: serverErrorResponse?.url() ?? null,
        responseStatus: serverErrorResponse?.status() ?? null,
        responseStatusText: serverErrorResponse?.statusText() ?? null,
        responseOk: serverErrorResponse?.ok() ?? null,
        responseHeader: serverErrorHeaders["x-fixture"] ?? null,
      };

      return { redirectSnapshot, notFoundSnapshot, serverErrorSnapshot };
    };

    const chromium = await runWithChromium(browser, collectNavigationResponseSnapshot);
    const crater = await runWithCrater(collectNavigationResponseSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("addInitScript runs before page scripts on every document navigation", async ({ browser }) => {
    const firstUrl = serveFixture(
      "/navigation/init-first.html",
      `
        <html>
          <body>
            <output id="status">pending</output>
            <script>
              document.getElementById("status").textContent =
                window.__navigationInitMarker + ":" + location.pathname;
            </script>
          </body>
        </html>
      `,
    );
    const secondUrl = serveFixture(
      "/navigation/init-second.html",
      `
        <html>
          <body>
            <output id="status">pending</output>
            <script>
              document.getElementById("status").textContent =
                window.__navigationInitMarker + ":" + location.pathname;
            </script>
          </body>
        </html>
      `,
    );
    const collectInitNavigationSnapshot = async (page: ChromiumOrCraterPage) => {
      await page.addInitScript(() => {
        window.__navigationInitMarker = "init:" + ((window.__navigationInitRuns || 0) + 1);
        window.__navigationInitRuns = (window.__navigationInitRuns || 0) + 1;
      });

      await page.goto(firstUrl);
      await page.locator("#status").waitFor();
      const first = await page.locator("#status").textContent();

      await page.goto(secondUrl);
      await page.locator("#status").waitFor();
      const second = await page.locator("#status").textContent();

      return { first, second };
    };

    const chromium = await runWithChromium(browser, collectInitNavigationSnapshot);
    const crater = await runWithCrater(collectInitNavigationSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("location navigation and history URL updates follow Chromium basics", async ({ browser }) => {
    const startUrl = serveFixture(
      "/navigation/location-start.html",
      `
        <html>
          <body><output id="status">start</output></body>
        </html>
      `,
    );
    const assignedUrl = serveFixture(
      "/navigation/location-assigned.html",
      `
        <html>
          <body><output id="status">assigned</output></body>
        </html>
      `,
    );
    const replacedUrl = serveFixture(
      "/navigation/location-replaced.html",
      `
        <html>
          <body><output id="status">replaced</output></body>
        </html>
      `,
    );
    const pushedUrl = serveFixture(
      "/navigation/location-pushed.html?from=history",
      `
        <html>
          <body><output id="status">pushed</output></body>
        </html>
      `,
    );
    const collectLocationNavigationSnapshot = async (page: ChromiumOrCraterPage) => {
      await page.goto(startUrl);
      await page.locator("#status").waitFor();

      await page.evaluate((url) => {
        location.assign(url);
      }, assignedUrl);
      await page.waitForURL(assignedUrl);
      await page.locator("#status").waitFor();
      const assigned = {
        url: await page.url(),
        status: await page.locator("#status").textContent(),
      };

      await page.evaluate((url) => {
        location.replace(url);
      }, replacedUrl);
      await page.waitForURL(replacedUrl);
      await page.locator("#status").waitFor();
      const replaced = {
        url: await page.url(),
        status: await page.locator("#status").textContent(),
      };

      await page.evaluate((url) => {
        history.pushState({ mode: "pushed" }, "", url);
      }, pushedUrl);
      await page.waitForURL(pushedUrl);
      const pushed = {
        url: await page.url(),
        status: await page.locator("#status").textContent(),
      };

      await page.evaluate(() => {
        location.reload();
      });
      await page.waitForURL(pushedUrl);
      await page.locator("#status").waitFor();
      const reloaded = {
        url: await page.url(),
        status: await page.locator("#status").textContent(),
      };

      return { assigned, replaced, pushed, reloaded };
    };

    const chromium = await runWithChromium(browser, collectLocationNavigationSnapshot);
    const crater = await runWithCrater(collectLocationNavigationSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("document and subresource requests are observable like Chromium", async ({ browser }) => {
    const scriptUrl = serveFixture(
      "/network/observed-script.js",
      `
        document.getElementById("status").textContent = "script-loaded";
      `,
      "text/javascript; charset=utf-8",
    );
    const styleUrl = serveFixture(
      "/network/observed-style.css",
      "body { color: rgb(1, 2, 3); }",
      "text/css; charset=utf-8",
    );
    const imageUrl = serveFixture(
      "/network/observed-image.svg",
      `<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>`,
      "image/svg+xml",
    );
    const pageUrl = serveFixture(
      "/network/observed-page.html",
      `
        <html>
          <head>
            <link rel="stylesheet" href="${urlPath(styleUrl)}">
          </head>
          <body>
            <output id="status">pending</output>
            <img id="logo" src="${urlPath(imageUrl)}">
            <script src="${urlPath(scriptUrl)}"></script>
          </body>
        </html>
      `,
    );
    const collectNetworkObservationSnapshot = async (page: ChromiumOrCraterPage) => {
      const installMatcher = /\/network\/__never_match__$/;
      await page.route(installMatcher, async (route) => {
        await route.continue();
      });
      await page.unroute(installMatcher);

      const documentRequest = page.waitForRequest(pageUrl);
      const scriptRequest = page.waitForRequest(scriptUrl);
      const styleRequest = page.waitForRequest(styleUrl);
      const imageRequest = page.waitForRequest(imageUrl);
      const scriptResponse = page.waitForResponse(scriptUrl);

      const gotoResponse = await page.goto(pageUrl);
      await page.locator("#status").waitFor();

      const requests = await Promise.all([
        documentRequest,
        scriptRequest,
        styleRequest,
        imageRequest,
      ]);
      const responses = await Promise.all([
        Promise.resolve(gotoResponse),
        scriptResponse,
      ]);

      return {
        status: await page.locator("#status").textContent(),
        requests: requests.map((request) => urlPath(request.url())),
        responses: responses.map((response) => [
          urlPath(response.url()),
          response.status(),
          response.ok(),
        ]),
      };
    };

    const chromium = await runWithChromium(browser, collectNetworkObservationSnapshot);
    const crater = await runWithCrater(collectNetworkObservationSnapshot);

    expect(crater).toEqual(chromium);
  });

  test("route can fulfill document and external script requests like Chromium", async ({ browser }) => {
    const routedPageUrl = `${fixtureOrigin}/network/routed-page.html`;
    const routedScriptUrl = `${fixtureOrigin}/network/routed-script.js`;
    const collectRoutedDocumentSnapshot = async (page: ChromiumOrCraterPage) => {
      await page.route(/\/network\/routed-page\.html$/, async (route) => {
        await route.fulfill({
          contentType: "text/html; charset=utf-8",
          body: `
            <html>
              <body>
                <output id="status">pending</output>
                <script src="/network/routed-script.js"></script>
              </body>
            </html>
          `,
        });
      });
      await page.route(/\/network\/routed-script\.js$/, async (route) => {
        await route.fulfill({
          contentType: "text/javascript; charset=utf-8",
          body: `
            document.getElementById("status").textContent = "routed-script";
          `,
        });
      });

      const documentRequest = page.waitForRequest(routedPageUrl);
      const scriptRequest = page.waitForRequest(routedScriptUrl);
      const response = await page.goto(routedPageUrl);
      await page.locator("#status").waitFor();
      const requests = await Promise.all([documentRequest, scriptRequest]);

      return {
        pageUrl: await page.url(),
        responseUrl: response?.url() ?? null,
        responseStatus: response?.status() ?? null,
        responseOk: response?.ok() ?? null,
        status: await page.locator("#status").textContent(),
        requests: requests.map((request) => urlPath(request.url())),
      };
    };

    const chromium = await runWithChromium(browser, collectRoutedDocumentSnapshot);
    const crater = await runWithCrater(collectRoutedDocumentSnapshot);

    expect(crater).toEqual(chromium);
  });
});
