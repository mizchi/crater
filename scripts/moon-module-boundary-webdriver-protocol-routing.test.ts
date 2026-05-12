import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver protocol routing boundaries", () => {
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
});
