// WASM Component tests
import { strict as assert } from 'node:assert';
import { test, describe, before, after } from 'node:test';

// Import from jco-transpiled component
import { renderer, incremental, yoga } from '../dist/crater.js';

describe('WASM Component: renderer', () => {
  test('renderHtml returns layout tree string', () => {
    const html = '<div style="width: 100px; height: 50px;"></div>';
    const result = renderer.renderHtml(html, 800, 600);
    assert.equal(typeof result, 'string');
    assert.ok(result.length > 0);
  });

  test('renderHtmlToJson returns valid JSON', () => {
    const html = '<div id="root" style="width: 100px; display: flex;"><div id="child" style="width: 50px;"></div></div>';
    const result = renderer.renderHtmlToJson(html, 800, 600);
    const layout = JSON.parse(result);

    assert.equal(layout.id, 'body');
    assert.ok(layout.children.length > 0);
  });

  test('renderHtmlToPaintTree returns valid JSON', () => {
    const html = '<div style="width: 100px; background-color: red;"></div>';
    const result = renderer.renderHtmlToPaintTree(html, 800, 600);
    const paintTree = JSON.parse(result);

    assert.ok(paintTree.id);
  });
});

describe('WASM Component: incremental', () => {
  after(() => {
    incremental.destroyTree();
  });

  test('createTree returns tree ID', () => {
    const html = '<div id="root" style="width: 100px;"></div>';
    const treeId = incremental.createTree(html, 800, 600);
    assert.equal(typeof treeId, 'number');
  });

  test('computeIncremental returns layout JSON', () => {
    const result = incremental.computeIncremental();
    assert.equal(typeof result, 'string');
    const parsed = JSON.parse(result);
    assert.ok(parsed.id);
  });

  test('computeFull returns layout JSON', () => {
    const result = incremental.computeFull();
    assert.equal(typeof result, 'string');
    const parsed = JSON.parse(result);
    assert.ok(parsed.id);
  });

  test('getCacheStats returns valid stats', () => {
    incremental.resetCacheStats();
    incremental.computeIncremental();

    const statsJson = incremental.getCacheStats();
    const stats = JSON.parse(statsJson);
    assert.equal(typeof stats.hits, 'number');
    assert.equal(typeof stats.misses, 'number');
  });

  test('needsLayout returns boolean', () => {
    const needs = incremental.needsLayout();
    assert.equal(typeof needs, 'boolean');
  });

  test('resizeViewport updates viewport', () => {
    incremental.resizeViewport(400, 300);
    // Should not throw
    assert.ok(true);
  });

  test('markDirty returns boolean', () => {
    const result = incremental.markDirty('div#root');
    assert.equal(typeof result, 'boolean');
  });

  test('updateStyle returns boolean', () => {
    const result = incremental.updateStyle('div#root', 'width: 200px;');
    assert.equal(typeof result, 'boolean');
  });
});

describe('WASM Component: yoga', () => {
  before(() => {
    const html = '<div id="root"></div>';
    incremental.createTree(html, 800, 600);
  });

  after(() => {
    incremental.destroyTree();
  });

  test('createNode returns node ID', () => {
    const nodeId = yoga.createNode('test-node');
    assert.equal(typeof nodeId, 'number');
  });

  test('setWidth/setHeight return boolean', () => {
    assert.equal(typeof yoga.setWidth('test', 100), 'boolean');
    assert.equal(typeof yoga.setHeight('test', 100), 'boolean');
  });

  test('setWidthPercent/setHeightPercent return boolean', () => {
    assert.equal(typeof yoga.setWidthPercent('test', 50), 'boolean');
    assert.equal(typeof yoga.setHeightPercent('test', 50), 'boolean');
  });

  test('setWidthAuto/setHeightAuto return boolean', () => {
    assert.equal(typeof yoga.setWidthAuto('test'), 'boolean');
    assert.equal(typeof yoga.setHeightAuto('test'), 'boolean');
  });

  test('flex properties return boolean', () => {
    assert.equal(typeof yoga.setFlexGrow('test', 1), 'boolean');
    assert.equal(typeof yoga.setFlexShrink('test', 1), 'boolean');
    assert.equal(typeof yoga.setFlexBasis('test', 100), 'boolean');
    assert.equal(typeof yoga.setFlexDirection('test', 'row'), 'boolean');
    assert.equal(typeof yoga.setFlexWrap('test', 'no-wrap'), 'boolean');
  });

  test('alignment properties return boolean', () => {
    assert.equal(typeof yoga.setJustifyContent('test', 'flex-start'), 'boolean');
    assert.equal(typeof yoga.setAlignItems('test', 'stretch'), 'boolean');
  });

  test('setDisplay returns boolean', () => {
    assert.equal(typeof yoga.setDisplay('test', 'flex'), 'boolean');
  });

  test('spacing properties return boolean', () => {
    assert.equal(typeof yoga.setMargin('test', 10), 'boolean');
    assert.equal(typeof yoga.setPadding('test', 10), 'boolean');
    assert.equal(typeof yoga.setGap('test', 10), 'boolean');
  });

  test('computed getters return numbers', () => {
    assert.equal(typeof yoga.getComputedLeft('test'), 'number');
    assert.equal(typeof yoga.getComputedTop('test'), 'number');
    assert.equal(typeof yoga.getComputedWidth('test'), 'number');
    assert.equal(typeof yoga.getComputedHeight('test'), 'number');
  });

  test('hasNewLayout/markLayoutSeen return boolean', () => {
    assert.equal(typeof yoga.hasNewLayout('test'), 'boolean');
    assert.equal(typeof yoga.markLayoutSeen('test'), 'boolean');
  });

  test('calculateLayout returns JSON', () => {
    const result = yoga.calculateLayout(400, 300);
    assert.equal(typeof result, 'string');
    const parsed = JSON.parse(result);
    assert.ok(parsed.id);
  });

  test('child operations return boolean/number', () => {
    assert.equal(typeof yoga.addChild('parent', 'child'), 'boolean');
    assert.equal(typeof yoga.insertChild('parent', 'child', 0), 'boolean');
    assert.equal(typeof yoga.removeChild('parent', 0), 'boolean');
    assert.equal(typeof yoga.getChildCount('parent'), 'number');
  });
});

console.log('All WASM Component tests completed!');
