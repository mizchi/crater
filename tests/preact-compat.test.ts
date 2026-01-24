/**
 * Preact Compatibility Tests for Crater WebDriver BiDi
 *
 * Tests that Preact's core functionality works with Crater's DOM implementation.
 * Run: pnpm test:preact (with BiDi server running)
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
  private ws: WebSocket | null = null;
  private commandId = 0;
  private pendingCommands = new Map<
    number,
    { resolve: (value: BidiResponse) => void; reject: (error: Error) => void }
  >();

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
    const pending = this.pendingCommands.get(msg.id);
    if (pending) {
      this.pendingCommands.delete(msg.id);
      pending.resolve(msg as BidiResponse);
    }
  }

  async send(method: string, params: unknown = {}): Promise<BidiResponse> {
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

  close(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

// Preact-like virtual DOM implementation for testing
// This tests that the DOM APIs needed by Preact work correctly
const PREACT_LIKE_CODE = `
// Minimal Preact-like implementation to test DOM compatibility
const h = (type, props, ...children) => ({ type, props: props || {}, children: children.flat() });

const render = (vnode, container) => {
  if (typeof vnode === 'string' || typeof vnode === 'number') {
    return container.appendChild(document.createTextNode(String(vnode)));
  }

  const el = document.createElement(vnode.type);

  // Set attributes and event handlers
  for (const [key, value] of Object.entries(vnode.props)) {
    if (key.startsWith('on') && typeof value === 'function') {
      const eventName = key.slice(2).toLowerCase();
      el.addEventListener(eventName, value);
    } else if (key === 'className') {
      el.setAttribute('class', value);
    } else if (key === 'style' && typeof value === 'object') {
      // Set style properties directly instead of using Object.assign
      for (const [prop, val] of Object.entries(value)) {
        el.style[prop] = val;
      }
    } else if (key !== 'children') {
      el.setAttribute(key, value);
    }
  }

  // Render children
  for (const child of vnode.children) {
    if (child != null && child !== false) {
      render(child, el);
    }
  }

  container.appendChild(el);
  return el;
};

// Make available globally
globalThis.h = h;
globalThis.render = render;
`;

test.describe("Preact Compatibility Tests", () => {
  let client: BidiClient;
  let contextId: string;

  test.beforeEach(async () => {
    client = new BidiClient();
    await client.connect();

    // Create a browsing context
    const createResp = await client.send("browsingContext.create", {
      type: "tab",
    });
    contextId = (createResp.result as { context: string }).context;

    // Navigate to a blank HTML page
    const html = `<!DOCTYPE html><html><head></head><body><div id="root"></div></body></html>`;
    const dataUrl = `data:text/html;base64,${Buffer.from(html).toString("base64")}`;
    await client.send("browsingContext.navigate", {
      context: contextId,
      url: dataUrl,
      wait: "complete",
    });

    // Initialize the Preact-like runtime (use sync eval to ensure Mock DOM is setup)
    await client.send("script.evaluate", {
      expression: PREACT_LIKE_CODE,
      target: { context: contextId },
      awaitPromise: false,
    });

    // Clear the root element for each test
    await client.send("script.evaluate", {
      expression: `document.getElementById('root')._children = [];`,
      target: { context: contextId },
      awaitPromise: false,
    });
  });

  test.afterEach(() => {
    client.close();
  });

  test("createElement and appendChild work", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const el = document.createElement('div');
        el.textContent = 'Hello';
        document.getElementById('root').appendChild(el);
        document.getElementById('root').innerHTML;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("<div>Hello</div>");
  });

  test("render simple element", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const vnode = h('div', { id: 'test' }, 'Hello World');
        render(vnode, document.getElementById('root'));
        document.getElementById('root').innerHTML;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toContain("Hello World");
    expect(result.result.value).toContain('id="test"');
  });

  test("render nested elements", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const vnode = h('div', { className: 'container' },
          h('h1', null, 'Title'),
          h('p', null, 'Paragraph text')
        );
        render(vnode, document.getElementById('root'));
        document.getElementById('root').innerHTML;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toContain("<h1>Title</h1>");
    expect(result.result.value).toContain("<p>Paragraph text</p>");
    expect(result.result.value).toContain('class="container"');
  });

  test("render with style object", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const vnode = h('div', {
          style: { color: 'red', backgroundColor: 'blue' }
        }, 'Styled');
        render(vnode, document.getElementById('root'));
        const el = document.getElementById('root').firstChild;
        [el.style.color, el.style.backgroundColor].join(',');
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("red,blue");
  });

  test("event handlers work", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        let clicked = false;
        const vnode = h('button', {
          onClick: () => { clicked = true; }
        }, 'Click me');
        const btn = render(vnode, document.getElementById('root'));
        btn.click();
        clicked;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: boolean } };
    expect(result.result.value).toBe(true);
  });

  test("render list of elements", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const items = ['Apple', 'Banana', 'Cherry'];
        const vnode = h('ul', null,
          ...items.map(item => h('li', null, item))
        );
        render(vnode, document.getElementById('root'));
        document.getElementById('root').getElementsByTagName('li').length;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: number } };
    expect(result.result.value).toBe(3);
  });

  test("conditional rendering", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const show = true;
        const vnode = h('div', null,
          show && h('span', null, 'Visible'),
          !show && h('span', null, 'Hidden')
        );
        render(vnode, document.getElementById('root'));
        document.getElementById('root').innerHTML;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toContain("Visible");
    expect(result.result.value).not.toContain("Hidden");
  });

  test("text node rendering", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const vnode = h('p', null,
          'Hello, ',
          h('strong', null, 'World'),
          '!'
        );
        render(vnode, document.getElementById('root'));
        document.getElementById('root').textContent;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("Hello, World!");
  });

  test("DOM manipulation after render", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        render(h('div', { id: 'dynamic' }, 'Initial'), document.getElementById('root'));
        const el = document.getElementById('dynamic');
        el.textContent = 'Updated';
        el.textContent;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("Updated");
  });

  test("classList manipulation", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        render(h('div', { id: 'cls' }), document.getElementById('root'));
        const el = document.getElementById('cls');
        el.classList.add('foo', 'bar');
        el.classList.remove('foo');
        el.classList.toggle('baz');
        Array.from(el.classList).sort().join(',');
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("bar,baz");
  });

  test("insertBefore works", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const container = document.getElementById('root');
        const first = document.createElement('span');
        first.textContent = 'First';
        const second = document.createElement('span');
        second.textContent = 'Second';
        container.appendChild(second);
        container.insertBefore(first, second);
        container.textContent;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("FirstSecond");
  });

  test("removeChild works", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const container = document.getElementById('root');
        render(h('div', null,
          h('span', { id: 'keep' }, 'Keep'),
          h('span', { id: 'remove' }, 'Remove')
        ), container);
        const toRemove = document.getElementById('remove');
        toRemove.parentNode.removeChild(toRemove);
        container.textContent;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("Keep");
  });

  test("input value handling", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        render(h('input', { type: 'text', value: 'initial' }), document.getElementById('root'));
        const input = document.querySelector('input');
        const initial = input.value;
        input.value = 'changed';
        [initial, input.value].join(',');
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("initial,changed");
  });

  test("checkbox checked state", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        render(h('input', { type: 'checkbox' }), document.getElementById('root'));
        const cb = document.querySelector('input');
        const initial = cb.checked;
        cb.checked = true;
        [initial, cb.checked].join(',');
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("false,true");
  });

  test("MutationObserver tracks childList changes with takeRecords", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const observer = new MutationObserver(() => {});
        const root = document.getElementById('root');
        observer.observe(root, { childList: true });
        const div = document.createElement('div');
        root.appendChild(div);
        // takeRecords returns pending mutations synchronously
        const records = observer.takeRecords();
        observer.disconnect();
        records.length;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: number } };
    expect(result.result.value).toBeGreaterThanOrEqual(1);
  });

  test("MutationObserver tracks attribute changes with takeRecords", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const observer = new MutationObserver(() => {});
        const root = document.getElementById('root');
        observer.observe(root, { attributes: true });
        root.setAttribute('data-test', 'value');
        const records = observer.takeRecords();
        observer.disconnect();
        records.length > 0 ? records[0].attributeName : 'none';
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("data-test");
  });

  test("MutationObserver with subtree tracks nested changes", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const observer = new MutationObserver(() => {});
        const root = document.getElementById('root');
        const parent = document.createElement('div');
        root.appendChild(parent);
        observer.observe(root, { childList: true, subtree: true });
        const child = document.createElement('span');
        parent.appendChild(child);
        const records = observer.takeRecords();
        observer.disconnect();
        records.length;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: number } };
    expect(result.result.value).toBeGreaterThanOrEqual(1);
  });

  test("MutationObserver disconnect clears pending records", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const observer = new MutationObserver(() => {});
        const root = document.getElementById('root');
        observer.observe(root, { childList: true });
        root.appendChild(document.createElement('div'));
        observer.disconnect();
        // After disconnect, takeRecords should return empty
        const records = observer.takeRecords();
        records.length;
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: number } };
    expect(result.result.value).toBe(0);
  });

  test("awaitPromise correctly awaits Promise resolution", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `new Promise(resolve => setTimeout(() => resolve('delayed'), 50))`,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("delayed");
  });

  test("MutationObserver callback fires with awaitPromise", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        new Promise(resolve => {
          const mutations = [];
          const observer = new MutationObserver(records => {
            mutations.push(...records);
            resolve(mutations.length);
          });
          const root = document.getElementById('root');
          observer.observe(root, { childList: true });
          root.appendChild(document.createElement('div'));
        })
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: number } };
    expect(result.result.value).toBeGreaterThanOrEqual(1);
  });

  test("MutationObserver callback receives correct record type", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        new Promise(resolve => {
          const observer = new MutationObserver(records => {
            resolve(records[0].type);
          });
          const root = document.getElementById('root');
          observer.observe(root, { attributes: true });
          root.setAttribute('data-async', 'test');
        })
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("attributes");
  });

  // WaitFor tests - CDP/BiDi automation helpers
  test("__waitForSelector finds existing element immediately", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        // Element already exists
        const existing = document.getElementById('root');
        __waitForSelector('#root').then(el => el.id);
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("root");
  });

  test("__waitForSelector waits for element to appear", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        // Create element after a delay
        setTimeout(() => {
          const div = document.createElement('div');
          div.id = 'delayed-element';
          document.body.appendChild(div);
        }, 50);

        // Wait for it
        __waitForSelector('#delayed-element', { timeout: 1000 }).then(el => el.id);
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("delayed-element");
  });

  test("__waitForFunction waits for condition", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        let counter = 0;
        setInterval(() => counter++, 10);

        __waitForFunction(() => counter >= 3, { timeout: 1000 }).then(() => counter >= 3);
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: boolean } };
    expect(result.result.value).toBe(true);
  });

  test("__waitFor works with selector string", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        __waitFor('#root').then(el => el !== null);
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: boolean } };
    expect(result.result.value).toBe(true);
  });

  test("__waitForSelector times out when element not found", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        __waitForSelector('#non-existent', { timeout: 100 })
          .then(() => 'found')
          .catch(e => 'timeout: ' + e.message);
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toContain("timeout");
  });

  // Element interaction helper tests
  test("__click dispatches click event", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        let clicked = false;
        const btn = document.createElement('button');
        btn.id = 'click-test';
        btn.addEventListener('click', () => { clicked = true; });
        document.body.appendChild(btn);
        __click('#click-test');
        clicked;
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: boolean } };
    expect(result.result.value).toBe(true);
  });

  test("__fill sets input value and dispatches events", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        let inputFired = false;
        let changeFired = false;
        const input = document.createElement('input');
        input.id = 'fill-test';
        input.addEventListener('input', () => { inputFired = true; });
        input.addEventListener('change', () => { changeFired = true; });
        document.body.appendChild(input);
        __fill('#fill-test', 'hello world');
        [input.value, inputFired, changeFired];
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<{ type: string; value: unknown }> } };
    const [value, inputFired, changeFired] = result.result.value.map((v) => v.value);
    expect(value).toBe("hello world");
    expect(inputFired).toBe(true);
    expect(changeFired).toBe(true);
  });

  test("__type appends text character by character", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const input = document.createElement('input');
        input.id = 'type-test';
        input.value = 'pre-';
        document.body.appendChild(input);
        __type('#type-test', 'abc');
        input.value;
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("pre-abc");
  });

  test("__clear empties input value", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const input = document.createElement('input');
        input.id = 'clear-test';
        input.value = 'to be cleared';
        document.body.appendChild(input);
        __clear('#clear-test');
        input.value;
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("");
  });

  test("__focus and __blur dispatch focus events", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        let focused = false;
        let blurred = false;
        const input = document.createElement('input');
        input.id = 'focus-test';
        input.addEventListener('focus', () => { focused = true; });
        input.addEventListener('blur', () => { blurred = true; });
        document.body.appendChild(input);
        __focus('#focus-test');
        const afterFocus = focused;
        __blur('#focus-test');
        [afterFocus, blurred];
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<{ type: string; value: unknown }> } };
    const [focused, blurred] = result.result.value.map((v) => v.value);
    expect(focused).toBe(true);
    expect(blurred).toBe(true);
  });

  test("__check and __uncheck toggle checkbox state", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.id = 'checkbox-test';
        document.body.appendChild(cb);

        const before = cb.checked;
        __check('#checkbox-test');
        const afterCheck = cb.checked;
        __uncheck('#checkbox-test');
        const afterUncheck = cb.checked;
        [before, afterCheck, afterUncheck];
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<{ type: string; value: unknown }> } };
    const [before, afterCheck, afterUncheck] = result.result.value.map((v) => v.value);
    expect(before).toBe(false);
    expect(afterCheck).toBe(true);
    expect(afterUncheck).toBe(false);
  });

  test("__hover dispatches mouse events", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        let mouseEntered = false;
        let mouseOvered = false;
        const div = document.createElement('div');
        div.id = 'hover-test';
        div.addEventListener('mouseenter', () => { mouseEntered = true; });
        div.addEventListener('mouseover', () => { mouseOvered = true; });
        document.body.appendChild(div);
        __hover('#hover-test');
        [mouseEntered, mouseOvered];
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<{ type: string; value: unknown }> } };
    const [mouseEntered, mouseOvered] = result.result.value.map((v) => v.value);
    expect(mouseEntered).toBe(true);
    expect(mouseOvered).toBe(true);
  });

  // Element property getter tests
  test("__getText returns textContent", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const div = document.createElement('div');
        div.id = 'text-test';
        div.textContent = 'Hello World';
        document.body.appendChild(div);
        __getText('#text-test');
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("Hello World");
  });

  test("__getValue returns input value", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const input = document.createElement('input');
        input.id = 'value-test';
        input.value = 'test value';
        document.body.appendChild(input);
        __getValue('#value-test');
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("test value");
  });

  test("__isVisible returns visibility state", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const visible = document.createElement('div');
        visible.id = 'visible-div';
        document.body.appendChild(visible);

        const hidden = document.createElement('div');
        hidden.id = 'hidden-div';
        hidden.hidden = true;
        document.body.appendChild(hidden);

        [__isVisible('#visible-div'), __isVisible('#hidden-div')];
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<{ type: string; value: unknown }> } };
    const [visible, hidden] = result.result.value.map((v) => v.value);
    expect(visible).toBe(true);
    expect(hidden).toBe(false);
  });

  test("__isChecked returns checkbox state", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.id = 'check-state-test';
        cb.checked = true;
        document.body.appendChild(cb);
        __isChecked('#check-state-test');
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: boolean } };
    expect(result.result.value).toBe(true);
  });

  // Query helper tests
  test("__$ returns element info", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const div = document.createElement('div');
        div.id = 'query-test';
        div.className = 'test-class';
        div.textContent = 'Query Test';
        document.body.appendChild(div);
        const info = __$('#query-test');
        [info.tagName, info.id, info.textContent];
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<{ type: string; value: unknown }> } };
    const [tagName, id, textContent] = result.result.value.map((v) => v.value);
    expect(tagName).toBe("DIV");
    expect(id).toBe("query-test");
    expect(textContent).toBe("Query Test");
  });

  test("__$$ returns multiple elements", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        for (let i = 0; i < 3; i++) {
          const div = document.createElement('div');
          div.className = 'multi-test';
          div.textContent = 'Item ' + i;
          document.body.appendChild(div);
        }
        __$$('.multi-test').length;
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: number } };
    expect(result.result.value).toBe(3);
  });

  test("__count returns element count", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        for (let i = 0; i < 5; i++) {
          const span = document.createElement('span');
          span.className = 'count-test';
          document.body.appendChild(span);
        }
        __count('.count-test');
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: number } };
    expect(result.result.value).toBe(5);
  });

  test("__waitForTimeout delays execution", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        const start = Date.now();
        __waitForTimeout(50).then(() => Date.now() - start);
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: number } };
    expect(result.result.value).toBeGreaterThanOrEqual(45);
  });

  test("__dispatchEvent dispatches custom events", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        let eventReceived = null;
        const div = document.createElement('div');
        div.id = 'event-test';
        div.addEventListener('custom-event', (e) => { eventReceived = e.type; });
        document.body.appendChild(div);
        __dispatchEvent('#event-test', 'custom-event');
        eventReceived;
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: string } };
    expect(result.result.value).toBe("custom-event");
  });

  // Page loading tests
  test("__loadHTML parses HTML and builds DOM", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        __loadHTML('<div id="test-div"><span class="child">Hello</span></div>');
        const div = document.getElementById('test-div');
        const span = div.querySelector('.child');
        [div.tagName, span.textContent];
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<{ type: string; value: unknown }> } };
    const [tagName, textContent] = result.result.value.map((v) => v.value);
    expect(tagName).toBe("DIV");
    expect(textContent).toBe("Hello");
  });

  test("__loadHTML handles full HTML document structure", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        __loadHTML('<!DOCTYPE html><html><head><title>Test</title></head><body><h1>Title</h1><p>Content</p></body></html>');
        [
          document.querySelector('h1').textContent,
          document.querySelector('p').textContent
        ];
      `,
      target: { context: contextId },
      awaitPromise: false,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<{ type: string; value: unknown }> } };
    const [h1Text, pText] = result.result.value.map((v) => v.value);
    expect(h1Text).toBe("Title");
    expect(pText).toBe("Content");
  });

  test("__loadPage fetches and parses remote page", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        __loadPage('https://example.com').then(result => {
          const title = document.querySelector('title');
          const h1 = document.querySelector('h1');
          return {
            url: result.url,
            status: result.status,
            title: title ? title.textContent : null,
            h1: h1 ? h1.textContent : null
          };
        });
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<[string, unknown]> } };
    const obj = Object.fromEntries(result.result.value.map(([k, v]: [string, { value: unknown }]) => [k, v.value]));
    expect(obj.url).toBe("https://example.com");
    expect(obj.status).toBe(200);
    expect(obj.h1).toContain("Example Domain");
  });

  // ES Modules support tests
  test("__executeScripts handles inline module scripts", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        __loadHTML(\`
          <html>
          <head></head>
          <body>
            <div id="target">initial</div>
            <script type="module">
              const target = document.getElementById('target');
              if (target) target.textContent = 'module executed';
            </script>
          </body>
          </html>
        \`);
        __executeScripts().then(results => {
          return {
            scriptCount: results.length,
            targetText: document.getElementById('target').textContent
          };
        });
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<[string, unknown]> } };
    const obj = Object.fromEntries(result.result.value.map(([k, v]: [string, { value: unknown }]) => [k, v.value]));
    expect(obj.scriptCount).toBe(1);
    expect(obj.targetText).toBe("module executed");
  });

  test("__executeScripts handles external ESM src attribute", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        __loadHTML(\`
          <html>
          <head></head>
          <body>
            <script type="module" src="https://esm.sh/lodash-es@4.17.21/add"></script>
          </body>
          </html>
        \`);
        __executeScripts().then(results => {
          return {
            executed: results.length > 0,
            hasModule: results.some(r => r.module === true),
            noError: results.every(r => !r.error)
          };
        });
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<[string, unknown]> } };
    const obj = Object.fromEntries(result.result.value.map(([k, v]: [string, { value: unknown }]) => [k, v.value]));
    expect(obj.executed).toBe(true);
    expect(obj.hasModule).toBe(true);
    expect(obj.noError).toBe(true);
  });

  test("__executeScripts handles dynamic import in inline module", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        __loadHTML(\`
          <html>
          <head></head>
          <body>
            <script type="module">
              // Use dynamic import which works from data URLs
              const lodashAdd = await import('https://esm.sh/lodash-es@4.17.21/add');
              globalThis.__esmResult = lodashAdd.default(2, 3);
            </script>
          </body>
          </html>
        \`);
        __executeScripts().then(results => {
          return {
            executed: results.length > 0,
            result: globalThis.__esmResult
          };
        });
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<[string, unknown]> } };
    const obj = Object.fromEntries(result.result.value.map(([k, v]: [string, { value: unknown }]) => [k, v.value]));
    expect(obj.executed).toBe(true);
    expect(obj.result).toBe(5);
  });

  test("__executeScripts handles mixed classic and module scripts", async () => {
    const evalResp = await client.send("script.evaluate", {
      expression: `
        __loadHTML(\`
          <html>
          <head></head>
          <body>
            <script>
              globalThis.__classicResult = 'classic';
            </script>
            <script type="module">
              globalThis.__moduleResult = 'module';
            </script>
          </body>
          </html>
        \`);
        __executeScripts().then(results => {
          return {
            count: results.length,
            classic: globalThis.__classicResult,
            module: globalThis.__moduleResult
          };
        });
      `,
      target: { context: contextId },
      awaitPromise: true,
    });

    expect(evalResp.type).toBe("success");
    const result = evalResp.result as { result: { type: string; value: Array<[string, unknown]> } };
    const obj = Object.fromEntries(result.result.value.map(([k, v]: [string, { value: unknown }]) => [k, v.value]));
    expect(obj.count).toBe(2);
    expect(obj.classic).toBe("classic");
    expect(obj.module).toBe("module");
  });
});
