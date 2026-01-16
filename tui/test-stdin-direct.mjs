#!/usr/bin/env node
/**
 * Direct test of stdin behavior
 */

console.log('isTTY:', process.stdin.isTTY);

if (process.stdin.isTTY) {
  process.stdin.setRawMode(true);
}
process.stdin.resume();
process.stdin.setEncoding('utf8');

console.log('Waiting for key...');

process.stdin.once('data', (key) => {
  console.log('Got key:', JSON.stringify(key));
  process.exit(0);
});

// Timeout
setTimeout(() => {
  console.log('Timeout');
  process.exit(1);
}, 5000);
