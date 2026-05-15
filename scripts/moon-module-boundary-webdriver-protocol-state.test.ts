import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver protocol state boundaries", () => {
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

  it("keeps WebDriver BiDi subscription commands out of the protocol core", () => {
    const subscriptionCommandFiles = [
      "webdriver/webdriver/bidi_protocol_subscription_lookup.mbt",
      "webdriver/webdriver/bidi_protocol_subscription_log.mbt",
      "webdriver/webdriver/bidi_protocol_subscription_state_ops.mbt",
      "webdriver/webdriver/bidi_protocol_subscription_subscribe.mbt",
      "webdriver/webdriver/bidi_protocol_subscription_unsubscribe.mbt",
    ];
    for (const file of subscriptionCommandFiles) {
      expect(fs.existsSync(path.join(REPO_ROOT, file)), file).toBe(true);
    }

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_subscribe",
      "fn BidiProtocol::handle_unsubscribe",
      "fn BidiProtocol::remove_subscription_by_id",
      "fn BidiProtocol::normalize_subscription_context",
      "fn has_log_subscription",
      "fn BidiProtocol::should_capture_console",
      "fn BidiProtocol::flush_pending_log_entries",
      "fn BidiProtocol::is_subscribed_for_context",
      "fn BidiProtocol::is_subscribed_for_context_chain",
      "fn get_subscription_key",
      "fn BidiProtocol::has_global_module_subscription",
      "fn BidiProtocol::has_global_event_subscription",
      "fn BidiProtocol::has_global_event_override_for_module",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
    expect(countLines("webdriver/webdriver/bidi_protocol.mbt")).toBeLessThanOrEqual(5200);
  });
});
