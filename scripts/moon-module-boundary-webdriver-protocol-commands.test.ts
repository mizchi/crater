import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver protocol command boundaries", () => {
  it("keeps WebDriver BiDi browsing context handlers out of the protocol core", () => {
    const browsingContextFiles = [
      "webdriver/webdriver/bidi_protocol_dispatch_browsing_context.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_create.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_query.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_tree.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_close_state.mbt",
      "webdriver/webdriver/bidi_protocol_browsing_context_navigation_state_helpers.mbt",
    ];
    for (const file of browsingContextFiles) {
      expect(fs.existsSync(path.join(REPO_ROOT, file)), file).toBe(true);
    }

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_browsing_context_create_synthetic_child_context",
      "fn BidiProtocol::handle_browsing_context_get_context_scope_info",
      "fn BidiProtocol::handle_browsing_context_get_tree_contexts",
      "fn BidiProtocol::resolve_current_context_url",
      "fn BidiProtocol::create_top_level_context_from_params",
      "fn BidiProtocol::handle_browsing_context_prepare_navigate",
      "fn BidiProtocol::complete_navigate_with_state",
      "fn BidiProtocol::handle_browsing_context_close_mode",
      "fn BidiProtocol::build_context_tree",
      "fn BidiProtocol::resolve_get_tree_contexts",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi network command handlers out of the protocol core", () => {
    const networkCommandFiles = [
      "webdriver/webdriver/bidi_protocol_dispatch_network.mbt",
      "webdriver/webdriver/bidi_protocol_network_intercept_commands.mbt",
      "webdriver/webdriver/bidi_protocol_network_data_collector_commands.mbt",
      "webdriver/webdriver/bidi_protocol_network_extra_header_commands.mbt",
    ];
    for (const file of networkCommandFiles) {
      expect(fs.existsSync(path.join(REPO_ROOT, file)), file).toBe(true);
    }

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_network_add_intercept",
      "fn BidiProtocol::handle_network_add_intercept_id",
      "fn BidiProtocol::handle_network_remove_intercept",
      "fn BidiProtocol::handle_network_add_data_collector",
      "fn BidiProtocol::handle_network_add_data_collector_id",
      "fn BidiProtocol::handle_network_set_extra_headers",
      "fn BidiProtocol::handle_network_remove_data_collector",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi browser handlers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_browser.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_browser_has_user_context",
      "fn BidiProtocol::handle_browser_has_user_context_value",
      "fn BidiProtocol::resolve_browser_has_user_context_known",
      "fn BidiProtocol::resolve_browser_user_contexts_list",
      "fn BidiProtocol::resolve_browser_client_windows_list",
      "fn BidiProtocol::resolve_browser_create_user_context",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi session test helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_session.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_session_is_subscribed_for_context",
      "fn BidiProtocol::handle_session_prepare_baseline_context_for_test",
      "fn BidiProtocol::recreate_default_context_with_id",
      "fn BidiProtocol::handle_session_get_baseline_context_info_for_test",
      "fn BidiProtocol::handle_session_get_baseline_context_info_value_for_test",
      "fn BidiProtocol::build_context_info_for_test",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
