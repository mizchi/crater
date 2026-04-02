import { describe, expect, it } from "vitest";
import { parseFlakerQuarantine } from "./flaker-quarantine-parser.ts";
import {
  compileTitlePattern,
  findMatchingQuarantine,
} from "./flaker-quarantine-match.ts";

describe("flaker-quarantine-match", () => {
  it("compiles valid patterns and rejects invalid regex source", () => {
    expect(compileTitlePattern("^real-world snapshot:")?.test("real-world snapshot: a")).toBe(
      true,
    );
    expect(compileTitlePattern("(")).toBeNull();
  });

  it("matches entries by task, spec, mode, and title", () => {
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
      "expiresAt": "2026-06-30"
    }
  ]
}
`);

    expect(findMatchingQuarantine(quarantine, {
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      title: "real-world snapshot: playwright-intro stays within loose visual diff budget",
      mode: "skip",
    })?.id).toBe("paint-vrt-real-world-local-assets");
    expect(findMatchingQuarantine(quarantine, {
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      title: "other",
    })).toBeUndefined();
  });
});
