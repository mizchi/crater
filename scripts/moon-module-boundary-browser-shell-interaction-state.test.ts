import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser shell interaction state boundaries", () => {
  it("keeps browser shell scroll state in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/scroll_state.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::max_scroll",
      "fn Browser::scroll_down",
      "fn Browser::scroll_up",
      "fn Browser::init_element_scroll",
      "fn Browser::clear_element_scroll_states",
      "fn Browser::init_scrollable_elements",
      "fn Browser::get_element_scroll_positions",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell option accessors in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/browser_options.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::set_enable_js",
      "fn Browser::set_enable_cookies",
      "fn Browser::set_image_cache_max_bytes",
      "fn Browser::set_request_sandbox",
      "fn Browser::get_dom_tree",
      "fn Browser::get_current_url",
      "fn Browser::get_last_navigation_url",
      "fn Browser::get_viewport_height",
      "fn Browser::get_link_count",
      "fn Browser::get_focused_link_index",
      "fn Browser::toggle_selection_mode",
      "fn Browser::toggle_dark_mode",
      "fn Browser::set_dark_mode",
      "fn Browser::set_no_color",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
