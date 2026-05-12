import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver protocol core boundaries", () => {
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
});
