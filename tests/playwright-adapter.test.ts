/**
 * Playwright Adapter Tests for Crater WebDriver BiDi
 *
 * Tests real Playwright integration with the Crater BiDi server.
 * This uses a custom adapter that translates Playwright-like API to BiDi protocol.
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
 * Parse Playwright-style selector into a query function
 * Supports: text=, role=, placeholder=, alt=, title=, testid=, label=
 */
function parseLocatorSelector(selector: string): { type: string; value: string; exact?: boolean } {
  // Check for prefix patterns
  const prefixMatch = selector.match(/^(text|role|placeholder|alt|title|testid|label)=(.+)$/i);
  if (prefixMatch) {
    const [, type, value] = prefixMatch;
    // Check for exact match modifier
    const exactMatch = value.match(/^exact:(.+)$/i);
    if (exactMatch) {
      return { type: type.toLowerCase(), value: exactMatch[1], exact: true };
    }
    return { type: type.toLowerCase(), value };
  }
  // Default to CSS selector
  return { type: "css", value: selector };
}

/**
 * Build a JS expression to find elements by parsed selector
 * Uses JavaScript iteration to work with Mock DOM limitations
 */
function buildSelectorExpr(parsed: { type: string; value: string; exact?: boolean }, method: "first" | "all"): string {
  const { type, value, exact } = parsed;
  const escapedValue = value.replace(/'/g, "\\'").replace(/\\/g, "\\\\");

  // Helper to get all elements recursively (since querySelectorAll('*') may not work)
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
      // For text matching, prefer elements with direct text nodes (leaf elements)
      // This avoids matching parent containers that contain the text in descendants
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
      // For partial match, find elements where direct text content includes the search term
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
        ? `document.querySelector('[role="${escapedValue}"]')`
        : `Array.from(document.querySelectorAll('[role="${escapedValue}"]'))`;

    case "placeholder":
      return method === "first"
        ? `${getAllElements}.find(el => el._attrs && (el._attrs.placeholder === '${escapedValue}' || (el._attrs.placeholder && el._attrs.placeholder.includes('${escapedValue}'))))`
        : `${getAllElements}.filter(el => el._attrs && (el._attrs.placeholder === '${escapedValue}' || (el._attrs.placeholder && el._attrs.placeholder.includes('${escapedValue}'))))`;

    case "alt":
      return method === "first"
        ? `${getAllElements}.find(el => el._attrs && (el._attrs.alt === '${escapedValue}' || (el._attrs.alt && el._attrs.alt.includes('${escapedValue}'))))`
        : `${getAllElements}.filter(el => el._attrs && (el._attrs.alt === '${escapedValue}' || (el._attrs.alt && el._attrs.alt.includes('${escapedValue}'))))`;

    case "title":
      return method === "first"
        ? `${getAllElements}.find(el => el._attrs && (el._attrs.title === '${escapedValue}' || (el._attrs.title && el._attrs.title.includes('${escapedValue}'))))`
        : `${getAllElements}.filter(el => el._attrs && (el._attrs.title === '${escapedValue}' || (el._attrs.title && el._attrs.title.includes('${escapedValue}'))))`;

    case "testid":
      return method === "first"
        ? `document.querySelector('[data-testid="${escapedValue}"]')`
        : `Array.from(document.querySelectorAll('[data-testid="${escapedValue}"]'))`;

    case "label":
      // Find by associated label text
      return method === "first"
        ? `(() => {
            const labels = ${getAllElements}.filter(el => el.tagName === 'LABEL');
            const label = labels.find(l => l.textContent && l.textContent.includes('${escapedValue}'));
            if (!label) return null;
            const forId = label._attrs && label._attrs.for;
            if (forId) return document.getElementById(forId);
            return label.querySelector('input, select, textarea');
          })()`
        : `(() => {
            const labels = ${getAllElements}.filter(el => el.tagName === 'LABEL' && el.textContent && el.textContent.includes('${escapedValue}'));
            return labels.map(label => {
              const forId = label._attrs && label._attrs.for;
              if (forId) return document.getElementById(forId);
              return label.querySelector('input, select, textarea');
            }).filter(Boolean);
          })()`;

    case "css":
    default:
      return method === "first"
        ? `document.querySelector('${escapedValue}')`
        : `Array.from(document.querySelectorAll('${escapedValue}'))`;
  }
}

