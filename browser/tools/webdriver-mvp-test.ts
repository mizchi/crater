/**
 * WebDriver MVP Integration Test
 *
 * This script demonstrates how to communicate with the Crater browser
 * via the JSON-RPC protocol. It shows the minimal viable interaction
 * for browser automation.
 *
 * Usage:
 *   npx tsx tools/webdriver-mvp-test.ts
 */

import { spawn, ChildProcess } from 'child_process';
import * as readline from 'readline';

// JSON-RPC types
interface RpcRequest {
  jsonrpc: '2.0';
  id: number;
  method: string;
  params?: Record<string, string>;
}

interface RpcResponse {
  jsonrpc: '2.0';
  id: number;
  result?: unknown;
  error?: {
    code: number;
    message: string;
    data?: unknown;
  };
}

// RPC Client for stdio communication
class RpcClient {
  private requestId = 0;
  private pending = new Map<number, {
    resolve: (value: unknown) => void;
    reject: (error: Error) => void;
  }>();
  private process: ChildProcess | null = null;
  private rl: readline.Interface | null = null;

  async start(command: string, args: string[]): Promise<void> {
    this.process = spawn(command, args, {
      stdio: ['pipe', 'pipe', 'inherit'],
    });

    if (!this.process.stdout || !this.process.stdin) {
      throw new Error('Failed to create process with stdio');
    }

    this.rl = readline.createInterface({
      input: this.process.stdout,
      crlfDelay: Infinity,
    });

    this.rl.on('line', (line) => {
      try {
        const response: RpcResponse = JSON.parse(line);
        const pending = this.pending.get(response.id);
        if (pending) {
          this.pending.delete(response.id);
          if (response.error) {
            pending.reject(new Error(response.error.message));
          } else {
            pending.resolve(response.result);
          }
        }
      } catch (e) {
        console.error('Failed to parse response:', line);
      }
    });

    this.process.on('exit', (code) => {
      console.log(`Process exited with code ${code}`);
    });
  }

  async call(method: string, params?: Record<string, string>): Promise<unknown> {
    if (!this.process?.stdin) {
      throw new Error('Process not started');
    }

    const id = ++this.requestId;
    const request: RpcRequest = {
      jsonrpc: '2.0',
      id,
      method,
      params,
    };

    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.process!.stdin!.write(JSON.stringify(request) + '\n');
    });
  }

  close(): void {
    this.process?.kill();
    this.rl?.close();
  }
}

// Simulated test without actual MoonBit process
// This demonstrates the expected protocol interaction
async function simulatedTest(): Promise<void> {
  console.log('=== WebDriver MVP Protocol Test (Simulated) ===\n');

  // Example JSON-RPC requests that would be sent to MoonBit
  const requests: RpcRequest[] = [
    { jsonrpc: '2.0', id: 1, method: 'newContext', params: {} },
    { jsonrpc: '2.0', id: 2, method: 'goto', params: { page_id: 'ctx-1', url: 'https://example.com' } },
    { jsonrpc: '2.0', id: 3, method: 'url', params: { page_id: 'ctx-1' } },
    { jsonrpc: '2.0', id: 4, method: 'title', params: { page_id: 'ctx-1' } },
    { jsonrpc: '2.0', id: 5, method: 'screenshot', params: { page_id: 'ctx-1' } },
  ];

  // Expected responses (simulated)
  const expectedResponses: RpcResponse[] = [
    { jsonrpc: '2.0', id: 1, result: 'ctx-1' },
    { jsonrpc: '2.0', id: 2, result: null },
    { jsonrpc: '2.0', id: 3, result: 'https://example.com' },
    { jsonrpc: '2.0', id: 4, result: 'Example Domain' },
    { jsonrpc: '2.0', id: 5, result: '... ANSI text output ...' },
  ];

  console.log('Request/Response Protocol:\n');

  for (let i = 0; i < requests.length; i++) {
    const req = requests[i];
    const res = expectedResponses[i];

    console.log(`${i + 1}. ${req.method}`);
    console.log(`   Request:  ${JSON.stringify(req)}`);
    console.log(`   Response: ${JSON.stringify(res)}`);
    console.log('');
  }

  console.log('=== Available Methods ===\n');
  const methods = [
    { method: 'newContext', description: 'Create a new browser context' },
    { method: 'closeContext', description: 'Close a browser context', params: 'context_id' },
    { method: 'goto', description: 'Navigate to URL', params: 'page_id, url' },
    { method: 'goBack', description: 'Go back in history', params: 'page_id' },
    { method: 'goForward', description: 'Go forward in history', params: 'page_id' },
    { method: 'reload', description: 'Reload current page', params: 'page_id' },
    { method: 'url', description: 'Get current URL', params: 'page_id' },
    { method: 'title', description: 'Get page title', params: 'page_id' },
    { method: 'content', description: 'Get page HTML content', params: 'page_id' },
    { method: 'screenshot', description: 'Get ANSI text screenshot', params: 'page_id' },
  ];

  for (const m of methods) {
    console.log(`  ${m.method.padEnd(15)} - ${m.description}`);
    if (m.params) {
      console.log(`                    params: ${m.params}`);
    }
  }

  console.log('\n=== Method Aliases (Playwright-compatible) ===\n');
  const aliases = [
    ['Browser.createContext', 'newContext'],
    ['Page.navigate', 'goto'],
    ['Page.goBack', 'goBack'],
    ['Page.goForward', 'goForward'],
    ['Page.reload', 'reload'],
    ['Page.url', 'url'],
    ['Page.title', 'title'],
    ['Page.screenshot', 'screenshot'],
    ['Element.click', 'click'],
    ['Element.fill', 'fill'],
  ];

  for (const [alias, target] of aliases) {
    console.log(`  ${alias.padEnd(25)} -> ${target}`);
  }

  console.log('\n=== Test Complete ===');
}

// Main entry point
async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
WebDriver MVP Test

Usage:
  npx tsx tools/webdriver-mvp-test.ts           Run simulated protocol test
  npx tsx tools/webdriver-mvp-test.ts --live    Connect to live MoonBit process

Options:
  --help, -h    Show this help message
  --live        Connect to a live MoonBit WebDriver process
`);
    return;
  }

  if (args.includes('--live')) {
    console.log('Live mode not yet implemented.');
    console.log('The MoonBit WebDriver server needs to be built first.');
    console.log('');
    console.log('To test manually:');
    console.log('  1. Build the WebDriver server: moon build --target js');
    console.log('  2. Run the server: node target/js/debug/build/main/main.js');
    console.log('  3. Send JSON-RPC requests via stdin');
    return;
  }

  // Run simulated test
  await simulatedTest();
}

main().catch(console.error);
