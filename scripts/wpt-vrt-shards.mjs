#!/usr/bin/env node

// Tuned against CI #24632336814 (80bef97):
// - wpt-vrt (display): ~22m
// - wpt-vrt (flexbox-2): ~19m
// - wpt-vrt (flexbox-1): ~14m
// - wpt-vrt (box-1/2): ~7m
// - wpt-vrt (position-1/2): ~8m / ~6m
//
// CI #345 showed that splitting css-flexbox into 3 shards changed VRT outcomes
// for threshold-sensitive cases, while the previous 2-shard layout was stable.
// Keep the flexbox grouping conservative, split css-display in half, and keep
// the already-balanced box/position layout.

export const CI_WPT_VRT_SHARDS = Object.freeze([
  { name: "flexbox-1", modules: ["css-flexbox"], offset: 0, limit: 21 },
  { name: "flexbox-2", modules: ["css-flexbox"], offset: 21, limit: 21 },
  { name: "display-1", modules: ["css-display"], offset: 0, limit: 20 },
  { name: "display-2", modules: ["css-display"], offset: 20, limit: 19 },
  { name: "box-1", modules: ["css-box"], offset: 0, limit: 14 },
  { name: "box-2", modules: ["css-box"], offset: 14, limit: 14 },
  { name: "position-1", modules: ["css-position"], offset: 0, limit: 15 },
  { name: "position-2", modules: ["css-position"], offset: 15, limit: 15 },
]);

export const CI_WPT_VRT_MODULES = new Set(
  CI_WPT_VRT_SHARDS.flatMap((shard) => shard.modules),
);

export function selectEntriesForShard(entries, shard) {
  const moduleEntries = entries.filter((entry) => shard.modules.includes(entry.moduleName));
  if ((shard.limit ?? 0) > 0) {
    return moduleEntries.slice(shard.offset ?? 0, (shard.offset ?? 0) + shard.limit);
  }
  return moduleEntries.slice(shard.offset ?? 0);
}

export function toGithubMatrix(shards = CI_WPT_VRT_SHARDS) {
  return {
    include: shards.map((shard) => ({
      name: shard.name,
      modules: shard.modules.join(","),
      ...(typeof shard.offset === "number" ? { offset: shard.offset } : {}),
      ...(typeof shard.limit === "number" ? { limit: shard.limit } : {}),
    })),
  };
}

function renderHumanSummary(shards = CI_WPT_VRT_SHARDS) {
  return [
    "CI WPT VRT shards",
    ...shards.map((shard) => {
      const range = typeof shard.limit === "number"
        ? ` offset=${shard.offset ?? 0} limit=${shard.limit}`
        : "";
      return `- ${shard.name}: ${shard.modules.join(",")}${range}`;
    }),
  ].join("\n");
}

function main(argv) {
  if (argv.includes("--github-matrix")) {
    process.stdout.write(JSON.stringify(toGithubMatrix()) + "\n");
    return;
  }
  process.stdout.write(renderHumanSummary() + "\n");
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  main(process.argv.slice(2));
}
