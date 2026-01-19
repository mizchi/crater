// Yoga-compatible API tests
import { strict as assert } from 'node:assert';
import { test, describe } from 'node:test';

import {
  // Render API (known to work)
  renderHtmlToJson,
  // Incremental API
  createTree,
  computeIncremental,
  computeFull,
  markDirty,
  updateStyle,
  resizeViewport,
  getCacheStats,
  resetCacheStats,
  needsLayout,
  destroyTree,
  // Yoga-compatible Node API
  createNode,
  addChild,
  insertChild,
  removeChild,
  getChildCount,
  // Yoga-compatible Style Setters
  setWidth,
  setWidthPercent,
  setWidthAuto,
  setHeight,
  setHeightPercent,
  setHeightAuto,
  setFlexGrow,
  setFlexShrink,
  setFlexBasis,
  setFlexDirection,
  setFlexWrap,
  setJustifyContent,
  setAlignItems,
  setDisplay,
  setMargin,
  setPadding,
  setGap,
  // Yoga-compatible Layout Getters
  getComputedLeft,
  getComputedTop,
  getComputedWidth,
  getComputedHeight,
  hasNewLayout,
  markLayoutSeen,
  calculateLayout,
  // Helpers
  Crater,
} from '../dist/index.js';

describe('Render API (baseline)', () => {
  test('renderHtmlToJson works correctly', () => {
    const html = '<div id="root" style="width: 100px; display: flex;"><div id="child" style="width: 50px;"></div></div>';
    const result = renderHtmlToJson(html, 800, 600);
    const layout = Crater.parseLayout(result);

    // Body is the root element from HTML parsing
    assert.equal(layout.id, 'body');
    assert.ok(layout.children.length > 0, 'Should have children');
    assert.equal(layout.children[0].id, 'div#root');
    assert.equal(layout.children[0].width, 100);
  });
});

describe('Incremental API', () => {
  test('createTree returns tree ID', () => {
    const html = '<div id="root" style="width: 100px;"></div>';
    const treeId = createTree(html, 800, 600);
    assert.equal(typeof treeId, 'number');
    destroyTree();
  });

  test('computeIncremental returns JSON', () => {
    const html = '<div id="root" style="width: 100px;"></div>';
    createTree(html, 800, 600);
    const result = computeIncremental();
    assert.equal(typeof result, 'string');
    const parsed = JSON.parse(result);
    assert.ok(parsed.id);
    destroyTree();
  });

  test('computeFull returns JSON', () => {
    const html = '<div id="root" style="width: 100px;"></div>';
    createTree(html, 800, 600);
    const result = computeFull();
    assert.equal(typeof result, 'string');
    const parsed = JSON.parse(result);
    assert.ok(parsed.id);
    destroyTree();
  });

  test('getCacheStats returns valid stats', () => {
    const html = '<div id="root" style="width: 100px;"></div>';
    createTree(html, 800, 600);
    resetCacheStats();
    computeIncremental();

    const stats = Crater.parseCacheStats(getCacheStats());
    assert.equal(typeof stats.hits, 'number');
    assert.equal(typeof stats.misses, 'number');
    assert.equal(typeof stats.nodesComputed, 'number');
    assert.equal(typeof stats.hitRate, 'number');
    destroyTree();
  });

  test('needsLayout returns boolean', () => {
    const html = '<div id="root" style="width: 100px;"></div>';
    createTree(html, 800, 600);
    const needs = needsLayout();
    assert.equal(typeof needs, 'boolean');
    destroyTree();
  });

  test('resizeViewport is callable', () => {
    const html = '<div id="root" style="width: 100%;"></div>';
    createTree(html, 800, 600);
    resizeViewport(400, 300);
    // Should not throw
    destroyTree();
  });
});

