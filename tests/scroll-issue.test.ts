/**
 * Scroll Issue Reproduction Test
 *
 * This test reproduces the issue where scrolling on addyosmani.com/blog/21-lessons/
 * causes the page to go blank after "in search of a justification."
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

test.describe("Scroll Issue", () => {
  test("scroll should not cause blank screen on tall content", async () => {
    const client = await connectBidi();

    try {
      // Create session
      const session = await client.send("session.new", {
        capabilities: {},
      }) as { sessionId: string };
      const sessionId = session.sessionId;

      // Create browsing context
      const context = await client.send("browsingContext.create", {
        type: "tab",
      }) as { context: string };
      const contextId = context.context;

      // Navigate to the problematic page
      await client.send("browsingContext.navigate", {
        context: contextId,
        url: "https://addyosmani.com/blog/21-lessons/",
        wait: "complete",
      });

      // Wait for page to load
      await new Promise(r => setTimeout(r, 2000));

      // Get initial content height
      const initialHeight = await client.send("script.evaluate", {
        expression: "document.body ? document.body.scrollHeight : 0",
        target: { context: contextId },
        awaitPromise: false,
      }) as { result: { value: number } };

      console.log("Initial scroll height:", initialHeight.result?.value);

      // Scroll down in steps and check if content is still visible
      const scrollSteps = [100, 500, 1000, 2000, 3000, 5000];

      for (const scrollY of scrollSteps) {
        // Scroll to position
        await client.send("script.evaluate", {
          expression: `window.scrollTo(0, ${scrollY}); window.scrollY`,
          target: { context: contextId },
          awaitPromise: false,
        });

        // Wait a bit for render
        await new Promise(r => setTimeout(r, 100));

        // Check if there's any visible content
        const visibleText = await client.send("script.evaluate", {
          expression: `
            (() => {
              const elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li');
              let visibleCount = 0;
              for (const el of elements) {
                const rect = el.getBoundingClientRect();
                if (rect.top >= 0 && rect.top < window.innerHeight) {
                  visibleCount++;
                }
              }
              return visibleCount;
            })()
          `,
          target: { context: contextId },
          awaitPromise: false,
        }) as { result: { value: number } };

        console.log(`Scroll ${scrollY}: visible elements = ${visibleText.result?.value}`);

        // We expect at least some content to be visible at each scroll position
        // (except maybe at the very end of the document)
        if (scrollY < 5000) {
          expect(visibleText.result?.value).toBeGreaterThan(0);
        }
      }

      // Cleanup
      await client.send("browsingContext.close", { context: contextId });
      await client.send("session.end", { sessionId });
    } finally {
      client.close();
    }
  });

  test("viewport culling should work correctly at various scroll positions", async () => {
    const client = await connectBidi();

    try {
      // Create session
      const session = await client.send("session.new", {
        capabilities: {},
      }) as { sessionId: string };
      const sessionId = session.sessionId;

      // Create browsing context
      const context = await client.send("browsingContext.create", {
        type: "tab",
      }) as { context: string };
      const contextId = context.context;

      // Create a simple tall page
      const tallHtml = `
        <!DOCTYPE html>
        <html>
        <head><title>Scroll Test</title></head>
        <body style="margin:0">
          ${Array.from({ length: 100 }, (_, i) =>
            `<div style="height:100px;background:${i % 2 ? '#eee' : '#ddd'}">Section ${i + 1}</div>`
          ).join("\n")}
        </body>
        </html>
      `;

      // Set content
      await client.send("script.evaluate", {
        expression: `document.open(); document.write(${JSON.stringify(tallHtml)}); document.close();`,
        target: { context: contextId },
        awaitPromise: false,
      });

      // Wait for render
      await new Promise(r => setTimeout(r, 500));

      // Get content height
      const heightResult = await client.send("script.evaluate", {
        expression: "document.body.scrollHeight",
        target: { context: contextId },
        awaitPromise: false,
      }) as { result: { value: number } };

      const contentHeight = heightResult.result?.value || 0;
      console.log("Content height:", contentHeight);

      // Should be 10000px (100 sections * 100px)
      expect(contentHeight).toBeGreaterThanOrEqual(10000);

      // Test scrolling to various positions
      const testPositions = [0, 1000, 5000, 9000, 9500];

      for (const scrollY of testPositions) {
        await client.send("script.evaluate", {
          expression: `window.scrollTo(0, ${scrollY})`,
          target: { context: contextId },
          awaitPromise: false,
        });

        await new Promise(r => setTimeout(r, 100));

        // Check visible sections
        const visibleSections = await client.send("script.evaluate", {
          expression: `
            (() => {
              const divs = document.querySelectorAll('div');
              let visible = [];
              for (const div of divs) {
                const rect = div.getBoundingClientRect();
                if (rect.bottom > 0 && rect.top < window.innerHeight) {
                  visible.push(div.textContent);
                }
              }
              return visible;
            })()
          `,
          target: { context: contextId },
          awaitPromise: false,
        }) as { result: { value: string[] } };

        console.log(`Scroll ${scrollY}: visible = ${JSON.stringify(visibleSections.result?.value)}`);

        // Should have visible sections at each position
        expect(visibleSections.result?.value?.length).toBeGreaterThan(0);
      }

      // Cleanup
      await client.send("browsingContext.close", { context: contextId });
      await client.send("session.end", { sessionId });
    } finally {
      client.close();
    }
  });
});
