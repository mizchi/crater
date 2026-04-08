import WebSocket from "ws";
import { resolveBidiUrl } from "../../scripts/bidi-url.ts";

interface BidiResponse {
  id: number;
  type: "success" | "error";
  result?: unknown;
  error?: string;
  message?: string;
}

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

type PendingCommand = {
  resolve: (value: BidiResponse) => void;
  reject: (error: Error) => void;
};

const keyValue = (key: string): string => SPECIAL_KEYS[key] ?? key;

export class CraterBidiPage {
  private ws: WebSocket | null = null;
  private commandId = 0;
  private pendingCommands = new Map<number, PendingCommand>();
  private contextId: string | null = null;

  async connect(options?: { timeout?: number; retries?: number }): Promise<void> {
    const timeout = options?.timeout ?? 15000;
    const retries = options?.retries ?? 2;
    let lastError: Error | undefined;
    for (let attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0) {
        await new Promise(r => setTimeout(r, 1000 * attempt));
      }
      try {
        await this.connectOnce(timeout);
        return;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        this.ws?.close();
        this.ws = null;
      }
    }
    throw lastError ?? new Error("connect failed");
  }

  private async connectOnce(timeout: number): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`BiDi connect timeout after ${timeout}ms`));
      }, timeout);
      void resolveBidiUrl()
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

  async setContentWithScripts(html: string): Promise<void> {
    const dataUrl = `data:text/html;base64,${Buffer.from(html).toString("base64")}`;
    await this.goto(dataUrl);
    await this.evaluate(`__loadHTML(${JSON.stringify(html)})`);
    await this.evaluate(`(async () => await __executeScripts())()`, { awaitPromise: true });
  }

  async goto(url: string): Promise<void> {
    await this.sendBidi("browsingContext.navigate", {
      context: this.requireContextId(),
      url,
      wait: "complete",
    });
  }

  async setViewport(width: number, height: number): Promise<void> {
    await this.sendBidi("browsingContext.setViewport", {
      context: this.requireContextId(),
      viewport: { width, height },
    });
  }

  async evaluate<T>(expression: string, options: { awaitPromise?: boolean } = {}): Promise<T> {
    const resp = await this.sendBidi("script.evaluate", {
      expression,
      target: { context: this.requireContextId() },
      awaitPromise:
        options.awaitPromise ??
        (expression.includes("await ") || expression.includes("new Promise")),
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
      const el = document.querySelector(${JSON.stringify(selector)});
      return !!(el && el.checked);
    })()`);
    if (!checked) {
      await this.click(selector);
    }
  }

  async uncheck(selector: string): Promise<void> {
    const checked = await this.evaluate<boolean>(`(() => {
      const el = document.querySelector(${JSON.stringify(selector)});
      return !!(el && el.checked);
    })()`);
    if (checked) {
      await this.click(selector);
    }
  }

  async select(selector: string, value: string): Promise<void> {
    const rawState = await this.evaluate<string | null>(`(() => {
      const el = document.querySelector(${JSON.stringify(selector)});
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
    return this.evaluate<string | null>(`(() => {
      const el = document.querySelector(${JSON.stringify(selector)});
      return el ? el.textContent : null;
    })()`);
  }

  async count(selector: string): Promise<number> {
    return this.evaluate<number>(`document.querySelectorAll(${JSON.stringify(selector)}).length`);
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
    const timeout = options.timeout ?? 3000;
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
    const timeout = options.timeout ?? 3000;
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

  private async elementSharedId(selector: string): Promise<string> {
    const resp = await this.sendBidi("script.evaluate", {
      expression: `document.querySelector(${JSON.stringify(selector)})`,
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

  private handleMessage(data: string): void {
    const message = JSON.parse(data) as { type?: string; id?: number } & Record<string, unknown>;
    if (message.type === "event") {
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
      const timeoutMs = method === "browsingContext.capturePaintData" ? 120000 : 10000;
      setTimeout(() => {
        if (this.pendingCommands.has(id)) {
          this.pendingCommands.delete(id);
          reject(new Error(`Timeout waiting for response to ${method}`));
        }
      }, timeoutMs);
    });
  }
}
