import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

const read = (relativePath: string): string => {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8");
};

const BROWSER_DOMAIN_FILES = [
  "webdriver/browser_domain/moon.pkg",
  "webdriver/browser_domain/bluetooth.mbt",
  "webdriver/browser_domain/emulation.mbt",
  "webdriver/browser_domain/geolocation.mbt",
  "webdriver/browser_domain/permissions.mbt",
  "webdriver/browser_domain/screen.mbt",
  "webdriver/browser_domain/screen_orientation.mbt",
  "webdriver/browser_domain/web_extension.mbt",
] as const;

const SYNTHETIC_CALLERS: ReadonlyArray<readonly [string, string]> = [
  ["webdriver/webdriver/bidi_bluetooth_synthetic.mbt", "@browser_domain.bluetooth_scope_key"],
  ["webdriver/webdriver/bidi_emulation_synthetic.mbt", "@browser_domain.default_runtime_user_agent"],
  ["webdriver/webdriver/bidi_geolocation_synthetic.mbt", "@browser_domain.default_geolocation_coordinates_json"],
  ["webdriver/webdriver/bidi_permissions_synthetic.mbt", "@browser_domain.is_supported_permission_name"],
  ["webdriver/webdriver/bidi_screen_orientation_synthetic.mbt", "@browser_domain.default_screen_orientation_json"],
  ["webdriver/webdriver/bidi_screen_settings_synthetic.mbt", "@browser_domain.build_screen_area_json"],
  ["webdriver/webdriver/bidi_web_extension_synthetic.mbt", "@browser_domain.is_valid_web_extension_archive_payload"],
];

const MOVED_DEFINITIONS = [
  "fn build_screen_area_json",
  "fn normalize_screen_area_json",
  "fn default_screen_orientation_json",
  "fn is_valid_screen_orientation_natural",
  "fn is_valid_screen_orientation_type",
  "fn compute_screen_orientation_angle",
  "fn normalize_screen_orientation_json",
  "fn is_supported_permission_name",
  "fn permission_scope_key",
  "fn normalize_permission_origin",
  "fn permission_scope_belongs_to_user_context",
  "fn extract_permissions_query_name",
  "fn is_valid_web_extension_archive_payload",
  "fn default_geolocation_coordinates_json",
  "fn build_geolocation_coordinates_override",
  "fn build_geolocation_error_override",
  "fn push_geolocation_number_remote_entry",
  "fn build_geolocation_coordinates_remote_value",
  "fn build_geolocation_error_remote_value",
  "fn geolocation_watch_scope_key",
  "fn geolocation_watch_scope_context",
  "fn normalize_geolocation_number_json",
  "fn default_runtime_user_agent",
  "fn emulation_timezone_offset_minutes",
  "fn extract_emulation_fetch_url",
  "fn bluetooth_device_field_string",
  "fn find_bluetooth_device_for_name",
  "fn upsert_bluetooth_device",
  "fn extract_first_bluetooth_string_argument",
  "fn make_bluetooth_requested_device_remote_value",
  "fn bluetooth_scope_key",
  "fn bluetooth_characteristic_prefix_key",
  "fn bluetooth_characteristic_scope_key",
  "fn bluetooth_descriptor_prefix_key",
  "fn bluetooth_descriptor_scope_key",
  "fn make_bluetooth_byte_remote_value",
  "fn extract_bluetooth_byte_array_literal",
  "fn extract_bluetooth_call_string_argument",
  "fn extract_bluetooth_uint8_array_data",
] as const;

describe("MoonBit WebDriver browser_domain boundaries", () => {
  it("keeps synthetic-domain pure helpers outside the implementation facade", () => {
    const missingFiles = BROWSER_DOMAIN_FILES.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));
    expect(missingFiles).toEqual([]);

    const browserDomainPackage = read("webdriver/browser_domain/moon.pkg");
    for (const forbidden of [
      'mizchi/crater"',
      "mizchi/crater-webdriver-bidi/webdriver",
      "mizchi/crater-webdriver-bidi/runtime",
      "mizchi/crater-webdriver-bidi/rendering",
      "mizchi/crater-network",
      "mizchi/crater-browser",
      "mizchi/crater-dom",
      "mizchi/crater-renderer",
      "mizchi/crater-painter",
      "mizchi/js",
      "mizchi/webdriver",
    ]) {
      expect(browserDomainPackage).not.toContain(forbidden);
    }
    expect(browserDomainPackage).toContain('"mizchi/crater-webdriver-bidi/protocol" @protocol');

    const webdriverPackage = read("webdriver/webdriver/moon.pkg");
    expect(webdriverPackage).toContain('"mizchi/crater-webdriver-bidi/browser_domain" @browser_domain');

    for (const [callerPath, marker] of SYNTHETIC_CALLERS) {
      expect(read(callerPath)).toContain(marker);
    }

    const implementationSources = SYNTHETIC_CALLERS.map(([file]) => read(file)).join("\n");
    for (const marker of MOVED_DEFINITIONS) {
      expect(implementationSources).not.toContain(marker);
    }
  });

  it("keeps the boundary test small enough to stay focused", () => {
    expect(countLines("scripts/moon-module-boundary-webdriver-browser-domain.test.ts")).toBeLessThanOrEqual(120);
  });
});
