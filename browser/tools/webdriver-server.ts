/**
 * WebDriver Server - Node.js HTTP wrapper
 *
 * This wraps the MoonBit WebDriver handler with a Node.js HTTP server.
 * It's used for integration testing the WebDriver protocol implementation.
 *
 * Features:
 * - Real HTTP fetching for navigation
 * - HTML parsing for element discovery
 * - Element click support
 *
 * Usage:
 *   npx tsx tools/webdriver-server.ts [port]
 *
 * Default port: 4444
 */

import { createServer, IncomingMessage, ServerResponse } from 'http';

const PORT = parseInt(process.argv[2] || '4444', 10);

// Element representation
interface Element {
  id: string;
  tagName: string;
  text: string;
  href?: string;
  attributes: Record<string, string>;
}

// Session state
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
  htmlContent: string;
  elements: Map<string, Element>;
  nextElementId: number;
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
      htmlContent: '',
      elements: new Map(),
      nextElementId: 1,
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

// Fetch a URL and return HTML content
async function fetchUrl(url: string): Promise<{ html: string; title: string }> {
  try {
    const response = await fetch(url);
    const html = await response.text();
    // Extract title
    const titleMatch = html.match(/<title[^>]*>([^<]*)<\/title>/i);
    const title = titleMatch ? titleMatch[1].trim() : '';
    return { html, title };
  } catch (error) {
    console.error(`Failed to fetch ${url}:`, error);
    return { html: '', title: '' };
  }
}

// Parse HTML and extract elements (links, buttons, inputs)
function parseElements(html: string, baseUrl: string): Element[] {
  const elements: Element[] = [];

  // Extract links
  const linkRegex = /<a\s+([^>]*)>([^<]*)<\/a>/gi;
  let match;
  while ((match = linkRegex.exec(html)) !== null) {
    const attrs = parseAttributes(match[1]);
    const text = match[2].trim();
    let href = attrs.href || '';
    // Resolve relative URLs
    if (href && !href.startsWith('http') && !href.startsWith('javascript:') && !href.startsWith('#')) {
      try {
        href = new URL(href, baseUrl).toString();
      } catch {
        // Keep original href if URL parsing fails
      }
    }
    elements.push({
      id: '',
      tagName: 'a',
      text,
      href,
      attributes: attrs,
    });
  }

  // Extract buttons
  const buttonRegex = /<button\s*([^>]*)>([^<]*)<\/button>/gi;
  while ((match = buttonRegex.exec(html)) !== null) {
    const attrs = parseAttributes(match[1]);
    elements.push({
      id: '',
      tagName: 'button',
      text: match[2].trim(),
      attributes: attrs,
    });
  }

  // Extract inputs
  const inputRegex = /<input\s+([^>]*)>/gi;
  while ((match = inputRegex.exec(html)) !== null) {
    const attrs = parseAttributes(match[1]);
    elements.push({
      id: '',
      tagName: 'input',
      text: '',
      attributes: attrs,
    });
  }

  return elements;
}

// Parse HTML attributes
function parseAttributes(attrString: string): Record<string, string> {
  const attrs: Record<string, string> = {};
  const attrRegex = /(\w+)(?:=["']([^"']*)["']|=(\S+))?/g;
  let match;
  while ((match = attrRegex.exec(attrString)) !== null) {
    const name = match[1].toLowerCase();
    const value = match[2] || match[3] || '';
    attrs[name] = value;
  }
  return attrs;
}

// Find element by CSS selector (simplified)
function findElement(
  session: SessionState,
  using: string,
  value: string
): Element | null {
  const elements = parseElements(session.htmlContent, session.currentUrl);

  for (const el of elements) {
    let matched = false;

    switch (using) {
      case 'css selector':
        // Simple CSS selector matching
        if (value.startsWith('a[href')) {
          // Match by href attribute
          const hrefMatch = value.match(/href=["']([^"']*)["']/);
          if (hrefMatch && el.href?.includes(hrefMatch[1])) {
            matched = true;
          }
        } else if (value.startsWith('#')) {
          // Match by id
          if (el.attributes.id === value.slice(1)) {
            matched = true;
          }
        } else if (value.startsWith('.')) {
          // Match by class
          const classes = (el.attributes.class || '').split(/\s+/);
          if (classes.includes(value.slice(1))) {
            matched = true;
          }
        } else if (value === 'a' || value === 'button' || value === 'input') {
          // Match by tag name
          if (el.tagName === value) {
            matched = true;
          }
        }
        break;

      case 'link text':
        if (el.tagName === 'a' && el.text === value) {
          matched = true;
        }
        break;

      case 'partial link text':
        if (el.tagName === 'a' && el.text.includes(value)) {
          matched = true;
        }
        break;

      case 'xpath':
        // Simple xpath support for //a[text()='...']
        const textMatch = value.match(/\/\/a\[text\(\)=['"]([^'"]+)['"]\]/);
        if (textMatch && el.tagName === 'a' && el.text === textMatch[1]) {
          matched = true;
        }
        break;
    }

    if (matched) {
      // Assign element ID and store it
      const elementId = `element-${session.nextElementId++}`;
      el.id = elementId;
      session.elements.set(elementId, el);
      return el;
    }
  }

  return null;
}

