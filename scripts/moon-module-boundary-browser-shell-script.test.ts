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

describe("MoonBit browser shell script boundaries", () => {
  it("keeps browser shell JavaScript execution in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/js_execution.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::set_js_runtime",
      "fn decode_js_string_result",
      "fn Browser::flush_js_logs",
      "fn escape_js_string",
      "fn Browser::execute_inline_js",
      "fn Browser::process_pending_script_tasks",
      "priv struct ScriptInfo",
      "fn extract_scripts",
      "fn Browser::init_js_execution",
      "fn Browser::execute_scripts",
      "fn Browser::execute_scripts_async",
      "fn Browser::sync_render_state_from_dom_tree",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell script extraction in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/script_extraction.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/js_execution.mbt"), "utf8");
    const implementationMarkers = [
      "priv struct ScriptInfo",
      "fn is_executable_script_type",
      "fn extract_scripts",
      "char_at(html",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell external script fetching in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/script_fetch.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/js_execution.mbt"), "utf8");
    const implementationMarkers = [
      "@http.cached_fetch_async",
      "@http.FetchOptions::default()",
      "@http.RequestMode::NoCors",
      "http_fetch_adapter",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell script DOM runtime in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/script_dom_runtime.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/js_execution.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::init_js_execution",
      "fn Browser::sync_render_state_from_dom_tree",
      "html_source_requires_runtime_rebuild",
      "build_dom_tree_from_source_html",
      "@js.serialize_dom_to_html",
      "@renderer.get_content_height_with_document",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell source DOM reconstruction in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/source_dom.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn build_dom_tree_from_document",
      "fn html_source_has_declarative_shadow_dom",
      "priv struct SourceHtmlFragment",
      "priv struct NormalizedShadowSourceHtml",
      "fn parse_html_attributes",
      "fn extract_source_html_fragment",
      "fn write_set_attributes_js",
      "fn create_empty_html_dom_tree",
      "fn normalize_declarative_shadow_source_html_with_hint",
      "fn build_dom_tree_from_source_html",
      "fn build_dom_children",
      "fn build_dom_element",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
