#!/usr/bin/env node
/**
 * Test MoonBit form by spawning the process and simulating input
 */

const { spawn } = require('child_process');
const path = require('path');

const tuiDir = __dirname;

console.log('Building MoonBit form...');

const build = spawn('moon', ['build', 'examples/form', '--target', 'js'], {
  cwd: tuiDir,
  stdio: 'inherit'
});

build.on('close', (code) => {
  if (code !== 0) {
    console.error('Build failed');
    process.exit(1);
  }

  console.log('\nRunning form with simulated input...\n');

  const jsPath = path.join(tuiDir, 'target/js/release/build/examples/form/form.js');

  const child = spawn('node', [jsPath], {
    stdio: ['pipe', 'pipe', 'pipe']
  });

  let stdout = '';
  let stderr = '';

  child.stdout.on('data', (data) => {
    const str = data.toString();
    stdout += str;
    // Print non-ANSI content for debugging
    const clean = str.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '').replace(/\x1b\[\?[0-9;]*[a-zA-Z]/g, '');
    if (clean.trim()) {
      console.log('[STDOUT]', clean.trim().slice(0, 100));
    }
  });

  child.stderr.on('data', (data) => {
    const str = data.toString();
    stderr += str;
    process.stderr.write(str);
  });

  // Step 1: Press Tab to focus on name-input
  setTimeout(() => {
    console.log('[TEST] Pressing Tab to focus name-input...');
    child.stdin.write('\t');
  }, 500);

  // Step 2: Press Enter to start editing
  setTimeout(() => {
    console.log('[TEST] Pressing Enter to start editing...');
    child.stdin.write('\r');
  }, 1000);

  // Step 3: Type name and press Enter
  setTimeout(() => {
    console.log('[TEST] Typing "テスト太郎" + Enter...');
    child.stdin.write('テスト太郎\n');
  }, 2000);

  // Step 4: Wait for form to return, then press q to quit
  setTimeout(() => {
    console.log('[TEST] Pressing q to quit...');
    child.stdin.write('q');
  }, 3500);

  // Timeout
  setTimeout(() => {
    console.log('\n[TEST] Timeout - killing process');
    child.kill();

    console.log('\n=== Final stdout (last 500 chars) ===');
    console.log(stdout.slice(-500));

    if (stderr) {
      console.log('\n=== STDERR ===');
      console.log(stderr);
    }

    if (stdout.includes('テスト太郎')) {
      console.log('\n✅ SUCCESS: Japanese input was captured!');
    } else {
      console.log('\n❌ FAILED: Japanese input was not captured');
      console.log('Looking for "テスト太郎" in output...');
    }
  }, 6000);

  child.on('close', (code) => {
    console.log(`\nProcess exited with code ${code}`);
  });
});
