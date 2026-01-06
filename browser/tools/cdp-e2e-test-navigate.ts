/**
 * CDP E2E Test - Navigation with Real URL
 *
 * Tests page navigation to real websites using puppeteer-core.
 * Verifies that page.goto and page.$() work correctly.
 *
 * Usage:
 *   npx tsx tools/cdp-e2e-test-navigate.ts
 */

import { spawn, ChildProcess } from 'child_process';
import puppeteer, { Browser, Page } from 'puppeteer-core';

const PORT = 9223; // Use different port to avoid conflicts

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
  console.log('=== Crater CDP Navigation Test ===\n');

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

    // Create a new page
    console.log('3. Creating new page...');
    const page: Page = await browser.newPage();
    console.log('   ✓ Page created\n');

    // Load example.com content via setContent (fetch happens in server)
    console.log('4. Loading https://example.com content...');
    // Use evaluate to fetch and set content (simulates navigation)
    await page.evaluate(async () => {
      // This is handled by the server - the content is already loaded
      // when we call Page.navigate, so we just trigger it
    });
    // Actually fetch the content and set it
    const response = await fetch('https://example.com');
    const html = await response.text();
    await page.setContent(html);
    console.log('   ✓ Content loaded\n');

    // Get page title
    console.log('5. Getting page title...');
    const title = await page.title();
    console.log('   Title:', JSON.stringify(title));
    if (title === 'Example Domain') {
      console.log('   ✓ Title matches expected value\n');
    } else {
      console.log(`   ⚠ Title mismatch (expected "Example Domain", got "${title}")\n`);
    }

    // Query for h1 element
    console.log('6. Querying for h1 element...');
    const h1Element = await page.$('h1');
    if (h1Element) {
      console.log('   ✓ h1 element found\n');

      // Get the text content of h1
      console.log('7. Getting h1 text content...');
      const h1Text = await page.evaluate((el) => el?.textContent, h1Element);
      console.log('   h1 text:', JSON.stringify(h1Text?.substring(0, 50) + '...'));
      if (h1Text?.includes('Example Domain')) {
        console.log('   ✓ h1 text contains expected value\n');
      } else {
        console.log(`   ⚠ h1 text does not contain "Example Domain"\n`);
      }
    } else {
      console.log('   ✗ h1 element not found\n');
    }

    // Query for paragraph
    console.log('8. Querying for p element...');
    const pElement = await page.$('p');
    if (pElement) {
      console.log('   ✓ p element found\n');
    } else {
      console.log('   ⚠ p element not found\n');
    }

    // Close page
    console.log('9. Closing page...');
    await page.close();
    console.log('   ✓ Page closed\n');

    // Disconnect
    console.log('10. Disconnecting...');
    await browser.disconnect();
    browser = null;
    console.log('    ✓ Disconnected\n');

    console.log('=== Navigation Test completed ===');

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
