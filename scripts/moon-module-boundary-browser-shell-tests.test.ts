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

describe("MoonBit browser shell regression test boundaries", () => {
  it("keeps browser JS runtime regression tests in their own file", () => {
    const runtimeTestFile = path.join(REPO_ROOT, "browser/shell/browser_js_runtime_wbtest.mbt");
    expect(fs.existsSync(runtimeTestFile)).toBe(true);

    const runtimeSource = fs.readFileSync(runtimeTestFile, "utf8");
    const browserJsSource = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/browser_js_wbtest.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "extract_scripts extracts inline script"',
      'test "Browser init_js_execution creates DOM tree"',
      'test "Browser execute_scripts runs inline scripts"',
      'test "WPT-style: createElement and appendChild"',
      'test "Browser tick_js applies queued JS tasks to render output"',
    ] as const;

    expect(migratedTests.every((marker) => runtimeSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => browserJsSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser JS interaction regression tests in their own file", () => {
    const interactionTestFile = path.join(
      REPO_ROOT,
      "browser/shell/browser_js_interaction_wbtest.mbt",
    );
    expect(fs.existsSync(interactionTestFile)).toBe(true);

    const interactionSource = fs.readFileSync(interactionTestFile, "utf8");
    const browserJsSource = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/browser_js_wbtest.mbt"),
      "utf8",
    );
    const migratedTests = [
      'async test "Browser activate_focused_link dispatches onclick and repaints"',
      'async test "Browser activate_at prefers topmost overlapping painted element"',
      'async test "Browser pointer drag dispatches drag sequence between source and target"',
      'async test "Browser activate_at prefers topmost persisted addEventListener element"',
    ] as const;

    expect(migratedTests.every((marker) => interactionSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => browserJsSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser JS navigation and form regression tests in their own file", () => {
    const navigationTestFile = path.join(
      REPO_ROOT,
      "browser/shell/browser_js_navigation_wbtest.mbt",
    );
    expect(fs.existsSync(navigationTestFile)).toBe(true);

    const navigationSource = fs.readFileSync(navigationTestFile, "utf8");
    const browserJsSource = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/browser_js_wbtest.mbt"),
      "utf8",
    );
    const migratedTests = [
      'async test "Browser activate_at submits GET form and navigates"',
      'test "Browser execute_inline_js form.requestSubmit preserves post body metadata"',
      'async test "Browser execute_inline_js_async requestSubmit posts body to external fetch"',
      'async test "Browser activate_focused_link submits focused button form"',
      'async test "Browser execute_inline_js setRangeText updates focused text input"',
    ] as const;

    expect(migratedTests.every((marker) => navigationSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => browserJsSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps remaining browser JS render, shadow DOM, and focus tests split by domain", () => {
    const renderTestFile = path.join(REPO_ROOT, "browser/shell/browser_js_render_wbtest.mbt");
    const shadowTestFile = path.join(REPO_ROOT, "browser/shell/browser_js_shadow_wbtest.mbt");
    const focusTestFile = path.join(REPO_ROOT, "browser/shell/browser_js_focus_wbtest.mbt");
    expect(fs.existsSync(renderTestFile)).toBe(true);
    expect(fs.existsSync(shadowTestFile)).toBe(true);
    expect(fs.existsSync(focusTestFile)).toBe(true);

    const renderSource = fs.readFileSync(renderTestFile, "utf8");
    const shadowSource = fs.readFileSync(shadowTestFile, "utf8");
    const focusSource = fs.readFileSync(focusTestFile, "utf8");
    const browserJsSource = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/browser_js_wbtest.mbt"),
      "utf8",
    );
    const renderTests = [
      'test "Browser getter API returns initial state"',
      'test "kitty render overlays cached image data for img src regions"',
      'test "sixel render composites cached data png image for img src"',
    ] as const;
    const shadowTests = [
      'async test "Browser sync_render_state_from_dom_tree renders shadow root composed content"',
      'test "Browser render_output normalizes declarative shadow DOM from initial HTML"',
      'async test "Browser sync_render_state_from_dom_tree renders distributed slot content"',
    ] as const;
    const focusTests = [
      'async test "Browser handle_focused_key dispatches change event for focused text input on Enter"',
      'async test "Browser pointer drag selects text in focused input before typing"',
      'async test "Browser activate_at resets form controls for reset button"',
    ] as const;
    const migratedTests = [...renderTests, ...shadowTests, ...focusTests] as const;

    expect(renderTests.every((marker) => renderSource.includes(marker))).toBe(true);
    expect(shadowTests.every((marker) => shadowSource.includes(marker))).toBe(true);
    expect(focusTests.every((marker) => focusSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => browserJsSource.includes(marker));
    expect(offenders).toEqual([]);
  });
});
