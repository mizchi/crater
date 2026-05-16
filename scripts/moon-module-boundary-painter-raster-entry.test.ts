import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

const read = (relativePath: string): string => {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8");
};

const EXPECTED_RASTER_LEAVES = [
  "painter/paint/raster/paint_raster.mbt",
  "painter/paint/raster/glyph_blit.mbt",
  "painter/paint/raster/glyph_render.mbt",
  "painter/paint/raster/framebuffer.mbt",
  "painter/paint/raster/framebuffer_encode.mbt",
  "painter/paint/raster/bitmap_text.mbt",
  "painter/paint/raster/bitmap_font_data.mbt",
  "painter/paint/raster/bitmap_font_metrics.mbt",
] as const;

const PAINT_RASTER_FORBIDDEN_MARKERS = [
  "fn rasterize_glyph_to_bitmap(",
  "fn layout_glyph_bitmaps(",
  "fn scanline_intersections_even_odd(",
  "let glyph_bitmap_cache",
  "let glyph_cache",
  "fn glyph_cache_key(",
  "pub fn pre_rasterize_glyphs(",
  "pub fn cached_glyph_bitmap(",
  "pub(all) struct GlyphBitmap",
  "pub(all) struct GlyphProvider",
  "fn measure_word_width(",
  "fn split_text_into_words(",
  "fn collapsed_space_advance(",
];

describe("MoonBit painter raster entry boundaries", () => {
  it("keeps paint_raster.mbt as a thin renderer entry, with leaves split out", () => {
    const missing = EXPECTED_RASTER_LEAVES.filter(
      (file) => !fs.existsSync(path.join(REPO_ROOT, file)),
    );
    expect(missing).toEqual([]);

    const entrySource = read("painter/paint/raster/paint_raster.mbt");
    for (const marker of PAINT_RASTER_FORBIDDEN_MARKERS) {
      expect(entrySource).not.toContain(marker);
    }

    // The entry should stay small: just the public render_* funcs and one private dispatcher.
    expect(countLines("painter/paint/raster/paint_raster.mbt")).toBeLessThanOrEqual(150);

    // glyph_blit.mbt must hold only the bitmap compositing helpers.
    const glyphBlit = read("painter/paint/raster/glyph_blit.mbt");
    expect(glyphBlit).toContain("fn blit_glyph_bitmap(");
    expect(glyphBlit).not.toContain("fn rasterize_glyph_to_bitmap(");
    expect(glyphBlit).not.toContain("fn layout_glyph_bitmaps(");
    expect(countLines("painter/paint/raster/glyph_blit.mbt")).toBeLessThanOrEqual(120);
  });

  it("keeps this boundary test small enough to stay focused", () => {
    expect(countLines("scripts/moon-module-boundary-painter-raster-entry.test.ts")).toBeLessThanOrEqual(80);
  });
});
