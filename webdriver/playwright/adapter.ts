import WebSocket from "ws";
import { resolveBidiUrl } from "../../scripts/bidi-url.ts";
export {
  CRATER_PLAYWRIGHT_API_SUPPORT,
  craterPlaywrightApisFor,
} from "./supported-apis.ts";
export type {
  CraterPlaywrightApiEntry,
  CraterPlaywrightApiOwner,
  CraterPlaywrightApiStatus,
} from "./supported-apis.ts";

export interface BidiResponse {
  id: number;
  type: "success" | "error";
  result?: unknown;
  error?: string;
  message?: string;
}

export interface BidiEvent {
  type: "event";
  method: string;
  params: unknown;
}

export type CraterBidiConnectOptions = {
  timeout?: number;
  retries?: number;
  url?: string;
};

export type CraterEvaluateOptions = {
  awaitPromise?: boolean;
};

export type CraterLoadState =
  | "load"
  | "domcontentloaded"
  | "networkidle"
  | "networkidle0"
  | "networkidle2";

export type CraterUrlMatcher = string | RegExp | ((url: URL) => boolean);

export type CraterAddScriptTagOptions = {
  content?: string;
  url?: string;
  type?: string;
};

export type CraterAddStyleTagOptions = {
  content?: string;
  url?: string;
};

export type CraterWaitForFunctionOptions = {
  timeout?: number;
  polling?: number;
};

type PendingCommand = {
  resolve: (value: BidiResponse) => void;
  reject: (error: Error) => void;
};

type ParsedLocatorSelector = {
  type: string;
  value: string;
  exact?: boolean;
};

type TextFilter = {
  kind: "hasText" | "hasNotText";
  value: string;
  flags?: string;
  regexp: boolean;
};

const SPECIAL_KEYS: Record<string, string> = {
  Enter: "\uE006",
  Tab: "\uE004",
  Backspace: "\uE003",
  Delete: "\uE017",
  ArrowLeft: "\uE012",
  ArrowRight: "\uE014",
  ArrowUp: "\uE013",
  ArrowDown: "\uE015",
  Space: " ",
};

const keyValue = (key: string): string => SPECIAL_KEYS[key] ?? key;

const jsString = (value: string): string => JSON.stringify(value);

const jsValue = (value: unknown): string => {
  const serialized = JSON.stringify(value);
  return serialized === undefined ? "undefined" : serialized;
};

const domKeyValue = (key: string): string => key === "Space" ? " " : key;

function isEvaluateOptions(value: unknown): value is CraterEvaluateOptions {
  return !!value && typeof value === "object" && "awaitPromise" in value;
}

