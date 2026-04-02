import { describe, expect, it } from "vitest";
import { parseFlakerQuarantine } from "./flaker-quarantine-parser.ts";
import { buildFlakerQuarantineSummary } from "./flaker-quarantine-summary-core.ts";

describe("buildFlakerQuarantineSummary", () => {
  it("validates ownership, expiry, and missing specs from prepared inputs", () => {
    const quarantine = parseFlakerQuarantine(`
{
  "schemaVersion": 1,
  "entries": [
    {
      "id": "paint-vrt-real-world-local-assets",
      "taskId": "paint-vrt",
      "spec": "tests/paint-vrt.test.ts",
      "titlePattern": "^real-world snapshot:",
      "mode": "skip",
      "scope": "environment",
      "owner": "mizchi",
      "reason": "Optional real-world fixtures are not always present locally.",
      "condition": "Skip only when the named real-world snapshot is missing from disk.",
      "introducedAt": "2026-04-01",
      "expiresAt": "2026-04-04"
    },
    {
      "id": "missing-spec",
      "taskId": "paint-vrt",
      "spec": "tests/missing.test.ts",
      "titlePattern": "^fixture:",
      "mode": "skip",
      "scope": "environment",
      "owner": "mizchi",
      "reason": "Broken config fixture",
      "condition": "Never",
      "introducedAt": "2026-04-01",
      "expiresAt": "2026-05-01"
    },
    {
      "id": "missing-task",
      "taskId": "does-not-exist",
      "spec": "tests/paint-vrt.test.ts",
      "titlePattern": "[",
      "mode": "skip",
      "scope": "environment",
      "owner": "mizchi",
      "reason": "Broken config fixture",
      "condition": "Never",
      "introducedAt": "2026-04-01",
      "expiresAt": "2026-03-31"
    }
  ]
}
`);

    const summary = buildFlakerQuarantineSummary({
      quarantine,
      tasks: [
        {
          id: "paint-vrt",
          specs: ["tests/paint-vrt.test.ts"],
        },
      ],
      existingSpecs: new Set(["tests/paint-vrt.test.ts"]),
      now: new Date("2026-04-01T00:00:00Z"),
    });

    expect(summary.entryCount).toBe(3);
    expect(summary.modeCounts.skip).toBe(3);
    expect(summary.scopeCounts.environment).toBe(3);
    expect(summary.errors.map((issue) => issue.code)).toEqual([
      "missing-spec",
      "unknown-task",
      "invalid-title-pattern",
      "invalid-expiry-range",
      "expired-quarantine",
    ]);
    expect(summary.warnings.map((issue) => issue.code)).toEqual(["expires-soon"]);
    expect(summary.entries.find((entry) => entry.id === "paint-vrt-real-world-local-assets")?.expiryStatus)
      .toBe("expires-soon");
    expect(summary.entries.find((entry) => entry.id === "missing-task")?.expiryStatus)
      .toBe("expired");
  });
});