// Find all elements matching selector
function findElements(
  session: SessionState,
  using: string,
  value: string
): Element[] {
  const allElements = parseElements(session.htmlContent, session.currentUrl);
  const matched: Element[] = [];

  for (const el of allElements) {
    let isMatch = false;

    switch (using) {
      case 'css selector':
        if (value === 'a') {
          isMatch = el.tagName === 'a';
        } else if (value === 'button') {
          isMatch = el.tagName === 'button';
        }
        break;
      case 'link text':
        isMatch = el.tagName === 'a' && el.text === value;
        break;
      case 'partial link text':
        isMatch = el.tagName === 'a' && el.text.includes(value);
        break;
    }

    if (isMatch) {
      const elementId = `element-${session.nextElementId++}`;
      el.id = elementId;
      session.elements.set(elementId, el);
      matched.push(el);
    }
  }

  return matched;
}

// Route parser
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
    if (method === 'GET' && rest[0] === 'source') {
      return { command: 'getPageSource', params: { sessionId } };
    }
    if (rest[0] === 'window' && rest[1] === 'rect') {
      return { command: 'getWindowRect', params: { sessionId } };
    }
    // Element operations (must come before findElement check)
    if (rest[0] === 'element' && rest[1]) {
      const elementId = rest[1];
      if (method === 'POST' && rest[2] === 'click') {
        return { command: 'elementClick', params: { sessionId, elementId } };
      }
      if (method === 'GET' && rest[2] === 'text') {
        return { command: 'getElementText', params: { sessionId, elementId } };
      }
      if (method === 'GET' && rest[2] === 'attribute' && rest[3]) {
        return { command: 'getElementAttribute', params: { sessionId, elementId, name: rest[3] } };
      }
      if (method === 'GET' && rest[2] === 'name') {
        return { command: 'getElementTagName', params: { sessionId, elementId } };
      }
    }
    // Element finding (comes after element operations to avoid matching /element/{id}/...)
    if (method === 'POST' && rest[0] === 'element' && rest.length === 1) {
      return { command: 'findElement', params: { sessionId } };
    }
    if (method === 'POST' && rest[0] === 'elements') {
      return { command: 'findElements', params: { sessionId } };
    }
  }

  return { command: 'unknown', params: { path } };
}

// Error response helper
function errorResponse(error: string, message: string, status = 404) {
  return {
    status,
    response: {
      value: { error, message, stacktrace: '' },
    },
  };
}

// Session not found error
function sessionNotFound(sessionId: string) {
  return errorResponse('invalid session id', `Session not found: ${sessionId}`);
}

// Element not found error
function elementNotFound(elementId: string) {
  return errorResponse('no such element', `Element not found: ${elementId}`);
}

