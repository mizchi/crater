/**
 * Test form input with cooked mode
 * This tests the full cycle: Enter -> edit -> input -> confirm -> display
 */

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import assert from 'node:assert';
import { describe, it } from 'node:test';

const __dirname = dirname(fileURLToPath(import.meta.url));
const tuiDir = join(__dirname, '..');

/**
 * Run the form program with simulated key inputs
 */
function runFormWithInputs(inputs, options = {}) {
  const { timeout = 15000, inputDelay = 300 } = options;

  return new Promise((resolve, reject) => {
    const formPath = join(tuiDir, 'target/js/release/build/examples/form/form.js');
    const proc = spawn('node', [formPath], {
      cwd: tuiDir,
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    let inputIndex = 0;
    let resolved = false;

    const finish = (success) => {
      if (resolved) return;
      resolved = true;
      clearTimeout(timer);
      proc.kill();
      resolve({ success, stdout, stderr });
    };

    proc.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    proc.stderr.on('data', (data) => {
      stderr += data.toString();
      // Check for completion markers in debug output
      if (stderr.includes('restore_tui: 7.')) {
        setTimeout(() => finish(true), 200);
      }
    });

    // Send inputs with delay
    const sendNextInput = () => {
      if (inputIndex < inputs.length) {
        const input = inputs[inputIndex];
        inputIndex++;

        if (typeof input === 'string') {
          // Send as raw bytes
          proc.stdin.write(input);
        } else if (input.key) {
          // Send special key
          proc.stdin.write(input.key);
        }

        setTimeout(sendNextInput, inputDelay);
      } else {
        // Wait a bit then finish
        setTimeout(() => finish(true), 500);
      }
    };

    // Start after initial render
    setTimeout(sendNextInput, 500);

    const timer = setTimeout(() => {
      if (resolved) return;
      finish(false);
    }, timeout);

    proc.on('close', () => {
      finish(true);
    });

    proc.on('error', (err) => {
      reject(err);
    });
  });
}

describe('form cooked mode input', () => {
  it('should show debug logs for input cycle', async () => {
    // Tab to focus on name-input, Enter to edit, type text, Enter to confirm
    const result = await runFormWithInputs([
      '\t',           // Tab to focus name-input
      '\r',           // Enter to start editing
      'Hello',        // Type text
      '\n',           // Enter to confirm
    ], {
      timeout: 10000,
      inputDelay: 300,
    });

    console.log('=== STDERR (debug logs) ===');
    console.log(result.stderr);
    console.log('=== END STDERR ===');

    // Check that restore_tui was called with the value
    assert.match(result.stderr, /restore_tui: 1\. called/, 'restore_tui should be called');
    assert.match(result.stderr, /restore_tui: 2\. name=/, 'name should be logged');
  });
});
