import { describe, expect, it } from "vitest";
import { normalizeRepoPath } from "./script-path.ts";

describe("normalizeRepoPath", () => {
  it("normalizes absolute and relative paths into repo-relative slash paths", () => {
    expect(normalizeRepoPath("/repo", "/repo/tests/paint-vrt.test.ts")).toBe(
      "tests/paint-vrt.test.ts",
    );
    expect(normalizeRepoPath("/repo", "tests\\paint-vrt.test.ts")).toBe(
      "tests/paint-vrt.test.ts",
    );
  });
});