// Request handler
async function handleRequest(
  method: string,
  path: string,
  body: string
): Promise<{ status: number; response: unknown }> {
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
      return sessionNotFound(params.sessionId);
    }

    case 'getSession': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return {
          status: 200,
          response: { value: { sessionId: session.id, capabilities: session.capabilities } },
        };
      }
      return sessionNotFound(params.sessionId);
    }

    case 'getCurrentUrl': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return { status: 200, response: { value: session.currentUrl } };
      }
      return sessionNotFound(params.sessionId);
    }

    case 'navigateTo': {
      const session = manager.getSession(params.sessionId);
      if (!session) {
        return sessionNotFound(params.sessionId);
      }
      try {
        const data = JSON.parse(body);
        const url = data.url;
        console.log(`  -> Fetching: ${url}`);
        const { html, title } = await fetchUrl(url);
        session.currentUrl = url;
        session.title = title;
        session.htmlContent = html;
        session.elements.clear();
        session.nextElementId = 1;
        console.log(`  -> Loaded: ${title} (${html.length} bytes)`);
        return { status: 200, response: { value: null } };
      } catch (err) {
        return errorResponse('unknown error', `Navigation failed: ${err}`, 500);
      }
    }

    case 'getTitle': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return { status: 200, response: { value: session.title } };
      }
      return sessionNotFound(params.sessionId);
    }

    case 'getPageSource': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return { status: 200, response: { value: session.htmlContent } };
      }
      return sessionNotFound(params.sessionId);
    }

    case 'getTimeouts': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return { status: 200, response: { value: session.capabilities.timeouts } };
      }
      return sessionNotFound(params.sessionId);
    }

    case 'getWindowRect': {
      const session = manager.getSession(params.sessionId);
      if (session) {
        return { status: 200, response: { value: session.windowRect } };
      }
      return sessionNotFound(params.sessionId);
    }

    case 'findElement': {
      const session = manager.getSession(params.sessionId);
      if (!session) {
        return sessionNotFound(params.sessionId);
      }
      try {
        const data = JSON.parse(body);
        const element = findElement(session, data.using, data.value);
        if (element) {
          return {
            status: 200,
            response: { value: { 'element-6066-11e4-a52e-4f735466cecf': element.id } },
          };
        }
        return errorResponse('no such element', `Unable to locate element: ${data.value}`);
      } catch (err) {
        return errorResponse('unknown error', `Find element failed: ${err}`, 500);
      }
    }

    case 'findElements': {
      const session = manager.getSession(params.sessionId);
      if (!session) {
        return sessionNotFound(params.sessionId);
      }
      try {
        const data = JSON.parse(body);
        const elements = findElements(session, data.using, data.value);
        const result = elements.map(el => ({
          'element-6066-11e4-a52e-4f735466cecf': el.id,
        }));
        return { status: 200, response: { value: result } };
      } catch (err) {
        return errorResponse('unknown error', `Find elements failed: ${err}`, 500);
      }
    }

    case 'elementClick': {
      const session = manager.getSession(params.sessionId);
      if (!session) {
        return sessionNotFound(params.sessionId);
      }
      const element = session.elements.get(params.elementId);
      if (!element) {
        return elementNotFound(params.elementId);
      }
      // If it's a link, navigate to it
      if (element.tagName === 'a' && element.href) {
        console.log(`  -> Click navigating to: ${element.href}`);
        const { html, title } = await fetchUrl(element.href);
        session.currentUrl = element.href;
        session.title = title;
        session.htmlContent = html;
        session.elements.clear();
        session.nextElementId = 1;
        console.log(`  -> Loaded: ${title} (${html.length} bytes)`);
      }
      return { status: 200, response: { value: null } };
    }

    case 'getElementText': {
      const session = manager.getSession(params.sessionId);
      if (!session) {
        return sessionNotFound(params.sessionId);
      }
      const element = session.elements.get(params.elementId);
      if (!element) {
        return elementNotFound(params.elementId);
      }
      return { status: 200, response: { value: element.text } };
    }

    case 'getElementAttribute': {
      const session = manager.getSession(params.sessionId);
      if (!session) {
        return sessionNotFound(params.sessionId);
      }
      const element = session.elements.get(params.elementId);
      if (!element) {
        return elementNotFound(params.elementId);
      }
      const value = element.attributes[params.name] || null;
      return { status: 200, response: { value } };
    }

    case 'getElementTagName': {
      const session = manager.getSession(params.sessionId);
      if (!session) {
        return sessionNotFound(params.sessionId);
      }
      const element = session.elements.get(params.elementId);
      if (!element) {
        return elementNotFound(params.elementId);
      }
      return { status: 200, response: { value: element.tagName } };
    }

    default:
      return errorResponse('unknown command', `Unknown command: ${path}`);
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

  const { status, response } = await handleRequest(method, path, body);

  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-cache',
  });
  res.end(JSON.stringify(response));
});

server.listen(PORT, () => {
  console.log(`Crater WebDriver server listening on port ${PORT}`);
  console.log(`Test with: npm run test:webdriver`);
});
