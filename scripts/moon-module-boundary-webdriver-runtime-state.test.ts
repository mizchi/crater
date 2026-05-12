import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver runtime state boundaries", () => {
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
});
