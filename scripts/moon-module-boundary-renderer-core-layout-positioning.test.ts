import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core layout positioning boundaries", () => {
  it("keeps renderer absolute positioning helpers out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/absolute_positioning.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn resolve_inset_for_root",
      "fn inset_is_definite_for_root",
      "fn resolve_out_of_flow_root_auto_size",
      "fn is_svg_container_id",
      "fn establishes_absolute_containing_block",
      "fn is_auto_inset",
      "fn compute_abspos_non_auto_inset_alignment_offset",
      "fn apply_zoom_and_scale",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer viewport skeleton helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/viewport_skeleton.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "let viewport_estimated_y",
      "let viewport_cutoff",
      "let viewport_skeleton_count",
      "let viewport_full_node_count",
      "let viewport_full_node_cutoff",
      "let viewport_skeleton_enabled",
      "let empty_indexed_stylesheets",
      "fn should_use_viewport_skeleton",
      "fn parse_skeleton_px_length",
      "fn apply_skeleton_inline_style_hints",
      "fn apply_skeleton_inline_display_hint",
      "fn apply_skeleton_inline_height_hint",
      "fn viewport_skeleton_advance",
      "fn skeleton_parent_allows_explicit_size_hints",
      "fn should_collapse_viewport_skeleton_subtree",
      "fn should_advance_viewport_estimate",
      "viewport_skeleton_count.val += 1",
      "apply_skeleton_inline_style_hints(",
      "apply_skeleton_inline_display_hint(",
      "viewport_skeleton_advance(",
      "should_collapse_viewport_skeleton_subtree(",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer box sizing helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/box_sizing.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn resolve_dimension_to_px",
      "fn resolve_dimension_with_percent_basis",
      "fn is_zero_dimension_value",
      "fn has_zero_box_offsets",
      "fn adjust_for_box_sizing",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
