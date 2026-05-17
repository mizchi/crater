/**
 * Thin BiDi connection helper used by e2e tests.
 *
 * Wraps the same raw WebSocket pattern as `tests/bidi-e2e.test.ts`, but exposes
 * a session-shaped facade with `browsingContext.navigate`, `script.evaluate`,
 * `storage.getCookies`, and `events.waitFor`. Keeps the test file readable
 * without committing to a full Playwright adapter (the
 * `CraterBidiPage`/`CraterBrowser` machinery exists for that, but pulls in a
 * much larger surface than these flow tests need).
 */

import WebSocket from "ws";
import { resolveBidiUrl } from "../../scripts/bidi-url.ts";

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

interface PendingCommand {
  resolve: (value: BidiResponse) => void;
  reject: (error: Error) => void;
  timer: ReturnType<typeof setTimeout>;
}

export interface BidiSendOptions {
  timeoutMs?: number;
}

export interface BidiWaitForOptions {
  timeoutMs?: number;
  predicate?: (event: BidiEvent) => boolean;
}

const DEFAULT_TIMEOUT_MS = 10000;

class RawBidiConnection {
  private ws: WebSocket | null = null;
  private commandId = 0;
  private pending = new Map<number, PendingCommand>();
  private handlers: ((event: BidiEvent) => void)[] = [];

