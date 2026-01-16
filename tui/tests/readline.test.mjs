/**
 * Automated tests for readline functionality
 * Tests stdin input handling with mode transitions
 */

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import assert from 'node:assert';
import { describe, it, before } from 'node:test';

const __dirname = dirname(fileURLToPath(import.meta.url));
const tuiDir = join(__dirname, '..');

/**
 * Helper to run a MoonBit JS program and interact with it
 */
function runProgram(jsPath, options = {}) {
  const { timeout = 10000, inputs = [], inputDelay = 100, successMarker = '[DONE]' } = options;

  return new Promise((resolve, reject) => {
    const proc = spawn('node', [jsPath], {
      cwd: tuiDir,
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    let inputIndex = 0;
    let resolved = false;

    const finish = () => {
      if (resolved) return;
      resolved = true;
      clearTimeout(timer);
      proc.kill();
      resolve({ code: 0, stdout, stderr });
    };

    proc.stdout.on('data', (data) => {
      stdout += data.toString();
      // Check for success marker to finish early
      if (successMarker && stdout.includes(successMarker)) {
        setTimeout(finish, 100);  // Small delay to capture any remaining output
      }
    });

    proc.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    // Send inputs with delay
    const sendNextInput = () => {
      if (inputIndex < inputs.length) {
        const input = inputs[inputIndex];
        inputIndex++;
        proc.stdin.write(input + '\n');
        setTimeout(sendNextInput, inputDelay);
      } else {
        // Close stdin after all inputs sent
        setTimeout(() => proc.stdin.end(), inputDelay);
      }
    };

    // Start sending inputs after a small delay
    setTimeout(sendNextInput, 100);

    const timer = setTimeout(() => {
      if (resolved) return;
      proc.kill();
      // If we got the success marker, consider it a success
      if (successMarker && stdout.includes(successMarker)) {
        resolved = true;
        resolve({ code: 0, stdout, stderr });
      } else {
        reject(new Error(`Timeout after ${timeout}ms\nstdout: ${stdout}\nstderr: ${stderr}`));
      }
    }, timeout);

    proc.on('close', (code) => {
      if (resolved) return;
      resolved = true;
      clearTimeout(timer);
      resolve({ code, stdout, stderr });
    });

    proc.on('error', (err) => {
      if (resolved) return;
      resolved = true;
      clearTimeout(timer);
      reject(err);
    });
  });
}

describe('readline tests', () => {
  const readlineTestPath = join(tuiDir, 'target/js/release/build/examples/readline-test/readline-test.js');

  it('should handle double readline inputs', async () => {
    const result = await runProgram(readlineTestPath, {
      inputs: ['first', 'second'],
      timeout: 15000,
      inputDelay: 200,
    });

    // Check that both inputs were received
    assert.match(result.stdout, /\[OK\] First: "first"/, 'First input should be received');
    assert.match(result.stdout, /\[OK\] Second: "second"/, 'Second input should be received');
    assert.match(result.stdout, /\[DONE\] Test complete/, 'Test should complete');
  });

  it('should handle empty input (use initial value)', async () => {
    // Create a simple test that checks empty input handling
    const result = await runProgram(readlineTestPath, {
      inputs: ['', 'hello'],  // First input is empty
      timeout: 15000,
      inputDelay: 200,
    });

    // Empty input should result in empty string (initial was "")
    assert.match(result.stdout, /\[OK\] First: ""/, 'Empty input should use initial value');
    assert.match(result.stdout, /\[OK\] Second: "hello"/, 'Second input should work');
  });

  it('should handle Japanese input (UTF-8)', async () => {
    const result = await runProgram(readlineTestPath, {
      inputs: ['日本語', 'テスト'],
      timeout: 15000,
      inputDelay: 200,
    });

    assert.match(result.stdout, /\[OK\] First: "日本語"/, 'Japanese input should be received');
    assert.match(result.stdout, /\[OK\] Second: "テスト"/, 'Second Japanese input should work');
  });

  it('should handle multiple rapid inputs', async () => {
    const result = await runProgram(readlineTestPath, {
      inputs: ['a', 'b'],
      timeout: 15000,
      inputDelay: 50,  // Faster inputs
    });

    assert.match(result.stdout, /\[OK\] First: "a"/, 'First rapid input should work');
    assert.match(result.stdout, /\[OK\] Second: "b"/, 'Second rapid input should work');
  });
});

describe('stdin state management', () => {
  const readlineTestPath = join(tuiDir, 'target/js/release/build/examples/readline-test/readline-test.js');

  it('should properly handle multiple readline sessions', async () => {
    const result = await runProgram(readlineTestPath, {
      inputs: ['test1', 'test2'],
      timeout: 15000,
      inputDelay: 200,
    });

    // Both inputs should be received successfully
    assert.match(result.stdout, /\[OK\] First: "test1"/, 'First input should be received');
    assert.match(result.stdout, /\[OK\] Second: "test2"/, 'Second input should be received');
    assert.match(result.stdout, /\[DONE\] Test complete/, 'Test should complete');
  });

  it('should complete both inputs without premature cancellation', async () => {
    const result = await runProgram(readlineTestPath, {
      inputs: ['x', 'y'],
      timeout: 15000,
      inputDelay: 200,
    });

    // Both inputs should complete (not be cancelled)
    assert.match(result.stdout, /\[OK\] First: "x"/, 'First input should complete');
    assert.match(result.stdout, /\[OK\] Second: "y"/, 'Second input should complete');
    // Should not see "Cancelled" for either input
    assert.doesNotMatch(result.stdout, /First: Cancelled/, 'First input should not be cancelled');
    assert.doesNotMatch(result.stdout, /Second: Cancelled/, 'Second input should not be cancelled');
  });
});
