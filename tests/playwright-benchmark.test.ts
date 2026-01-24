/**
 * Playwright Adapter Benchmark for Crater WebDriver BiDi
 *
 * Measures performance of various Playwright-like operations.
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

// Minimal CraterPage for benchmarking
class CraterPage {
  private ws: WebSocket | null = null;
  private commandId = 0;
  private pendingCommands = new Map<
    number,
    { resolve: (value: BidiResponse) => void; reject: (error: Error) => void }
  >();
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
    if (msg.type === "event") return;
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

  async setContent(html: string): Promise<void> {
    const dataUrl = `data:text/html;base64,${Buffer.from(html).toString("base64")}`;
    await this.sendBidi("browsingContext.navigate", {
      context: this.contextId,
      url: dataUrl,
      wait: "complete",
    });
    await this.sendBidi("script.evaluate", {
      expression: `__loadHTML(${JSON.stringify(html)})`,
      target: { context: this.contextId },
      awaitPromise: false,
    });
  }

  async evaluate<T>(expression: string): Promise<T> {
    const resp = await this.sendBidi("script.evaluate", {
      expression,
      target: { context: this.contextId },
      awaitPromise: false,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error);
    }
    const result = resp.result as { result?: { value?: T } };
    return result.result?.value as T;
  }

  async close(): Promise<void> {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

// Benchmark utilities
interface BenchmarkResult {
  name: string;
  iterations: number;
  totalMs: number;
  avgMs: number;
  minMs: number;
  maxMs: number;
  opsPerSec: number;
}

async function benchmark(
  name: string,
  fn: () => Promise<void>,
  iterations: number = 100
): Promise<BenchmarkResult> {
  const times: number[] = [];

  // Warmup
  for (let i = 0; i < Math.min(10, iterations); i++) {
    await fn();
  }

  // Actual measurement
  for (let i = 0; i < iterations; i++) {
    const start = performance.now();
    await fn();
    const end = performance.now();
    times.push(end - start);
  }

  const totalMs = times.reduce((a, b) => a + b, 0);
  const avgMs = totalMs / times.length;
  const minMs = Math.min(...times);
  const maxMs = Math.max(...times);
  const opsPerSec = 1000 / avgMs;

  return { name, iterations, totalMs, avgMs, minMs, maxMs, opsPerSec };
}

function formatResult(result: BenchmarkResult): string {
  return `${result.name.padEnd(40)} | avg: ${result.avgMs.toFixed(3).padStart(8)}ms | min: ${result.minMs.toFixed(3).padStart(8)}ms | max: ${result.maxMs.toFixed(3).padStart(8)}ms | ${result.opsPerSec.toFixed(1).padStart(8)} ops/s`;
}

test.describe("Playwright Adapter Benchmark", () => {
  let page: CraterPage;
  const results: BenchmarkResult[] = [];

  test.beforeAll(async () => {
    page = new CraterPage();
    await page.connect();
  });

  test.afterAll(async () => {
    await page.close();

    // Print results summary
    console.log("\n" + "=".repeat(100));
    console.log("BENCHMARK RESULTS");
    console.log("=".repeat(100));
    for (const result of results) {
      console.log(formatResult(result));
    }
    console.log("=".repeat(100) + "\n");
  });

  test("setContent - simple HTML", async () => {
    const result = await benchmark("setContent (simple HTML)", async () => {
      await page.setContent(`<html><body><div>Hello</div></body></html>`);
    }, 50);
    results.push(result);
    expect(result.avgMs).toBeLessThan(100);
  });

  test("setContent - complex HTML", async () => {
    const complexHtml = `
      <html>
        <body>
          <header><nav><ul>${Array(10).fill('<li><a href="#">Link</a></li>').join('')}</ul></nav></header>
          <main>
            ${Array(20).fill('<div class="card"><h2>Title</h2><p>Content paragraph with some text.</p><button>Click me</button></div>').join('')}
          </main>
          <footer><p>Footer content</p></footer>
        </body>
      </html>
    `;
    const result = await benchmark("setContent (complex HTML)", async () => {
      await page.setContent(complexHtml);
    }, 30);
    results.push(result);
    expect(result.avgMs).toBeLessThan(200);
  });

  test("evaluate - simple expression", async () => {
    await page.setContent(`<html><body><div id="test">Hello</div></body></html>`);
    const result = await benchmark("evaluate (simple)", async () => {
      await page.evaluate(`1 + 1`);
    }, 200);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("evaluate - DOM access", async () => {
    await page.setContent(`<html><body><div id="test">Hello</div></body></html>`);
    const result = await benchmark("evaluate (DOM access)", async () => {
      await page.evaluate(`document.getElementById('test').textContent`);
    }, 200);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("querySelector - by ID", async () => {
    await page.setContent(`<html><body><div id="target">Target</div></body></html>`);
    const result = await benchmark("querySelector (by ID)", async () => {
      await page.evaluate(`document.querySelector('#target')?.textContent`);
    }, 200);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("querySelector - by class", async () => {
    await page.setContent(`
      <html><body>
        ${Array(50).fill('<div class="item">Item</div>').join('')}
        <div class="target">Target</div>
      </body></html>
    `);
    const result = await benchmark("querySelector (by class)", async () => {
      await page.evaluate(`document.querySelector('.target')?.textContent`);
    }, 200);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("querySelectorAll - multiple elements", async () => {
    await page.setContent(`
      <html><body>
        ${Array(100).fill('<div class="item">Item</div>').join('')}
      </body></html>
    `);
    const result = await benchmark("querySelectorAll (100 elements)", async () => {
      await page.evaluate(`document.querySelectorAll('.item').length`);
    }, 100);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("click - simple button", async () => {
    await page.setContent(`
      <html><body>
        <button id="btn" onclick="this.dataset.clicked = 'true'">Click</button>
      </body></html>
    `);
    const result = await benchmark("click (button)", async () => {
      await page.evaluate(`document.getElementById('btn').click()`);
    }, 200);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("input - fill value", async () => {
    await page.setContent(`<html><body><input id="input" type="text"></body></html>`);
    const result = await benchmark("fill (input)", async () => {
      await page.evaluate(`
        const el = document.getElementById('input');
        el.value = 'test value';
        el.dispatchEvent(new Event('input', { bubbles: true }));
      `);
    }, 200);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("getByText - find by text", async () => {
    await page.setContent(`
      <html><body>
        ${Array(50).fill('<div>Other text</div>').join('')}
        <button>Click me</button>
      </body></html>
    `);
    const result = await benchmark("getByText (find element)", async () => {
      await page.evaluate(`
        (() => {
          const all = [];
          const walk = (node) => {
            if (node.nodeType === 1) all.push(node);
            const children = node._children || node.childNodes || [];
            for (const child of children) walk(child);
          };
          walk(document.documentElement || document.body);
          return all.find(el => {
            const children = el._children || el.childNodes || [];
            const directText = Array.from(children)
              .filter(n => n.nodeType === 3)
              .map(n => n.textContent || '')
              .join('');
            return directText.includes('Click me');
          })?.tagName;
        })()
      `);
    }, 100);
    results.push(result);
    expect(result.avgMs).toBeLessThan(100);
  });

  test("getByRole - find by role", async () => {
    await page.setContent(`
      <html><body>
        ${Array(50).fill('<div>Other</div>').join('')}
        <button role="button">Submit</button>
      </body></html>
    `);
    const result = await benchmark("getByRole (find element)", async () => {
      await page.evaluate(`
        (() => {
          const all = [];
          const walk = (node) => {
            if (node.nodeType === 1) all.push(node);
            const children = node._children || node.childNodes || [];
            for (const child of children) walk(child);
          };
          walk(document.documentElement || document.body);
          return all.find(el => {
            const role = el.getAttribute ? el.getAttribute('role') : (el._attrs && el._attrs.role);
            return role === 'button';
          })?.textContent;
        })()
      `);
    }, 100);
    results.push(result);
    expect(result.avgMs).toBeLessThan(100);
  });

  test("DOM manipulation - createElement and appendChild", async () => {
    await page.setContent(`<html><body><div id="container"></div></body></html>`);
    const result = await benchmark("DOM manipulation (create + append)", async () => {
      await page.evaluate(`
        (() => {
          const container = document.getElementById('container');
          const el = document.createElement('div');
          el.textContent = 'New element';
          container.appendChild(el);
        })()
      `);
    }, 100);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("attribute access - getAttribute", async () => {
    await page.setContent(`<html><body><div id="test" data-value="123" data-name="test"></div></body></html>`);
    const result = await benchmark("getAttribute", async () => {
      await page.evaluate(`document.getElementById('test').getAttribute('data-value')`);
    }, 200);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("style access - getComputedStyle", async () => {
    await page.setContent(`<html><body><div id="test" style="display: flex; color: red;">Test</div></body></html>`);
    const result = await benchmark("getComputedStyle", async () => {
      await page.evaluate(`window.getComputedStyle(document.getElementById('test')).display`);
    }, 200);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("event dispatch - custom event", async () => {
    await page.setContent(`
      <html><body>
        <div id="target"></div>
        <script>
          document.getElementById('target').addEventListener('custom', function(e) {
            this.dataset.fired = 'true';
          });
        </script>
      </body></html>
    `);
    const result = await benchmark("dispatchEvent (custom)", async () => {
      await page.evaluate(`
        document.getElementById('target').dispatchEvent(new CustomEvent('custom', { detail: { value: 1 } }))
      `);
    }, 200);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("tree traversal - deep DOM", async () => {
    // Create a deeply nested structure
    let html = '<div id="root">';
    for (let i = 0; i < 10; i++) {
      html += '<div class="level">';
    }
    html += '<span id="deep">Deep</span>';
    for (let i = 0; i < 10; i++) {
      html += '</div>';
    }
    html += '</div>';

    await page.setContent(`<html><body>${html}</body></html>`);
    const result = await benchmark("tree traversal (10 levels deep)", async () => {
      await page.evaluate(`document.getElementById('deep').textContent`);
    }, 200);
    results.push(result);
    expect(result.avgMs).toBeLessThan(50);
  });

  test("bulk operations - iterate 100 elements", async () => {
    await page.setContent(`
      <html><body>
        ${Array(100).fill(0).map((_, i) => `<div class="item" data-index="${i}">Item ${i}</div>`).join('')}
      </body></html>
    `);
    const result = await benchmark("bulk iteration (100 elements)", async () => {
      await page.evaluate(`
        Array.from(document.querySelectorAll('.item')).map(el => el.textContent)
      `);
    }, 50);
    results.push(result);
    expect(result.avgMs).toBeLessThan(100);
  });

  test("combined operations - realistic scenario", async () => {
    await page.setContent(`
      <html><body>
        <form id="form">
          <input id="name" type="text" placeholder="Name">
          <input id="email" type="email" placeholder="Email">
          <button type="submit">Submit</button>
        </form>
        <div id="output"></div>
      </body></html>
    `);
    const result = await benchmark("combined (form fill + submit)", async () => {
      await page.evaluate(`
        (() => {
          const name = document.getElementById('name');
          name.value = 'John Doe';
          name.dispatchEvent(new Event('input', { bubbles: true }));

          const email = document.getElementById('email');
          email.value = 'john@example.com';
          email.dispatchEvent(new Event('input', { bubbles: true }));

          const form = document.getElementById('form');
          form.dispatchEvent(new Event('submit', { bubbles: true }));
        })()
      `);
    }, 100);
    results.push(result);
    expect(result.avgMs).toBeLessThan(100);
  });
});
