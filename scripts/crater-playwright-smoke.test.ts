import { describe, expect, it } from "vitest";
import { parseCraterPlaywrightSmokeArgs } from "./crater-playwright-smoke";

describe("parseCraterPlaywrightSmokeArgs", () => {
  it("uses stable defaults for a local static smoke", () => {
    expect(parseCraterPlaywrightSmokeArgs([])).toEqual({
      autoStartBidi: true,
      height: 600,
      output: undefined,
      serverTimeoutMs: 20_000,
      timeoutMs: 5_000,
      url: undefined,
      width: 800,
    });
  });

  it("parses URL, viewport, output, and connect-only flags", () => {
    expect(parseCraterPlaywrightSmokeArgs([
      "--",
      "--url",
      "http://127.0.0.1:3000/",
      "--width",
      "1024",
      "--height",
      "768",
      "--output",
      "tmp/smoke.png",
      "--connect-only",
      "--timeout-ms",
      "30000",
      "--server-timeout-ms",
      "45000",
    ])).toEqual({
      autoStartBidi: false,
      height: 768,
      output: "tmp/smoke.png",
      serverTimeoutMs: 45_000,
      timeoutMs: 30_000,
      url: "http://127.0.0.1:3000/",
      width: 1024,
    });
  });
});
