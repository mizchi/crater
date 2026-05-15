import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver protocol rendering boundaries", () => {
  it("keeps WebDriver BiDi browsingContext rendering commands out of the protocol core", () => {
    const renderingCommandFiles = [
      "webdriver/webdriver/bidi_protocol_dispatch_browsing_context_rendering.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_viewport_history.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_screenshot.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_print.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_locate_nodes.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_locate_nodes_helpers.mbt",
    ];
    for (const file of renderingCommandFiles) {
      expect(fs.existsSync(path.join(REPO_ROOT, file)), file).toBe(true);
    }

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_set_viewport",
      "fn BidiProtocol::handle_traverse_history",
      "fn BidiProtocol::handle_capture_screenshot",
      "fn BidiProtocol::handle_capture_screenshot_data",
      "fn BidiProtocol::resolve_capture_screenshot_data",
      "fn BidiProtocol::handle_print",
      "fn BidiProtocol::handle_print_data",
      "fn BidiProtocol::resolve_print_data",
      "fn is_valid_print_page_range",
      "fn is_valid_locate_nodes_locator_type",
      "fn xpath_to_css_selector",
      "fn BidiProtocol::handle_locate_nodes",
      "fn normalize_svg_namespace_in_nodes",
      "fn BidiProtocol::locate_nodes_css",
      "fn BidiProtocol::evaluate_locate_expression",
      "fn BidiProtocol::create_synthetic_child_context_result",
      "fn BidiProtocol::locate_nodes_xpath",
      "fn BidiProtocol::locate_nodes_inner_text",
      "fn BidiProtocol::locate_nodes_accessibility",
      "fn BidiProtocol::locate_nodes_context",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