export function parseLocatorSelector(selector: string): ParsedLocatorSelector {
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

function allElementsExpr(rootExpr: string): string {
  return `(() => {
    const currentRoot = ${rootExpr};
    const start = currentRoot && currentRoot.nodeType === 9 ? (currentRoot.documentElement || currentRoot.body) : currentRoot;
    const all = [];
    const walk = (node) => {
      if (!node) return;
      if (node.nodeType === 1) all.push(node);
      const children = node._children || node.childNodes || [];
      for (const child of Array.from(children)) walk(child);
    };
    walk(start);
    return all;
  })()`;
}

function attrExpr(rootExpr: string, name: string, value: string, method: "first" | "all"): string {
  const predicate = `(el) => {
    const attr = typeof el.getAttribute === "function" ? el.getAttribute(${jsString(name)}) : (el._attrs && el._attrs[${jsString(name)}]);
    return attr === ${jsString(value)} || (attr && String(attr).includes(${jsString(value)}));
  }`;
  const all = `${allElementsExpr(rootExpr)}.filter(${predicate})`;
  return method === "first" ? `(${all})[0] || null` : all;
}

function buildSelectorExpr(
  parsed: ParsedLocatorSelector,
  method: "first" | "all",
  rootExpr = "document",
): string {
  const value = parsed.value;
  const quoted = jsString(value);
  const allElements = allElementsExpr(rootExpr);

  switch (parsed.type) {
    case "text": {
      const predicate = parsed.exact
        ? `(el) => {
            const children = el._children || el.childNodes || [];
            return Array.from(children).some((node) => node.nodeType === 3 && node.textContent && node.textContent.trim() === ${quoted});
          }`
        : `(el) => {
            const children = el._children || el.childNodes || [];
            const directText = Array.from(children)
              .filter((node) => node.nodeType === 3)
              .map((node) => node.textContent || "")
              .join("");
            return directText.includes(${quoted});
          }`;
      const all = `${allElements}.filter(${predicate})`;
      return method === "first" ? `(${all})[0] || null` : all;
    }
    case "role": {
      const all = `${allElements}.filter((el) => {
        const role = typeof el.getAttribute === "function" ? el.getAttribute("role") : (el._attrs && el._attrs.role);
        return role === ${quoted};
      })`;
      return method === "first" ? `(${all})[0] || null` : all;
    }
    case "placeholder":
      return attrExpr(rootExpr, "placeholder", value, method);
    case "alt":
      return attrExpr(rootExpr, "alt", value, method);
    case "title":
      return attrExpr(rootExpr, "title", value, method);
    case "testid": {
      const selector = jsString(`[data-testid="${value.replace(/"/g, '\\"')}"]`);
      return method === "first"
        ? `(${rootExpr}).querySelector(${selector})`
        : `Array.from((${rootExpr}).querySelectorAll(${selector}))`;
    }
    case "label": {
      const all = `(() => {
        const labels = ${allElements}.filter((el) => String(el.tagName || el.nodeName || "").toLowerCase() === "label");
        return labels.map((label) => {
          if (!label.textContent || !label.textContent.includes(${quoted})) return null;
          const forId = typeof label.getAttribute === "function" ? label.getAttribute("for") : (label._attrs && label._attrs.for);
          if (forId) return document.getElementById(forId);
          return typeof label.querySelector === "function" ? label.querySelector("input, select, textarea") : null;
        }).filter(Boolean);
      })()`;
      return method === "first" ? `(${all})[0] || null` : all;
    }
    case "css":
    default:
      return method === "first"
        ? `(${rootExpr}).querySelector(${quoted})`
        : `Array.from((${rootExpr}).querySelectorAll(${quoted}))`;
  }
}

function normalizeTextFilter(kind: TextFilter["kind"], value: string | RegExp): TextFilter {
  if (value instanceof RegExp) {
    return { kind, value: value.source, flags: value.flags, regexp: true };
  }
  return { kind, value: String(value), regexp: false };
}

function filterPredicateExpr(filter: TextFilter): string {
  const textExpr = `String(el.textContent || "")`;
  const testExpr = filter.regexp
    ? `new RegExp(${jsString(filter.value)}, ${jsString(filter.flags ?? "")}).test(${textExpr})`
    : `${textExpr}.includes(${jsString(filter.value)})`;
  return filter.kind === "hasText" ? testExpr : `!(${testExpr})`;
}

export class CraterLocator {
  private readonly parsed: ParsedLocatorSelector;
  private readonly filters: TextFilter[];
  private readonly rootExpression: string | null;
  private readonly index: number | "last" | null;

  constructor(
    protected page: CraterBidiPage,
    protected selector: string,
    options: {
      rootExpression?: string | null;
      filters?: TextFilter[];
      index?: number | "last" | null;
    } = {},
  ) {
    this.parsed = parseLocatorSelector(selector);
    this.rootExpression = options.rootExpression ?? null;
    this.filters = options.filters ?? [];
    this.index = options.index ?? null;
  }

  filter(options: { hasText?: string | RegExp; hasNotText?: string | RegExp }): CraterLocator {
    const filters = [...this.filters];
    if (options.hasText !== undefined) {
      filters.push(normalizeTextFilter("hasText", options.hasText));
    }
    if (options.hasNotText !== undefined) {
      filters.push(normalizeTextFilter("hasNotText", options.hasNotText));
    }
    return new CraterLocator(this.page, this.selector, {
      rootExpression: this.rootExpression,
      filters,
      index: this.index,
    });
  }

  locator(selector: string): CraterLocator {
    return new CraterLocator(this.page, selector, {
      rootExpression: this.queryExpr("querySelector"),
    });
  }

  getByText(text: string, options: { exact?: boolean } = {}): CraterLocator {
    return this.locator(options.exact ? `text=exact:${text}` : `text=${text}`);
  }

  getByRole(role: string): CraterLocator {
    return this.locator(`role=${role}`);
  }

  first(): CraterLocator {
    return new CraterLocator(this.page, this.selector, {
      rootExpression: this.rootExpression,
      filters: this.filters,
      index: 0,
    });
  }

  last(): CraterLocator {
    return new CraterLocator(this.page, this.selector, {
      rootExpression: this.rootExpression,
      filters: this.filters,
      index: "last",
    });
  }

  nth(index: number): CraterLocator {
    return new CraterLocator(this.page, this.selector, {
      rootExpression: this.rootExpression,
      filters: this.filters,
      index,
    });
  }

  async click(): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        el.click();
      })()
    `);
  }

  async hover(): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        el.dispatchEvent(new Event("pointerenter", { bubbles: false }));
        el.dispatchEvent(new Event("mouseover", { bubbles: true }));
      })()
    `);
  }

  async focus(): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        if (typeof el.focus === "function") {
          el.focus();
        }
        el.dispatchEvent(new Event("focus", { bubbles: false }));
        el.dispatchEvent(new Event("focusin", { bubbles: true }));
      })()
    `);
  }

  async fill(value: string): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        el.value = ${jsString(value)};
        el.dispatchEvent(new Event("input", { bubbles: true }));
        el.dispatchEvent(new Event("change", { bubbles: true }));
      })()
    `);
  }

  async clear(): Promise<void> {
    await this.fill("");
  }

  async type(text: string): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        const current = String(el.value ?? "");
        el.value = current + ${jsString(text)};
        el.dispatchEvent(new Event("input", { bubbles: true }));
      })()
    `);
  }

  async press(key: string): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        const key = ${jsString(domKeyValue(key))};
        const makeKeyEvent = (type) => {
          const event = typeof KeyboardEvent === "function"
            ? new KeyboardEvent(type, { key, bubbles: true })
            : new Event(type, { bubbles: true });
          if (event.key !== key) {
            Object.defineProperty(event, "key", { value: key });
          }
          return event;
        };
        el.dispatchEvent(makeKeyEvent("keydown"));
        if (key === "Backspace" && typeof el.value === "string") {
          el.value = el.value.slice(0, -1);
          el.dispatchEvent(new Event("input", { bubbles: true }));
        } else if (key.length === 1 && typeof el.value === "string") {
          el.value += key;
          el.dispatchEvent(new Event("input", { bubbles: true }));
        }
        el.dispatchEvent(makeKeyEvent("keyup"));
      })()
    `);
  }

  async dispatchEvent(type: string, eventInit: Record<string, unknown> = {}): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        const init = ${JSON.stringify(eventInit)};
        const hasDetail = Object.prototype.hasOwnProperty.call(init, "detail");
        const event = hasDetail && typeof CustomEvent === "function"
          ? new CustomEvent(${jsString(type)}, { bubbles: true, cancelable: true, ...init })
          : new Event(${jsString(type)}, { bubbles: true, cancelable: true, ...init });
        if (hasDetail && event.detail !== init.detail) {
          Object.defineProperty(event, "detail", { value: init.detail });
        }
        el.dispatchEvent(event);
      })()
    `);
  }

  async check(): Promise<void> {
    await this.setChecked(true);
  }

  async uncheck(): Promise<void> {
    await this.setChecked(false);
  }

  async selectOption(value: string): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        const options = Array.from(el.options || el.children || el._children || []).filter((option) => {
          const tag = String(option?.tagName || option?.nodeName || "").toLowerCase();
          return tag === "option";
        });
        const targetIndex = options.findIndex((option) => {
          const optionValue = String(option.value ?? option.getAttribute?.("value") ?? option.textContent ?? "");
          return optionValue === ${jsString(value)};
        });
        if (targetIndex < 0) throw new Error(${jsString(`Option not found: ${value}`)});
        for (let i = 0; i < options.length; i += 1) {
          options[i].selected = i === targetIndex;
        }
        el.selectedIndex = targetIndex;
        el.value = ${jsString(value)};
        el.dispatchEvent(new Event("input", { bubbles: true }));
        el.dispatchEvent(new Event("change", { bubbles: true }));
      })()
    `);
  }

  async evaluate<T, Arg = unknown>(
    fn: (element: Element, arg: Arg) => T | Promise<T>,
    arg?: Arg,
  ): Promise<T> {
    const fnStr = fn.toString();
    const argExpr = arguments.length >= 2 ? `, ${jsValue(arg)}` : "";
    return this.page.evaluate(
      `(() => {
        const element = ${this.queryExpr("querySelector")};
        if (!element) throw new Error("Element not found: ${this.selectorForError()}");
        return (${fnStr})(element${argExpr});
      })()`,
      { awaitPromise: fn.constructor.name === "AsyncFunction" },
    );
  }

  async evaluateAll<T, Arg = unknown>(
    fn: (elements: Element[], arg: Arg) => T | Promise<T>,
    arg?: Arg,
  ): Promise<T> {
    const fnStr = fn.toString();
    const argExpr = arguments.length >= 2 ? `, ${jsValue(arg)}` : "";
    return this.page.evaluate(
      `(() => {
        const elements = ${this.queryExpr("querySelectorAll")};
        return (${fnStr})(elements${argExpr});
      })()`,
      { awaitPromise: fn.constructor.name === "AsyncFunction" },
    );
  }

  async allTextContents(): Promise<string[]> {
    const json = await this.page.evaluate<string>(
      `JSON.stringify((${this.queryExpr("querySelectorAll")}).map((el) => String(el.textContent || "")))`,
    );
    return JSON.parse(json) as string[];
  }

  async allInnerTexts(): Promise<string[]> {
    const json = await this.page.evaluate<string>(
      `JSON.stringify((${this.queryExpr("querySelectorAll")}).map((el) => String(el.innerText ?? el.textContent ?? "")))`,
    );
    return JSON.parse(json) as string[];
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
        return el ? el.innerHTML : "";
      })()
    `);
  }

  async inputValue(): Promise<string> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.value : "";
      })()
    `);
  }

  async isVisible(): Promise<boolean> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) return false;
        const style = window.getComputedStyle ? window.getComputedStyle(el) : el.style;
        return !el.hidden && style.display !== "none" && style.visibility !== "hidden";
      })()
    `);
  }

  async isHidden(): Promise<boolean> {
    return !(await this.isVisible());
  }

  async isChecked(): Promise<boolean> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return !!(el && el.checked);
      })()
    `);
  }

  async isDisabled(): Promise<boolean> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return !!(el && (el.disabled || (typeof el.hasAttribute === "function" && el.hasAttribute("disabled"))));
      })()
    `);
  }

  async isEnabled(): Promise<boolean> {
    return !(await this.isDisabled());
  }

  async isEditable(): Promise<boolean> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) return false;
        const tag = String(el.tagName || el.nodeName || "").toLowerCase();
        const editableTag = tag === "input" || tag === "textarea";
        const contentEditable = String(el.contentEditable || "").toLowerCase() === "true";
        const disabled = !!(el.disabled || (typeof el.hasAttribute === "function" && el.hasAttribute("disabled")));
        const readonly = !!(el.readOnly || (typeof el.hasAttribute === "function" && el.hasAttribute("readonly")));
        return (editableTag || contentEditable) && !disabled && !readonly;
      })()
    `);
  }

  async getAttribute(name: string): Promise<string | null> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.getAttribute(${jsString(name)}) : null;
      })()
    `);
  }

  async waitFor(options: { timeout?: number } = {}): Promise<void> {
    const timeout = this.page.timeoutOrDefault(options.timeout, 5000);
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const found = await this.page.evaluate<boolean>(`${this.queryExpr("querySelector")} !== null`);
      if (found) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    throw new Error(`Timeout waiting for selector: ${this.selector}`);
  }

  async count(): Promise<number> {
    return this.page.evaluate(`
      (() => {
        const els = ${this.queryExpr("querySelectorAll")};
        return els ? els.length : 0;
      })()
    `);
  }

  private async setChecked(checked: boolean): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        if (el.checked === ${checked}) return;
        if (${checked} && String(el.type || "").toLowerCase() === "radio" && el.name) {
          const inputs = Array.from(document.querySelectorAll("input"));
          for (const input of inputs) {
            if (input !== el && String(input.type || "").toLowerCase() === "radio" && input.name === el.name) {
              input.checked = false;
            }
          }
        }
        el.checked = ${checked};
        el.dispatchEvent(new Event("input", { bubbles: true }));
        el.dispatchEvent(new Event("change", { bubbles: true }));
      })()
    `);
  }

  protected queryExpr(method: "querySelector" | "querySelectorAll"): string {
    const allExpr = this.filteredAllQueryExpr();
    if (method === "querySelectorAll") {
      return allExpr;
    }
    if (this.index === "last") {
      return `(() => {
        const els = ${allExpr};
        return els.length > 0 ? els[els.length - 1] : null;
      })()`;
    }
    const index = this.index ?? 0;
    return `(() => {
      const els = ${allExpr};
      return els[${index}] || null;
    })()`;
  }

  private filteredAllQueryExpr(): string {
    const rootExpr = this.rootExpression
      ? `(() => {
          const root = ${this.rootExpression};
          if (!root) return [];
          return ${buildSelectorExpr(this.parsed, "all", "root")};
        })()`
      : buildSelectorExpr(this.parsed, "all");
    if (this.filters.length === 0) {
      return rootExpr;
    }
    const predicate = this.filters.map(filterPredicateExpr).join(" && ");
    return `(${rootExpr}).filter((el) => ${predicate})`;
  }

  private selectorForError(): string {
    return this.selector.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  }
}

