/**
 * WebDriver Protocol Connectivity Test
 *
 * This script tests the WebDriver protocol implementation by making
 * actual HTTP requests to a WebDriver server.
 *
 * Usage:
 *   npx tsx tools/webdriver-test.ts [server-url]
 *
 * Default server URL: http://localhost:4444
 */

const SERVER_URL = process.argv[2] || 'http://localhost:4444';

interface WebDriverResponse<T = unknown> {
  value: T | { error: string; message: string; stacktrace: string };
}

async function request<T>(
  method: 'GET' | 'POST' | 'DELETE',
  path: string,
  body?: object
): Promise<{ status: number; data: WebDriverResponse<T> }> {
  const url = `${SERVER_URL}${path}`;
  const options: RequestInit = {
    method,
    headers: {
      'Content-Type': 'application/json',
    },
  };
  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(url, options);
  const data = await response.json() as WebDriverResponse<T>;
  return { status: response.status, data };
}

async function test(name: string, fn: () => Promise<void>): Promise<boolean> {
  try {
    await fn();
    console.log(`✅ ${name}`);
    return true;
  } catch (error) {
    console.log(`❌ ${name}`);
    console.log(`   Error: ${error}`);
    return false;
  }
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEq<T>(actual: T, expected: T, message?: string): void {
  if (actual !== expected) {
    throw new Error(message || `Expected ${expected}, got ${actual}`);
  }
}

async function main() {
  console.log(`Testing WebDriver server at ${SERVER_URL}\n`);

  let passed = 0;
  let failed = 0;
  let sessionId: string | null = null;

  // Test 1: Status endpoint
  if (await test('GET /status returns ready', async () => {
    const { status, data } = await request('GET', '/status');
    assertEq(status, 200);
    assert(typeof data.value === 'object' && data.value !== null, 'value should be an object');
    const value = data.value as { ready: boolean; message: string };
    assertEq(value.ready, true);
  })) passed++; else failed++;

  // Test 2: Create session
  if (await test('POST /session creates new session', async () => {
    const { status, data } = await request<{ sessionId: string; capabilities: object }>('POST', '/session', {
      capabilities: {
        alwaysMatch: {},
        firstMatch: [{}]
      }
    });
    assertEq(status, 200);
    const value = data.value as { sessionId: string; capabilities: object };
    assert(typeof value.sessionId === 'string', 'sessionId should be a string');
    assert(typeof value.capabilities === 'object', 'capabilities should be an object');
    sessionId = value.sessionId;
    console.log(`   Session ID: ${sessionId}`);
  })) passed++; else failed++;

  if (!sessionId) {
    console.log('\n⚠️ Cannot continue tests without a session');
    process.exit(1);
  }

  // Test 3: Get current URL
  if (await test(`GET /session/${sessionId}/url returns URL`, async () => {
    const { status, data } = await request<string>('GET', `/session/${sessionId}/url`);
    assertEq(status, 200);
    assert(typeof data.value === 'string', 'value should be a string');
  })) passed++; else failed++;

  // Test 4: Navigate to URL
  if (await test(`POST /session/${sessionId}/url navigates`, async () => {
    const { status } = await request('POST', `/session/${sessionId}/url`, {
      url: 'https://example.com'
    });
    assertEq(status, 200);
  })) passed++; else failed++;

  // Test 5: Get title
  if (await test(`GET /session/${sessionId}/title returns title`, async () => {
    const { status, data } = await request<string>('GET', `/session/${sessionId}/title`);
    assertEq(status, 200);
    assert(typeof data.value === 'string', 'value should be a string');
  })) passed++; else failed++;

  // Test 6: Get window rect
  if (await test(`GET /session/${sessionId}/window/rect returns dimensions`, async () => {
    const { status, data } = await request<{ x: number; y: number; width: number; height: number }>(
      'GET',
      `/session/${sessionId}/window/rect`
    );
    assertEq(status, 200);
    const value = data.value as { x: number; y: number; width: number; height: number };
    assert(typeof value.width === 'number', 'width should be a number');
    assert(typeof value.height === 'number', 'height should be a number');
  })) passed++; else failed++;

  // Test 7: Get timeouts
  if (await test(`GET /session/${sessionId}/timeouts returns timeouts`, async () => {
    const { status, data } = await request<{ script: number; pageLoad: number; implicit: number }>(
      'GET',
      `/session/${sessionId}/timeouts`
    );
    assertEq(status, 200);
    const value = data.value as { script: number; pageLoad: number; implicit: number };
    assert(typeof value.script === 'number', 'script timeout should be a number');
    assert(typeof value.pageLoad === 'number', 'pageLoad timeout should be a number');
  })) passed++; else failed++;

  // Test 8: Delete session
  if (await test(`DELETE /session/${sessionId} deletes session`, async () => {
    const { status, data } = await request('DELETE', `/session/${sessionId}`);
    assertEq(status, 200);
    assertEq(data.value, null);
  })) passed++; else failed++;

  // Test 9: Access deleted session should fail
  if (await test(`GET /session/${sessionId}/url on deleted session returns 404`, async () => {
    const { status, data } = await request('GET', `/session/${sessionId}/url`);
    assertEq(status, 404);
    const value = data.value as { error: string };
    assertEq(value.error, 'invalid session id');
  })) passed++; else failed++;

  // Test 10: Unknown endpoint
  if (await test('GET /unknown returns 404', async () => {
    const { status, data } = await request('GET', '/unknown/path');
    assertEq(status, 404);
    const value = data.value as { error: string };
    assertEq(value.error, 'unknown command');
  })) passed++; else failed++;

  // Summary
  console.log(`\n${'='.repeat(40)}`);
  console.log(`Results: ${passed} passed, ${failed} failed`);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
