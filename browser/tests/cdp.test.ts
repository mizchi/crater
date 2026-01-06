/**
 * CDP E2E Tests with Vitest
 *
 * Tests the Crater CDP server using puppeteer-core.
 * Verifies Chrome DevTools Protocol compatibility.
 */

import { spawn, ChildProcess } from 'child_process';
import puppeteer, { Browser, Page } from 'puppeteer-core';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';

const PORT = 9224;

let server: ChildProcess | null = null;
let browser: Browser | null = null;
let page: Page | null = null;

// Start the CDP server
async function startServer(): Promise<ChildProcess> {
  return new Promise((resolve, reject) => {
    const serverProcess = spawn('npx', ['tsx', 'tools/cdp-server.ts', PORT.toString()], {
      stdio: ['pipe', 'pipe', 'inherit'],
      cwd: process.cwd(),
    });

    let started = false;

    serverProcess.stdout?.on('data', (data: Buffer) => {
      const output = data.toString();
      if (output.includes('listening') && !started) {
        started = true;
        setTimeout(() => resolve(serverProcess), 500);
      }
    });

    serverProcess.on('error', (err) => {
      if (!started) reject(err);
    });

    serverProcess.on('exit', (code) => {
      if (!started) reject(new Error(`Server exited with code ${code}`));
    });

    setTimeout(() => {
      if (!started) {
        serverProcess.kill();
        reject(new Error('Server startup timeout'));
      }
    }, 10000);
  });
}

describe('CDP Protocol', () => {
  beforeAll(async () => {
    server = await startServer();
    browser = await puppeteer.connect({
      browserWSEndpoint: `ws://localhost:${PORT}/devtools/browser`,
    });
    // Create a single page for all tests
    page = await browser.newPage();
  });

  afterAll(async () => {
    if (browser) {
      try {
        await browser.disconnect();
      } catch {
        // Ignore cleanup errors
      }
    }
    if (server) {
      server.kill();
    }
  });

  describe('Browser', () => {
    it('should return browser version', async () => {
      const version = await browser!.version();
      expect(version).toBe('Crater/1.0');
    });
  });

  describe('Page basics', () => {
    it('should have a page defined', async () => {
      expect(page).toBeDefined();
    });

    it('should set content and update title', async () => {
      await page!.setContent('<html><head><title>Test Page</title></head><body><h1>Hello</h1></body></html>');
      const title = await page!.title();
      expect(title).toBe('Test Page');
    });

    it('should evaluate JavaScript and return string', async () => {
      const result = await page!.evaluate(() => {
        return 'Hello from evaluate';
      });
      expect(result).toBe('Hello from evaluate');
    });

    it('should find element with querySelector', async () => {
      await page!.setContent('<html><body><h1>Hello</h1><p>World</p></body></html>');
      const h1 = await page!.$('h1');
      expect(h1).not.toBeNull();
    });

    it('should find paragraph element', async () => {
      await page!.setContent('<html><body><p id="test">Test paragraph</p></body></html>');
      const p = await page!.$('p');
      expect(p).not.toBeNull();
    });
  });

  describe('Navigation with real content', () => {
    it('should load example.com content and get title', async () => {
      const response = await fetch('https://example.com');
      const html = await response.text();
      await page!.setContent(html);

      const title = await page!.title();
      expect(title).toBe('Example Domain');
    });

    it('should find h1 element in example.com', async () => {
      // Re-set content to ensure fresh state
      const response = await fetch('https://example.com');
      const html = await response.text();
      await page!.setContent(html);

      const h1 = await page!.$('h1');
      expect(h1).not.toBeNull();
    });

    it('should get h1 text content via direct query', async () => {
      // Re-set content to ensure fresh state
      const response = await fetch('https://example.com');
      const html = await response.text();
      await page!.setContent(html);

      // Query and get textContent in a single evaluate call
      // This bypasses element handle passing
      const h1Text = await page!.evaluate(() => {
        const h1 = document.querySelector('h1');
        return h1?.textContent ?? null;
      });
      expect(h1Text).toContain('Example Domain');
    });

    it('should find paragraph element in example.com', async () => {
      // Re-set content to ensure fresh state
      const response = await fetch('https://example.com');
      const html = await response.text();
      await page!.setContent(html);

      const p = await page!.$('p');
      expect(p).not.toBeNull();
    });
  });
});
