import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver protocol navigation boundaries", () => {
  it("keeps WebDriver BiDi navigation URL helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_navigation_url.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn is_valid_navigation_target_url",
      "fn should_fail_navigation_with_unknown_error",
      "fn BidiProtocol::is_iframe_navigation_blocked",
      "fn should_block_navigation_response",
      "extern \"js\" fn js_encode_base64_utf8",
      "fn BidiProtocol::resolve_navigation_target_url",
      "fn BidiProtocol::resolve_fetch_target_url",
      "fn BidiProtocol::normalize_wpt_navigation_target_url",
      "fn BidiProtocol::resolve_effective_navigation_target_url",
      "fn resolve_navigation_committed_url",
      "fn resolve_inline_script_redirect_url",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi navigation state helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_navigation_state.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::abort_in_flight_navigation_unless_matching",
      "fn BidiProtocol::complete_pending_navigation_response",
      "fn outbox_message_matches_pending_navigation_lifecycle",
      "fn BidiProtocol::strip_pending_navigation_lifecycle_events",
      "fn BidiProtocol::complete_navigation_request_with_wait",
      "fn BidiProtocol::apply_navigation_commit_state",
      "fn BidiProtocol::build_navigation_completion",
      "fn BidiProtocol::complete_fragment_navigation_request",
      "fn BidiProtocol::emit_navigation_started_event",
      "fn BidiProtocol::emit_navigation_lifecycle_events",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps the WebDriver BiDi protocol core below the navigation helper split budget", () => {
    expect(countLines("webdriver/webdriver/bidi_protocol.mbt")).toBeLessThanOrEqual(4450);
  });
});
