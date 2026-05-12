import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver protocol event boundaries", () => {
  it("keeps WebDriver BiDi event emitters out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_events.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::emit_context_created",
      "fn BidiProtocol::emit_context_destroyed",
      "fn BidiProtocol::emit_user_prompt_opened",
      "fn BidiProtocol::emit_user_prompt_closed",
      "fn BidiProtocol::emit_download_will_begin",
      "fn BidiProtocol::emit_download_end",
      "fn BidiProtocol::emit_realm_destroyed_for_context",
      "fn BidiProtocol::emit_realm_created",
      "fn BidiProtocol::emit_default_realm",
      "fn BidiProtocol::emit_existing_realms_for_context",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
