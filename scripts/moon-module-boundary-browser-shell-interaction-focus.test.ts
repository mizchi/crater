import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser shell focus interaction boundaries", () => {
  it("keeps browser shell focus and hit testing in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/focus_hit_testing.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::is_bounds_visible",
      "fn Browser::next_link",
      "fn Browser::prev_link",
      "fn Browser::ensure_declarative_shadow_dom_normalized",
      "fn Browser::build_accessibility_tree",
      "fn Browser::get_focused_element_name",
      "fn Browser::get_focused_source_id",
      "fn Browser::get_link_source_id_at",
      "fn Browser::get_link_href_for_source_id",
      "fn Browser::is_clickable_source_id",
      "fn Browser::get_a11y_source_id_at",
      "fn Browser::get_source_id_at",
      "fn Browser::focus_source_id",
      "fn Browser::get_visible_focus_index",
      "fn Browser::get_link_at",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell accessibility tree building in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/accessibility_tree.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/focus_hit_testing.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn Browser::ensure_declarative_shadow_dom_normalized",
      "fn Browser::build_accessibility_tree",
      "fn Browser::build_accessibility_tree_lightweight",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
