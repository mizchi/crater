import { describe, expect, it } from "vitest";
import {
  FONT_RUNTIME_BUILD_CANDIDATES,
  resolveFontRuntimeBuildPath,
  resolveFontRuntimeBuildUrl,
} from "./font-build-paths.mjs";

describe("font build paths", () => {
  it("prefers current workspace output over stale module builds", () => {
    const workspacePath = "/repo/_build/js/release/build/mizchi/crater-webdriver-bidi/font_runtime/font_runtime.js";
    expect(resolveFontRuntimeBuildPath("/repo", () => true)).toBe(workspacePath);
  });

  it("resolves the first existing candidate", () => {
    const cwd = "/repo";
    const expected = `${cwd}/${FONT_RUNTIME_BUILD_CANDIDATES[1]}`;
    const resolved = resolveFontRuntimeBuildPath(
      cwd,
      (candidate) => candidate === expected,
    );
    expect(resolved).toBe(expected);
  });

  it("returns null when no candidate exists", () => {
    expect(resolveFontRuntimeBuildPath("/repo", () => false)).toBeNull();
  });

  it("throws with the candidate list when unresolved", () => {
    expect(() => resolveFontRuntimeBuildUrl("/repo", () => false)).toThrow(
      /Font runtime not built/,
    );
  });
});
