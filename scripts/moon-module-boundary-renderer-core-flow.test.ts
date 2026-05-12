import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core flow boundaries", () => {
  it("keeps renderer inline-flow helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/inline_flow.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn is_inline_element_by_tag",
      "fn is_inline_element(",
      "fn will_have_non_inline_display",
      "fn is_inline_participating_display",
      "fn has_inline_participating_display",
      "fn is_whitespace_only_text",
      "fn is_collapsible_whitespace_char",
      "fn trim_collapsible_whitespace_edges",
      "fn trim_boundary_collapsible_whitespace_for_inline_context",
      "fn should_preserve_inter_element_whitespace",
      "fn should_preserve_inline_element",
      "fn contains_preserved_inline_descendant",
      "fn collect_text_from_inline",
      "fn contains_replaced_element",
      "fn contains_block_child",
      "fn has_direct_display_contents_child",
      "fn has_direct_contents_class_child",
      "fn is_out_of_flow_positioned",
      "fn collect_inline_content",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer styled child node construction out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/styled_children.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "let mut prev_sibling_counters",
      "let mut prev_selector_sibling",
      "html_to_selector_element_with_parent(",
      "trim_boundary_collapsible_whitespace_for_inline_context(",
      "should_preserve_inter_element_whitespace(",
      "filter_counter_state_for_style_containment(",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer text node creation out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/text_node.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn create_text_node",
      "let normalized_text = if parent_style.display == @types.TableCell",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
