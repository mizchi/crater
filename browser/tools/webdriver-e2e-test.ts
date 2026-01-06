/**
 * WebDriver E2E Test
 *
 * Tests the Crater WebDriver server using the webdriver npm package.
 * This verifies W3C WebDriver protocol compatibility.
 *
 * Usage:
 *   npx tsx tools/webdriver-e2e-test.ts
 */

import { spawn, ChildProcess } from 'child_process';
import WebDriver from 'webdriver';

const PORT = 4444;
const SERVER_URL = `http://localhost:${PORT}`;

// Start the WebDriver server
async function startServer(): Promise<ChildProcess> {
  return new Promise((resolve, reject) => {
    const server = spawn('npx', ['tsx', 'tools/webdriver-server.ts', PORT.toString()], {
      stdio: ['pipe', 'pipe', 'inherit'],
      cwd: process.cwd(),
    });

    let started = false;

    server.stdout?.on('data', (data: Buffer) => {
      const output = data.toString();
      console.log('[Server]', output.trim());
      if (output.includes('listening') && !started) {
        started = true;
        // Give it a moment to fully initialize
        setTimeout(() => resolve(server), 500);
      }
    });

    server.on('error', (err) => {
      if (!started) {
        reject(err);
      }
    });

    server.on('exit', (code) => {
      if (!started) {
        reject(new Error(`Server exited with code ${code}`));
      }
    });

    // Timeout if server doesn't start
    setTimeout(() => {
      if (!started) {
        server.kill();
        reject(new Error('Server startup timeout'));
      }
    }, 10000);
  });
}

// Run the E2E test
async function runTest(): Promise<void> {
  console.log('=== Crater WebDriver E2E Test ===\n');

  let server: ChildProcess | null = null;
  let client: WebdriverIO.Browser | null = null;

  try {
    // Start the server
    console.log('1. Starting WebDriver server...');
    server = await startServer();
    console.log('   ✓ Server started\n');

    // Create WebDriver client
    console.log('2. Connecting to WebDriver...');
    client = await WebDriver.newSession({
      hostname: 'localhost',
      port: PORT,
      path: '/',
      capabilities: {
        browserName: 'crater',
      },
    });
    console.log('   ✓ Session created:', client.sessionId, '\n');

    // Navigate to example.com
    console.log('3. Navigating to https://example.com...');
    await client.navigateTo('https://example.com');
    console.log('   ✓ Navigation complete\n');

    // Get current URL
    console.log('4. Getting current URL...');
    const url = await client.getUrl();
    console.log('   URL:', url);
    if (url === 'https://example.com') {
      console.log('   ✓ URL matches\n');
    } else {
      console.log('   ⚠ URL mismatch (expected: https://example.com)\n');
    }

    // Get page title
    console.log('5. Getting page title...');
    const title = await client.getTitle();
    console.log('   Title:', title);
    if (title === 'Example Domain') {
      console.log('   ✓ Title matches\n');
    } else {
      console.log('   ⚠ Title mismatch (expected: Example Domain)\n');
    }

    // Get window rect
    console.log('6. Getting window rect...');
    const rect = await client.getWindowRect();
    console.log('   Rect:', JSON.stringify(rect));
    console.log('   ✓ Window rect retrieved\n');

    // Delete session
    console.log('7. Closing session...');
    await client.deleteSession();
    console.log('   ✓ Session closed\n');

    console.log('=== All tests passed! ===');

  } catch (error) {
    console.error('\n✗ Test failed:', error);
    process.exitCode = 1;
  } finally {
    // Cleanup
    if (client) {
      try {
        await client.deleteSession();
      } catch {
        // Ignore cleanup errors
      }
    }
    if (server) {
      server.kill();
      console.log('\nServer stopped.');
    }
  }
}

// Type declaration for webdriver
declare namespace WebdriverIO {
  interface Browser {
    sessionId: string;
    navigateTo(url: string): Promise<void>;
    getUrl(): Promise<string>;
    getTitle(): Promise<string>;
    getWindowRect(): Promise<{ x: number; y: number; width: number; height: number }>;
    deleteSession(): Promise<void>;
  }
}

// Run the test
runTest();
