import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  BROWSER_TERMINAL_PROTOCOL_ANSI_FILES,
  DIRECT_TUI_TERMINAL_PROTOCOL_FILES,
  REPO_ROOT,
  collectMoonBitFiles,
  collectMoonPackageFiles,
  countLines,
} from "./moon-module-boundary-helpers";

describe("MoonBit browser shell navigation boundaries", () => {
  it("keeps browser shell navigation implementation in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/navigation.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn resolve_url",
      "fn decode_sync_navigable_html_url",
      "fn Browser::load_sync_navigable_html_request",
      "fn Browser::navigate_sync_if_supported",
      "fn fetch_external_css",
      "fn Browser::load_url_request",
      "fn Browser::load_url_lightweight",
      "fn Browser::go_back",
      "fn Browser::go_forward",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell navigation URL helpers in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/navigation_url.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/navigation.mbt"), "utf8");
    const implementationMarkers = [
      "fn resolve_url",
      "fn make_substr",
      "fn hex_digit_to_int",
      "fn percent_decode_data_url_payload",
      "fn decode_sync_navigable_html_url",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell external CSS fetch in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/external_css_fetch.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/navigation.mbt"), "utf8");
    const implementationMarkers = [
      "fn http_fetch_adapter",
      "fn fetch_external_css",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell focus navigation in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/focus_navigation.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/focus_hit_testing.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn Browser::is_bounds_visible",
      "fn Browser::is_focus_node_visible",
      "fn Browser::next_link",
      "fn Browser::prev_link",
      "fn Browser::get_focused_element_name",
      "fn Browser::get_focused_link_url",
      "fn Browser::get_focused_source_id",
      "fn Browser::focus_source_id",
      "fn Browser::get_visible_focusable_count",
      "fn Browser::get_visible_focus_index",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell content lifecycle in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/content_lifecycle.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = ["fn Browser::set_html_content"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps navigation HTML source lifecycle out of navigation", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/navigation.mbt"), "utf8");
    const implementationMarkers = [
      "html_source_has_declarative_shadow_dom",
      "normalize_declarative_shadow_source_html_with_hint",
      "@html.parse_document(self.html_content)",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps navigation fetch plumbing in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/navigation_fetch.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/navigation.mbt"), "utf8");
    const implementationMarkers = [
      "@http.fetch",
      "@http.FetchOptions::default()",
      "get_cookie_header",
      "store_from_header",
      "page_headers",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
