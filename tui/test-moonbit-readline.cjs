#!/usr/bin/env node
/**
 * Test MoonBit readline by spawning the process and writing to stdin
 */

const { spawn } = require('child_process');
const path = require('path');

const tuiDir = __dirname;

console.log('Building MoonBit input-test...');

const build = spawn('moon', ['build', 'examples/input-test', '--target', 'js'], {
  cwd: tuiDir,
  stdio: 'inherit'
});

build.on('close', (code) => {
  if (code !== 0) {
    console.error('Build failed');
    process.exit(1);
  }

  console.log('\nRunning input-test with simulated input...\n');

  // Find the built JS file
  const jsPath = path.join(tuiDir, 'target/js/release/build/examples/input-test/input-test.js');

  const child = spawn('node', [jsPath], {
    stdio: ['pipe', 'pipe', 'pipe']
  });

  let stdout = '';
  let stderr = '';

  child.stdout.on('data', (data) => {
    const str = data.toString();
    stdout += str;
    process.stdout.write(str);
  });

  child.stderr.on('data', (data) => {
    const str = data.toString();
    stderr += str;
    process.stderr.write(str);
  });

  // Wait a bit then send input
  setTimeout(() => {
    console.log('\n[TEST] Sending first key "x"...');
    child.stdin.write('x');
  }, 500);

  // Send readline input after raw mode key
  setTimeout(() => {
    console.log('\n[TEST] Sending readline input "hello world" + Enter...');
    child.stdin.write('hello world\n');
  }, 1500);

  // Timeout
  setTimeout(() => {
    console.log('\n[TEST] Timeout - killing process');
    child.kill();

    console.log('\n=== STDOUT ===');
    console.log(stdout);
    if (stderr) {
      console.log('\n=== STDERR ===');
      console.log(stderr);
    }

    if (stdout.includes('hello world')) {
      console.log('\n✅ SUCCESS: Input was captured!');
    } else {
      console.log('\n❌ FAILED: Input was not captured');
    }
  }, 5000);

  child.on('close', (code) => {
    console.log(`\nProcess exited with code ${code}`);
  });
});
