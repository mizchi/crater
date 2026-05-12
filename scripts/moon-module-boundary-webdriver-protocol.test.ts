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

describe("MoonBit WebDriver protocol module boundaries", () => {
  it("keeps WebDriver BiDi validation helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_validation.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::validate_session_subscribe_params",
      "fn BidiProtocol::validate_browser_create_user_context",
      "fn BidiProtocol::validate_network_add_intercept_params",
      "fn BidiProtocol::validate_network_set_extra_headers_params",
      "fn is_valid_network_pattern_url_pattern",
      "fn is_valid_subscription_id_format",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi JSON parameter helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_json.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn make_object",
      "fn get_field",
      "fn get_param_raw",
      "fn get_map_field_with_alias",
      "fn canonicalize_serialization_options_map",
      "fn resolve_runtime_context_id",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi message serialization out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_messages.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "priv struct BidiRequest",
      "priv struct BidiResponse",
      "priv enum BidiOutMessage",
      "fn BidiProtocol::process_message",
      "fn BidiProtocol::send_success",
      "fn response_to_json",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi wire envelopes in standalone mizchi/webdriver", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/bidi_wire/moon.pkg"))).toBe(false);

    const moduleJson = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, "webdriver/moon.mod.json"), "utf8"),
    );
    expect(moduleJson.deps["mizchi/webdriver"]).toBe("0.2.6");

    const packageSource = fs.readFileSync(path.join(REPO_ROOT, "webdriver/webdriver/moon.pkg"), "utf8");
    expect(packageSource).toContain("\"mizchi/webdriver/bidi\" @bidi_wire");

    const messageSource = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_messages.mbt"),
      "utf8",
    );
    expect(messageSource).toContain("@bidi_wire.parse_request(");
    expect(messageSource).toContain("@bidi_wire.success_response_to_json(");
    expect(messageSource).toContain("@bidi_wire.error_response_to_json_with_stacktrace(");
    expect(messageSource).toContain("@bidi_wire.event_to_json(");
    expect(messageSource).not.toContain("@json.parse(json_str)");
    expect(messageSource).not.toContain("\"type\"] = Json::string(\"success\")");
  });

  it("keeps WebDriver BiDi subscription state out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_subscription_state.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "subscriptions : Map[String, Bool]",
      "context_subscriptions : Map[String, Array[String]]",
      "user_context_subscriptions : Map[String, Array[String]]",
      "global_subscriptions : Array[String]",
      "global_unsubscribed_events : Array[String]",
      "subscription_events : Map[String, Array[String]]",
      "subscription_contexts : Map[String, Array[String]]",
      "subscription_user_contexts : Map[String, Array[String]]",
      "next_subscription_id : Int",
      "pending_log_entries : Map[String, Array[Json]]",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);

    const stateSource = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_subscription_state.mbt"),
      "utf8",
    );
    expect(stateSource).toContain("priv struct BidiSubscriptionState");
    expect(stateSource).toContain("fn BidiSubscriptionState::new(");
    expect(stateSource).toContain("fn BidiSubscriptionState::reset(");
    expect(stateSource).toContain("fn BidiSubscriptionState::generate_subscription_id(");
  });

  it("keeps WebDriver BiDi emulation state out of the protocol core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_emulation_state.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "emulation_user_agent_global : String?",
      "emulation_user_agent_by_context : Map[String, String]",
      "emulation_user_agent_by_user_context : Map[String, String]",
      "emulation_locale_global : String?",
      "emulation_locale_by_context : Map[String, String]",
      "emulation_locale_by_user_context : Map[String, String]",
      "emulation_timezone_global : String?",
      "emulation_timezone_by_context : Map[String, String]",
      "emulation_timezone_by_user_context : Map[String, String]",
      "emulation_geolocation_global : Json?",
      "emulation_geolocation_by_context : Map[String, Json]",
      "emulation_geolocation_by_user_context : Map[String, Json]",
      "emulation_network_conditions_global : Json?",
      "emulation_network_conditions_by_context : Map[String, Json]",
      "emulation_network_conditions_by_user_context : Map[String, Json]",
      "emulation_screen_orientation_global : Json?",
      "emulation_screen_orientation_by_context : Map[String, Json]",
      "emulation_screen_orientation_by_user_context : Map[String, Json]",
      "emulation_screen_area_global : Json?",
      "emulation_screen_area_by_context : Map[String, Json]",
      "emulation_screen_area_by_user_context : Map[String, Json]",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);

    const stateSource = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_emulation_state.mbt"),
      "utf8",
    );
    expect(stateSource).toContain("priv struct BidiEmulationState");
    expect(stateSource).toContain("fn BidiEmulationState::new(");
    expect(stateSource).toContain("fn BidiEmulationState::reset(");
  });

  it("keeps WebDriver BiDi dispatch routing out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_dispatch.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::dispatch(",
      "fn BidiProtocol::dispatch_session",
      "fn BidiProtocol::dispatch_browser",
      "fn BidiProtocol::dispatch_browsing_context",
      "fn BidiProtocol::dispatch_script",
      "fn BidiProtocol::dispatch_input",
      "fn BidiProtocol::dispatch_network",
      "fn BidiProtocol::dispatch_log",
      "fn split_method",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi browsing context handlers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_browsing_context.mbt")),
    ).toBe(true);

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

  it("keeps WebDriver BiDi script evaluation handlers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_script_eval.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn resolve_sync_await_expression_fallback",
      "fn resolve_sync_await_call_expression",
      "fn BidiProtocol::try_send_sync_await_expression_fallback",
      "fn BidiProtocol::try_send_sync_await_call_fallback",
      "fn BidiProtocol::handle_script_evaluate",
      "fn BidiProtocol::handle_script_call_function",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi script fixture helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_script_fixtures.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_script_get_element_for_test",
      "fn BidiProtocol::handle_script_prepare_loaded_static_test_page",
      "fn BidiProtocol::handle_script_load_static_test_page_for_test",
      "fn BidiProtocol::resolve_script_get_element_for_test",
      "fn BidiProtocol::resolve_script_create_iframe_context_result",
      "fn BidiProtocol::handle_script_fetch_for_test",
      "fn synthetic_fetch_request_headers_from_json",
      "extern \"js\" fn js_test_page_dom_content_loaded_source",
      "extern \"js\" fn js_fetch_from_context_for_test_expression",
      "extern \"js\" fn js_test_page_create_iframe_source",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi input action handlers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_input_actions.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_input_perform_actions",
      "fn BidiProtocol::handle_input_release_actions",
      "fn BidiProtocol::handle_input_set_files",
      "fn BidiProtocol::validate_input_context",
      "fn BidiProtocol::resolve_pointer_origin",
      "fn BidiProtocol::push_pressed_key",
      "fn button_to_mask",
      "extern \"js\" fn js_input_apply_file_selection",
      "fn BidiProtocol::try_handle_synthetic_file_dialog_eval",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi network command handlers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_network_commands.mbt")),
    ).toBe(true);

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

  it("keeps WebDriver BiDi log and script event helpers out of the protocol core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_log.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::emit_log_entry_with_details",
      "fn BidiProtocol::emit_log_entry",
      "fn BidiProtocol::emit_javascript_log_entry",
      "fn BidiProtocol::process_console_entries",
      "fn BidiProtocol::emit_script_message",
      "fn BidiProtocol::process_channel_messages",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi preload and context scope helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_preload.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::collect_context_ancestry",
      "fn BidiProtocol::build_context_ancestry",
      "fn BidiProtocol::build_context_scope_info_json",
      "fn BidiProtocol::resolve_top_level_context(",
      "fn BidiProtocol::is_preload_script_applicable",
      "fn build_preload_call_expression",
      "fn extract_window_property_names",
      "fn BidiProtocol::clear_window_properties_in_context",
      "fn BidiProtocol::cleanup_removed_preload_entry",
      "fn BidiProtocol::remove_all_preload_scripts",
      "fn BidiProtocol::run_preload_script_in_context",
      "fn BidiProtocol::apply_preload_scripts_for_context",
      "fn BidiProtocol::has_mutation_observer_preload_for_context",
      "fn BidiProtocol::emit_synthetic_mutation_observer_messages",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi browsingContext rendering commands out of the protocol core", () => {
    expect(
      fs.existsSync(
        path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_browsing_context_rendering.mbt"),
      ),
    ).toBe(true);

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
