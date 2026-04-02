import { describe, expect, it } from "vitest";
import {
  classifyQuarantineExpiry,
  normalizeToUtcMidnight,
  parseDateOnly,
} from "./flaker-quarantine-expiry.ts";

describe("flaker-quarantine-expiry", () => {
  it("parses YYYY-MM-DD dates only", () => {
    expect(parseDateOnly("2026-04-02")?.toISOString()).toBe("2026-04-02T00:00:00.000Z");
    expect(parseDateOnly("2026-04-31")).toBeNull();
    expect(parseDateOnly("2026/04/02")).toBeNull();
  });

  it("normalizes dates to UTC midnight", () => {
    expect(normalizeToUtcMidnight(new Date("2026-04-02T12:34:56Z")).toISOString()).toBe(
      "2026-04-02T00:00:00.000Z",
    );
  });

  it("classifies active, expires-soon, expired, and invalid expiry states", () => {
    const now = new Date("2026-04-02T00:00:00.000Z");

    expect(
      classifyQuarantineExpiry(now, parseDateOnly("2026-04-10"), 7),
    ).toEqual({
      status: "active",
      daysUntilExpiry: 8,
    });
    expect(
      classifyQuarantineExpiry(now, parseDateOnly("2026-04-09"), 7),
    ).toEqual({
      status: "expires-soon",
      daysUntilExpiry: 7,
    });
    expect(
      classifyQuarantineExpiry(now, parseDateOnly("2026-04-01"), 7),
    ).toEqual({
      status: "expired",
      daysUntilExpiry: -1,
    });
    expect(classifyQuarantineExpiry(now, null, 7)).toEqual({
      status: "invalid",
      daysUntilExpiry: null,
    });
  });
});