/**
 * Locator class - Playwright-style element locator
 * Note: Uses relative queries from parent to work around Mock DOM limitations
 * Supports: CSS selectors, text=, role=, placeholder=, alt=, title=, testid=, label=
 */
class CraterLocator {
  protected parsed: { type: string; value: string; exact?: boolean };
  protected filters: Array<{ hasText?: string; hasNotText?: string }> = [];

  constructor(
    protected page: CraterPage,
    protected selector: string,
    protected parentSelector: string | null = null
  ) {
    this.parsed = parseLocatorSelector(selector);
  }

  /**
   * Build an expression that queries elements relative to parent (if any)
   */
  protected queryExpr(method: "querySelector" | "querySelectorAll"): string {
    const baseExpr = buildSelectorExpr(this.parsed, method === "querySelector" ? "first" : "all");

    if (this.parentSelector) {
      const parentParsed = parseLocatorSelector(this.parentSelector);
      const parentExpr = buildSelectorExpr(parentParsed, "first");
      if (method === "querySelector") {
        return `(() => { const p = ${parentExpr}; if (!p) return null; const all = ${baseExpr.replace(/document\./g, "p.")}; return all; })()`;
      } else {
        return `(() => { const p = ${parentExpr}; if (!p) return []; return ${baseExpr.replace(/document\./g, "p.")}; })()`;
      }
    }

    // Apply filters if any
    if (this.filters.length > 0 && method === "querySelectorAll") {
      let filterExpr = baseExpr;
      for (const filter of this.filters) {
        if (filter.hasText) {
          const escaped = filter.hasText.replace(/'/g, "\\'");
          filterExpr = `(${filterExpr}).filter(el => el.textContent && el.textContent.includes('${escaped}'))`;
        }
        if (filter.hasNotText) {
          const escaped = filter.hasNotText.replace(/'/g, "\\'");
          filterExpr = `(${filterExpr}).filter(el => !el.textContent || !el.textContent.includes('${escaped}'))`;
        }
      }
      return filterExpr;
    }

    if (this.filters.length > 0 && method === "querySelector") {
      let filterExpr = buildSelectorExpr(this.parsed, "all");
      for (const filter of this.filters) {
        if (filter.hasText) {
          const escaped = filter.hasText.replace(/'/g, "\\'");
          filterExpr = `(${filterExpr}).filter(el => el.textContent && el.textContent.includes('${escaped}'))`;
        }
        if (filter.hasNotText) {
          const escaped = filter.hasNotText.replace(/'/g, "\\'");
          filterExpr = `(${filterExpr}).filter(el => !el.textContent || !el.textContent.includes('${escaped}'))`;
        }
      }
      return `(${filterExpr})[0] || null`;
    }

    return baseExpr;
  }

  /**
   * Filter locator results
   */
  filter(options: { hasText?: string | RegExp; hasNotText?: string | RegExp }): CraterLocator {
    const newLocator = new CraterLocator(this.page, this.selector, this.parentSelector);
    newLocator.parsed = this.parsed;
    newLocator.filters = [...this.filters];
    if (options.hasText) {
      newLocator.filters.push({ hasText: String(options.hasText) });
    }
    if (options.hasNotText) {
      newLocator.filters.push({ hasNotText: String(options.hasNotText) });
    }
    return newLocator;
  }

  /**
   * Get a child locator
   */
  locator(selector: string): CraterLocator {
    // Chain by creating a new locator with current as parent
    const fullParent = this.parentSelector
      ? `${this.parentSelector} ${this.selector}`.trim()
      : this.selector;
    return new CraterLocator(this.page, selector, fullParent || null);
  }

  /**
   * Get locator by text content
   */
  getByText(text: string, options: { exact?: boolean } = {}): CraterLocator {
    const selector = options.exact ? `text=exact:${text}` : `text=${text}`;
    return this.locator(selector);
  }

  /**
   * Get locator by role
   */
  getByRole(role: string): CraterLocator {
    return this.locator(`role=${role}`);
  }

  /**
   * Get locator by placeholder
   */
  getByPlaceholder(text: string): CraterLocator {
    return this.locator(`placeholder=${text}`);
  }

  /**
   * Get locator by alt text
   */
  getByAltText(text: string): CraterLocator {
    return this.locator(`alt=${text}`);
  }

  /**
   * Get locator by title
   */
  getByTitle(text: string): CraterLocator {
    return this.locator(`title=${text}`);
  }

  /**
   * Get locator by test ID
   */
  getByTestId(testId: string): CraterLocator {
    return this.locator(`testid=${testId}`);
  }

  /**
   * Get locator by label text
   */
  getByLabel(text: string): CraterLocator {
    return this.locator(`label=${text}`);
  }

  /**
   * Get the first matching element
   */
  first(): CraterLocator {
    return new CraterNthLocator(this.page, this.selector, 0, this.parentSelector);
  }

  /**
   * Get the last matching element
   */
  last(): CraterLocator {
    return new CraterLastLocator(this.page, this.selector, this.parentSelector);
  }

  /**
   * Get the nth matching element (0-indexed)
   */
  nth(index: number): CraterLocator {
    return new CraterNthLocator(this.page, this.selector, index, this.parentSelector);
  }

  /**
   * Click the element
   */
  async click(): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error('Element not found: ${this.selector}');
        el.click();
      })()
    `);
  }

  /**
   * Fill the element with a value
   */
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

  /**
   * Get text content
   */
  async textContent(): Promise<string | null> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.textContent : null;
      })()
    `);
  }

