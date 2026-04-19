import { svg } from './gen/svg-component.js';
import assert from 'node:assert/strict';

const { render } = svg;

// Test 1: simple red rect
{
  const img = render(
    '<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4"><rect width="4" height="4" fill="red"/></svg>',
    4,
    4
  );
  assert.notEqual(img, undefined, 'render should return an image');
  assert.equal(img.width, 4);
  assert.equal(img.height, 4);
  assert.equal(img.data.length, 64); // 4*4*4 bytes (RGBA)
  console.log('PASS: simple red rect');
}

// Test 2: invalid SVG returns undefined
{
  const bad = render('not svg', 4, 4);
  assert.equal(bad, undefined, 'invalid SVG should return undefined');
  console.log('PASS: invalid SVG returns undefined');
}

// Test 3: larger canvas
{
  const img = render(
    '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><circle cx="50" cy="50" r="40" fill="blue"/></svg>',
    100,
    100
  );
  assert.notEqual(img, undefined);
  assert.equal(img.width, 100);
  assert.equal(img.height, 100);
  assert.equal(img.data.length, 100 * 100 * 4);
  console.log('PASS: larger canvas (100x100)');
}

console.log('All tests passed!');
