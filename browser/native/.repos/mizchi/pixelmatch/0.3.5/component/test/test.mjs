import { pixelmatch as pm } from './gen/pixelmatch-component.js';
import assert from 'node:assert/strict';

const { pixelmatch, pixelmatchSimple, matchRatio } = pm;

// Helper: create a solid RGBA image
function solidImage(w, h, r, g, b, a) {
  const data = new Uint8Array(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    data[i * 4] = r;
    data[i * 4 + 1] = g;
    data[i * 4 + 2] = b;
    data[i * 4 + 3] = a;
  }
  return data;
}

// Test 1: identical images → 0 diff
{
  const img = solidImage(4, 4, 255, 0, 0, 255);
  const result = pixelmatch(img, img, 4, 4, false, 0.1, false, 0.1, false);
  assert.equal(result.diffCount, 0, 'identical images should have 0 diff');
  assert.equal(result.output, undefined, 'no output when include-output=false');
  console.log('PASS: identical images');
}

// Test 2: completely different images
{
  const red = solidImage(4, 4, 255, 0, 0, 255);
  const blue = solidImage(4, 4, 0, 0, 255, 255);
  const result = pixelmatch(red, blue, 4, 4, false, 0.1, false, 0.1, false);
  assert.equal(result.diffCount, 16, 'all 16 pixels should differ');
  console.log('PASS: completely different images');
}

// Test 3: pixelmatch with output
{
  const red = solidImage(4, 4, 255, 0, 0, 255);
  const blue = solidImage(4, 4, 0, 0, 255, 255);
  const result = pixelmatch(red, blue, 4, 4, true, 0.1, false, 0.1, false);
  assert.equal(result.diffCount, 16);
  assert.notEqual(result.output, undefined, 'should have output data');
  assert.equal(result.output.length, 64, 'output should be 4*4*4 bytes');
  console.log('PASS: pixelmatch with output');
}

// Test 4: pixelmatch-simple
{
  const red = solidImage(4, 4, 255, 0, 0, 255);
  const blue = solidImage(4, 4, 0, 0, 255, 255);
  const count = pixelmatchSimple(red, blue, 4, 4, 0.1);
  assert.equal(count, 16);
  console.log('PASS: pixelmatch-simple');
}

// Test 5: match-ratio identical
{
  const img = solidImage(4, 4, 255, 0, 0, 255);
  const ratio = matchRatio(img, img, 4, 4, 0.1, false, 0.1, false);
  assert.equal(ratio, 1.0, 'identical images should have ratio 1.0');
  console.log('PASS: match-ratio identical');
}

// Test 6: match-ratio different
{
  const red = solidImage(4, 4, 255, 0, 0, 255);
  const blue = solidImage(4, 4, 0, 0, 255, 255);
  const ratio = matchRatio(red, blue, 4, 4, 0.1, false, 0.1, false);
  assert.equal(ratio, 0.0, 'completely different should have ratio 0.0');
  console.log('PASS: match-ratio different');
}

console.log('All tests passed!');
