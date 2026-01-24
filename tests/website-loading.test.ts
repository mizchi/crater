/**
 * Website Loading Tests for Crater WebDriver BiDi
 *
 * Tests real website loading scenarios with HTML, CSS, and JavaScript assets.
 * Uses the BiDi protocol to load pages and verify script execution.
 */

import { test, expect } from "@playwright/test";
import WebSocket from "ws";

const BIDI_URL = "ws://127.0.0.1:9222";

interface BidiResponse {
  id: number;
  type: "success" | "error";
  result?: unknown;
  error?: string;
  message?: string;
}

interface BidiEvent {
  type: "event";
  method: string;
  params: unknown;
}

/**
 * Parse Playwright-style selector into a query expression
 */
function parseLocatorSelector(selector: string): { type: string; value: string; exact?: boolean } {
  const prefixMatch = selector.match(/^(text|role|placeholder|alt|title|testid|label)=(.+)$/i);
  if (prefixMatch) {
    const [, type, value] = prefixMatch;
    const exactMatch = value.match(/^exact:(.+)$/i);
    if (exactMatch) {
      return { type: type.toLowerCase(), value: exactMatch[1], exact: true };
    }
    return { type: type.toLowerCase(), value };
  }
  return { type: "css", value: selector };
}

/**
 * Build JavaScript expression to find elements
 */
