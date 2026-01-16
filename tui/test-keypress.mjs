#!/usr/bin/env node
/**
 * Test keypress events with emitKeypressEvents
 */

import { emitKeypressEvents } from 'node:readline';
import { stdin, stdout } from 'node:process';

console.log('=== Keypress Test ===');
console.log('isTTY:', stdin.isTTY);

emitKeypressEvents(stdin);

if (stdin.isTTY) {
  stdin.setRawMode(true);
}
stdin.resume();

console.log('Press any key (q to quit)...');

stdin.on('keypress', (str, key) => {
  console.log('keypress:', { str, key });

  if (str === 'q' || (key && key.ctrl && key.name === 'c')) {
    console.log('Exiting...');
    process.exit(0);
  }
});
