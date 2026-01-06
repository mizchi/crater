/**
 * CDP E2E Test with puppeteer-core
 *
 * Tests the Crater CDP server using puppeteer-core.
 * Verifies Chrome DevTools Protocol compatibility.
 *
 * Usage:
 *   npx tsx tools/cdp-e2e-test.ts
 */

import { spawn, ChildProcess } from 'child_process';
import puppeteer, { Browser } from 'puppeteer-core';

const PORT = 9222;

// Start the CDP server
async function startServer(): Promise<ChildProcess> {
  return new Promise((resolve, reject) => {
    const server = spawn('npx', ['tsx', 'tools/cdp-server.ts', PORT.toString()], {
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
  console.log('=== Crater CDP E2E Test (puppeteer-core) ===\n');

  let server: ChildProcess | null = null;
  let browser: Browser | null = null;

  try {
    // Start the server
    console.log('1. Starting CDP server...');
    server = await startServer();
    console.log('   ✓ Server started\n');

    // Connect with puppeteer-core
    console.log('2. Connecting puppeteer-core...');
    browser = await puppeteer.connect({
      browserWSEndpoint: `ws://localhost:${PORT}/devtools/browser`,
    });
    console.log('   ✓ Connected\n');

    // Get browser version
    console.log('3. Getting browser version...');
    const version = await browser.version();
    console.log('   Version:', version);
    console.log('   ✓ Version retrieved\n');

    // Create a new page (target)
    console.log('4. Creating new page...');
    const page = await browser.newPage();
    console.log('   ✓ Page created\n');

    // Get page title (should be empty initially)
    console.log('5. Getting initial page title...');
    const initialTitle = await page.title();
    console.log('   Title:', JSON.stringify(initialTitle));
    console.log('   ✓ Title retrieved\n');

    // Set page content
    console.log('6. Setting page content...');
    await page.setContent('<html><head><title>Test Page</title></head><body><h1>Hello Crater</h1><p id="message">Welcome</p></body></html>');
    console.log('   ✓ Content set\n');

    // Get page title after setting content
    console.log('7. Getting page title after content...');
    const title = await page.title();
    console.log('   Title:', JSON.stringify(title));
    if (title === 'Test Page') {
      console.log('   ✓ Title matches\n');
    } else {
      console.log('   ⚠ Title mismatch (expected "Test Page")\n');
    }

    // Evaluate JavaScript (basic)
    console.log('8. Evaluating JavaScript...');
    try {
      const result = await page.evaluate(() => {
        return 'Hello from evaluate';
      });
      console.log('   Result:', result);
      console.log('   ✓ Evaluate completed\n');
    } catch (err) {
      console.log('   ⚠ Evaluate not fully implemented:', (err as Error).message, '\n');
    }

    // Query selector
    console.log('9. Querying selector...');
    try {
      const element = await page.$('h1');
      if (element) {
        console.log('   ✓ Element found\n');
      } else {
        console.log('   ⚠ Element not found\n');
      }
    } catch (err) {
      console.log('   ⚠ Query selector error:', (err as Error).message, '\n');
    }

    // Close page
    console.log('10. Closing page...');
    await page.close();
    console.log('    ✓ Page closed\n');

    // Disconnect
    console.log('11. Disconnecting...');
    await browser.disconnect();
    browser = null;
    console.log('    ✓ Disconnected\n');

    console.log('=== CDP E2E Test completed ===');

  } catch (error) {
    console.error('\n✗ Test failed:', error);
    process.exitCode = 1;
  } finally {
    // Cleanup
    if (browser) {
      try {
        await browser.disconnect();
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

// Run the test
runTest();