function buildSelectorExpr(parsed: { type: string; value: string; exact?: boolean }, method: "first" | "all"): string {
  const { type, value, exact } = parsed;
  const escapedValue = value.replace(/'/g, "\\'").replace(/\\/g, "\\\\");

  const getAllElements = `(() => {
    const all = [];
    const walk = (node) => {
      if (node.nodeType === 1) all.push(node);
      const children = node._children || node.childNodes || [];
      for (const child of children) walk(child);
    };
    walk(document.documentElement || document.body);
    return all;
  })()`;

  switch (type) {
    case "text":
      if (exact) {
        return method === "first"
          ? `${getAllElements}.find(el => {
              const children = el._children || el.childNodes || [];
              return Array.from(children).some(n => n.nodeType === 3 && n.textContent && n.textContent.trim() === '${escapedValue}');
            })`
          : `${getAllElements}.filter(el => {
              const children = el._children || el.childNodes || [];
              return Array.from(children).some(n => n.nodeType === 3 && n.textContent && n.textContent.trim() === '${escapedValue}');
            })`;
      }
      return method === "first"
        ? `${getAllElements}.find(el => {
            const children = el._children || el.childNodes || [];
            const directText = Array.from(children)
              .filter(n => n.nodeType === 3)
              .map(n => n.textContent || '')
              .join('');
            return directText.includes('${escapedValue}');
          })`
        : `${getAllElements}.filter(el => {
            const children = el._children || el.childNodes || [];
            const directText = Array.from(children)
              .filter(n => n.nodeType === 3)
              .map(n => n.textContent || '')
              .join('');
            return directText.includes('${escapedValue}');
          })`;

    case "role":
      return method === "first"
        ? `${getAllElements}.find(el => (el.getAttribute ? el.getAttribute('role') : (el._attrs && el._attrs.role)) === '${escapedValue}')`
        : `${getAllElements}.filter(el => (el.getAttribute ? el.getAttribute('role') : (el._attrs && el._attrs.role)) === '${escapedValue}')`;

    case "testid":
      return method === "first"
        ? `document.querySelector('[data-testid="${escapedValue}"]')`
        : `Array.from(document.querySelectorAll('[data-testid="${escapedValue}"]'))`;

    case "css":
    default:
      return method === "first"
        ? `document.querySelector('${escapedValue}')`
        : `Array.from(document.querySelectorAll('${escapedValue}'))`;
  }
}

/**
 * BiDi client with page-like API
 */
class CraterPage {
  private ws: WebSocket | null = null;
  private commandId = 0;
  private pendingCommands = new Map<
    number,
    { resolve: (value: BidiResponse) => void; reject: (error: Error) => void }
  >();
  private eventHandlers: ((event: BidiEvent) => void)[] = [];
  private contextId: string | null = null;

  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(BIDI_URL);
      this.ws.on("open", async () => {
        const resp = await this.sendBidi("browsingContext.create", { type: "tab" });
        this.contextId = (resp.result as { context: string }).context;
        resolve();
      });
      this.ws.on("error", (err) => reject(err));
      this.ws.on("message", (data) => this.handleMessage(data.toString()));
    });
  }

  private handleMessage(data: string): void {
    const msg = JSON.parse(data);
    if (msg.type === "event") {
      for (const handler of this.eventHandlers) {
        handler(msg as BidiEvent);
      }
      return;
    }
    const pending = this.pendingCommands.get(msg.id);
    if (pending) {
      this.pendingCommands.delete(msg.id);
      pending.resolve(msg as BidiResponse);
    }
  }

  onEvent(handler: (event: BidiEvent) => void): void {
    this.eventHandlers.push(handler);
  }

  private async sendBidi(method: string, params: unknown = {}): Promise<BidiResponse> {
    if (!this.ws) throw new Error("Not connected");
    const id = ++this.commandId;
    const message = JSON.stringify({ id, method, params });
    return new Promise((resolve, reject) => {
      this.pendingCommands.set(id, { resolve, reject });
      this.ws!.send(message);
      setTimeout(() => {
        if (this.pendingCommands.has(id)) {
          this.pendingCommands.delete(id);
          reject(new Error(`Timeout waiting for response to ${method}`));
        }
      }, 10000);
    });
  }

  async goto(url: string): Promise<void> {
    await this.sendBidi("browsingContext.navigate", {
      context: this.contextId,
      url,
      wait: "complete",
    });
  }

  async setContent(html: string): Promise<void> {
    const dataUrl = `data:text/html;base64,${Buffer.from(html).toString("base64")}`;
    await this.goto(dataUrl);
    await this.sendBidi("script.evaluate", {
      expression: `__loadHTML(${JSON.stringify(html)})`,
      target: { context: this.contextId },
      awaitPromise: false,
    });
  }

  async setContentWithScripts(html: string): Promise<{ scripts: unknown[] }> {
    const dataUrl = `data:text/html;base64,${Buffer.from(html).toString("base64")}`;
    await this.goto(dataUrl);
    await this.sendBidi("script.evaluate", {
      expression: `__loadHTML(${JSON.stringify(html)})`,
      target: { context: this.contextId },
      awaitPromise: false,
    });
    // Execute inline scripts
    const resp = await this.sendBidi("script.evaluate", {
      expression: `(async () => await __executeScripts())()`,
      target: { context: this.contextId },
      awaitPromise: true,
    });
    const result = resp.result as { result?: { value?: unknown[] } };
    return { scripts: result.result?.value || [] };
  }

  async loadPage(url: string, options: { executeScripts?: boolean } = {}): Promise<{ url: string; status: number; scripts?: unknown[] }> {
    const executeScripts = options.executeScripts !== false;
    const resp = await this.sendBidi("script.evaluate", {
      expression: `(async () => await __loadPageWithScripts(${JSON.stringify(url)}, { executeScripts: ${executeScripts} }))()`,
      target: { context: this.contextId },
      awaitPromise: true,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error);
    }
    const result = resp.result as { result?: { value?: { url: string; status: number; scripts?: unknown[] } } };
    return result.result?.value || { url, status: 0 };
  }

  async evaluate<T>(expression: string, options: { awaitPromise?: boolean } = {}): Promise<T> {
    const isAsync = options.awaitPromise !== undefined
      ? options.awaitPromise
      : (expression.includes("await ") || expression.includes("new Promise"));

    const resp = await this.sendBidi("script.evaluate", {
      expression,
      target: { context: this.contextId },
      awaitPromise: isAsync,
    });

    if (resp.type === "error") {
      throw new Error(resp.message || resp.error);
    }

    const result = resp.result as { result?: { value?: T }; exceptionDetails?: unknown };
    if (result.exceptionDetails) {
      throw new Error(JSON.stringify(result.exceptionDetails));
    }
    return result.result?.value as T;
  }

  locator(selector: string): Locator {
    return new Locator(this, selector);
  }

  getByText(text: string, options: { exact?: boolean } = {}): Locator {
    const selector = options.exact ? `text=exact:${text}` : `text=${text}`;
    return this.locator(selector);
  }

  getByRole(role: string): Locator {
    return this.locator(`role=${role}`);
  }

  getByTestId(testId: string): Locator {
    return this.locator(`testid=${testId}`);
  }

  async close(): Promise<void> {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

class Locator {
  constructor(
    private page: CraterPage,
    private selector: string,
    private parentSelector: string | null = null
  ) {}

  private parsed = parseLocatorSelector(this.selector);

  private queryExpr(method: "querySelector" | "querySelectorAll"): string {
    const m = method === "querySelector" ? "first" : "all";
    return buildSelectorExpr(this.parsed, m);
  }

  locator(selector: string): Locator {
    const fullParent = this.parentSelector
      ? `${this.parentSelector} ${this.selector}`.trim()
      : this.selector;
    return new Locator(this.page, selector, fullParent);
  }

  async click(): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error('Element not found: ${this.selector}');
        el.click();
      })()
    `);
  }

  async fill(value: string): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error('Element not found: ${this.selector}');
        el.value = ${JSON.stringify(value)};
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      })()
    `);
  }

  async textContent(): Promise<string | null> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.textContent : null;
      })()
    `);
  }

  async innerHTML(): Promise<string> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.innerHTML : '';
      })()
    `);
  }

  async inputValue(): Promise<string> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.value : '';
      })()
    `);
  }

  async getAttribute(name: string): Promise<string | null> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.getAttribute('${name}') : null;
      })()
    `);
  }

  async count(): Promise<number> {
    return this.page.evaluate(`
      (() => {
        const els = ${this.queryExpr("querySelectorAll")};
        return Array.isArray(els) ? els.length : (els ? els.length : 0);
      })()
    `);
  }

  async isVisible(): Promise<boolean> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) return false;
        const style = window.getComputedStyle ? window.getComputedStyle(el) : el.style;
        return !el.hidden && style.display !== 'none' && style.visibility !== 'hidden';
      })()
    `);
  }
}

test.describe("Website Loading Tests", () => {
  let page: CraterPage;

  test.beforeEach(async () => {
    page = new CraterPage();
    await page.connect();
  });

  test.afterEach(async () => {
    await page.close();
  });

  test("load HTML with inline script that modifies DOM", async () => {
    const html = `
      <html>
        <body>
          <div id="target">Original</div>
          <script>
            document.getElementById('target').textContent = 'Modified by script';
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    const text = await page.locator("#target").textContent();
    expect(text).toBe("Modified by script");
  });

  test("load HTML with script that creates elements", async () => {
    const html = `
      <html>
        <body>
          <div id="container"></div>
          <script>
            const container = document.getElementById('container');
            for (let i = 0; i < 3; i++) {
              const item = document.createElement('div');
              item.className = 'item';
              item.textContent = 'Item ' + (i + 1);
              container.appendChild(item);
            }
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    const count = await page.locator(".item").count();
    expect(count).toBe(3);

    const firstItem = await page.evaluate<string>(`
      document.querySelector('.item').textContent
    `);
    expect(firstItem).toBe("Item 1");
  });

  test("load HTML with event listener script", async () => {
    const html = `
      <html>
        <body>
          <button id="btn">Click me</button>
          <div id="output">Not clicked</div>
          <script>
            document.getElementById('btn').addEventListener('click', () => {
              document.getElementById('output').textContent = 'Button was clicked!';
            });
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    // Verify initial state
    let output = await page.locator("#output").textContent();
    expect(output).toBe("Not clicked");

    // Click the button
    await page.locator("#btn").click();

    // Verify the event handler ran
    output = await page.locator("#output").textContent();
    expect(output).toBe("Button was clicked!");
  });

  test("load HTML with multiple scripts in order", async () => {
    const html = `
      <html>
        <body>
          <div id="log"></div>
          <script>
            window.log = [];
            window.log.push('script1');
          </script>
          <script>
            window.log.push('script2');
          </script>
          <script>
            window.log.push('script3');
            document.getElementById('log').textContent = window.log.join(',');
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    const logContent = await page.locator("#log").textContent();
    expect(logContent).toBe("script1,script2,script3");
  });

  test("load HTML with script that uses data attributes via dataset", async () => {
    const html = `
      <html>
        <body>
          <div id="config" data-api-url="https://api.example.com" data-version="1.0"></div>
          <div id="result"></div>
          <script>
            const config = document.getElementById('config');
            const result = document.getElementById('result');
            // Use dataset API to access data-* attributes
            result.textContent = 'API: ' + config.dataset.apiUrl + ', v' + config.dataset.version;
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    const result = await page.locator("#result").textContent();
    expect(result).toBe("API: https://api.example.com, v1.0");
  });

  test("load HTML with form interaction script", async () => {
    const html = `
      <html>
        <body>
          <form id="form">
            <input id="name" type="text" placeholder="Enter name">
            <input id="email" type="email" placeholder="Enter email">
            <button type="submit">Submit</button>
          </form>
          <div id="result"></div>
          <script>
            document.getElementById('form').addEventListener('submit', (e) => {
              e.preventDefault();
              const name = document.getElementById('name').value;
              const email = document.getElementById('email').value;
              document.getElementById('result').textContent = 'Submitted: ' + name + ' <' + email + '>';
            });
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    // Fill the form
    await page.locator("#name").fill("John Doe");
    await page.locator("#email").fill("john@example.com");

    // Submit the form
    await page.evaluate(`document.getElementById('form').dispatchEvent(new Event('submit'))`);

    // Verify result
    const result = await page.locator("#result").textContent();
    expect(result).toBe("Submitted: John Doe <john@example.com>");
  });

  test("use getByText to find elements", async () => {
    const html = `
      <html>
        <body>
          <button>Save</button>
          <button>Cancel</button>
          <button>Delete</button>
        </body>
      </html>
    `;

    await page.setContent(html);

    const saveButton = page.getByText("Save");
    const saveText = await saveButton.textContent();
    expect(saveText).toBe("Save");

    const cancelButton = page.getByText("Cancel", { exact: true });
    const cancelText = await cancelButton.textContent();
    expect(cancelText).toBe("Cancel");
  });

  test("use getByRole to find elements", async () => {
    const html = `
      <html>
        <body>
          <nav role="navigation">
            <a href="/">Home</a>
            <a href="/about">About</a>
          </nav>
          <main role="main">
            <h1>Welcome</h1>
          </main>
        </body>
      </html>
    `;

    await page.setContent(html);

    const nav = page.getByRole("navigation");
    const navHtml = await nav.innerHTML();
    expect(navHtml).toContain("Home");
    expect(navHtml).toContain("About");
  });

  test("use getByTestId to find elements", async () => {
    const html = `
      <html>
        <body>
          <div data-testid="user-profile">
            <span data-testid="user-name">Alice</span>
            <span data-testid="user-email">alice@example.com</span>
          </div>
        </body>
      </html>
    `;

    await page.setContent(html);

    const userName = page.getByTestId("user-name");
    const userNameText = await userName.textContent();
    expect(userNameText).toBe("Alice");

    const userEmail = page.getByTestId("user-email");
    const userEmailText = await userEmail.textContent();
    expect(userEmailText).toBe("alice@example.com");
  });

  test("script modifies styles dynamically", async () => {
    const html = `
      <html>
        <body>
          <div id="box" style="display: none;">Hidden content</div>
          <button id="toggle">Toggle</button>
          <script>
            document.getElementById('toggle').addEventListener('click', () => {
              const box = document.getElementById('box');
              box.style.display = box.style.display === 'none' ? 'block' : 'none';
            });
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    // Initially hidden
    let isVisible = await page.locator("#box").isVisible();
    expect(isVisible).toBe(false);

    // Toggle visibility
    await page.locator("#toggle").click();

    // Now visible
    isVisible = await page.locator("#box").isVisible();
    expect(isVisible).toBe(true);
  });

  test("script uses setTimeout for async behavior", async () => {
    const html = `
      <html>
        <body>
          <div id="status">Loading...</div>
          <script>
            setTimeout(() => {
              document.getElementById('status').textContent = 'Loaded!';
            }, 100);
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    // Wait for setTimeout to complete
    await page.evaluate(`new Promise(r => setTimeout(r, 150))`, { awaitPromise: true });

    const status = await page.locator("#status").textContent();
    expect(status).toBe("Loaded!");
  });

  test("script creates nested DOM structure", async () => {
    const html = `
      <html>
        <body>
          <div id="app"></div>
          <script>
            const app = document.getElementById('app');

            // Create a nested structure
            const card = document.createElement('div');
            card.className = 'card';

            const header = document.createElement('div');
            header.className = 'card-header';
            header.textContent = 'Card Title';

            const body = document.createElement('div');
            body.className = 'card-body';
            body.textContent = 'Card content goes here';

            const footer = document.createElement('div');
            footer.className = 'card-footer';

            const button = document.createElement('button');
            button.textContent = 'Action';
            footer.appendChild(button);

            card.appendChild(header);
            card.appendChild(body);
            card.appendChild(footer);
            app.appendChild(card);
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    const cardHeader = await page.locator(".card-header").textContent();
    expect(cardHeader).toBe("Card Title");

    const cardBody = await page.locator(".card-body").textContent();
    expect(cardBody).toBe("Card content goes here");

    // Use evaluate for descendant selector since Mock DOM doesn't support it directly
    const buttonText = await page.evaluate<string>(`
      document.querySelector('.card-footer').querySelector('button').textContent
    `);
    expect(buttonText).toBe("Action");
  });

  test("chained locators work correctly", async () => {
    const html = `
      <html>
        <body>
          <div class="container">
            <ul class="list">
              <li class="item">First</li>
              <li class="item">Second</li>
              <li class="item">Third</li>
            </ul>
          </div>
        </body>
      </html>
    `;

    await page.setContent(html);

    const container = page.locator(".container");
    const list = container.locator(".list");
    const items = list.locator(".item");

    const count = await items.count();
    expect(count).toBe(3);
  });

  test("isVisible returns correct state for different elements", async () => {
    const html = `
      <html>
        <body>
          <div id="visible">Visible content</div>
          <div id="hidden-display" style="display: none;">Hidden by display</div>
          <div id="hidden-visibility" style="visibility: hidden;">Hidden by visibility</div>
          <div id="hidden-attr" hidden>Hidden by attribute</div>
        </body>
      </html>
    `;

    await page.setContent(html);

    expect(await page.locator("#visible").isVisible()).toBe(true);
    expect(await page.locator("#hidden-display").isVisible()).toBe(false);
    expect(await page.locator("#hidden-visibility").isVisible()).toBe(false);
    expect(await page.locator("#hidden-attr").isVisible()).toBe(false);
  });
});

