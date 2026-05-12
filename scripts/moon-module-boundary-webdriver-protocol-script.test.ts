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

  it("keeps WebDriver BiDi script result helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_script_result.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::send_script_remote_value_result",
      "fn BidiProtocol::send_script_remote_value_response",
      "fn BidiProtocol::send_script_eval_result_mode",
      "fn BidiProtocol::resolve_unhandled_prompt_handler",
      "fn BidiProtocol::register_navigation_prompt_from_url",
      "fn BidiProtocol::send_script_prompt_result",
      "fn remote_value_as_bool",
      "fn simplify_node_remote_value",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi synthetic download helpers out of the protocol core", () => {
    expect(
      fs.existsSync(
        path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_synthetic_download.mbt"),
      ),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::try_handle_synthetic_download",
      "fn extract_click_target_identifier",
      "fn is_known_synthetic_download_target",
      "fn resolve_synthetic_download_final_url",
      "fn resolve_synthetic_download_filename",
      "fn resolve_synthetic_download_file_content",
      "fn is_synthetic_download_canceled",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi synthetic script helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_synthetic_script.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::try_handle_synthetic_all_events_eval",
      "extern \"js\" fn js_normalize_all_events_json",
      "fn BidiProtocol::try_handle_synthetic_register_service_worker_eval",
      "fn BidiProtocol::try_handle_synthetic_speculation_eval",
      "fn BidiProtocol::maybe_adjust_document_dimensions_eval_result",
      "fn BidiProtocol::evaluate_handled_script_expression",
      "fn BidiProtocol::try_handle_synthetic_user_prompt",
      "fn BidiProtocol::try_handle_synthetic_iframe_remove",
      "fn BidiProtocol::try_handle_synthetic_document_write_eval",
      "fn BidiProtocol::try_handle_synthetic_local_storage_call",
      "fn BidiProtocol::try_handle_synthetic_history_document_open_call",
      "fn BidiProtocol::try_handle_synthetic_document_status_call",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps the WebDriver BiDi protocol core below the current helper split budget", () => {
    expect(countLines("webdriver/webdriver/bidi_protocol.mbt")).toBeLessThanOrEqual(5800);
  });
});
