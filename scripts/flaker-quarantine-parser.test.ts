import { describe, expect, it } from "vitest";
import { parseFlakerQuarantine } from "./flaker-quarantine-parser.ts";

describe("flaker-quarantine-parser", () => {
  it("parses tracked quarantine entries directly", () => {
    const config = parseFlakerQuarantine(`
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
      "expiresAt": "2026-06-30"
    }
  ]
}
`);

    expect(config).toEqual({
      schemaVersion: 1,
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
          trackingIssue: undefined,
        },
      ],
    });
  });
});
