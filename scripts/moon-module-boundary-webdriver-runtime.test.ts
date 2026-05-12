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

describe("MoonBit WebDriver runtime module boundaries", () => {
  it("keeps WebDriver BiDi network runtime state out of the protocol core", () => {
    const stateSource = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_network_state.mbt"),
      "utf8",
    );
    expect(stateSource).toContain("priv struct BidiNetworkState");
    expect(stateSource).toContain("fn BidiNetworkState::new(");

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "network_intercepts : Map[String, Json]",
      "next_network_intercept_id : Int",
      "next_network_request_id : Int",
      "network_cache_behavior_global : String",
      "network_extra_headers_global : Map[String, String]",
      "network_extra_headers_by_context : Map[String, Map[String, String]]",
      "network_extra_headers_by_user_context : Map[String, Map[String, String]]",
      "network_cache_behavior_by_context : Map[String, String]",
      "network_state_channel_by_context : Map[String, String]",
      "network_cached_requests_by_context : Map[String, Map[String, Bool]]",
      "network_blocked_requests : Map[String, Json]",
      "network_data_collectors : Map[String, Json]",
      "network_collected_data : Map[String, Map[String, Map[String, Json]]]",
      "next_network_data_collector_id : Int",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime document helpers out of the server transport", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_document.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn js_sync_runtime_html_async",
      "extern \"js\" fn js_sync_runtime_page_async",
      "pub fn sync_runtime_page",
      "pub fn sync_runtime_html",
      "extern \"js\" fn js_decode_base64",
      "pub fn decode_base64",
      "pub fn parse_data_url",
      "fn make_substr",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime eval helpers out of the server transport", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_eval.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn js_evaluate_expression",
      "extern \"js\" fn js_evaluate_expression_fast",
      "fn evaluate_js_with_console",
      "pub fn evaluate_js",
      "extern \"js\" fn js_evaluate_expression_async",
      "extern \"js\" fn js_await_promise",
      "pub fn evaluate_js_async",
      "extern \"js\" fn js_eval_and_send_async",
      "fn eval_and_send_async_with_console",
      "pub fn eval_and_send_async",
      "pub fn await_promise",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime context helpers out of the server transport", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_context.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn reset_runtime_js_state",
      "extern \"js\" fn ensure_runtime_navigator_patch_helper",
      "extern \"js\" fn js_set_runtime_context",
      "pub fn set_runtime_context",
      "extern \"js\" fn js_reset_runtime_event_buffers",
      "pub fn reset_runtime_event_buffers",
      "extern \"js\" fn js_set_runtime_context_frames",
      "pub fn set_runtime_context_frames",
      "extern \"js\" fn js_set_runtime_context_viewport",
      "pub fn set_runtime_context_viewport",
      "extern \"js\" fn js_set_runtime_context_user_agent",
      "pub fn set_runtime_context_user_agent",
      "extern \"js\" fn js_set_runtime_context_locale",
      "pub fn set_runtime_context_locale",
      "extern \"js\" fn js_set_runtime_context_network_online",
      "pub fn set_runtime_context_network_online",
      "extern \"js\" fn js_set_runtime_context_screen_orientation",
      "pub fn set_runtime_context_screen_orientation",
      "extern \"js\" fn js_set_runtime_context_screen_area",
      "pub fn set_runtime_context_screen_area",
      "extern \"js\" fn js_has_runtime_handle",
      "pub fn has_runtime_handle",
      "extern \"js\" fn js_runtime_shared_node_center_json",
      "pub fn get_runtime_shared_node_center_json",
      "extern \"js\" fn js_runtime_href_at_point",
      "pub fn get_runtime_href_at_point",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime channel helpers out of the server transport", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_channel.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn js_take_channel_messages",
      "pub fn take_channel_messages_json",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime input helpers out of the server transport", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_input.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn js_input_dispatch_key_action",
      "pub fn input_dispatch_key_action",
      "extern \"js\" fn js_input_is_single_grapheme",
      "pub fn input_is_single_grapheme",
      "extern \"js\" fn js_input_set_pointer_event_properties",
      "pub fn input_set_pointer_event_properties",
      "extern \"js\" fn js_input_clear_pointer_event_properties",
      "pub fn input_clear_pointer_event_properties",
      "extern \"js\" fn js_input_dispatch_pointer_event_with_related",
      "pub fn input_dispatch_pointer_event",
      "pub fn input_dispatch_pointer_event_with_related",
      "extern \"js\" fn js_input_dispatch_drag_event",
      "pub fn input_dispatch_drag_event",
      "extern \"js\" fn js_input_dispatch_wheel_event",
      "pub fn input_dispatch_wheel_event",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
