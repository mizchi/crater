/**
 * WebDriver Server - Node.js HTTP wrapper
 *
 * This wraps the MoonBit WebDriver handler with a Node.js HTTP server.
 * It's used for integration testing the WebDriver protocol implementation.
 *
 * Usage:
 *   npx tsx tools/webdriver-server.ts [port]
 *
 * Default port: 4444
 */

import { createServer, IncomingMessage, ServerResponse } from 'http';

const PORT = parseInt(process.argv[2] || '4444', 10);

// Minimal WebDriver implementation for testing
// This mirrors the MoonBit implementation in server.mbt

interface SessionState {
  id: string;
  capabilities: {
    browserName: string;
    browserVersion: string;
    platformName: string;
    acceptInsecureCerts: boolean;
    pageLoadStrategy: string;
    timeouts: { script: number; pageLoad: number; implicit: number };
  };
  currentUrl: string;
  title: string;
  windowRect: { x: number; y: number; width: number; height: number };
}

class SessionManager {
  private sessions: Map<string, SessionState> = new Map();
  private nextId = 1;

  generateId(): string {
    return `session-${this.nextId++}`;
  }

  createSession(): { sessionId: string; capabilities: SessionState['capabilities'] } {
    const id = this.generateId();
    const capabilities = {
      browserName: 'crater',
      browserVersion: '0.1.0',
      platformName: 'MoonBit',
      acceptInsecureCerts: false,
      pageLoadStrategy: 'normal',
      timeouts: { script: 30000, pageLoad: 300000, implicit: 0 },
    };
    const state: SessionState = {
      id,
      capabilities,
      currentUrl: 'about:blank',
      title: '',
      windowRect: { x: 0, y: 0, width: 800, height: 600 },
    };
    this.sessions.set(id, state);
    return { sessionId: id, capabilities };
  }

  deleteSession(sessionId: string): boolean {
    return this.sessions.delete(sessionId);
  }

  getSession(sessionId: string): SessionState | undefined {
    return this.sessions.get(sessionId);
  }
}

const manager = new SessionManager();

function parseRoute(method: string, path: string): { command: string; params: Record<string, string> } {
  const parts = path.split('/').filter(Boolean);

  if (method === 'GET' && parts[0] === 'status') {
    return { command: 'status', params: {} };
  }
  if (method === 'POST' && parts[0] === 'session' && parts.length === 1) {
    return { command: 'newSession', params: {} };
  }
  if (parts[0] === 'session' && parts[1]) {
    const sessionId = parts[1];
    const rest = parts.slice(2);

    if (method === 'DELETE' && rest.length === 0) {
      return { command: 'deleteSession', params: { sessionId } };
    }
    if (method === 'GET' && rest.length === 0) {
      return { command: 'getSession', params: { sessionId } };
    }
    if (rest[0] === 'url') {
      return { command: method === 'GET' ? 'getCurrentUrl' : 'navigateTo', params: { sessionId } };
    }
    if (method === 'GET' && rest[0] === 'title') {
      return { command: 'getTitle', params: { sessionId } };
    }
    if (method === 'GET' && rest[0] === 'timeouts') {
      return { command: 'getTimeouts', params: { sessionId } };
    }
    if (rest[0] === 'window' && rest[1] === 'rect') {
      return { command: 'getWindowRect', params: { sessionId } };
    }
  }

  return { command: 'unknown', params: { path } };
}

function handleRequest(
  method: string,
  path: string,
  body: string
): { status: number; response: unknown } {
  const { command, params } = parseRoute(method, path);

  switch (command) {
    case 'status':
      return {
        status: 200,
        response: { value: { ready: true, message: 'Crater WebDriver is ready' } },
      };

    case 'newSession': {
      const result = manager.createSession();
      return { status: 200, response: { value: result } };
    }

    case 'deleteSession': {
      const deleted = manager.deleteSession(params.sessionId);
      if (deleted) {
        return { status: 200, response: { value: null } };
      }
      return {
        status: 404,
        response: {
          value: {
            error: 'invalid session id',
            message: `Session not found: ${params.sessionId}`,
            stacktrace: '',
          },
        },
      };
    }

    case 'getSession': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return {
          status: 200,
          response: { value: { sessionId: session.id, capabilities: session.capabilities } },
        };
      }
      return {
        status: 404,
        response: {
          value: {
            error: 'invalid session id',
            message: `Session not found: ${params.sessionId}`,
            stacktrace: '',
          },
        },
      };
    }

    case 'getCurrentUrl': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return { status: 200, response: { value: session.currentUrl } };
      }
      return {
        status: 404,
        response: {
          value: {
            error: 'invalid session id',
            message: `Session not found: ${params.sessionId}`,
            stacktrace: '',
          },
        },
      };
    }

    case 'navigateTo': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        try {
          const data = JSON.parse(body);
          session.currentUrl = data.url || 'https://example.com';
          session.title = 'Example Domain';
        } catch {
          session.currentUrl = 'https://example.com';
          session.title = 'Example Domain';
        }
        return { status: 200, response: { value: null } };
      }
      return {
        status: 404,
        response: {
          value: {
            error: 'invalid session id',
            message: `Session not found: ${params.sessionId}`,
            stacktrace: '',
          },
        },
      };
    }

    case 'getTitle': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return { status: 200, response: { value: session.title } };
      }
      return {
        status: 404,
        response: {
          value: {
            error: 'invalid session id',
            message: `Session not found: ${params.sessionId}`,
            stacktrace: '',
          },
        },
      };
    }

    case 'getTimeouts': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return { status: 200, response: { value: session.capabilities.timeouts } };
      }
      return {
        status: 404,
        response: {
          value: {
            error: 'invalid session id',
            message: `Session not found: ${params.sessionId}`,
            stacktrace: '',
          },
        },
      };
    }

    case 'getWindowRect': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return { status: 200, response: { value: session.windowRect } };
      }
      return {
        status: 404,
        response: {
          value: {
            error: 'invalid session id',
            message: `Session not found: ${params.sessionId}`,
            stacktrace: '',
          },
        },
      };
    }

    default:
      return {
        status: 404,
        response: {
          value: {
            error: 'unknown command',
            message: `Unknown command: ${path}`,
            stacktrace: '',
          },
        },
      };
  }
}

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
    });
    req.on('end', () => {
      resolve(body);
    });
  });
}

const server = createServer(async (req: IncomingMessage, res: ServerResponse) => {
  const method = req.method || 'GET';
  const path = req.url || '/';
  const body = await readBody(req);

  console.log(`${method} ${path}`);

  const { status, response } = handleRequest(method, path, body);

  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-cache',
  });
  res.end(JSON.stringify(response));
});

server.listen(PORT, () => {
  console.log(`Crater WebDriver server listening on port ${PORT}`);
  console.log(`Test with: npx tsx tools/webdriver-test.ts http://localhost:${PORT}`);
});
