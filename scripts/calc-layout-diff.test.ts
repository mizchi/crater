import { describe, expect, it } from 'vitest';
import {
  CALC_FIXTURES,
  diffCase,
  findTestRoot,
  meaningfulChildren,
  walkLayout,
  type FieldDiff,
  type LayoutRect,
} from './calc-layout-diff.ts';

function rect(partial: Partial<LayoutRect> & { id: string }): LayoutRect {
  return { x: 0, y: 0, width: 0, height: 0, children: [], ...partial };
}

describe('calc-layout-diff pure helpers', () => {
  it('CALC_FIXTURES is non-empty and well-formed', () => {
    expect(CALC_FIXTURES.length).toBeGreaterThan(0);
    for (const f of CALC_FIXTURES) {
      expect(f.name).toBeTruthy();
      expect(f.html).toContain('id="test"');
    }
    // Names must be unique so report rows are unambiguous.
    const names = new Set(CALC_FIXTURES.map((f) => f.name));
    expect(names.size).toBe(CALC_FIXTURES.length);
  });

  it('meaningfulChildren drops #text nodes', () => {
    const node = rect({
      id: 'div',
      children: [rect({ id: '#text' }), rect({ id: 'span' })],
    });
    expect(meaningfulChildren(node).map((c) => c.id)).toEqual(['span']);
  });

  it('findTestRoot locates the #test subtree', () => {
    const tree = rect({
      id: 'body',
      children: [rect({ id: 'div#test', width: 42 })],
    });
    expect(findTestRoot(tree).id).toBe('div#test');
    expect(findTestRoot(tree).width).toBe(42);
  });

  it('findTestRoot falls back to the node itself', () => {
    const tree = rect({ id: 'body', width: 7 });
    expect(findTestRoot(tree).id).toBe('body');
  });

  it('walkLayout records a delta per field, recursing into children', () => {
    const b = rect({ id: 'test', width: 100, height: 50, children: [rect({ id: 'a', width: 30 })] });
    const c = rect({ id: 'test', width: 100, height: 50, children: [rect({ id: 'a', width: 20 })] });
    const rows: FieldDiff[] = [];
    walkLayout(b, c, 'test', rows);
    // 4 fields for the root + 4 for the single child.
    expect(rows.length).toBe(8);
    const childWidth = rows.find((r) => r.path === 'test>a' && r.field === 'width');
    expect(childWidth?.delta).toBe(10);
  });

  it('diffCase flags only fields beyond the threshold', () => {
    const browser = rect({ id: 'div#test', width: 120, height: 40 });
    const crater = rect({ id: 'div#test', width: 100, height: 40 });
    const result = diffCase('mixed', browser, crater, 0.5);
    expect(result.mismatches.length).toBe(1);
    expect(result.mismatches[0]!.field).toBe('width');
    expect(result.mismatches[0]!.delta).toBe(20);
    expect(result.matched).toBe(result.fields - 1);
  });

  it('diffCase reports no mismatch when within threshold', () => {
    const browser = rect({ id: 'div#test', width: 100.3 });
    const crater = rect({ id: 'div#test', width: 100 });
    expect(diffCase('near', browser, crater, 0.5).mismatches.length).toBe(0);
  });
});
