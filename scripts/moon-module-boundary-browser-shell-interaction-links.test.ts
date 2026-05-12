import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser shell link interaction boundaries", () => {
  it("keeps browser shell link extraction in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/link_extraction.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn char_at",
      "fn extract_links_fallback",
      "extern \"js\" fn extract_links_js",
      "fn extract_links",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell link cache refresh with link extraction", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/rendering.mbt"), "utf8");
    const implementationMarkers = ["fn Browser::refresh_links_from_render_source"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell link resolution in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/link_resolution.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/focus_hit_testing.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn Browser::get_extracted_link_href_for_source_id",
      "fn Browser::get_a11y_link_href_for_source_id",
      "fn Browser::get_link_href_for_source_id",
      "fn Browser::get_link_href_for_region",
      "fn Browser::get_href_for_source_id",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell hint mode in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/hint_mode.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::is_hint_mode",
      "fn Browser::enter_hint_mode",
      "fn generate_single_label",
      "fn Browser::exit_hint_mode",
      "fn Browser::process_hint_char",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
