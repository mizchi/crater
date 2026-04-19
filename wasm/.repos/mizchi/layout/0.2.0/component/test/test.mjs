import { layout } from './gen/layout-component.js';
import assert from 'node:assert/strict';

const {
  computeJustify, computeAlignOffset, resolveAlignSelf,
  computeAlignSelfOffset, resolveAutoMarginPair,
  clampValue, clampSize, clampSizeWithBoxMin, applyAspectRatio
} = layout;

// Test 1: compute-justify with space-between
{
  const { a: start, b: gap } = computeJustify('space-between', 100.0, 3);
  assert.equal(start, 0.0);
  assert.equal(gap, 50.0); // 100 / (3-1) = 50
  console.log('PASS: compute-justify space-between');
}

// Test 2: compute-justify with center
{
  const { a: start, b: gap } = computeJustify('center', 100.0, 2);
  assert.equal(gap, 0.0);
  assert.equal(start, 50.0);
  console.log('PASS: compute-justify center');
}

// Test 3: compute-align-offset
{
  const offset = computeAlignOffset('center', 80.0);
  assert.equal(offset, 40.0); // 80 / 2
  console.log('PASS: compute-align-offset center');
}

// Test 4: compute-align-offset end
{
  const offset = computeAlignOffset('end', 80.0);
  assert.equal(offset, 80.0);
  console.log('PASS: compute-align-offset end');
}

// Test 5: resolve-align-self
{
  const resolved = resolveAlignSelf('auto', 'center');
  assert.equal(resolved, 'center'); // auto inherits parent
  console.log('PASS: resolve-align-self auto->center');
}

// Test 6: resolve-align-self explicit
{
  const resolved = resolveAlignSelf('end', 'center');
  assert.equal(resolved, 'end');
  console.log('PASS: resolve-align-self explicit end');
}

// Test 7: compute-align-self-offset
{
  const offset = computeAlignSelfOffset('center', 'start', 60.0);
  assert.equal(offset, 30.0); // center overrides start
  console.log('PASS: compute-align-self-offset');
}

// Test 8: resolve-auto-margin-pair both auto
{
  const { a: ms, b: me } = resolveAutoMarginPair(true, true, 0.0, 0.0, 100.0);
  assert.equal(ms, 50.0);
  assert.equal(me, 50.0);
  console.log('PASS: resolve-auto-margin-pair both auto');
}

// Test 9: clamp-value
{
  assert.equal(clampValue(5.0, 0.0, 10.0), 5.0);
  assert.equal(clampValue(-1.0, 0.0, 10.0), 0.0);
  assert.equal(clampValue(15.0, 0.0, 10.0), 10.0);
  console.log('PASS: clamp-value');
}

// Test 10: clamp-size
{
  const { a: w, b: h } = clampSize(200.0, 300.0, 50.0, 150.0, 50.0, 250.0);
  assert.equal(w, 150.0); // clamped to max-width
  assert.equal(h, 250.0); // clamped to max-height
  console.log('PASS: clamp-size');
}

// Test 11: clamp-size-with-box-min
{
  const { a: w, b: h } = clampSizeWithBoxMin(10.0, 10.0, 50.0, 200.0, 50.0, 200.0, 30.0, 30.0);
  assert.equal(w, 50.0); // clamped to min-width
  assert.equal(h, 50.0);
  console.log('PASS: clamp-size-with-box-min');
}

// Test 12: apply-aspect-ratio without ratio
{
  const { a: w, b: h } = applyAspectRatio(100.0, 200.0, false, 0.0, false, false);
  assert.equal(w, 100.0); // unchanged
  assert.equal(h, 200.0);
  console.log('PASS: apply-aspect-ratio no ratio');
}

console.log('All tests passed!');
