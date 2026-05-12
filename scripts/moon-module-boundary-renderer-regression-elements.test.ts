import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer element regression test boundaries", () => {
  it("keeps renderer form control regression tests in their own file", () => {
    const formControlTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/form_control_render_test.mbt",
    );
    expect(fs.existsSync(formControlTestFile)).toBe(true);

    const formControlSource = fs.readFileSync(formControlTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "contain_size_select_single_uses_empty_control_metrics"',
      'test "input_button_like_intrinsic_width_uses_value_length"',
      'test "wpt_justify_self_widgets_textarea_keeps_browser_default_block_heights"',
    ] as const;

    expect(migratedTests.every((marker) => formControlSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer replaced media regression tests in their own file", () => {
    const replacedMediaTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/replaced_media_render_test.mbt",
    );
    expect(fs.existsSync(replacedMediaTestFile)).toBe(true);

    const replacedMediaSource = fs.readFileSync(replacedMediaTestFile, "utf8");
    const sourceFiles = [
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
    ];
    const sourceText = sourceFiles.map((file) => fs.readFileSync(file, "utf8")).join("\n");
    const migratedTests = [
      'test "intrinsic_percent_replaced_wpt_style"',
      'test "video_with_source_children_keeps_explicit_replaced_size"',
      'test "br element preserved as separate node with line-height"',
    ] as const;

    expect(migratedTests.every((marker) => replacedMediaSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => sourceText.includes(marker));
    expect(offenders).toEqual([]);
  });
});