  /**
   * Get inner HTML
   */
  async innerHTML(): Promise<string> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.innerHTML : '';
      })()
    `);
  }

  /**
   * Get input value
   */
  async inputValue(): Promise<string> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.value : '';
      })()
    `);
  }

  /**
   * Check if visible
   */
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

  /**
   * Get attribute
   */
  async getAttribute(name: string): Promise<string | null> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.getAttribute('${name}') : null;
      })()
    `);
  }

  /**
   * Wait for element to appear
   */
  async waitFor(options: { timeout?: number } = {}): Promise<void> {
    const timeout = options.timeout || 5000;
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const found = await this.page.evaluate(`${this.queryExpr("querySelector")} !== null`);
      if (found) return;
      await new Promise(r => setTimeout(r, 100));
    }
    throw new Error(`Timeout waiting for selector: ${this.selector}`);
  }

  /**
   * Count matching elements
   */
  async count(): Promise<number> {
    return this.page.evaluate(`
      (() => {
        const els = ${this.queryExpr("querySelectorAll")};
        return els ? els.length : 0;
      })()
    `);
  }
}

/**
 * Special locator for nth element selection
 */
class CraterNthLocator extends CraterLocator {
  constructor(
    page: CraterPage,
    selector: string,
    private index: number,
    parentSelector: string | null = null
  ) {
    super(page, selector, parentSelector);
  }

  private nthQueryExpr(): string {
    if (this.parentSelector) {
      return `document.querySelector('${this.parentSelector}')?.querySelectorAll('${this.selector}')`;
    }
    return `document.querySelectorAll('${this.selector}')`;
  }

  async click(): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const els = ${this.nthQueryExpr()};
        const el = els ? els[${this.index}] : null;
        if (!el) throw new Error('Element not found at index ${this.index}');
        el.click();
      })()
    `);
  }

  async fill(value: string): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const els = ${this.nthQueryExpr()};
        const el = els ? els[${this.index}] : null;
        if (!el) throw new Error('Element not found at index ${this.index}');
        el.value = ${JSON.stringify(value)};
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      })()
    `);
  }

  async textContent(): Promise<string | null> {
    return this.page.evaluate(`
      (() => {
        const els = ${this.nthQueryExpr()};
        const el = els ? els[${this.index}] : null;
        return el ? el.textContent : null;
      })()
    `);
  }

  async innerHTML(): Promise<string> {
    return this.page.evaluate(`
      (() => {
        const els = ${this.nthQueryExpr()};
        const el = els ? els[${this.index}] : null;
        return el ? el.innerHTML : '';
      })()
    `);
  }

  async inputValue(): Promise<string> {
    return this.page.evaluate(`
      (() => {
        const els = ${this.nthQueryExpr()};
        const el = els ? els[${this.index}] : null;
        return el ? el.value : '';
      })()
    `);
  }

  async isVisible(): Promise<boolean> {
    return this.page.evaluate(`
      (() => {
        const els = ${this.nthQueryExpr()};
        const el = els ? els[${this.index}] : null;
        if (!el) return false;
        const style = window.getComputedStyle ? window.getComputedStyle(el) : el.style;
        return !el.hidden && style.display !== 'none' && style.visibility !== 'hidden';
      })()
    `);
  }

  async getAttribute(name: string): Promise<string | null> {
    return this.page.evaluate(`
      (() => {
        const els = ${this.nthQueryExpr()};
        const el = els ? els[${this.index}] : null;
        return el ? el.getAttribute('${name}') : null;
      })()
    `);
  }
}

/**
 * Special locator for last element selection
 */
class CraterLastLocator extends CraterLocator {
  constructor(
    page: CraterPage,
    selector: string,
    parentSelector: string | null = null
  ) {
    super(page, selector, parentSelector);
  }

  private lastQueryExpr(): string {
    if (this.parentSelector) {
      return `document.querySelector('${this.parentSelector}')?.querySelectorAll('${this.selector}')`;
    }
    return `document.querySelectorAll('${this.selector}')`;
  }

  async textContent(): Promise<string | null> {
    return this.page.evaluate(`
      (() => {
        const els = ${this.lastQueryExpr()};
        const el = els && els.length > 0 ? els[els.length - 1] : null;
        return el ? el.textContent : null;
      })()
    `);
  }
}

/**
 * Playwright-like adapter for Crater BiDi server
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
  private navigationPromise: Promise<void> | null = null;
  private navigationResolve: (() => void) | null = null;

  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(BIDI_URL);
      this.ws.on("open", async () => {
        // Create a browsing context
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
      // Handle navigation events
      if (msg.method === "browsingContext.load" || msg.method === "browsingContext.domContentLoaded") {
        if (this.navigationResolve) {
          this.navigationResolve();
          this.navigationResolve = null;
          this.navigationPromise = null;
        }
      }
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

  /**
   * Navigate to a URL
   */
  async goto(url: string): Promise<void> {
    if (!this.contextId) throw new Error("No context");

    // Handle data URLs
    let targetUrl = url;
    if (url.startsWith("data:")) {
      targetUrl = url;
    } else if (!url.startsWith("http://") && !url.startsWith("https://")) {
      // Convert HTML string to data URL
      targetUrl = `data:text/html;base64,${Buffer.from(url).toString("base64")}`;
    }

    await this.sendBidi("browsingContext.navigate", {
      context: this.contextId,
      url: targetUrl,
      wait: "complete",
    });
  }

  /**
   * Set HTML content
   */
  async setContent(html: string): Promise<void> {
    const dataUrl = `data:text/html;base64,${Buffer.from(html).toString("base64")}`;
    await this.goto(dataUrl);

    // Load the HTML into the Mock DOM
    await this.sendBidi("script.evaluate", {
      expression: `__loadHTML(${JSON.stringify(html)})`,
      target: { context: this.contextId },
      awaitPromise: false,
    });
  }

  /**
   * Evaluate JavaScript in the page
   */
  async evaluate<T>(expression: string | (() => T), options: { awaitPromise?: boolean } = {}): Promise<T> {
    if (!this.contextId) throw new Error("No context");

    const expr = typeof expression === "function"
      ? `(${expression.toString()})()`
      : expression;

    // Check if expression is async
    const isAsync = options.awaitPromise !== undefined
      ? options.awaitPromise
      : (typeof expression === "function" && expression.constructor.name === "AsyncFunction") ||
        (typeof expression === "string" && (expression.includes("await ") || expression.includes("new Promise")));

    const resp = await this.sendBidi("script.evaluate", {
      expression: expr,
      target: { context: this.contextId },
      awaitPromise: isAsync,
    });

    if (resp.type === "error") {
      throw new Error(resp.message || resp.error);
    }

    const result = resp.result as { result?: { value?: T; type?: string }; exceptionDetails?: unknown };
    if (result.exceptionDetails) {
      throw new Error(JSON.stringify(result.exceptionDetails));
    }
    return result.result?.value as T;
  }

  /**
   * Wait for a selector to appear
   */
  async waitForSelector(selector: string, options: { timeout?: number } = {}): Promise<void> {
    const timeout = options.timeout || 5000;
    const start = Date.now();

    while (Date.now() - start < timeout) {
      const found = await this.evaluate(`document.querySelector('${selector}') !== null`);
      if (found) return;
      await new Promise(r => setTimeout(r, 100));
    }

    throw new Error(`Timeout waiting for selector: ${selector}`);
  }

  /**
   * Click an element
   */
  async click(selector: string): Promise<void> {
    await this.evaluate(`
      const el = document.querySelector('${selector}');
      if (!el) throw new Error('Element not found: ${selector}');
      el.click();
    `);
  }

  /**
   * Fill an input
   */
  async fill(selector: string, value: string): Promise<void> {
    await this.evaluate(`
      const el = document.querySelector('${selector}');
      if (!el) throw new Error('Element not found: ${selector}');
      el.value = ${JSON.stringify(value)};
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    `);
  }

  /**
   * Get text content
   */
  async textContent(selector: string): Promise<string | null> {
    return this.evaluate(`
      const el = document.querySelector('${selector}');
      el ? el.textContent : null;
    `);
  }

  /**
   * Get inner HTML
   */
  async innerHTML(selector: string): Promise<string> {
    return this.evaluate(`
      const el = document.querySelector('${selector}');
      el ? el.innerHTML : '';
    `);
  }

  /**
   * Get input value
   */
  async inputValue(selector: string): Promise<string> {
    return this.evaluate(`
      const el = document.querySelector('${selector}');
      el ? el.value : '';
    `);
  }

  /**
   * Check if element is visible
   */
  async isVisible(selector: string): Promise<boolean> {
    return this.evaluate(`
      (() => {
        const el = document.querySelector('${selector}');
        if (!el) return false;
        const style = window.getComputedStyle ? window.getComputedStyle(el) : el.style;
        return !el.hidden && style.display !== 'none' && style.visibility !== 'hidden';
      })()
    `);
  }

  /**
   * Get attribute value
   */
  async getAttribute(selector: string, name: string): Promise<string | null> {
    return this.evaluate(`
      const el = document.querySelector('${selector}');
      el ? el.getAttribute('${name}') : null;
    `);
  }

  /**
   * Query all elements
   */
  async $$eval<T>(selector: string, fn: (elements: Element[]) => T): Promise<T> {
    const fnStr = fn.toString();
    return this.evaluate(`
      const elements = Array.from(document.querySelectorAll('${selector}'));
      (${fnStr})(elements);
    `);
  }

  /**
   * Create a locator for an element
   */
  locator(selector: string): CraterLocator {
    return new CraterLocator(this, selector);
  }

  /**
   * Get locator by text content
   */
  getByText(text: string, options: { exact?: boolean } = {}): CraterLocator {
    const selector = options.exact ? `text=exact:${text}` : `text=${text}`;
    return new CraterLocator(this, selector);
  }

  /**
   * Get locator by role
   */
  getByRole(role: string, options: { name?: string } = {}): CraterLocator {
    const locator = new CraterLocator(this, `role=${role}`);
    if (options.name) {
      return locator.filter({ hasText: options.name });
    }
    return locator;
  }

  /**
   * Get locator by placeholder
   */
  getByPlaceholder(text: string): CraterLocator {
    return new CraterLocator(this, `placeholder=${text}`);
  }

  /**
   * Get locator by alt text
   */
  getByAltText(text: string): CraterLocator {
    return new CraterLocator(this, `alt=${text}`);
  }

  /**
   * Get locator by title
   */
  getByTitle(text: string): CraterLocator {
    return new CraterLocator(this, `title=${text}`);
  }

  /**
   * Get locator by test ID
   */
  getByTestId(testId: string): CraterLocator {
    return new CraterLocator(this, `testid=${testId}`);
  }

  /**
   * Get locator by label text
   */
  getByLabel(text: string): CraterLocator {
    return new CraterLocator(this, `label=${text}`);
  }

  /**
   * Wait for navigation to complete
   */
  async waitForNavigation(options: { timeout?: number } = {}): Promise<void> {
    const timeout = options.timeout || 10000;

    // Subscribe to navigation events if not already
    await this.sendBidi("session.subscribe", {
      events: ["browsingContext.load", "browsingContext.domContentLoaded"],
      contexts: [this.contextId],
    });

    // Create a promise that resolves when navigation completes
    this.navigationPromise = new Promise<void>((resolve, reject) => {
      this.navigationResolve = resolve;

      setTimeout(() => {
        if (this.navigationResolve) {
          this.navigationResolve = null;
          this.navigationPromise = null;
          reject(new Error("Navigation timeout"));
        }
      }, timeout);
    });

    return this.navigationPromise;
  }

  /**
   * Wait for load state
   */
  async waitForLoadState(
    state: "load" | "domcontentloaded" | "networkidle" | "networkidle0" | "networkidle2" = "load",
    options: { timeout?: number } = {}
  ): Promise<void> {
    const timeout = options.timeout || 30000;

    switch (state) {
      case "networkidle":
      case "networkidle0":
        await this.evaluate(`__waitForNetworkIdle0({ timeout: ${timeout} })`, { awaitPromise: true });
        break;
      case "networkidle2":
        await this.evaluate(`__waitForNetworkIdle2({ timeout: ${timeout} })`, { awaitPromise: true });
        break;
      case "load":
      case "domcontentloaded":
      default:
        // In mock environment, page is always "loaded" after setContent
        await this.evaluate(`document.readyState`);
        break;
    }
  }

  /**
   * Wait for network to be idle (0 inflight requests for 500ms)
   */
  async waitForNetworkIdle(options: { timeout?: number; idleTime?: number; maxInflight?: number } = {}): Promise<void> {
    const timeout = options.timeout || 30000;
    const idleTime = options.idleTime || 500;
    const maxInflight = options.maxInflight ?? 0;
    await this.evaluate(
      `__waitForNetworkIdle({ timeout: ${timeout}, idleTime: ${idleTime}, maxInflight: ${maxInflight} })`,
      { awaitPromise: true }
    );
  }

  /**
   * Close the page
   */
  async close(): Promise<void> {
    if (this.contextId) {
      await this.sendBidi("browsingContext.close", { context: this.contextId });
    }
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

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

    // Set up the click handler
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

    // Query links inside nav
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

    // Fill form
    await page.fill("#username", "testuser");
    await page.fill("#email", "test@example.com");

    // Set up click handler and trigger it
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

    try {
      await page.evaluate(() => {
        throw new Error("Test error");
      });
      expect.fail("Should have thrown");
    } catch (e) {
      expect(String(e)).toContain("Test error");
    }
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

    // Get count of items
    const itemCount = await page.evaluate(`
      document.querySelectorAll(".item").length;
    `);
    expect(itemCount).toBe(2);

    // Get count of labels
    const labelCount = await page.evaluate(`
      document.querySelectorAll(".label").length;
    `);
    expect(labelCount).toBe(2);

    // Get count of values
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

    // Test textContent via locator
    const text = await page.locator("#text").textContent();
    expect(text).toBe("Hello World");

    // Test fill via locator
    await page.locator("#input").fill("Test value");
    const value = await page.locator("#input").inputValue();
    expect(value).toBe("Test value");

    // Test getAttribute via locator
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

    // Chain locators - parent first, then child
    const container = page.locator("#parent");
    const items = container.locator(".item");
    const count = await items.count();
    expect(count).toBe(2);

    // Also test getting text from chained locator
    const firstItem = await items.nth(0).textContent();
    expect(firstItem).toBe("Item 1");
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

    // Get nth element
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

    // Visible element
    const isVisible = await page.locator("#visible").isVisible();
    expect(isVisible).toBe(true);

    // Hidden element (display: none)
    const isHidden = await page.locator("#hidden").isVisible();
    expect(isHidden).toBe(false);

    // Invisible element (visibility: hidden)
    const isInvisible = await page.locator("#invisible").isVisible();
    expect(isInvisible).toBe(false);

    // Non-existent element
    const notExists = await page.locator("#not-exists").isVisible();
    expect(notExists).toBe(false);
  });

  test("waitForLoadState", async () => {
    await page.setContent("<html><body><p>Ready</p></body></html>");

    // Should not throw
    await page.waitForLoadState("load");
    await page.waitForLoadState("domcontentloaded");

    const text = await page.locator("p").textContent();
    expect(text).toBe("Ready");
  });

  test("waitForNetworkIdle with no requests", async () => {
    await page.setContent("<html><body><p>Ready</p></body></html>");

    // With no active requests, should resolve immediately
    await page.waitForNetworkIdle({ idleTime: 100 });

    const text = await page.locator("p").textContent();
    expect(text).toBe("Ready");
  });

  test("waitForLoadState networkidle", async () => {
    await page.setContent("<html><body><p>Ready</p></body></html>");

    // Should not throw - no active requests means immediate idle
    await page.waitForLoadState("networkidle0", { timeout: 5000 });
    await page.waitForLoadState("networkidle2", { timeout: 5000 });

    const text = await page.locator("p").textContent();
    expect(text).toBe("Ready");
  });

  test("network request tracking", async () => {
    await page.setContent("<html><body></body></html>");

    // Check initial state - no active requests
    const initialCount = await page.evaluate(`globalThis.__activeNetworkRequests`);
    expect(initialCount).toBe(0);

    // Verify the tracking functions exist
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

    // Find by partial text
    const button = page.getByText("Click");
    const buttonText = await button.textContent();
    expect(buttonText).toBe("Click me");

    // Find by exact text
    const para = page.getByText("Hello World", { exact: true });
    const paraText = await para.textContent();
    expect(paraText).toBe("Hello World");
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

    // Find by role
    const buttons = page.getByRole("button");
    const count = await buttons.count();
    expect(count).toBe(2);

    // Find by role with name filter
    const submitBtn = page.getByRole("button", { name: "Submit" });
    const submitText = await submitBtn.textContent();
    expect(submitText).toBe("Submit");
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

    // Label with for attribute
    const usernameInput = page.getByLabel("Username");
    await usernameInput.fill("john_doe");
    const usernameValue = await usernameInput.inputValue();
    expect(usernameValue).toBe("john_doe");
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

    // Filter by text
    const submitBtn = page.locator("button").filter({ hasText: "Submit" });
    const submitText = await submitBtn.textContent();
    expect(submitText).toBe("Submit");

    // Filter by not having text
    const nonSubmitBtns = page.locator("button").filter({ hasNotText: "Submit" });
    const count = await nonSubmitBtns.count();
    expect(count).toBe(2);
  });
});
