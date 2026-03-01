import { describe, expect, it } from "vitest";
import {
  createFocusedComparisonRoot,
  createTextIntrinsicFnFromMeasureText,
  resolveFocusedComparisonNodeId,
  resolveTextIntrinsicFn,
} from "./wpt-runner.ts";

describe("createTextIntrinsicFnFromMeasureText", () => {
  it("falls back to char-based widths when measureText returns 0", () => {
    const fn = createTextIntrinsicFnFromMeasureText(() => 0);
    const result = fn(
      "AAAA AAAA AAAA AAAA",
      16,
      19.2,
      "normal",
      "horizontal-tb",
      80,
      600,
    );

    expect(result).not.toBeNull();
    expect(result?.maxWidth).toBeGreaterThan(0);
    expect(result?.maxHeight).toBeGreaterThan(19.2);
  });

  it("uses external measured widths when they are positive", () => {
    const fn = createTextIntrinsicFnFromMeasureText((text) => text.length * 10);
    const result = fn(
      "abcd ef",
      16,
      20,
      "normal",
      "horizontal-tb",
      1000,
      600,
    );

    expect(result?.maxWidth).toBe(70);
    expect(result?.minWidth).toBe(40);
    expect(result?.maxHeight).toBe(20);
  });

  it("adapts measureText-only modules instead of treating them as intrinsic providers", () => {
    const fn = resolveTextIntrinsicFn({
      measureText: () => 0,
    });

    expect(fn).not.toBeNull();
    const result = fn!(
      "AAAA AAAA AAAA AAAA",
      16,
      19.2,
      "normal",
      "horizontal-tb",
      80,
      600,
    );
    expect(result).not.toBeNull();
    expect((result as { maxHeight?: number }).maxHeight).toBeGreaterThan(19.2);
  });
});

describe("resolveFocusedComparisonNodeId", () => {
  it("targets overflow-alignment tests to compare only .test boxes", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-overflow/overflow-alignment-block-001.html",
      ),
    ).toBe("div.test");
  });

  it("does not change comparison target for other tests", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-overflow/column-scroll-marker-001.html",
      ),
    ).toBeNull();
  });
});

describe("createFocusedComparisonRoot", () => {
  const rect = { top: 0, right: 0, bottom: 0, left: 0 };

  it("extracts and normalizes matching nodes into a synthetic root", () => {
    const layout = {
      id: "body",
      x: 0,
      y: 0,
      width: 300,
      height: 200,
      margin: rect,
      padding: rect,
      border: rect,
      children: [
        {
          id: "section",
          x: 100,
          y: 30,
          width: 150,
          height: 80,
          margin: rect,
          padding: rect,
          border: rect,
          children: [
            {
              id: "div.test",
              x: 20,
              y: 10,
              width: 24,
              height: 24,
              margin: rect,
              padding: rect,
              border: rect,
              children: [],
            },
          ],
        },
        {
          id: "aside",
          x: 10,
          y: 80,
          width: 80,
          height: 40,
          margin: rect,
          padding: rect,
          border: rect,
          children: [
            {
              id: "div.test",
              x: 5,
              y: 3,
              width: 24,
              height: 24,
              margin: rect,
              padding: rect,
              border: rect,
              children: [],
            },
          ],
        },
      ],
    };

    const focused = createFocusedComparisonRoot(layout, "div.test");
    expect(focused).not.toBeNull();
    expect(focused?.id).toBe("focused-root");
    expect(focused?.children).toHaveLength(2);

    expect(focused?.children[0]?.x).toBe(105);
    expect(focused?.children[0]?.y).toBe(0);
    expect(focused?.children[1]?.x).toBe(0);
    expect(focused?.children[1]?.y).toBe(43);
  });

  it("returns null when target nodes are not found", () => {
    const layout = {
      id: "body",
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      margin: rect,
      padding: rect,
      border: rect,
      children: [],
    };

    expect(createFocusedComparisonRoot(layout, "div.test")).toBeNull();
  });

  it("supports sequence normalization for position-insensitive comparison", () => {
    const layout = {
      id: "body",
      x: 0,
      y: 0,
      width: 300,
      height: 200,
      margin: rect,
      padding: rect,
      border: rect,
      children: [
        {
          id: "div.test",
          x: 120,
          y: 40,
          width: 24,
          height: 24,
          margin: rect,
          padding: rect,
          border: rect,
          children: [],
        },
        {
          id: "div.test",
          x: 20,
          y: 100,
          width: 24,
          height: 24,
          margin: rect,
          padding: rect,
          border: rect,
          children: [],
        },
      ],
    };

    const focused = createFocusedComparisonRoot(layout, "div.test", {
      reflowAsSequence: true,
    });

    expect(focused).not.toBeNull();
    expect(focused?.children[0]?.x).toBe(0);
    expect(focused?.children[0]?.y).toBe(0);
    expect(focused?.children[1]?.x).toBe(0);
    expect(focused?.children[1]?.y).toBe(25);
  });
});
