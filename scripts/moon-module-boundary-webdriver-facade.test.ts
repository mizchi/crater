import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

const read = (relativePath: string): string => {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8");
};

describe("MoonBit WebDriver facade and contract boundaries", () => {
  it("keeps published webdriver root as a thin facade", () => {
    const source = read("webdriver/top.mbt");
    const implementationMarkers = [
      "extern \"js\"",
      "quickjs_",
      "BidiProtocol::",
      "BidiServer::",
      "SessionManager::new",
      "CdpSessionManager::new",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
    expect(source).toContain("pub using @webdriver");
    expect(countLines("webdriver/top.mbt")).toBeLessThanOrEqual(140);
  });

  it("keeps pure WebDriver API and legacy protocol contracts outside implementation facade", () => {
    const expectedContractFiles = [
      "webdriver/contract/api.mbt",
      "webdriver/contract/types.mbt",
      "webdriver/contract/json.mbt",
      "webdriver/contract/router.mbt",
      "webdriver/contract/api_test.mbt",
      "webdriver/contract/json_test.mbt",
      "webdriver/contract/router_test.mbt",
    ] as const;
    const missingFiles = expectedContractFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });

    expect(missingFiles).toEqual([]);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/api.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/types.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/json.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/router.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/api_test.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/json_test.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/router_test.mbt"))).toBe(false);

    const contractPackage = read("webdriver/contract/moon.pkg");
    expect(contractPackage).not.toContain("mizchi/crater");
    expect(contractPackage).not.toContain("mizchi/webdriver");
    expect(contractPackage).not.toContain("mizchi/js");
  });

  it("keeps webdriver/webdriver as a compatibility facade over contract types", () => {
    const packageSource = read("webdriver/webdriver/moon.pkg");
    const facadeSource = read("webdriver/webdriver/contract.mbt");

    expect(packageSource).toContain('"mizchi/crater-webdriver-bidi/contract" @contract');
    expect(facadeSource).toContain("pub using @contract");
    for (const typeName of [
      "ApiError",
      "ApiMethod",
      "ErrorCode",
      "HttpMethod",
      "WebDriverCommand",
      "WebDriverRequest",
      "WebDriverResponse",
      "WebDriverValue",
    ] as const) {
      expect(facadeSource).toContain(`type ${typeName}`);
    }
  });

  it("keeps JSON-RPC protocol helpers outside the implementation facade", () => {
    const expectedRpcFiles = [
      "webdriver/rpc/rpc.mbt",
      "webdriver/rpc/rpc_test.mbt",
    ] as const;
    const missingFiles = expectedRpcFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });

    expect(missingFiles).toEqual([]);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/rpc.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/rpc_test.mbt"))).toBe(false);

    const rpcPackage = read("webdriver/rpc/moon.pkg");
    expect(rpcPackage).toContain('"mizchi/crater-webdriver-bidi/contract" @contract');
    expect(rpcPackage).not.toContain("mizchi/crater\"");
    expect(rpcPackage).not.toContain("mizchi/webdriver");
    expect(rpcPackage).not.toContain("mizchi/js");

    const webdriverPackage = read("webdriver/webdriver/moon.pkg");
    const facadeSource = read("webdriver/webdriver/contract.mbt");
    expect(webdriverPackage).toContain('"mizchi/crater-webdriver-bidi/rpc" @rpc');
    expect(facadeSource).toContain("pub using @rpc");
    for (const symbol of [
      "RpcErrorCode",
      "RpcId",
      "RpcRequest",
      "RpcResponse",
      "parse_method",
      "parse_json_object",
      "api_error_to_rpc",
    ] as const) {
      expect(facadeSource).toContain(symbol);
    }
  });

  it("keeps QuickJS runtime implementation outside the implementation facade", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/runtime/quickjs_runtime.mbt"))).toBe(true);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/quickjs_runtime.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/runtime/navigation_encoding.mbt"))).toBe(true);
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_navigation_encoding.mbt")),
    ).toBe(false);

    const runtimePackage = read("webdriver/runtime/moon.pkg");
    expect(runtimePackage).toContain('"mizchi/js/core"');
    expect(runtimePackage).not.toContain("mizchi/crater\"");
    expect(runtimePackage).not.toContain("mizchi/webdriver");

    const webdriverPackage = read("webdriver/webdriver/moon.pkg");
    const facadeSource = read("webdriver/webdriver/runtime.mbt");
    expect(webdriverPackage).toContain('"mizchi/crater-webdriver-bidi/runtime" @runtime');
    for (const symbol of [
      "init_quickjs",
      "mark_quickjs_initialized",
      "is_quickjs_initialized",
      "quickjs_eval_sync",
      "quickjs_eval_async",
      "quickjs_eval_ws",
      "quickjs_eval_module",
      "quickjs_load",
      "quickjs_fetch",
    ] as const) {
      expect(facadeSource).toContain(symbol);
    }

    const encodingFacadeSource = read("webdriver/webdriver/navigation_encoding.mbt");
    for (const symbol of [
      "encode_base64_utf8",
      "encode_base64_raw",
      "json_ensure_ascii",
      "extract_inline_script_blocks",
      "build_html_data_url",
    ] as const) {
      expect(encodingFacadeSource).toContain(symbol);
    }
  });

  it("keeps pure BiDi protocol helpers outside the implementation facade", () => {
    const expectedProtocolFiles = [
      "webdriver/protocol/json.mbt",
      "webdriver/protocol/validation_shared.mbt",
      "webdriver/protocol/protocol_test.mbt",
    ] as const;
    const missingFiles = expectedProtocolFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });

    expect(missingFiles).toEqual([]);

    const protocolPackage = read("webdriver/protocol/moon.pkg");
    expect(protocolPackage).toContain('"moonbitlang/core/json"');
    expect(protocolPackage).not.toContain("mizchi/crater\"");
    expect(protocolPackage).not.toContain("mizchi/webdriver");
    expect(protocolPackage).not.toContain("mizchi/js");

    const webdriverPackage = read("webdriver/webdriver/moon.pkg");
    expect(webdriverPackage).toContain('"mizchi/crater-webdriver-bidi/protocol" @protocol');

    const jsonFacade = read("webdriver/webdriver/bidi_protocol_json.mbt");
    const validationFacade = read("webdriver/webdriver/bidi_protocol_validation_shared.mbt");
    expect(jsonFacade).toContain("@protocol.make_object");
    expect(jsonFacade).not.toContain("for key, value in raw_opts");
    expect(jsonFacade).not.toContain("Json::object(map)");
    expect(validationFacade).toContain("@protocol.parse_decimal_string");
    expect(validationFacade).not.toContain("parsed = parsed * 10");
    expect(validationFacade).not.toContain("lhs.to_array()");
  });

  it("keeps BiDi wire message parsing and serialization behind protocol wire", () => {
    const expectedWireFiles = [
      "webdriver/protocol/wire/moon.pkg",
      "webdriver/protocol/wire/messages.mbt",
      "webdriver/protocol/wire/messages_test.mbt",
    ] as const;
    const missingFiles = expectedWireFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });

    expect(missingFiles).toEqual([]);

    const wirePackage = read("webdriver/protocol/wire/moon.pkg");
    expect(wirePackage).toContain('"mizchi/webdriver/bidi" @bidi_wire');
    expect(wirePackage).not.toContain("mizchi/crater\"");
    expect(wirePackage).not.toContain("mizchi/js");

    const webdriverPackage = read("webdriver/webdriver/moon.pkg");
    expect(webdriverPackage).toContain(
      '"mizchi/crater-webdriver-bidi/protocol/wire" @protocol_wire',
    );

    const messageFacade = read("webdriver/webdriver/bidi_protocol_messages.mbt");
    for (const symbol of [
      "@protocol_wire.parse_request",
      "@protocol_wire.success_response_to_json",
      "@protocol_wire.error_response_to_json",
      "@protocol_wire.event_to_json",
    ] as const) {
      expect(messageFacade).toContain(symbol);
    }
    expect(messageFacade).not.toContain("@bidi_wire");
  });

  it("keeps network runtime state and JS helpers outside the implementation facade", () => {
    const moonWork = read("moon.work");
    expect(moonWork).toContain('"./network"');

    const networkModule = read("network/moon.mod.json");
    expect(networkModule).toContain('"name": "mizchi/crater-network"');
    expect(fs.existsSync(path.join(REPO_ROOT, "network/state.mbt"))).toBe(true);
    expect(fs.existsSync(path.join(REPO_ROOT, "network/encoding.mbt"))).toBe(true);
    expect(fs.existsSync(path.join(REPO_ROOT, "network/event_types.mbt"))).toBe(true);
    expect(fs.existsSync(path.join(REPO_ROOT, "network/fetch_types.mbt"))).toBe(true);

    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/network/state.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/network/encoding.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/network/event_types.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/network/fetch_types.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/network/facade.mbt"))).toBe(true);
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_network_fetch_types.mbt"))).toBe(
      false,
    );

    const webdriverNetworkState = read("webdriver/webdriver/bidi_network_state.mbt");
    const webdriverNetworkTypes = read("webdriver/webdriver/bidi_network_types.mbt");
    expect(webdriverNetworkState).not.toContain("struct BidiNetworkState");
    expect(webdriverNetworkState).not.toContain("BidiNetworkState::new");
    expect(webdriverNetworkTypes).not.toContain("struct SyntheticNetworkEventInput");
    expect(webdriverNetworkTypes).not.toContain("struct SyntheticNetworkResponseOverrides");
    expect(webdriverNetworkTypes).not.toContain("struct SyntheticNetworkContinueCredentials");
    expect(webdriverNetworkTypes).not.toContain('extern "js" fn js_utf8_byte_length');
    expect(webdriverNetworkTypes).not.toContain('extern "js" fn js_base64_byte_length');
    expect(webdriverNetworkTypes).not.toContain('extern "js" fn js_decode_query_component');

    const networkPackage = read("webdriver/network/moon.pkg");
    expect(networkPackage).toContain('"mizchi/crater-network" @crater_network');
    expect(networkPackage).not.toContain("mizchi/webdriver");
    expect(networkPackage).not.toContain("mizchi/js");

    const facadeSource = read("webdriver/network/facade.mbt");
    expect(facadeSource).toContain("pub using @crater_network");
    for (const symbol of [
      "BidiNetworkState",
      "SyntheticNetworkEventInput",
      "SyntheticFetchPlanEntry",
      "utf8_byte_length",
      "base64_byte_length",
      "decode_query_component",
    ] as const) {
      expect(facadeSource).toContain(symbol);
    }

    const webdriverNetworkFiles = fs
      .readdirSync(path.join(REPO_ROOT, "webdriver/network"))
      .filter((file) => file.endsWith(".mbt"));
    const adapterImplementationMarkers = [
      'extern "js"',
      "struct BidiNetworkState",
      "struct SyntheticNetworkEventInput",
      "struct SyntheticNetworkResponseOverrides",
      "struct SyntheticFetchPlanEntry",
    ] as const;
    const adapterOffenders = webdriverNetworkFiles.flatMap((file) => {
      const source = read(path.join("webdriver/network", file));
      return adapterImplementationMarkers
        .filter((marker) => source.includes(marker))
        .map((marker) => `${file}: ${marker}`);
    });
    expect(adapterOffenders).toEqual([]);

    const webdriverPackage = read("webdriver/webdriver/moon.pkg");
    expect(webdriverPackage).toContain('"mizchi/crater-network" @crater_network');
    expect(webdriverPackage).not.toContain('"mizchi/crater-webdriver-bidi/network" @network');
  });

  it("keeps protocol-neutral network URL pattern matching in crater-network", () => {
    const expectedNetworkFiles = [
      "network/url_patterns.mbt",
      "network/url_patterns_test.mbt",
    ] as const;
    const missingFiles = expectedNetworkFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });

    expect(missingFiles).toEqual([]);

    const networkPackage = read("network/moon.pkg");
    expect(networkPackage).not.toContain("mizchi/crater-webdriver-bidi");
    expect(networkPackage).not.toContain("mizchi/webdriver");

    const matchingSource = read("webdriver/webdriver/bidi_network_intercept_matching.mbt");
    for (const symbol of [
      "@crater_network.network_intercept_matches_phase",
      "@crater_network.network_option_contexts_match",
      "@crater_network.network_url_patterns_match",
    ] as const) {
      expect(matchingSource).toContain(symbol);
    }
    for (const implementationMarker of [
      "fn network_url_patterns_match",
      "fn network_url_pattern_entry_matches",
      "fn network_string_url_pattern_matches",
      "fn network_object_url_pattern_matches",
      "fn canonicalize_network_http_url",
      "fn parse_network_host_and_port",
      "fn normalize_network_pattern_protocol",
    ] as const) {
      expect(matchingSource).not.toContain(implementationMarker);
    }
  });

  it("keeps protocol-neutral network header and query helpers in crater-network", () => {
    const expectedNetworkFiles = [
      "network/header_url_helpers.mbt",
      "network/header_url_helpers_test.mbt",
    ] as const;
    const missingFiles = expectedNetworkFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });

    expect(missingFiles).toEqual([]);

    const helperFacade = read("webdriver/webdriver/bidi_network_header_url_helpers.mbt");
    for (const symbol of [
      "@crater_network.synthetic_network_header_entries_from_object",
      "@crater_network.synthetic_network_first_query_value",
      "@crater_network.synthetic_network_status_text_for_code",
    ] as const) {
      expect(helperFacade).toContain(symbol);
    }
    for (const implementationMarker of [
      "for name, raw_value in raw_headers",
      "let order : Array[String]",
      "match find_substring(url, \"?\", 0)",
      "101 => \"Switching Protocols\"",
    ] as const) {
      expect(helperFacade).not.toContain(implementationMarker);
    }

    const networkSource = read("network/header_url_helpers.mbt");
    expect(networkSource).toContain("pub fn synthetic_network_normalize_continue_url");
    const eventNormalizerSource = read("webdriver/webdriver/bidi_network_event_normalizers.mbt");
    expect(eventNormalizerSource).toContain("@crater_network.synthetic_network_normalize_continue_url");
    expect(eventNormalizerSource).not.toContain("synthetic_network_is_valid_continue_url(url)");
  });

  it("keeps protocol-neutral Set-Cookie formatting in crater-network", () => {
    const expectedNetworkFiles = [
      "network/cookie_headers.mbt",
      "network/cookie_headers_test.mbt",
    ] as const;
    const missingFiles = expectedNetworkFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });

    expect(missingFiles).toEqual([]);

    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_network_set_cookie_format.mbt")),
    ).toBe(false);
  });

  it("keeps protocol-neutral Set-Cookie parsing in crater-network", () => {
    const cookieHeaderSource = read("network/cookie_headers.mbt");
    expect(cookieHeaderSource).toContain("pub(all) struct SyntheticNetworkCookie");
    expect(cookieHeaderSource).toContain("pub fn synthetic_network_extract_set_cookie_entries");
    expect(cookieHeaderSource).toContain("pub fn synthetic_network_parse_set_cookie_header_value");

    const parseFacade = read("webdriver/webdriver/bidi_network_set_cookie_parse.mbt");
    expect(parseFacade).toContain(
      "@crater_network.synthetic_network_extract_set_cookie_entries",
    );
    for (const implementationMarker of [
      "for raw_part in header_value.split(\";\")",
      "storage_cookie_domain_from_base_url(base_url)",
      "storage_strip_leading_dot",
      "js_parse_cookie_expiry_seconds",
      "storage_now_seconds() + parsed_max_age",
    ] as const) {
      expect(parseFacade).not.toContain(implementationMarker);
    }
  });

  it("keeps protocol-neutral document.cookie assignment parsing in crater-network", () => {
    const cookieHeaderSource = read("network/cookie_headers.mbt");
    expect(cookieHeaderSource).toContain(
      "pub fn synthetic_network_parse_document_cookie_assignment",
    );

    const storageSource = read("webdriver/webdriver/bidi_storage.mbt");
    expect(storageSource).toContain(
      "@crater_network.synthetic_network_parse_document_cookie_assignment",
    );
    for (const implementationMarker of [
      "for part in cookie_assignment.split(\";\")",
      "js_parse_cookie_expiry_seconds(attr_value)",
      "storage_now_seconds() + max_age",
    ] as const) {
      expect(storageSource).not.toContain(implementationMarker);
    }
  });

  it("keeps protocol-neutral network cookie override normalization in crater-network", () => {
    const cookieHeaderSource = read("network/cookie_headers.mbt");
    expect(cookieHeaderSource).toContain(
      "pub fn synthetic_network_normalize_set_cookie_override_entry",
    );

    const cookieOverrideSource = read("webdriver/webdriver/bidi_network_cookie_headers.mbt");
    expect(cookieOverrideSource).toContain(
      "@crater_network.synthetic_network_normalize_set_cookie_override_entry",
    );
    for (const implementationMarker of [
      "is_valid_network_header_name_token(name)",
      "storage_cookie_domain_from_base_url(base_url)",
      "storage_strip_leading_dot",
      "js_parse_cookie_expiry_seconds(raw_expiry)",
      "storage_now_seconds() + max_age",
      "synthetic_network_format_set_cookie_header(header_entry)",
    ] as const) {
      expect(cookieOverrideSource).not.toContain(implementationMarker);
    }
  });

  it("keeps protocol-neutral request cookie override normalization in crater-network", () => {
    const cookieHeaderSource = read("network/cookie_headers.mbt");
    expect(cookieHeaderSource).toContain(
      "pub fn synthetic_network_normalize_request_cookie_entries",
    );

    const normalizerSource = read("webdriver/webdriver/bidi_network_event_normalizers.mbt");
    expect(normalizerSource).toContain(
      "@crater_network.synthetic_network_normalize_request_cookie_entries",
    );
    for (const implementationMarker of [
      "requestCookies entry must be an object",
      "requestCookies.value.type must be a string",
      "requestCookies.value.type is invalid",
      "make_object({ \"name\": Json::string(name), \"value\": value })",
    ] as const) {
      expect(normalizerSource).not.toContain(implementationMarker);
    }
  });

  it("documents next module boundaries before further WebDriver extraction", () => {
    const todo = read("TODO.md");
    const requiredBoundaries = [
      "`webdriver/contract`",
      "`webdriver/rpc`",
      "`webdriver/runtime`",
      "`webdriver/network`",
      "`webdriver/protocol`",
      "`webdriver/rendering`",
      "`webdriver/browser_domain`",
      "`webdriver/server`",
      "`mizchi/font`",
      "`mizchi/svg`",
    ] as const;

    const missingBoundaries = requiredBoundaries.filter((boundary) => !todo.includes(boundary));
    expect(missingBoundaries).toEqual([]);
  });
});
