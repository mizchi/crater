import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core style resolve boundaries", () => {
  it("keeps renderer nested element style adjustment out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/element_style_adjust.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      'elem.attributes.contains("hidden")',
      'tag_lower == "dialog"',
      "preserve_inline_contain",
      "is_ruby_internal",
      "contains_block_child(",
      "has_direct_display_contents_child(",
      "has_direct_contents_class_child(",
      "contains_replaced_element(",
      "apply_svg_attributes_to_style(",
      "apply_svg_intrinsic_size(",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer SVG style helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/svg_style.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn is_svg_element",
      "fn selector_parent_is_svg",
      "fn normalize_svg_display_contents",
      "fn apply_svg_attributes_to_style",
      "fn apply_svg_intrinsic_size",
      "fn parse_svg_length",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer style resolution helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/style_resolve.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn is_root_selector",
      "fn clone_string_map",
      "fn collect_cascaded_custom_properties",
      "fn collect_inline_custom_properties",
      "fn collect_root_css_variables",
      "fn get_ua_default_style",
      "fn uses_table_normal_line_height",
      "fn normalize_display_contents_for_unusual_html",
      "fn compute_element_style_indexed",
      "fn compute_element_css_vars_indexed",
      "fn apply_css_property_with_viewport",
      "pub fn apply_css_property_debug",
      "fn apply_inline_css_with_vars",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
