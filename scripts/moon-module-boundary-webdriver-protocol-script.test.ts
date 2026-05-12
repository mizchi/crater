import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver protocol script and input boundaries", () => {
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
});
