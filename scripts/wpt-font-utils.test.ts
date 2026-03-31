import fs from "node:fs";
import { describe, expect, it } from "vitest";
import {
  resolveBundledWptFontByFamily,
  resolveBundledWptFontUrl,
} from "./wpt-font-utils.ts";

describe("wpt-font-utils", () => {
  it("resolves bundled Ahem font metadata case-insensitively", () => {
    const font = resolveBundledWptFontByFamily("Ahem");

    expect(font).not.toBeNull();
    expect(font?.family).toBe("ahem");
    expect(font?.fileName).toBe("Ahem.ttf");
  });

  it("points bundled Ahem font URLs at an existing fixture", () => {
    const font = resolveBundledWptFontByFamily("Ahem");
    expect(font).not.toBeNull();

    const fontUrl = resolveBundledWptFontUrl(font!.fileName);
    expect(fs.existsSync(fontUrl)).toBe(true);
  });
});
