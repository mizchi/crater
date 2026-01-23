/**
 * Playwright E2E tests for Crater WebDriver BiDi
 *
 * Tests basic BiDi protocol operations via WebSocket connection.
 * Run: pnpm test:bidi-e2e (with server running)
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

class BidiClient {
  private ws: WebSocket | null = null;
  private commandId = 0;
  private pendingCommands = new Map<
    number,
    { resolve: (value: BidiResponse) => void; reject: (error: Error) => void }
  >();
  private eventHandlers: ((event: BidiEvent) => void)[] = [];

  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(BIDI_URL);

      this.ws.on("open", () => resolve());
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

    // Response to a command
    const pending = this.pendingCommands.get(msg.id);
    if (pending) {
      this.pendingCommands.delete(msg.id);
      pending.resolve(msg as BidiResponse);
    }
  }

  onEvent(handler: (event: BidiEvent) => void): void {
    this.eventHandlers.push(handler);
  }

  async send(method: string, params: unknown = {}): Promise<BidiResponse> {
    if (!this.ws) throw new Error("Not connected");

    const id = ++this.commandId;
    const message = JSON.stringify({ id, method, params });

    return new Promise((resolve, reject) => {
      this.pendingCommands.set(id, { resolve, reject });
      this.ws!.send(message);

      // Timeout after 5 seconds
      setTimeout(() => {
        if (this.pendingCommands.has(id)) {
          this.pendingCommands.delete(id);
          reject(new Error(`Timeout waiting for response to ${method}`));
        }
      }, 5000);
    });
  }

  close(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

test.describe("BiDi Protocol E2E Tests", () => {
  let client: BidiClient;

  test.beforeEach(async () => {
    client = new BidiClient();
    await client.connect();
  });

  test.afterEach(() => {
    client.close();
  });

  test("session.status returns ready", async () => {
    const resp = await client.send("session.status");
    expect(resp.type).toBe("success");
    expect((resp.result as { ready: boolean }).ready).toBe(true);
  });

  test("browsingContext.create creates a new context", async () => {
    const resp = await client.send("browsingContext.create", { type: "tab" });
    expect(resp.type).toBe("success");
    const result = resp.result as { context: string };
    expect(result.context).toBeTruthy();
    expect(typeof result.context).toBe("string");
  });

  test("browsingContext.getTree returns context list", async () => {
    // First create a context
    await client.send("browsingContext.create", { type: "tab" });

    // Then get tree
    const resp = await client.send("browsingContext.getTree");
    expect(resp.type).toBe("success");
    const result = resp.result as { contexts: unknown[] };
    expect(result.contexts).toBeInstanceOf(Array);
    expect(result.contexts.length).toBeGreaterThan(0);
  });

  test("browsingContext.navigate with data URL", async () => {
    const createResp = await client.send("browsingContext.create", {
      type: "tab",
    });
    const ctxId = (createResp.result as { context: string }).context;

    const html = "<html><body><h1>Hello</h1></body></html>";
    const dataUrl = `data:text/html;base64,${Buffer.from(html).toString("base64")}`;

    const navResp = await client.send("browsingContext.navigate", {
      context: ctxId,
      url: dataUrl,
      wait: "complete",
    });
    expect(navResp.type).toBe("success");
    const result = navResp.result as { navigation: string; url: string };
    expect(result.navigation).toBeTruthy();
    expect(result.url).toBe(dataUrl);
  });

  test("script.evaluate evaluates JavaScript", async () => {
    const createResp = await client.send("browsingContext.create", {
      type: "tab",
    });
    const ctxId = (createResp.result as { context: string }).context;

    const evalResp = await client.send("script.evaluate", {
      expression: "1 + 2",
      target: { context: ctxId },
      awaitPromise: true,
    });
    expect(evalResp.type).toBe("success");
    const result = evalResp.result as {
      result: { type: string; value: number };
    };
    expect(result.result.type).toBe("number");
    expect(result.result.value).toBe(3);
  });

  test("script.evaluate handles strings", async () => {
    const createResp = await client.send("browsingContext.create", {
      type: "tab",
    });
    const ctxId = (createResp.result as { context: string }).context;

    const evalResp = await client.send("script.evaluate", {
      expression: "'hello world'",
      target: { context: ctxId },
      awaitPromise: true,
    });
    expect(evalResp.type).toBe("success");
    const result = evalResp.result as {
      result: { type: string; value: string };
    };
    expect(result.result.type).toBe("string");
    expect(result.result.value).toBe("hello world");
  });

  test("script.callFunction calls a function", async () => {
    const createResp = await client.send("browsingContext.create", {
      type: "tab",
    });
    const ctxId = (createResp.result as { context: string }).context;

    const callResp = await client.send("script.callFunction", {
      functionDeclaration: "(a, b) => a * b",
      target: { context: ctxId },
      arguments: [
        { type: "number", value: 6 },
        { type: "number", value: 7 },
      ],
      awaitPromise: true,
    });
    expect(callResp.type).toBe("success");
    const result = callResp.result as {
      result: { type: string; value: number };
    };
    expect(result.result.type).toBe("number");
    expect(result.result.value).toBe(42);
  });

  test("session.subscribe registers event subscriptions", async () => {
    const resp = await client.send("session.subscribe", {
      events: ["browsingContext.load", "browsingContext.domContentLoaded"],
    });
    expect(resp.type).toBe("success");
  });

  test("session.unsubscribe removes event subscriptions", async () => {
    // First subscribe
    await client.send("session.subscribe", {
      events: ["browsingContext.load"],
    });

    // Then unsubscribe
    const resp = await client.send("session.unsubscribe", {
      events: ["browsingContext.load"],
    });
    expect(resp.type).toBe("success");
  });

  test("events are received after subscription", async () => {
    const events: BidiEvent[] = [];
    client.onEvent((event) => events.push(event));

    // Subscribe to events
    await client.send("session.subscribe", {
      events: ["browsingContext"],
    });

    // Create context - should trigger contextCreated event
    await client.send("browsingContext.create", { type: "tab" });

    // Wait for events to be received (may need longer wait for async delivery)
    for (let i = 0; i < 20; i++) {
      if (events.some((e) => e.method === "browsingContext.contextCreated")) {
        break;
      }
      await new Promise((r) => setTimeout(r, 50));
    }

    // Check that we received the contextCreated event
    const contextCreatedEvent = events.find(
      (e) => e.method === "browsingContext.contextCreated"
    );
    expect(contextCreatedEvent).toBeTruthy();
    expect((contextCreatedEvent!.params as { context: string }).context).toBeTruthy();
  });

  test("browsingContext.close closes a context", async () => {
    const createResp = await client.send("browsingContext.create", {
      type: "tab",
    });
    const ctxId = (createResp.result as { context: string }).context;

    const closeResp = await client.send("browsingContext.close", {
      context: ctxId,
    });
    expect(closeResp.type).toBe("success");
  });

  test("validation: invalid maxDepth type returns error", async () => {
    const resp = await client.send("browsingContext.getTree", {
      maxDepth: "invalid",
    });
    expect(resp.type).toBe("error");
    expect(resp.error).toBe("invalid argument");
  });

  test("validation: missing target returns error", async () => {
    const resp = await client.send("script.evaluate", {
      expression: "1",
    });
    expect(resp.type).toBe("error");
    expect(resp.error).toBe("invalid argument");
  });
});