  async connect(): Promise<void> {
    const url = await resolveBidiUrl();
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(url);
      this.ws.on("open", () => resolve());
      this.ws.on("error", (err) => reject(err));
      this.ws.on("message", (data) => this.handleMessage(data.toString()));
    });
  }

  private handleMessage(data: string): void {
    let msg: { id?: number; type?: string; method?: string; params?: unknown };
    try {
      msg = JSON.parse(data);
    } catch {
      return;
    }
    if (msg.type === "event") {
      const event = msg as BidiEvent;
      for (const h of this.handlers) {
        try {
          h(event);
        } catch {
          // swallow event handler errors so they don't kill the socket loop
        }
      }
      return;
    }
    if (typeof msg.id === "number") {
      const pending = this.pending.get(msg.id);
      if (pending) {
        clearTimeout(pending.timer);
        this.pending.delete(msg.id);
        pending.resolve(msg as BidiResponse);
      }
    }
  }

  onEvent(handler: (event: BidiEvent) => void): void {
    this.handlers.push(handler);
  }

  send(method: string, params: unknown = {}, opts: BidiSendOptions = {}): Promise<BidiResponse> {
    if (!this.ws) throw new Error("BiDi connection not open");
    const id = ++this.commandId;
    const payload = JSON.stringify({ id, method, params });
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (this.pending.has(id)) {
          this.pending.delete(id);
          reject(new Error(`Timeout waiting for response to ${method}`));
        }
      }, opts.timeoutMs ?? DEFAULT_TIMEOUT_MS);
      this.pending.set(id, { resolve, reject, timer });
      this.ws!.send(payload);
    });
  }

  close(): void {
    for (const [, p] of this.pending) {
      clearTimeout(p.timer);
    }
    this.pending.clear();
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

export interface CraterBidiSession {
  readonly contextId: string;
  readonly raw: {
    send: (method: string, params?: unknown, opts?: BidiSendOptions) => Promise<BidiResponse>;
    onEvent: (handler: (event: BidiEvent) => void) => void;
  };
  browsingContext: {
    navigate: (params: {
      url: string;
      wait?: "none" | "interactive" | "complete";
    }) => Promise<{ navigation: string | null; url: string }>;
  };
  script: {
    evaluate: <T = unknown>(params: {
      expression: string;
      awaitPromise?: boolean;
      resultOwnership?: "root" | "none";
    }) => Promise<T>;
  };
  storage: {
    getCookies: (params?: {
      partition?: unknown;
      filter?: unknown;
    }) => Promise<Array<Record<string, unknown>>>;
  };
  events: {
    waitFor: (method: string, opts?: BidiWaitForOptions) => Promise<BidiEvent>;
  };
  end: () => Promise<void>;
}

export interface ConnectCraterBidiOptions {
  /**
   * Subscribe to these event groups when the session opens. Defaults to
   * the navigation lifecycle events the auth-flow test waits on.
   */
  subscribe?: string[];
}

const DEFAULT_SUBSCRIBE = [
  "browsingContext.load",
  "browsingContext.domContentLoaded",
  "browsingContext.navigationStarted",
  "browsingContext.fragmentNavigated",
];

export async function connectCraterBidi(
  opts: ConnectCraterBidiOptions = {},
): Promise<CraterBidiSession> {
  const conn = new RawBidiConnection();
  await conn.connect();

  const createResp = await conn.send("browsingContext.create", { type: "tab" });
  if (createResp.type !== "success") {
    conn.close();
    throw new Error(
      `browsingContext.create failed: ${createResp.error ?? createResp.message ?? "unknown"}`,
    );
  }
  const contextId = (createResp.result as { context: string }).context;

  const events = opts.subscribe ?? DEFAULT_SUBSCRIBE;
  if (events.length > 0) {
    const subResp = await conn.send("session.subscribe", { events });
    if (subResp.type !== "success") {
      conn.close();
      throw new Error(
        `session.subscribe failed: ${subResp.error ?? subResp.message ?? "unknown"}`,
      );
    }
  }

  function ensureSuccess(method: string, resp: BidiResponse): unknown {
    if (resp.type !== "success") {
      throw new Error(
        `${method} failed: ${resp.error ?? resp.message ?? "unknown error"}`,
      );
    }
    return resp.result;
  }

  return {
    contextId,
    raw: {
      send: (method, params, sendOpts) => conn.send(method, params, sendOpts),
      onEvent: (handler) => conn.onEvent(handler),
    },
    browsingContext: {
      async navigate({ url, wait = "complete" }) {
        const resp = await conn.send("browsingContext.navigate", {
          context: contextId,
          url,
          wait,
        });
        const result = ensureSuccess("browsingContext.navigate", resp) as {
          navigation: string | null;
          url: string;
        };
        return result;
      },
    },
    script: {
      async evaluate<T = unknown>({
        expression,
        awaitPromise = true,
        resultOwnership,
      }: {
        expression: string;
        awaitPromise?: boolean;
        resultOwnership?: "root" | "none";
      }): Promise<T> {
        const params: Record<string, unknown> = {
          expression,
          target: { context: contextId },
          awaitPromise,
        };
        if (resultOwnership) params.resultOwnership = resultOwnership;
        const resp = await conn.send("script.evaluate", params);
        const result = ensureSuccess("script.evaluate", resp) as {
          type: string;
          result?: { type: string; value?: T };
        };
        // BiDi 'evaluation' result shape: { type: "success", result: { type, value } }.
        // For exception, surface a thrown Error so callers don't silently see undefined.
        const inner = result.result;
        if (!inner) {
          throw new Error(
            `script.evaluate returned unexpected payload: ${JSON.stringify(result)}`,
          );
        }
        if ((result as { type?: string }).type === "exception") {
          throw new Error(
            `script.evaluate threw: ${JSON.stringify(result)}`,
          );
        }
        return (inner.value as T) ?? (inner as unknown as T);
      },
    },
    storage: {
      async getCookies(params = {}) {
        const payload: Record<string, unknown> = {};
        if (params.partition !== undefined) payload.partition = params.partition;
        else payload.partition = { type: "context", context: contextId };
        if (params.filter !== undefined) payload.filter = params.filter;
        const resp = await conn.send("storage.getCookies", payload);
        const result = ensureSuccess("storage.getCookies", resp) as {
          cookies?: Array<Record<string, unknown>>;
        };
        return result.cookies ?? [];
      },
    },
    events: {
      waitFor(method, opts2 = {}) {
        const timeoutMs = opts2.timeoutMs ?? DEFAULT_TIMEOUT_MS;
        return new Promise<BidiEvent>((resolve, reject) => {
          const timer = setTimeout(() => {
            reject(new Error(`Timed out waiting for BiDi event ${method}`));
          }, timeoutMs);
          conn.onEvent((event) => {
            if (event.method !== method) return;
            if (opts2.predicate && !opts2.predicate(event)) return;
            clearTimeout(timer);
            resolve(event);
          });
        });
      },
    },
    async end() {
      try {
        await conn.send("browsingContext.close", { context: contextId }, { timeoutMs: 2000 });
      } catch {
        // ignore — server may already be gone, we still need to close the socket
      }
      conn.close();
    },
  };
}
