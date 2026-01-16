#!/usr/bin/env node
/**
 * Test: Callback-based readline after raw mode
 * This mimics what we need to do in MoonBit
 */

const readline = require('readline');

console.log('=== Callback-based Readline Test ===');
console.log('isTTY:', process.stdin.isTTY);
console.log('');

// Step 1: Read one key in raw mode
console.log('Step 1: Press any key (raw mode)...');

process.stdin.setRawMode(true);
process.stdin.resume();
process.stdin.setEncoding('utf8');

process.stdin.once('data', (key) => {
  const keyCode = key.charCodeAt(0);
  console.log(`Got key: "${key}" (code: ${keyCode})`);

  if (keyCode === 3) {
    console.log('Ctrl+C pressed, exiting');
    process.exit(130);
  }

  // Step 2: Switch to readline
  console.log('');
  console.log('Step 2: Now readline (callback-based)...');
  console.log('Type something and press Enter:');

  // Reset stdin
  process.stdin.removeAllListeners('data');
  process.stdin.setRawMode(false);
  process.stdin.pause();

  // Create readline with callback
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: true,
  });

  rl.on('line', (answer) => {
    console.log(`You entered: "${answer}"`);
    rl.close();
    console.log('');
    console.log('Test complete!');
    process.exit(0);
  });

  rl.on('SIGINT', () => {
    console.log('\nCancelled');
    rl.close();
    process.exit(130);
  });

  // Show prompt
  rl.prompt();
});
