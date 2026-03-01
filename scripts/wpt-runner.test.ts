import { describe, expect, it } from "vitest";
import {
  createTextIntrinsicFnFromMeasureText,
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