export class CraterBidiPage {
  private ws: WebSocket | null = null;
  private commandId = 0;
  private pendingCommands = new Map<number, PendingCommand>();
  private eventHandlers: ((event: BidiEvent) => void)[] = [];
  private contextId: string | null = null;
  private navigationPromise: Promise<void> | null = null;
  private navigationResolve: (() => void) | null = null;
  private initScripts: string[] = [];
  private defaultTimeout: number | null = null;

  async connect(options: CraterBidiConnectOptions = {}): Promise<void> {
    const timeout = options.timeout ?? 15000;
    const retries = options.retries ?? 2;
    let lastError: Error | undefined;
    for (let attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0) {
        await new Promise((resolve) => setTimeout(resolve, 1000 * attempt));
      }
      try {
        await this.connectOnce(timeout, options.url);
        return;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        this.ws?.close();
        this.ws = null;
      }
    }
    throw lastError ?? new Error("connect failed");
  }

  onEvent(handler: (event: BidiEvent) => void): void {
    this.eventHandlers.push(handler);
  }

  async close(): Promise<void> {
    if (this.contextId) {
      try {
        await this.sendBidi("browsingContext.close", { context: this.contextId });
      } catch {
        // Best-effort close for long-running VRT cases; the socket is closed below regardless.
      }
    }
    this.contextId = null;
    this.ws?.close();
    this.ws = null;
  }

  async goto(url: string): Promise<void> {
    const targetUrl = url.startsWith("http://") || url.startsWith("https://") || url.startsWith("data:")
      ? url
      : `data:text/html;base64,${Buffer.from(url).toString("base64")}`;
    await this.sendBidi("browsingContext.navigate", {
      context: this.requireContextId(),
      url: targetUrl,
      wait: "complete",
    });
  }

  async setContent(html: string): Promise<void> {
    const dataUrl = `data:text/html;base64,${Buffer.from(html).toString("base64")}`;
    await this.goto(dataUrl);
    await this.evaluate(`__loadHTML(${jsString(html)})`);
    await this.runInitScripts();
  }

  async setContentWithScripts(html: string): Promise<void> {
    await this.setContent(html);
    await this.evaluate(`(async () => await __executeScripts())()`, { awaitPromise: true });
  }

  async loadPage(
    url: string,
    options: { executeScripts?: boolean } = {},
  ): Promise<{ url: string; status: number; scripts?: unknown[] }> {
    const executeScripts = options.executeScripts !== false;
    const json = await this.evaluate<string>(
      `(async () => JSON.stringify(await __loadPageWithScripts(${jsString(url)}, { executeScripts: false })))()`,
      { awaitPromise: true },
    );
    await this.runInitScripts();
    const result = JSON.parse(json) as { url: string; status: number; scripts?: unknown[] };
    if (executeScripts) {
      const scriptsJson = await this.evaluate<string>(
        `(async () => JSON.stringify(await __executeScripts({ baseUrl: ${jsString(url)} })))()`,
        { awaitPromise: true },
      );
      result.scripts = JSON.parse(scriptsJson) as unknown[];
    }
    return result;
  }

  async addInitScript(script: string | (() => unknown | Promise<unknown>)): Promise<void> {
    this.initScripts.push(this.scriptSource(script));
  }

  async addScriptTag(options: CraterAddScriptTagOptions): Promise<CraterLocator> {
    const content = await this.resolveInjectableContent(options, "script");
    await this.evaluate(
      `(async () => {
        const script = document.createElement("script");
        if (${jsString(options.type ?? "")}) script.setAttribute("type", ${jsString(options.type ?? "")});
        if (${jsString(options.url ?? "")}) script.setAttribute("src", ${jsString(options.url ?? "")});
        script.textContent = ${jsString(content)};
        (document.head || document.querySelector("head") || document.body || document.documentElement).appendChild(script);
        (0, eval)(${jsString(content)});
      })()`,
      { awaitPromise: true },
    );
    return this.locator("script").last();
  }

  async addStyleTag(options: CraterAddStyleTagOptions): Promise<CraterLocator> {
    const content = await this.resolveInjectableContent(options, "style");
    await this.evaluate(`
      (() => {
        const style = document.createElement("style");
        if (${jsString(options.url ?? "")}) style.setAttribute("data-crater-source", ${jsString(options.url ?? "")});
        style.textContent = ${jsString(content)};
        (document.head || document.querySelector("head") || document.body || document.documentElement).appendChild(style);
      })()
    `);
    return this.locator("style").last();
  }

  async url(): Promise<string> {
    return this.evaluate<string>("window.location.href");
  }

  async title(): Promise<string> {
    return this.evaluate<string>(
      "document.title || document.querySelector('title')?.textContent || ''",
    );
  }

  async content(): Promise<string> {
    return this.evaluate<string>(`
      (() => {
        const html = document.documentElement;
        if (!html) return "";
        if (typeof html.outerHTML === "string") return html.outerHTML;
        const head = document.querySelector("head");
        const body = document.body || document.querySelector("body");
        const headHtml = head ? "<head>" + head.innerHTML + "</head>" : "";
        const bodyHtml = body ? "<body>" + body.innerHTML + "</body>" : "";
        return "<html>" + headHtml + bodyHtml + "</html>";
      })()
    `);
  }

  async setViewport(width: number, height: number): Promise<void> {
    await this.sendBidi("browsingContext.setViewport", {
      context: this.requireContextId(),
      viewport: { width, height },
    });
  }

  setDefaultTimeout(timeout: number): void {
    if (!Number.isFinite(timeout) || timeout < 0) {
      throw new Error(`Invalid timeout: ${timeout}`);
    }
    this.defaultTimeout = timeout;
  }

  async evaluate<T, Arg = unknown>(
    expression: string | ((arg: Arg) => T | Promise<T>),
    argOrOptions?: Arg | CraterEvaluateOptions,
    options: CraterEvaluateOptions = {},
  ): Promise<T> {
    const hasFunctionArg = typeof expression === "function" && arguments.length >= 2;
    const expr = typeof expression === "function"
      ? `(${expression.toString()})(${hasFunctionArg ? jsValue(argOrOptions) : ""})`
      : expression;
    const evaluateOptions = typeof expression === "function"
      ? options
      : isEvaluateOptions(argOrOptions) ? argOrOptions : {};
    const isAsync = options.awaitPromise ?? (
      typeof expression === "function"
        ? expression.constructor.name === "AsyncFunction"
        : expr.includes("await ") || expr.includes("new Promise") || expr.includes(".then(")
    );
    const resp = await this.sendBidi("script.evaluate", {
      expression: expr,
      target: { context: this.requireContextId() },
      awaitPromise: evaluateOptions.awaitPromise ?? isAsync,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "script.evaluate failed");
    }
    const result = resp.result as { result?: { value?: T }; exceptionDetails?: unknown };
    if (result.exceptionDetails) {
      throw new Error(JSON.stringify(result.exceptionDetails));
    }
    return result.result?.value as T;
  }

  async waitForSelector(selector: string, options: { timeout?: number } = {}): Promise<void> {
    await this.locator(selector).waitFor(options);
  }

  async waitForTimeout(timeout: number): Promise<void> {
    await new Promise((resolve) => setTimeout(resolve, timeout));
  }

  async waitForFunction<T>(
    pageFunction: string | (() => T | Promise<T>),
    options: CraterWaitForFunctionOptions = {},
  ): Promise<T> {
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const polling = options.polling ?? 30;
    const expression = this.waitForFunctionExpression(pageFunction);
    const start = Date.now();
    let lastError: Error | null = null;
    while (Date.now() - start < timeout) {
      try {
        const value = await this.evaluate<T>(
          `(async () => await ${expression})()`,
          { awaitPromise: true },
        );
        if (value) {
          return value;
        }
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
      }
      await this.waitForTimeout(polling);
    }
    const suffix = lastError ? ` Last error: ${lastError.message}` : "";
    throw new Error(`Timeout waiting for function.${suffix}`);
  }

  async click(selector: string): Promise<void> {
    const sharedId = await this.elementSharedId(selector);
    await this.performPointer([
      {
        type: "pointerMove",
        origin: { type: "element", element: { sharedId } },
        x: 0,
        y: 0,
      },
      { type: "pointerDown", button: 0 },
      { type: "pointerUp", button: 0 },
    ]);
  }

  async hover(selector: string): Promise<void> {
    const sharedId = await this.elementSharedId(selector);
    await this.performPointer([
      {
        type: "pointerMove",
        origin: { type: "element", element: { sharedId } },
        x: 0,
        y: 0,
      },
    ]);
  }

  async fill(selector: string, value: string): Promise<void> {
    await this.locator(selector).fill(value);
  }

  async type(selector: string, text: string): Promise<void> {
    await this.click(selector);
    const actions = [...text].flatMap((char) => {
      const value = keyValue(char);
      return [
        { type: "keyDown", value },
        { type: "keyUp", value },
      ];
    });
    await this.performKey(actions);
  }

  async press(key: string): Promise<void> {
    const value = keyValue(key);
    await this.performKey([
      { type: "keyDown", value },
      { type: "keyUp", value },
    ]);
  }

  async check(selector: string): Promise<void> {
    const checked = await this.evaluate<boolean>(`(() => {
      const el = document.querySelector(${jsString(selector)});
      return !!(el && el.checked);
    })()`);
    if (!checked) {
      await this.click(selector);
    }
  }

  async uncheck(selector: string): Promise<void> {
    const checked = await this.evaluate<boolean>(`(() => {
      const el = document.querySelector(${jsString(selector)});
      return !!(el && el.checked);
    })()`);
    if (checked) {
      await this.click(selector);
    }
  }

  async select(selector: string, value: string): Promise<void> {
    const rawState = await this.evaluate<string | null>(`(() => {
      const el = document.querySelector(${jsString(selector)});
      if (!el) return null;
      const options = Array.from(el.options || el.children || el._children || []).filter((option) => {
        const tag = String(option?.tagName || option?.nodeName || "").toLowerCase();
        return tag === "option";
      });
      return JSON.stringify({
        selectedIndex: typeof el.selectedIndex === "number" ? el.selectedIndex : -1,
        values: options.map((option) =>
          String(option.value ?? option.getAttribute?.("value") ?? option.textContent ?? ""),
        ),
      });
    })()`);
    if (!rawState) {
      throw new Error(`Element not found: ${selector}`);
    }
    const state = JSON.parse(rawState) as { selectedIndex: number; values: string[] };
    const targetIndex = state.values.indexOf(value);
    if (targetIndex < 0) {
      throw new Error(`Option not found: ${value}`);
    }
    if (state.selectedIndex === targetIndex) {
      return;
    }
    await this.click(selector);
    const delta = targetIndex - state.selectedIndex;
    const key = delta >= 0 ? "ArrowDown" : "ArrowUp";
    const steps = Math.abs(delta);
    const actions = Array.from({ length: steps }, () => [
      { type: "keyDown", value: keyValue(key) },
      { type: "keyUp", value: keyValue(key) },
    ]).flat();
    await this.performKey(actions);
  }

  async textContent(selector: string): Promise<string | null> {
    return this.locator(selector).textContent();
  }

  async innerHTML(selector: string): Promise<string> {
    return this.locator(selector).innerHTML();
  }

  async inputValue(selector: string): Promise<string> {
    return this.locator(selector).inputValue();
  }

  async isVisible(selector: string): Promise<boolean> {
    return this.locator(selector).isVisible();
  }

  async getAttribute(selector: string, name: string): Promise<string | null> {
    return this.locator(selector).getAttribute(name);
  }

  async count(selector: string): Promise<number> {
    return this.locator(selector).count();
  }

  async $(selector: string): Promise<CraterLocator | null> {
    const count = await this.count(selector);
    return count > 0 ? this.locator(selector) : null;
  }

  async $$(selector: string): Promise<CraterLocator[]> {
    const count = await this.count(selector);
    const locator = this.locator(selector);
    return Array.from({ length: count }, (_, index) => locator.nth(index));
  }

  async $eval<T>(selector: string, fn: (element: Element) => T | Promise<T>): Promise<T> {
    return this.locator(selector).evaluate(fn);
  }

  async $$eval<T>(selector: string, fn: (elements: Element[]) => T): Promise<T> {
    const fnStr = fn.toString();
    return this.evaluate(`
      (() => {
        const elements = Array.from(document.querySelectorAll(${jsString(selector)}));
        return (${fnStr})(elements);
      })()
    `);
  }

  locator(selector: string): CraterLocator {
    return new CraterLocator(this, selector);
  }

  getByText(text: string, options: { exact?: boolean } = {}): CraterLocator {
    return this.locator(options.exact ? `text=exact:${text}` : `text=${text}`);
  }

  getByRole(role: string, options: { name?: string | RegExp } = {}): CraterLocator {
    const locator = this.locator(`role=${role}`);
    if (options.name !== undefined) {
      return locator.filter({ hasText: options.name });
    }
    return locator;
  }

  getByPlaceholder(text: string): CraterLocator {
    return this.locator(`placeholder=${text}`);
  }

  getByAltText(text: string): CraterLocator {
    return this.locator(`alt=${text}`);
  }

  getByTitle(text: string): CraterLocator {
    return this.locator(`title=${text}`);
  }

  getByTestId(testId: string): CraterLocator {
    return this.locator(`testid=${testId}`);
  }

  getByLabel(text: string): CraterLocator {
    return this.locator(`label=${text}`);
  }

  async selectOption(selector: string, value: string): Promise<void> {
    await this.locator(selector).selectOption(value);
  }

  async screenshot(): Promise<Buffer> {
    return this.captureScreenshot();
  }

  async drag(sourceSelector: string, targetSelector: string): Promise<void> {
    const sourceSharedId = await this.elementSharedId(sourceSelector);
    const targetSharedId = await this.elementSharedId(targetSelector);
    await this.performPointer([
      {
        type: "pointerMove",
        origin: { type: "element", element: { sharedId: sourceSharedId } },
        x: 0,
        y: 0,
      },
      { type: "pointerDown", button: 0 },
      {
        type: "pointerMove",
        origin: { type: "element", element: { sharedId: targetSharedId } },
        x: 0,
        y: 0,
      },
      { type: "pointerUp", button: 0 },
    ]);
  }

  async waitForText(selector: string, expected: string, options: { timeout?: number } = {}): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const text = await this.textContent(selector);
      if (text === expected) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    throw new Error(`Timeout waiting for ${selector} to become ${expected}`);
  }

  async waitForCondition(expression: string, options: { timeout?: number } = {}): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const ok = await this.evaluate<boolean>(expression);
      if (ok) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    throw new Error(`Timeout waiting for condition: ${expression}`);
  }

  async waitForURL(expected: CraterUrlMatcher, options: { timeout?: number } = {}): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const current = await this.url();
      if (this.urlMatches(current, expected)) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    throw new Error(`Timeout waiting for URL: ${String(expected)}`);
  }

  async waitForNavigation(options: { timeout?: number } = {}): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 10000);
    await this.sendBidi("session.subscribe", {
      events: ["browsingContext.load", "browsingContext.domContentLoaded"],
      contexts: [this.requireContextId()],
    });
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

  async waitForLoadState(
    state: CraterLoadState = "load",
    options: { timeout?: number } = {},
  ): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 30000);
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
        await this.evaluate("document.readyState");
        break;
    }
  }

  async waitForNetworkIdle(
    options: { timeout?: number; idleTime?: number; maxInflight?: number } = {},
  ): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 30000);
    const idleTime = options.idleTime ?? 500;
    const maxInflight = options.maxInflight ?? 0;
    await this.evaluate(
      `__waitForNetworkIdle({ timeout: ${timeout}, idleTime: ${idleTime}, maxInflight: ${maxInflight} })`,
      { awaitPromise: true },
    );
  }

  async captureScreenshot(): Promise<Buffer> {
    const resp = await this.sendBidi("browsingContext.captureScreenshotData", {
      context: this.requireContextId(),
      origin: "viewport",
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "captureScreenshotData failed");
    }
    return Buffer.from(String(resp.result || ""), "base64");
  }

  async capturePaintData(): Promise<{ width: number; height: number; data: Uint8Array }> {
    const resp = await this.sendBidi("browsingContext.capturePaintData", {
      context: this.requireContextId(),
      origin: "viewport",
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "capturePaintData failed");
    }
    const result = resp.result as { width?: number; height?: number; data?: string };
    const width = Number(result.width ?? 0);
    const height = Number(result.height ?? 0);
    const data = Buffer.from(String(result.data || ""), "base64");
    return {
      width,
      height,
      data: Uint8Array.from(data),
    };
  }

  async capturePaintTree(): Promise<{ width: number; height: number; paintTree: string }> {
    const resp = await this.sendBidi("browsingContext.capturePaintTree", {
      context: this.requireContextId(),
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "capturePaintTree failed");
    }
    const result = resp.result as { width?: number; height?: number; paintTree?: string };
    return {
      width: Number(result.width ?? 0),
      height: Number(result.height ?? 0),
      paintTree: String(result.paintTree || "{}"),
    };
  }

  async getComputedStyles(selector: string, properties: string[]): Promise<Record<string, string>> {
    return this.requestComputedStyles({ selector, properties });
  }

  async getComputedStylesBySharedId(
    sharedId: string,
    properties: string[],
  ): Promise<Record<string, string>> {
    return this.requestComputedStyles({ sharedId, properties });
  }

  async getAllComputedStyles(properties: string[]): Promise<Record<string, Record<string, string>>> {
    const resp = await this.sendBidi("browsingContext.getAllComputedStyles", {
      context: this.requireContextId(),
      properties,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "getAllComputedStyles failed");
    }
    const result = resp.result as {
      styles?: Record<string, Record<string, string>>;
    };
    return result.styles ?? {};
  }

  async getComputedStylesForElement(
    selector: string,
    properties: string[],
  ): Promise<Record<string, string>> {
    const sharedId = await this.elementSharedId(selector);
    return this.getComputedStylesBySharedId(sharedId, properties);
  }

  async getCssRuleUsage(): Promise<
    Array<{
      selector: string;
      matched: boolean;
      elements: number;
      overridden: boolean;
      overriddenBy?: string;
    }>
  > {
    const resp = await this.sendBidi("browsingContext.getCssRuleUsage", {
      context: this.requireContextId(),
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "getCssRuleUsage failed");
    }
    const result = resp.result as {
      rules?: Array<{
        selector?: string;
        matched?: boolean;
        elements?: number;
        overridden?: boolean;
        overriddenBy?: string;
      }>;
    };
    return (result.rules ?? []).map((rule) => ({
      selector: String(rule.selector ?? ""),
      matched: Boolean(rule.matched),
      elements: Number(rule.elements ?? 0),
      overridden: Boolean(rule.overridden),
      ...(rule.overriddenBy ? { overriddenBy: String(rule.overriddenBy) } : {}),
    }));
  }

  async getCssRuleUsageDetails(): Promise<{
    rules: Array<{
      selector: string;
      matched: boolean;
      elements: number;
      overridden: boolean;
      overriddenBy?: string;
      noEffect?: boolean;
      noEffectReason?: string;
    }>;
    elements: Record<string, Record<string, string>>;
  }> {
    const resp = await this.sendBidi("browsingContext.getCssRuleUsage", {
      context: this.requireContextId(),
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "getCssRuleUsage failed");
    }
    const result = resp.result as {
      rules?: Array<{
        selector?: string;
        matched?: boolean;
        elements?: number;
        overridden?: boolean;
        overriddenBy?: string;
        noEffect?: boolean;
        noEffectReason?: string;
      }>;
      elements?: Record<string, Record<string, string>>;
    };
    return {
      rules: (result.rules ?? []) as Array<{
        selector: string;
        matched: boolean;
        elements: number;
        overridden: boolean;
        overriddenBy?: string;
        noEffect?: boolean;
        noEffectReason?: string;
      }>,
      elements: result.elements ?? {},
    };
  }

  private async connectOnce(timeout: number, url?: string): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`BiDi connect timeout after ${timeout}ms`));
      }, timeout);
      void (url ? Promise.resolve(url) : resolveBidiUrl())
        .then((bidiUrl) => {
          this.ws = new WebSocket(bidiUrl);
          this.ws.on("open", async () => {
            try {
              const resp = await this.sendBidi("browsingContext.create", { type: "tab" });
              this.contextId = (resp.result as { context: string }).context;
              clearTimeout(timer);
              resolve();
            } catch (error) {
              clearTimeout(timer);
              reject(error);
            }
          });
          this.ws.on("error", (error) => {
            clearTimeout(timer);
            reject(error);
          });
          this.ws.on("message", (data) => this.handleMessage(data.toString()));
        })
        .catch((error) => {
          clearTimeout(timer);
          reject(error);
        });
    });
  }

  private async requestComputedStyles(params: Record<string, unknown>): Promise<Record<string, string>> {
    const resp = await this.sendBidi("browsingContext.getComputedStyles", {
      context: this.requireContextId(),
      ...params,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "getComputedStyles failed");
    }
    const result = resp.result as { styles?: Record<string, string> };
    return result.styles ?? {};
  }

  private async elementSharedId(selector: string): Promise<string> {
    const resp = await this.sendBidi("script.evaluate", {
      expression: `document.querySelector(${jsString(selector)})`,
      target: { context: this.requireContextId() },
      awaitPromise: false,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || `Failed to resolve ${selector}`);
    }
    const result = resp.result as {
      result?: { type?: string; sharedId?: string; value?: unknown };
    };
    const sharedId = result.result?.sharedId;
    if (!sharedId) {
      throw new Error(`Element not found: ${selector}`);
    }
    return sharedId;
  }

  private async performPointer(actions: Array<Record<string, unknown>>): Promise<void> {
    await this.sendBidi("input.performActions", {
      context: this.requireContextId(),
      actions: [
        {
          type: "pointer",
          id: "mouse-0",
          parameters: { pointerType: "mouse" },
          actions,
        },
      ],
    });
  }

  private async performKey(actions: Array<Record<string, string>>): Promise<void> {
    await this.sendBidi("input.performActions", {
      context: this.requireContextId(),
      actions: [
        {
          type: "key",
          id: "keyboard-0",
          actions,
        },
      ],
    });
  }

  private requireContextId(): string {
    if (!this.contextId) {
      throw new Error("No browsing context");
    }
    return this.contextId;
  }

  private scriptSource(script: string | (() => unknown | Promise<unknown>)): string {
    return typeof script === "function" ? `(${script.toString()})()` : script;
  }

  timeoutOrDefault(timeout: number | undefined, fallback: number): number {
    return timeout ?? this.defaultTimeout ?? fallback;
  }

  private waitForFunctionExpression<T>(pageFunction: string | (() => T | Promise<T>)): string {
    return typeof pageFunction === "function"
      ? `(${pageFunction.toString()})()`
      : `(${pageFunction})`;
  }

  private async runInitScripts(): Promise<void> {
    for (const script of this.initScripts) {
      await this.evaluate(script, {
        awaitPromise: script.includes("await ") || script.includes("new Promise") || script.includes(".then("),
      });
    }
  }

  private async resolveInjectableContent(
    options: CraterAddScriptTagOptions | CraterAddStyleTagOptions,
    kind: "script" | "style",
  ): Promise<string> {
    if (options.content !== undefined) {
      return options.content;
    }
    if (options.url) {
      return this.evaluate<string>(
        `(async () => await (await fetch(${jsString(options.url!)})).text())()`,
        { awaitPromise: true },
      );
    }
    throw new Error(`add${kind === "script" ? "Script" : "Style"}Tag requires content or url`);
  }

  private urlMatches(current: string, expected: CraterUrlMatcher): boolean {
    if (typeof expected === "string") {
      return current === expected || current.includes(expected);
    }
    if (expected instanceof RegExp) {
      return expected.test(current);
    }
    return expected(new URL(current));
  }

  private handleMessage(data: string): void {
    const message = JSON.parse(data) as { type?: string; id?: number; method?: string } & Record<string, unknown>;
    if (message.type === "event") {
      if (message.method === "browsingContext.load" || message.method === "browsingContext.domContentLoaded") {
        if (this.navigationResolve) {
          this.navigationResolve();
          this.navigationResolve = null;
          this.navigationPromise = null;
        }
      }
      for (const handler of this.eventHandlers) {
        handler(message as unknown as BidiEvent);
      }
      return;
    }
    const pending = typeof message.id === "number" ? this.pendingCommands.get(message.id) : null;
    if (!pending) {
      return;
    }
    this.pendingCommands.delete(message.id as number);
    pending.resolve(message as unknown as BidiResponse);
  }

  private async sendBidi(method: string, params: unknown): Promise<BidiResponse> {
    if (!this.ws) {
      throw new Error("Not connected");
    }
    const id = ++this.commandId;
    const payload = JSON.stringify({ id, method, params });
    return await new Promise<BidiResponse>((resolve, reject) => {
      this.pendingCommands.set(id, { resolve, reject });
      this.ws!.send(payload);
      const timeoutMs = method === "browsingContext.capturePaintData" ? 300000 : 10000;
      setTimeout(() => {
        if (this.pendingCommands.has(id)) {
          this.pendingCommands.delete(id);
          reject(new Error(`Timeout waiting for response to ${method}`));
        }
      }, timeoutMs);
    });
  }
}
