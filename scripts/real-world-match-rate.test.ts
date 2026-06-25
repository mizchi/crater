import { describe, expect, it } from 'vitest';
import {
  coverage,
  iou,
  matchTrees,
  normalizeRoot,
  summarize,
  tagHistogram,
  tagOf,
  type Box,
} from './real-world-match-rate.ts';

function box(p: Partial<Box> & { id: string }): Box {
  return { x: 0, y: 0, width: 0, height: 0, children: [], ...p };
}

describe('real-world-match-rate pure helpers', () => {
  it('iou is 1 for identical boxes and 0 for disjoint', () => {
    const a = box({ id: 'a', width: 10, height: 10 });
    expect(iou(a, a)).toBe(1);
    const b = box({ id: 'b', x: 100, y: 100, width: 10, height: 10 });
    expect(iou(a, b)).toBe(0);
  });

  it('iou is 0.5 for half-overlap', () => {
    const a = box({ id: 'a', width: 10, height: 10 });
    const b = box({ id: 'b', x: 0, y: 5, width: 10, height: 10 });
    // intersection 10x5=50, union 100+100-50=150 -> 1/3
    expect(iou(a, b)).toBeCloseTo(1 / 3, 5);
  });

  it('normalizeRoot zeroes the root offset only', () => {
    const n = normalizeRoot(box({ id: 'body', x: 8, y: 8, width: 100, height: 50 }));
    expect(n.x).toBe(0);
    expect(n.y).toBe(0);
    expect(n.width).toBe(100);
  });

  it('matchTrees counts matched within tolerance and recurses', () => {
    const browser = box({
      id: 'body',
      width: 100,
      height: 100,
      children: [box({ id: 'a', width: 50, height: 20 })],
    });
    const crater = box({
      id: 'body',
      width: 100,
      height: 100,
      children: [box({ id: 'a', width: 50, height: 20 })],
    });
    const s = matchTrees(browser, crater, 1);
    expect(s.compared).toBe(2);
    expect(s.matched).toBe(2);
    expect(s.browserOnly).toBe(0);
    expect(s.craterOnly).toBe(0);
  });

  it('matchTrees flags an element beyond tolerance', () => {
    const browser = box({ id: 'body', width: 100, height: 100 });
    const crater = box({ id: 'body', width: 100, height: 130 });
    const s = matchTrees(browser, crater, 1);
    expect(s.compared).toBe(1);
    expect(s.matched).toBe(0);
    expect(s.worst[0]!.delta).toBe(30);
  });

  it('matchTrees attributes diverging subtrees to browserOnly/craterOnly', () => {
    const browser = box({
      id: 'body',
      children: [box({ id: 'a' }), box({ id: 'b', children: [box({ id: 'b1' })] })],
    });
    const crater = box({ id: 'body', children: [box({ id: 'a' })] });
    const s = matchTrees(browser, crater, 1);
    // root + 'a' compared; 'b' and its child 'b1' are browser-only (2 nodes).
    expect(s.compared).toBe(2);
    expect(s.browserOnly).toBe(2);
    expect(s.craterOnly).toBe(0);
  });

  it('matchTrees ignores #text nodes', () => {
    const browser = box({ id: 'body', children: [box({ id: '#text' }), box({ id: 'a' })] });
    const crater = box({ id: 'body', children: [box({ id: 'a' })] });
    const s = matchTrees(browser, crater, 1);
    expect(s.compared).toBe(2);
    expect(s.browserOnly).toBe(0);
  });

  it('summarize derives match rate and average IoU', () => {
    const browser = box({ id: 'body', width: 100, height: 100 });
    const crater = box({ id: 'body', width: 100, height: 100 });
    const report = summarize('demo', matchTrees(browser, crater, 1));
    expect(report.matchRate).toBe(1);
    expect(report.averageIoU).toBe(1);
    expect(report.compared).toBe(1);
  });
});

describe('content coverage helpers', () => {
  it('tagOf extracts the tag from various id forms', () => {
    expect(tagOf(box({ id: 'div#foo' }))).toBe('div');
    expect(tagOf(box({ id: 'span.bar' }))).toBe('span');
    expect(tagOf(box({ id: 'section' }))).toBe('section');
  });

  it('tagHistogram counts visible non-text elements by tag', () => {
    const tree = box({
      id: 'body',
      width: 100,
      height: 100,
      children: [
        box({ id: 'div#a', width: 10, height: 10 }),
        box({ id: 'span.x', width: 5, height: 5 }),
        box({ id: '#text', width: 5, height: 5 }), // text: ignored
        box({ id: 'div', width: 0, height: 0 }), // zero-size: ignored
      ],
    });
    const h = tagHistogram(tree);
    expect(h.get('body')).toBe(1);
    expect(h.get('div')).toBe(1);
    expect(h.get('span')).toBe(1);
  });

  it('coverage reports ratio and per-tag deficits', () => {
    const browser = box({
      id: 'body',
      width: 100,
      height: 100,
      children: [
        box({ id: 'span.a', width: 5, height: 5 }),
        box({ id: 'span.b', width: 5, height: 5 }),
        box({ id: 'div#d', width: 10, height: 10 }),
      ],
    });
    const crater = box({
      id: 'body',
      width: 100,
      height: 100,
      children: [
        box({ id: 'span.a', width: 5, height: 5 }),
        box({ id: 'div#d', width: 10, height: 10 }),
      ],
    });
    const cov = coverage(browser, crater);
    expect(cov.browserTotal).toBe(4); // body + 2 span + div
    expect(cov.craterTotal).toBe(3); // body + 1 span + div
    expect(cov.ratio).toBeCloseTo(0.75, 5);
    expect(cov.deficits).toEqual([{ tag: 'span', browser: 2, crater: 1 }]);
  });
});
