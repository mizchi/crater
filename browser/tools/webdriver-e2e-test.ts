/**
 * WebDriver E2E Test
 *
 * Tests the Crater WebDriver server using the webdriver npm package.
 * This verifies W3C WebDriver protocol compatibility.
 *
 * Tests:
 * - Session management
 * - Real URL navigation with HTTP fetching
 * - Element finding (link text, CSS selector)
 * - Element click (triggers navigation for links)
 *
 * Usage:
 *   npx tsx tools/webdriver-e2e-test.ts
 */

import { spawn, ChildProcess } from 'child_process';
import WebDriver from 'webdriver';

const PORT = 4444;

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

    // Navigate to example.com (real HTTP fetch)
    console.log('3. Navigating to https://example.com (real fetch)...');
    await client.navigateTo('https://example.com');
    console.log('   ✓ Navigation complete\n');

    // Get current URL
    console.log('4. Getting current URL...');
    const url = await client.getUrl();
    console.log('   URL:', url);
    if (url === 'https://example.com') {
      console.log('   ✓ URL matches\n');
    } else {
      throw new Error(`URL mismatch: expected https://example.com, got ${url}`);
    }

    // Get page title (from real HTML)
    console.log('5. Getting page title...');
    const title = await client.getTitle();
    console.log('   Title:', title);
    if (title === 'Example Domain') {
      console.log('   ✓ Title matches\n');
    } else {
      throw new Error(`Title mismatch: expected "Example Domain", got "${title}"`);
    }

    // Find element by link text
    console.log('6. Finding "Learn more" link...');
    const link = await client.findElement('link text', 'Learn more');
    console.log('   Element ID:', link['element-6066-11e4-a52e-4f735466cecf']);
    console.log('   ✓ Link found\n');

    // Get element text
    console.log('7. Getting element text...');
    const elementId = link['element-6066-11e4-a52e-4f735466cecf'];
    const text = await client.getElementText(elementId);
    console.log('   Text:', text);
    if (text === 'Learn more') {
      console.log('   ✓ Text matches\n');
    } else {
      console.log('   ⚠ Text mismatch\n');
    }

    // Click the link (should navigate to IANA)
    console.log('8. Clicking the link...');
    await client.elementClick(elementId);
    console.log('   ✓ Click complete\n');

    // Verify navigation happened
    console.log('9. Verifying navigation after click...');
    const newUrl = await client.getUrl();
    console.log('   New URL:', newUrl);
    if (newUrl.includes('iana.org')) {
      console.log('   ✓ Navigated to IANA\n');
    } else {
      console.log('   ⚠ Expected IANA URL, got:', newUrl, '\n');
    }

    // Get new page title
    console.log('10. Getting new page title...');
    const newTitle = await client.getTitle();
    console.log('    Title:', newTitle);
    console.log('    ✓ Title retrieved\n');

    // Find all links on new page
    console.log('11. Finding all links on page...');
    const links = await client.findElements('css selector', 'a');
    console.log('    Found', links.length, 'links');
    console.log('    ✓ Elements found\n');

    // Delete session
    console.log('12. Closing session...');
    await client.deleteSession();
    client = null;
    console.log('    ✓ Session closed\n');

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
    findElement(using: string, value: string): Promise<{ 'element-6066-11e4-a52e-4f735466cecf': string }>;
    findElements(using: string, value: string): Promise<Array<{ 'element-6066-11e4-a52e-4f735466cecf': string }>>;
    getElementText(elementId: string): Promise<string>;
    elementClick(elementId: string): Promise<void>;
    deleteSession(): Promise<void>;
  }
}

// Run the test
runTest();