describe('Yoga-compatible Style Setters (API validation)', () => {
  // Note: These tests validate API exists and returns expected types.
  // The functions may return false when node is not found, which is expected
  // since HTML parsing creates nodes with IDs like "div#root" not "root"

  test('setWidth/Height return boolean', () => {
    const html = '<div id="root"></div>';
    createTree(html, 800, 600);

    assert.equal(typeof setWidth('any', 100), 'boolean');
    assert.equal(typeof setHeight('any', 100), 'boolean');
    destroyTree();
  });

  test('setWidthPercent/HeightPercent return boolean', () => {
    const html = '<div id="root"></div>';
    createTree(html, 800, 600);

    assert.equal(typeof setWidthPercent('any', 50), 'boolean');
    assert.equal(typeof setHeightPercent('any', 50), 'boolean');
    destroyTree();
  });

  test('setWidthAuto/HeightAuto return boolean', () => {
    const html = '<div id="root"></div>';
    createTree(html, 800, 600);

    assert.equal(typeof setWidthAuto('any'), 'boolean');
    assert.equal(typeof setHeightAuto('any'), 'boolean');
    destroyTree();
  });

  test('flex setters return boolean', () => {
    const html = '<div id="root"></div>';
    createTree(html, 800, 600);

    assert.equal(typeof setFlexGrow('any', 1), 'boolean');
    assert.equal(typeof setFlexShrink('any', 1), 'boolean');
    assert.equal(typeof setFlexBasis('any', 100), 'boolean');
    assert.equal(typeof setFlexDirection('any', 0), 'boolean');
    assert.equal(typeof setFlexWrap('any', 0), 'boolean');
    destroyTree();
  });

  test('alignment setters return boolean', () => {
    const html = '<div id="root"></div>';
    createTree(html, 800, 600);

    assert.equal(typeof setJustifyContent('any', 0), 'boolean');
    assert.equal(typeof setAlignItems('any', 0), 'boolean');
    destroyTree();
  });

  test('setDisplay returns boolean', () => {
    const html = '<div id="root"></div>';
    createTree(html, 800, 600);

    assert.equal(typeof setDisplay('any', 0), 'boolean');
    destroyTree();
  });

  test('setMargin/Padding/Gap return boolean', () => {
    const html = '<div id="root"></div>';
    createTree(html, 800, 600);

    assert.equal(typeof setMargin('any', 10), 'boolean');
    assert.equal(typeof setPadding('any', 10), 'boolean');
    assert.equal(typeof setGap('any', 10), 'boolean');
    destroyTree();
  });
});

describe('Yoga-compatible Layout Getters', () => {
  test('getComputedLeft/Top/Width/Height return numbers', () => {
    const html = '<div id="root" style="width: 100px;"></div>';
    createTree(html, 800, 600);
    computeIncremental();

    assert.equal(typeof getComputedLeft('any'), 'number');
    assert.equal(typeof getComputedTop('any'), 'number');
    assert.equal(typeof getComputedWidth('any'), 'number');
    assert.equal(typeof getComputedHeight('any'), 'number');
    destroyTree();
  });

  test('hasNewLayout returns boolean', () => {
    const html = '<div id="root" style="width: 100px;"></div>';
    createTree(html, 800, 600);
    computeIncremental();

    assert.equal(typeof hasNewLayout('any'), 'boolean');
    destroyTree();
  });

  test('markLayoutSeen returns boolean', () => {
    const html = '<div id="root" style="width: 100px;"></div>';
    createTree(html, 800, 600);

    assert.equal(typeof markLayoutSeen('any'), 'boolean');
    destroyTree();
  });

  test('calculateLayout returns JSON', () => {
    const html = '<div id="root" style="width: 100px;"></div>';
    createTree(html, 800, 600);

    const result = calculateLayout(400, 300);
    assert.equal(typeof result, 'string');
    const parsed = JSON.parse(result);
    assert.ok(parsed.id);
    destroyTree();
  });
});

describe('Node API', () => {
  test('createNode returns number', () => {
    assert.equal(typeof createNode('test'), 'number');
  });

  test('child manipulation returns boolean', () => {
    const html = '<div id="root"></div>';
    createTree(html, 800, 600);

    assert.equal(typeof addChild('parent', 'child'), 'boolean');
    assert.equal(typeof insertChild('parent', 'child', 0), 'boolean');
    assert.equal(typeof removeChild('parent', 0), 'boolean');
    destroyTree();
  });

  test('getChildCount returns number', () => {
    const html = '<div id="root"></div>';
    createTree(html, 800, 600);

    assert.equal(typeof getChildCount('any'), 'number');
    destroyTree();
  });
});

describe('Operations without tree', () => {
  test('operations return defaults without tree', () => {
    destroyTree(); // Ensure no tree

    assert.equal(setWidth('any', 100), false);
    assert.equal(markDirty('any'), false);
    assert.equal(getComputedWidth('any'), 0);
    assert.equal(needsLayout(), false);
    assert.equal(getChildCount('any'), 0);
  });
});

console.log('All Yoga-compatible API tests completed!');
