/**
 * Debug script to reproduce scroll issue
 *
 * This script connects to the BiDi server and simulates scrolling
 * to reproduce the blank screen issue.
 */

import WebSocket from "ws";

const BIDI_URL = "ws://127.0.0.1:9222";

interface BidiResponse {
  id: number;
  type: "success" | "error";
  result?: unknown;
  error?: string;
  message?: string;
}

class BidiClient {
  private ws: WebSocket;
  private messageId = 0;
  private pending = new Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();

  constructor(ws: WebSocket) {
    this.ws = ws;
    ws.on("message", (data) => {
      const msg = JSON.parse(data.toString());
      if (msg.id !== undefined && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id)!;
        this.pending.delete(msg.id);
        if (msg.type === "error") {
          reject(new Error(msg.error || msg.message || "Unknown error"));
        } else {
          resolve(msg.result);
        }
      }
    });
  }

  async send(method: string, params: Record<string, unknown> = {}): Promise<unknown> {
    const id = ++this.messageId;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  close() {
    this.ws.close();
  }
}

async function connectBidi(): Promise<BidiClient> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(BIDI_URL);
    ws.on("open", () => resolve(new BidiClient(ws)));
    ws.on("error", reject);
  });
}

async function main() {
  console.log("Connecting to BiDi server...");
  const client = await connectBidi();

  try {
    // Create session
    console.log("Creating session...");
    const session = await client.send("session.new", {
      capabilities: {},
    }) as { sessionId: string };
    const sessionId = session.sessionId;
    console.log("Session ID:", sessionId);

    // Create browsing context
    console.log("Creating context...");
    const context = await client.send("browsingContext.create", {
      type: "tab",
    }) as { context: string };
    const contextId = context.context;
    console.log("Context ID:", contextId);

    // Load the problematic page
    console.log("Loading page...");
    await client.send("browsingContext.navigate", {
      context: contextId,
      url: "https://addyosmani.com/blog/21-lessons/",
      wait: "complete",
    });

    // Wait for page to load
    await new Promise(r => setTimeout(r, 3000));

    // Get document info
    const docInfo = await client.send("script.evaluate", {
      expression: `({
        scrollHeight: document.body ? document.body.scrollHeight : 0,
        clientHeight: document.documentElement.clientHeight,
        innerHeight: window.innerHeight,
      })`,
      target: { context: contextId },
      awaitPromise: false,
    }) as { result: { value: { scrollHeight: number; clientHeight: number; innerHeight: number } } };

    console.log("Document info:", docInfo.result?.value);

    // Test scrolling at different positions
    const scrollPositions = [0, 100, 200, 300, 500, 800, 1000, 2000, 3000, 5000, 8000];

    for (const scrollY of scrollPositions) {
      await client.send("script.evaluate", {
        expression: `window.scrollTo(0, ${scrollY}); window.scrollY`,
        target: { context: contextId },
        awaitPromise: false,
      });

      await new Promise(r => setTimeout(r, 200));

      // Get visible content
      const visible = await client.send("script.evaluate", {
        expression: `(() => {
          const vh = window.innerHeight;
          const elements = document.querySelectorAll('p, h1, h2, h3, li, div');
          let visibleText = [];
          for (const el of elements) {
            const rect = el.getBoundingClientRect();
            if (rect.top >= 0 && rect.top < vh && el.textContent) {
              const text = el.textContent.trim().slice(0, 50);
              if (text) visibleText.push(text);
            }
          }
          return visibleText.slice(0, 3);
        })()`,
        target: { context: contextId },
        awaitPromise: false,
      }) as { result: { value: string[] } };

      console.log(`Scroll ${scrollY}: visible = ${JSON.stringify(visible.result?.value || [])}`);
    }

    // Cleanup
    await client.send("browsingContext.close", { context: contextId });
    await client.send("session.end", { sessionId });
  } finally {
    client.close();
  }
}

main().catch(console.error);