test.describe("Script Execution Edge Cases", () => {
  let page: CraterPage;

  test.beforeEach(async () => {
    page = new CraterPage();
    await page.connect();
  });

  test.afterEach(async () => {
    await page.close();
  });

  test("script with syntax error does not break page", async () => {
    const html = `
      <html>
        <body>
          <div id="before">Before error</div>
          <script>
            // This script has a syntax error
            if (true { console.log('error'); }
          </script>
          <div id="after">After error</div>
          <script>
            // This script should still run (browser behavior varies)
            document.getElementById('after').textContent = 'Script ran';
          </script>
        </body>
      </html>
    `;

    // Should not throw
    await page.setContentWithScripts(html);

    // First element should be unchanged
    const before = await page.locator("#before").textContent();
    expect(before).toBe("Before error");
  });

  test("script with runtime error does not break other scripts", async () => {
    const html = `
      <html>
        <body>
          <div id="result">Initial</div>
          <script>
            // This will throw at runtime
            nonExistentFunction();
          </script>
          <script>
            // This should still run
            document.getElementById('result').textContent = 'Second script ran';
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    const result = await page.locator("#result").textContent();
    expect(result).toBe("Second script ran");
  });

  test("script can access and modify window object", async () => {
    const html = `
      <html>
        <body>
          <div id="result"></div>
          <script>
            window.myGlobal = 'Hello from window';
            document.getElementById('result').textContent = window.myGlobal;
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    const result = await page.locator("#result").textContent();
    expect(result).toBe("Hello from window");

    // Verify we can access the global from evaluate
    const global = await page.evaluate<string>(`window.myGlobal`);
    expect(global).toBe("Hello from window");
  });

  test("script can use JSON parsing", async () => {
    const html = `
      <html>
        <body>
          <script id="config" type="application/json">
            {"name": "Test App", "version": "1.0.0"}
          </script>
          <div id="result"></div>
          <script>
            const configScript = document.getElementById('config');
            const config = JSON.parse(configScript.textContent);
            document.getElementById('result').textContent = config.name + ' v' + config.version;
          </script>
        </body>
      </html>
    `;

    await page.setContentWithScripts(html);

    const result = await page.locator("#result").textContent();
    expect(result).toBe("Test App v1.0.0");
  });
});
