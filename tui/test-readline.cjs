#!/usr/bin/env node
/**
 * Readline test script - debug stdin/stdout behavior
 * Run interactively: node test-readline.cjs
 * Run with pipe: echo "test" | node test-readline.cjs --simple
 */

const readline = require('readline');

const isTTY = process.stdin.isTTY;
console.log('=== Readline Test ===');
console.log('isTTY:', isTTY);
console.log('');

// Test 1: Simple readline
async function testSimpleReadline() {
  console.log('Test 1: Simple readline');
  console.log('Type something and press Enter:');

  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: isTTY,
    });

    rl.question('> ', (answer) => {
      console.log(`You entered: "${answer}"`);
      rl.close();
      resolve(answer);
    });

    // Handle Ctrl+C
    rl.on('SIGINT', () => {
      console.log('\nCancelled');
      rl.close();
      process.exit(130);
    });

    // Timeout after 10 seconds
    setTimeout(() => {
      console.log('\nTimeout!');
      rl.close();
      resolve(null);
    }, 10000);
  });
}

// Test 2: Raw mode then readline (TTY only)
async function testRawModeThenReadline() {
  if (!isTTY) {
    console.log('ERROR: This test requires a TTY (interactive terminal)');
    console.log('Run without pipe: node test-readline.cjs --raw-then-readline');
    return null;
  }

  console.log('Test 2: Raw mode then readline');
  console.log('Press any key to continue (raw mode)...');

  // Simulate what read_key does
  const key = await new Promise((resolve) => {
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.setEncoding('utf8');

    const onData = (data) => {
      process.stdin.removeListener('data', onData);
      resolve(data);
    };
    process.stdin.on('data', onData);
  });

  const keyCode = key.charCodeAt(0);
  console.log(`Got key: ${JSON.stringify(key)} (code: ${keyCode})`);

  if (keyCode === 3) { // Ctrl+C
    console.log('Ctrl+C pressed, exiting');
    process.exit(130);
  }

  // Now try readline
  console.log('\nNow trying readline after raw mode...');
  console.log('Type something and press Enter:');

  // Reset stdin state - THIS IS THE CRITICAL PART
  console.log('DEBUG: Removing listeners...');
  process.stdin.removeAllListeners('data');
  console.log('DEBUG: Setting raw mode false...');
  process.stdin.setRawMode(false);
  console.log('DEBUG: Pausing stdin...');
  process.stdin.pause();
  console.log('DEBUG: Creating readline interface...');

  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: true,
    });

    console.log('DEBUG: readline created, calling question()...');

    rl.question('> ', (answer) => {
      console.log(`You entered: "${answer}"`);
      rl.close();
      resolve(answer);
    });

    rl.on('SIGINT', () => {
      console.log('\nCancelled');
      rl.close();
      process.exit(130);
    });

    setTimeout(() => {
      console.log('\nTimeout!');
      rl.close();
      resolve(null);
    }, 10000);
  });
}

// Test 3: Multiple raw key reads then readline
async function testMultipleRawThenReadline() {
  if (!isTTY) {
    console.log('ERROR: This test requires a TTY');
    return null;
  }

  console.log('Test 3: Multiple raw key reads then readline');
  console.log('Press 3 keys in raw mode...');

  for (let i = 0; i < 3; i++) {
    const key = await new Promise((resolve) => {
      process.stdin.setRawMode(true);
      process.stdin.resume();
      process.stdin.setEncoding('utf8');

      const onData = (data) => {
        process.stdin.removeListener('data', onData);
        resolve(data);
      };
      process.stdin.on('data', onData);
    });

    const keyCode = key.charCodeAt(0);
    console.log(`Key ${i + 1}: ${JSON.stringify(key)} (code: ${keyCode})`);

    if (keyCode === 3) {
      console.log('Ctrl+C pressed, exiting');
      process.exit(130);
    }
  }

  console.log('\nNow readline...');

  // Reset stdin
  process.stdin.removeAllListeners('data');
  process.stdin.setRawMode(false);
  process.stdin.pause();

  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: true,
    });

    rl.question('> ', (answer) => {
      console.log(`You entered: "${answer}"`);
      rl.close();
      resolve(answer);
    });

    rl.on('SIGINT', () => {
      console.log('\nCancelled');
      rl.close();
      process.exit(130);
    });

    setTimeout(() => {
      console.log('\nTimeout!');
      rl.close();
      resolve(null);
    }, 10000);
  });
}

// Main
async function main() {
  const args = process.argv.slice(2);

  if (args.includes('--simple')) {
    await testSimpleReadline();
  } else if (args.includes('--raw-then-readline')) {
    await testRawModeThenReadline();
  } else if (args.includes('--multi-raw')) {
    await testMultipleRawThenReadline();
  } else {
    console.log('Usage:');
    console.log('  node test-readline.cjs --simple           # Simple readline');
    console.log('  node test-readline.cjs --raw-then-readline # Raw mode then readline (TTY only)');
    console.log('  node test-readline.cjs --multi-raw        # Multiple raw reads then readline');
    console.log('');
    if (isTTY) {
      console.log('Running --raw-then-readline (interactive)...');
      console.log('');
      await testRawModeThenReadline();
    } else {
      console.log('Running --simple (piped input detected)...');
      console.log('');
      await testSimpleReadline();
    }
  }

  process.exit(0);
}

main().catch(console.error);
