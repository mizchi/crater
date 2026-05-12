import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core document style boundaries", () => {
  it("keeps renderer document preparation out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/document_prepare.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "pub struct PseudoRule",
      "pub struct PseudoRuleIndex",
      "fn PseudoRuleIndex::build",
      "fn PseudoRuleIndex::get_candidates",
      "pub struct PreparedExternalCss",
      "let external_css_bundle_cache",
      "fn external_css_cache_key",
      "fn collect_pseudo_rules_from_stylesheet",
      "fn empty_prepared_external_css",
      "pub fn prepare_external_css",
      "pub struct PreparedRenderDocument",
      "pub fn prepare_render_document",
      "pub fn prepare_render_document_with_prepared_external_css",
      "fn prepare_render_document_with_external_css_bundle",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer generated content and counters out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/generated_content.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "priv struct CounterEntry",
      "priv struct CounterDirective",
      "priv enum ContentPart",
      "priv enum PseudoKind",
      "fn parse_counter_directives",
      "fn copy_counter_state",
      "fn filter_counter_state_for_style_containment",
      "fn apply_counter_reset_directives",
      "fn apply_counter_increment_directives",
      "fn counter_value",
      "fn resolve_pseudo_attr_functions",
      "fn resolve_pseudo_content_value",
      "fn parse_content_parts",
      "fn evaluate_content_parts",
      "fn selector_text_without_pseudo",
      "fn create_generated_pseudo_node",
      "fn apply_generated_pseudo_host_style_offsets",
      "fn resolve_pseudo_spec",
      "fn resolve_pseudo_spec_fast",
      "fn get_counter_directives",
      "fn selector_has_generated_pseudo_content",
      "fn compute_element_own_counters",
      "spec.position_relative && spec.left_offset",
      "compute_element_own_counters(",
      "resolve_pseudo_spec_fast(",
      "apply_generated_pseudo_host_style_offsets(",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
