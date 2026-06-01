import { describe, expect, it } from "vitest";
import { createVendoredFontMeasure } from "./wpt-font-measure.ts";

describe("createVendoredFontMeasure", () => {
  const measure = createVendoredFontMeasure();

  it("returns 0 for empty text", () => {
    expect(measure("", 16, "")).toBe(0);
  });

  it("measures Ahem glyphs as 1em squares", () => {
    expect(measure("XXXX", 16, "Ahem")).toBe(64);
    expect(measure("XX", 20, "ahem, sans-serif")).toBe(40);
  });

  it("measures monospace families at 0.6em advance", () => {
    expect(measure("code", 16, "monospace")).toBeCloseTo(4 * 16 * 0.6, 5);
    expect(measure("abcde", 10, "Source Code, monospace")).toBeCloseTo(5 * 10 * 0.6, 5);
  });

  it("measures default/serif text with proportional glyph advances (Tinos)", () => {
    // Tinos is metric-compatible with Times New Roman (Chromium default).
    // 'i' is much narrower than 'm', so a proportional font must reflect that.
    const iWidth = measure("iiiii", 16, "");
    const mWidth = measure("mmmmm", 16, "");
    expect(mWidth).toBeGreaterThan(iWidth * 2);
    // Reference advances captured against Chromium (Times New Roman) at 16px.
    expect(measure("The quick brown fox jumps over the lazy dog", 16, "")).toBeCloseTo(292.4, 0);
    expect(iWidth).toBeCloseTo(22.2, 0);
    expect(mWidth).toBeCloseTo(62.2, 0);
  });

  it("falls back to the 0.5 ratio heuristic when the font is unavailable", () => {
    const broken = createVendoredFontMeasure("/nonexistent/font.ttf");
    expect(broken("hello", 16, "")).toBeCloseTo(5 * 16 * 0.5, 5);
    // Ahem and monospace special-cases still apply without the font.
    expect(broken("XX", 16, "Ahem")).toBe(32);
    expect(broken("xx", 16, "monospace")).toBeCloseTo(2 * 16 * 0.6, 5);
  });
});
