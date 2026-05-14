import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade boundaries", () => {
  it("keeps SVG type facade boundary tests split by SVG sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-svg-types-animation.test.ts",
      "scripts/moon-module-boundary-svg-types-core.test.ts",
      "scripts/moon-module-boundary-svg-types-effects.test.ts",
      "scripts/moon-module-boundary-svg-types-interaction.test.ts",
      "scripts/moon-module-boundary-svg-types-raster.test.ts",
      "scripts/moon-module-boundary-svg-types-text-symbol.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-svg-types.test.ts")).toBeLessThanOrEqual(80);
  });

  it("keeps mizchi/svg interop adapters split by SVG responsibility", () => {
    const adapterFiles = [
      "painter/svg/interop_animation_resource.mbt",
      "painter/svg/interop_core.mbt",
      "painter/svg/interop_geometry_node.mbt",
      "painter/svg/interop_paint_effects.mbt",
      "painter/svg/interop_text_symbol.mbt",
    ];
    const missingFiles = adapterFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("painter/svg/interop.mbt")).toBeLessThanOrEqual(80);
    for (const file of adapterFiles) {
      expect(countLines(file)).toBeLessThanOrEqual(520);
    }
  });
});
