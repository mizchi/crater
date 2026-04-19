import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import {
  DEFAULT_TEXT_FONT_FAMILY,
  resolveEffectiveFontFamily,
} from "./font-family-defaults.ts";

describe("font-family defaults", () => {
  test("uses serif as the browser-like default for unspecified text", () => {
    expect(DEFAULT_TEXT_FONT_FAMILY).toBe("serif, times new roman");
    expect(resolveEffectiveFontFamily("")).toBe("serif, times new roman");
    expect(resolveEffectiveFontFamily(undefined)).toBe("serif, times new roman");
  });

  test("preserves explicit families", () => {
    expect(resolveEffectiveFontFamily("sans-serif")).toBe("sans-serif");
    expect(resolveEffectiveFontFamily("\"Helvetica Neue\", sans-serif")).toBe(
      "\"Helvetica Neue\", sans-serif",
    );
  });

  test("start-with-font routes missing families through the shared default helper", () => {
    const source = readFileSync(
      new URL("../browser/jsbidi/bidi_main/start-with-font.ts", import.meta.url),
      "utf8",
    );

    expect(source).not.toMatch(/\|\|\s*"sans-serif"/);
    expect(source).toContain("resolveEffectiveFontFamily");
  });
});
