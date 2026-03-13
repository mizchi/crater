import WebSocket from "ws";

const BIDI_URL = "ws://127.0.0.1:9222";

interface BidiResponse {
  id: number;
  type: "success" | "error";
  result?: unknown;
  error?: string;
  message?: string;
}

type PendingCommand = {
  resolve: (value: BidiResponse) => void;
  reject: (error: Error) => void;
};

export class CraterBidiPage {
  private ws: WebSocket | null = null;
  private commandId = 0;
  private pendingCommands = new Map<number, PendingCommand>();
  private contextId: string | null = null;

  async connect(): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      this.ws = new WebSocket(BIDI_URL);
      this.ws.on("open", async () => {
        try {
          const resp = await this.sendBidi("browsingContext.create", { type: "tab" });
          this.contextId = (resp.result as { context: string }).context;
          resolve();
        } catch (error) {
          reject(error);
        }
      });
      this.ws.on("error", (error) => reject(error));
      this.ws.on("message", (data) => this.handleMessage(data.toString()));
    });
  }

  async close(): Promise<void> {
    if (this.contextId) {
      await this.sendBidi("browsingContext.close", { context: this.contextId });
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

  async click(selector: string): Promise<void> {
    await this.evaluate(`__click(${JSON.stringify(selector)})`);
  }

  async type(selector: string, text: string): Promise<void> {
    await this.evaluate(`__type(${JSON.stringify(selector)}, ${JSON.stringify(text)})`, {
      awaitPromise: true,
    });
  }

  async check(selector: string): Promise<void> {
    await this.evaluate(`__check(${JSON.stringify(selector)})`);
  }

  async uncheck(selector: string): Promise<void> {
    await this.evaluate(`__uncheck(${JSON.stringify(selector)})`);
  }

  async select(selector: string, value: string): Promise<void> {
    await this.evaluate(`__select(${JSON.stringify(selector)}, ${JSON.stringify(value)})`);
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
      setTimeout(() => {
        if (this.pendingCommands.has(id)) {
          this.pendingCommands.delete(id);
          reject(new Error(`Timeout waiting for response to ${method}`));
        }
      }, 10000);
    });
  }
}
