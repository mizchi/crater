import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

const read = (relativePath: string): string => {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8");
};

const INTEROP_FILES = [
  "painter/svg/interop.mbt",
  "painter/svg/interop_core.mbt",
  "painter/svg/interop_animation_resource.mbt",
  "painter/svg/interop_geometry_node.mbt",
  "painter/svg/interop_paint_effects.mbt",
  "painter/svg/interop_text_symbol.mbt",
] as const;

describe("MoonBit painter/svg interop boundaries", () => {
  it("keeps @msvg interop helpers split by responsibility", () => {
    const missing = INTEROP_FILES.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));
    expect(missing).toEqual([]);

    // interop.mbt is the package overview: only a comment, no logic.
    const overview = read("painter/svg/interop.mbt");
    expect(overview).toContain("mizchi/svg interop adapters are split by responsibility");
    expect(countLines("painter/svg/interop.mbt")).toBeLessThanOrEqual(5);

    // interop_core.mbt holds the foundational shape converters.
    const core = read("painter/svg/interop_core.mbt");
    expect(core).toContain("pub fn extract_root_view_box(");
    expect(core).toContain("fn transform_from_msvg(");
    expect(core).toContain("fn color_from_msvg(");
    expect(core).toContain("fn pointer_event_from_msvg(");

    // Specialized adapters own their own helpers, not interop_core.
    for (const [otherFile, markers] of [
      [
        "painter/svg/interop_animation_resource.mbt",
        ["fn image_from_msvg(", "fn sprite_from_msvg(", "fn animated_sprite_from_msvg("],
      ],
      ["painter/svg/interop_geometry_node.mbt", ["fn svg_node_from_msvg("]],
      ["painter/svg/interop_paint_effects.mbt", ["fn filter_from_msvg("]],
      ["painter/svg/interop_text_symbol.mbt", ["fn text_anchor_from_msvg("]],
    ] as const) {
      const adapter = read(otherFile);
      for (const marker of markers) {
        expect(adapter).toContain(marker);
        expect(core).not.toContain(marker);
      }
    }

    // The moon.pkg imports mizchi/svg as @msvg (the only upstream dependency the
    // adapters legitimately reach for).
    const moonPkg = read("painter/svg/moon.pkg");
    expect(moonPkg).toContain('"mizchi/svg" @msvg');
    for (const forbidden of [
      "mizchi/crater-webdriver",
      "mizchi/crater-browser",
      "mizchi/crater-renderer",
      "mizchi/crater-dom",
      "mizchi/js",
      "mizchi/webdriver",
    ]) {
      expect(moonPkg).not.toContain(forbidden);
    }
  });

  it("keeps this boundary test small enough to stay focused", () => {
    expect(countLines("scripts/moon-module-boundary-painter-svg-interop.test.ts")).toBeLessThanOrEqual(80);
  });
});
