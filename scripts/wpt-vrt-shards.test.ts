import { describe, expect, it } from "vitest";
import {
  CI_WPT_VRT_MODULES,
  CI_WPT_VRT_SHARDS,
  selectEntriesForShard,
  toGithubMatrix,
} from "./wpt-vrt-shards.mjs";
import { collectWptVrtTests, loadWptVrtConfig } from "../tests/helpers/wpt-vrt-utils.ts";

describe("CI_WPT_VRT_SHARDS", () => {
  it("covers each CI-targeted WPT VRT test exactly once", () => {
    const entries = collectWptVrtTests(loadWptVrtConfig()).filter((entry) =>
      CI_WPT_VRT_MODULES.has(entry.moduleName)
    );
    const selected = CI_WPT_VRT_SHARDS.flatMap((shard) => selectEntriesForShard(entries, shard));
    const selectedPaths = selected.map((entry) => entry.relativePath).sort();
    const expectedPaths = entries.map((entry) => entry.relativePath).sort();

    expect(selectedPaths).toEqual(expectedPaths);

    const seen = new Set<string>();
    const duplicates = new Set<string>();
    for (const relativePath of selectedPaths) {
      if (seen.has(relativePath)) duplicates.add(relativePath);
      seen.add(relativePath);
    }
    expect([...duplicates]).toEqual([]);
  });

  it("publishes a GitHub matrix with the expected shard names", () => {
    const matrix = toGithubMatrix();
    expect(matrix.include.map((row) => row.name)).toEqual([
      "flexbox-1",
      "flexbox-2",
      "flexbox-3",
      "display",
      "box-1",
      "box-2",
      "position-1",
      "position-2",
    ]);
  });
});
