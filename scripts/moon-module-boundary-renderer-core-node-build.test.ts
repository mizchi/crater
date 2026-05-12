import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core node build boundaries", () => {
  it("keeps renderer root element node construction out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/root_element_node.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn element_to_node_with_styles(",
      "empty_indexed_stylesheets.val",
      "html_to_selector_element(elem, parent)",
      "parent is None",
      "None, // Root element has no parent style",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer nested element node construction out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/nested_element_node.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn element_to_node_with_styles_internal(",
      "build_viewport_skeleton_node(",
      "compute_element_style_indexed(",
      "apply_element_visibility_attributes(",
      "should_advance_viewport_estimate(",
      "adjust_nested_element_style(",
      "compute_element_css_vars_indexed(",
      "resolve_element_counter_pseudos(",
      "build_styled_element_children(",
      "prune_closed_details_children(",
      "finalize_special_element_node(",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer render root helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/render_root.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "let active_before_index",
      "let active_after_index",
      "pub fn build_render_root_node",
      "pub fn compute_layout_from_render_root",
      "fn find_body(",
      "fn find_body_in_children",
      "fn resolve_document_root_zoom",
      "fn propagate_document_root_multicol_to_body",
      "fn should_layout_document_root",
      "fn select_render_root",
      "fn resolve_root_available_width",
      "fn node_with_style",
      "fn should_clamp_body_to_viewport",
      "fn adjust_root_height_for_viewport",
      "fn stretch_single_frameset_child_to_root",
      "fn create_zero_layout_from_node",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer simple element conversion out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/simple_element_node.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = ["pub fn element_to_node"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
