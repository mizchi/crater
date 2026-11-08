import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { parseModuleManifest } from "./moon-publish-workspace.mjs";
import { REPO_ROOT } from "./moon-module-boundary-helpers";

describe("crater-core module boundary", () => {
  it("has no in-repo deps (it is the bottom of the dependency graph)", () => {
    const manifest = parseModuleManifest(
      fs.readFileSync(path.join(REPO_ROOT, "core/moon.mod"), "utf8"),
      { json: false },
    );
    expect(manifest.name).toBe("mizchi/crater-core");
    const inRepoDeps = manifest.depNames.filter((d) =>
      d.startsWith("mizchi/crater"),
    );
    expect(inRepoDeps).toEqual([]);
  });

  it("ships only pure type definitions (no impl coupling)", () => {
    const pkg = fs.readFileSync(path.join(REPO_ROOT, "core/moon.pkg"), "utf8");
    expect(pkg).not.toMatch(/mizchi\/crater-/);
  });

  it("appears in moon.work before any consumer", () => {
    const work = fs.readFileSync(path.join(REPO_ROOT, "moon.work"), "utf8");
    const coreIdx = work.indexOf('"./core"');
    const layoutIdx = work.indexOf('"./layout"');
    expect(coreIdx).toBeGreaterThan(-1);
    expect(coreIdx).toBeLessThan(layoutIdx);
  });
});
