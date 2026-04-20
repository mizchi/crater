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

  it("keeps the stable first css-flexbox shard and splits the heavy tail", () => {
    const entries = collectWptVrtTests(loadWptVrtConfig()).filter((entry) =>
      entry.moduleName === "css-flexbox"
    );
    const flexboxShards = CI_WPT_VRT_SHARDS.filter((shard) =>
      shard.modules.length === 1 && shard.modules[0] === "css-flexbox"
    );

    expect(flexboxShards.map((shard) => shard.name)).toEqual([
      "flexbox-1",
      "flexbox-2",
      "flexbox-3",
    ]);

    const selectedPathsByShard = flexboxShards.map((shard) =>
      selectEntriesForShard(entries, shard).map((entry) => entry.relativePath)
    );
    expect(selectedPathsByShard.map((paths) => paths.length)).toEqual([21, 9, 11]);
    expect(selectedPathsByShard[0]).toContain("css-flexbox/align-content_stretch.html");
    expect(selectedPathsByShard[1]).toContain("css-flexbox/align-self-015.html");
    expect(selectedPathsByShard[2]).toEqual(
      expect.arrayContaining([
        "css-flexbox/anonymous-flex-item-004.html",
        "css-flexbox/anonymous-flex-item-005.html",
        "css-flexbox/anonymous-flex-item-006.html",
      ]),
    );
  });

  it("splits css-display into two balanced shards", () => {
    const entries = collectWptVrtTests(loadWptVrtConfig()).filter((entry) =>
      entry.moduleName === "css-display"
    );
    const displayShards = CI_WPT_VRT_SHARDS.filter((shard) =>
      shard.modules.length === 1 && shard.modules[0] === "css-display"
    );

    expect(displayShards.map((shard) => shard.name)).toEqual([
      "display-1",
      "display-2",
    ]);

    const selectedPathsByShard = displayShards.map((shard) =>
      selectEntriesForShard(entries, shard).map((entry) => entry.relativePath)
    );
    expect(selectedPathsByShard.map((paths) => paths.length)).toEqual([20, 19]);
    expect(selectedPathsByShard[0]).toContain(
      "css-display/display-contents-details-001.html",
    );
  });

  it("publishes a GitHub matrix with the expected shard names", () => {
    const matrix = toGithubMatrix();
    expect(matrix.include.map((row) => row.name)).toEqual([
      "flexbox-1",
      "flexbox-2",
      "flexbox-3",
      "display-1",
      "display-2",
      "box-1",
      "box-2",
      "position-1",
      "position-2",
    ]);
  });
});
