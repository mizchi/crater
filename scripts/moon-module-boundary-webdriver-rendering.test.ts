import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

const read = (relativePath: string): string => {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8");
};

describe("MoonBit WebDriver rendering boundaries", () => {
  it("keeps pure rendering validation helpers outside the implementation facade", () => {
    const expectedRenderingFiles = [
      "webdriver/rendering/moon.pkg",
      "webdriver/rendering/actual_paint.mbt",
      "webdriver/rendering/actual_paint_test.mbt",
      "webdriver/rendering/capture_result.mbt",
      "webdriver/rendering/capture_result_test.mbt",
      "webdriver/rendering/screenshot.mbt",
      "webdriver/rendering/screenshot_test.mbt",
      "webdriver/rendering/validation.mbt",
      "webdriver/rendering/validation_test.mbt",
    ] as const;
    const missingFiles = expectedRenderingFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });

    expect(missingFiles).toEqual([]);

    const renderingPackage = read("webdriver/rendering/moon.pkg");
    expect(renderingPackage).not.toContain("mizchi/crater\"");
    expect(renderingPackage).not.toContain("mizchi/js");
    expect(renderingPackage).not.toContain("mizchi/webdriver");

    const webdriverPackage = read("webdriver/webdriver/moon.pkg");
    expect(webdriverPackage).toContain('"mizchi/crater-webdriver-bidi/rendering" @rendering');

    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_rendering_validation.mbt"))).toBe(false);
    const printSource = read("webdriver/webdriver/bidi_protocol_browsing_context_print.mbt");
    expect(printSource).toContain("@rendering.normalize_print_options");
    const screenshotSource = read("webdriver/webdriver/bidi_protocol_browsing_context_screenshot.mbt");
    expect(screenshotSource).toContain("@rendering.normalize_capture_screenshot_options");
    const actualPaintSource = read("webdriver/webdriver/bidi_browsing_context_actual_paint.mbt");
    expect(actualPaintSource).toContain(
      "@rendering.actual_paint_document_dimensions_from_node_and_layout",
    );
    expect(actualPaintSource).toContain("@rendering.should_use_font_aware_text_provider");
    expect(actualPaintSource).toContain("@rendering.capture_timing_to_json");
    expect(actualPaintSource).toContain("@rendering.capture_visual_to_json");

    const implementationSources = [
      "webdriver/webdriver/bidi_protocol_input_helpers.mbt",
      "webdriver/webdriver/bidi_browsing_context_actual_paint.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_print.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_screenshot.mbt",
    ].map(read).join("\n");
    for (const marker of [
      "fn is_valid_print_page_range",
      "let default_print_margin_cm",
      "let minimum_printable_cm",
      "margin values must be non-negative numbers",
      "pageRanges entries are invalid",
      "clip.box x/y/width/height must be numbers",
      "format.quality must be a number in [0,1]",
      "fn actual_paint_layout_content_right",
      "fn actual_paint_layout_content_bottom",
      "fn actual_paint_document_dimensions_from_node_and_layout",
      "fn should_use_font_aware_text_provider",
      "fn capture_timing_to_json",
      "fn capture_visual_to_json",
    ] as const) {
      expect(implementationSources).not.toContain(marker);
    }
  });

  it("keeps rendering boundary tests small enough to stay focused", () => {
    expect(countLines("scripts/moon-module-boundary-webdriver-rendering.test.ts")).toBeLessThanOrEqual(90);
  });
});
