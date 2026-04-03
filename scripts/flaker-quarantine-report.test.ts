import { describe, expect, it } from "vitest";
import { renderQuarantineMarkdown } from "./flaker-quarantine-report.ts";
import type { FlakerQuarantineSummary } from "./flaker-quarantine.ts";

const SUMMARY: FlakerQuarantineSummary = {
  schemaVersion: 1,
  generatedAt: "2026-04-02T00:00:00.000Z",
  entryCount: 1,
  modeCounts: {
    skip: 1,
    allow_flaky: 0,
    allow_failure: 0,
  },
  scopeCounts: {
    environment: 1,
    flaky: 0,
    expected_failure: 0,
  },
  entries: [
    {
      id: "paint-vrt-real-world-local-assets",
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      titlePattern: "^real-world snapshot:",
      mode: "skip",
      scope: "environment",
      owner: "mizchi",
      reason: "Optional real-world fixtures are not always present locally.",
      condition: "Skip only when the named real-world snapshot is missing from disk.",
      introducedAt: "2026-04-01",
      expiresAt: "2026-06-30",
      expiryStatus: "active",
      daysUntilExpiry: 89,
    },
  ],
  errors: [
    {
      severity: "error",
      code: "expired-quarantine",
      message: "Quarantine entry expired",
    },
  ],
  warnings: [
    {
      severity: "warning",
      code: "expires-soon",
      message: "Quarantine entry expires soon",
    },
  ],
};

describe("flaker-quarantine-report", () => {
  it("renders markdown summary directly", () => {
    const markdown = renderQuarantineMarkdown(SUMMARY);

    expect(markdown).toContain("# Flaker Quarantine Summary");
    expect(markdown).toContain("| Entries | 1 |");
    expect(markdown).toContain("paint-vrt-real-world-local-assets");
    expect(markdown).toContain("## Errors");
    expect(markdown).toContain("## Warnings");
  });
});
