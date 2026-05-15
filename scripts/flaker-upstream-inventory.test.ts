import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildFlakerUpstreamInventory,
  type FlakerUpstreamGroup,
  renderFlakerUpstreamInventoryMarkdown,
  runFlakerUpstreamInventoryCli,
} from "./flaker-upstream-inventory.ts";

const SCRIPT_DIR = path.dirname(new URL(import.meta.url).pathname);

function groupById(groups: FlakerUpstreamGroup[]): Map<string, FlakerUpstreamGroup> {
  return new Map(groups.map((group) => [group.id, group]));
}

describe("buildFlakerUpstreamInventory", () => {
  it("groups files by upstream ownership and extraction unit", () => {
    const inventory = buildFlakerUpstreamInventory();
    const groups = groupById(inventory.groups);

    expect(inventory.groups.map((group) => `${group.category}:${group.id}`)).toEqual([
      "metric-ci:playwright-report-core",
      "metric-ci:flaker-task-summary-core",
      "metric-ci:flaker-batch-plan-core",
      "metric-ci:flaker-quarantine-core",
      "metric-ci:flaker-config-core",
      "crater-adapter:flaker-batch-summary-adapter",
      "crater-adapter:flaker-config-adapter",
      "crater-adapter:task-runner-adapter",
      "crater-adapter:flaker-report-loader-adapter",
      "crater-domain:flaker-batch-vrt-extension",
      "crater-domain:vrt-report-core",
      "crater-domain:wpt-vrt-summary-core",
      "crater-tooling:report-cli-wrappers",
      "crater-tooling:flaker-cli-tooling",
      "crater-tooling:upstream-staging-tooling",
      "crater-tooling:script-runtime-boundary",
    ]);
    expect(groups.get("playwright-report-core")?.files).toContain("scripts/playwright-report-summary-core.ts");
    expect(groups.get("playwright-report-core")?.origin).toBe("crater-extracted");
    expect(groups.get("playwright-report-core")?.testFiles).toContain("scripts/playwright-report-summary.test.ts");
    expect(groups.get("flaker-batch-plan-core")?.files).toContain("scripts/flaker-batch-plan-core.ts");
    expect(groups.get("flaker-quarantine-core")?.files).toContain("scripts/flaker-quarantine-contract.ts");
    expect(groups.get("flaker-quarantine-core")?.status).toBe("upstreamed");
    expect(groups.get("flaker-config-core")?.files).toContain("scripts/flaker-config-parser.ts");
    expect(groups.get("flaker-config-core")?.files).toContain("scripts/flaker-config-summary-core.ts");
    expect(groups.get("flaker-config-core")?.files).toContain("scripts/flaker-config-task.ts");
    expect(groups.get("flaker-config-core")?.testFiles).toContain("scripts/flaker-config-task.test.ts");
    expect(groups.get("flaker-batch-summary-adapter")?.files).toEqual([
      "scripts/flaker-batch-summary-core.ts",
    ]);
    expect(groups.get("flaker-batch-summary-adapter")?.category).toBe("crater-adapter");
    expect(groups.get("flaker-batch-vrt-extension")?.files).toContain("scripts/flaker-batch-vrt-extension.ts");
    expect(groups.get("flaker-batch-vrt-extension")?.testFiles).toContain("scripts/flaker-batch-vrt-extension.test.ts");
    expect(groups.get("flaker-batch-vrt-extension")?.category).toBe("crater-domain");
    expect(groups.get("flaker-report-loader-adapter")?.files).toContain("scripts/flaker-batch-summary-loader.ts");
    expect(groups.get("flaker-report-loader-adapter")?.files).toContain("scripts/flaker-quarantine-loader.ts");
    expect(groups.get("flaker-report-loader-adapter")?.testFiles).toContain("scripts/flaker-batch-summary-loader.test.ts");
    expect(groups.get("flaker-report-loader-adapter")?.testFiles).toContain("scripts/flaker-quarantine-loader.test.ts");
    expect(groups.get("flaker-report-loader-adapter")?.testFiles).toContain("scripts/vrt-report-loader.test.ts");
    expect(groups.get("vrt-report-core")?.files).toContain("scripts/vrt-report-contract.ts");
    expect(groups.get("vrt-report-core")?.files).toContain("scripts/vrt-report-summary-core.ts");
    expect(groups.get("vrt-report-core")?.testFiles).toContain("scripts/vrt-report-contract.test.ts");
    expect(groups.get("vrt-report-core")?.testFiles).toContain("scripts/vrt-report-summary.test.ts");
    expect(groups.get("vrt-report-core")?.reason).toContain("VRT");
    expect(groups.get("wpt-vrt-summary-core")?.testFiles).toContain("scripts/wpt-vrt-summary.test.ts");
    expect(groups.get("wpt-vrt-summary-core")?.reason).toContain("VRT");
    expect(groups.get("report-cli-wrappers")?.files).toContain("scripts/playwright-report-summary.ts");
    expect(groups.get("report-cli-wrappers")?.files).toContain("scripts/vrt-report-summary.ts");
    expect(groups.get("report-cli-wrappers")?.testFiles).toContain("scripts/playwright-report-summary-cli.test.ts");
    expect(groups.get("report-cli-wrappers")?.testFiles).toContain("scripts/vrt-report-summary-cli.test.ts");
    expect(groups.get("flaker-cli-tooling")?.files).toContain("scripts/flaker-entry.ts");
    expect(groups.get("flaker-cli-tooling")?.files).toContain("scripts/flaker-cli-path.ts");
    expect(groups.get("upstream-staging-tooling")?.files).toContain("scripts/flaker-upstream-inventory.ts");
    expect(groups.get("upstream-staging-tooling")?.testFiles).toContain("scripts/flaker-upstream-export.test.ts");
    expect(groups.get("script-runtime-boundary")?.files).toContain("scripts/flaker-collected-summary-paths.ts");
    expect(groups.get("script-runtime-boundary")?.testFiles).toContain("scripts/flaker-collected-summary-paths.test.ts");
  });

  it("keeps VRT domain metadata out of metric-ci groups", () => {
    const inventory = buildFlakerUpstreamInventory();
    const metricCiGroups = inventory.groups.filter((group) => group.category === "metric-ci");
    const metricCiText = metricCiGroups
      .flatMap((group) => [
        group.id,
        group.title,
        group.reason,
        group.nextAction,
        ...group.files,
        ...group.testFiles,
      ])
      .join("\n");

    expect(metricCiText).not.toMatch(/\bVRT\b|diffRatio|threshold|snapshotKind|backend|CssDead|vrt-/);
  });

  it("classifies every flaker/report/vrt script file into an inventory group", () => {
    const inventory = buildFlakerUpstreamInventory();
    const covered = new Set(
      inventory.groups.flatMap((group) => [...group.files, ...group.testFiles]),
    );
    const candidates = fs.readdirSync(SCRIPT_DIR)
      .filter((fileName) => /^(flaker-|playwright-report-|vrt-report-|wpt-vrt-summary)/.test(fileName))
      .map((fileName) => `scripts/${fileName}`)
      .sort();

    expect(candidates.filter((fileName) => !covered.has(fileName))).toEqual([]);
  });
});

describe("renderFlakerUpstreamInventoryMarkdown", () => {
  it("renders grouped ownership summary", () => {
    const markdown = renderFlakerUpstreamInventoryMarkdown(buildFlakerUpstreamInventory());

    expect(markdown).toContain("# Metric CI Upstream Inventory");
    expect(markdown).toContain("| Category | Group | Status | Origin | Files | Tests |");
    expect(markdown).toContain("playwright-report-core");
    expect(markdown).toContain("crater-extracted");
    expect(markdown).toContain("Reference tests");
    expect(markdown).toContain("crater-domain");
  });
});

describe("runFlakerUpstreamInventoryCli", () => {
  it("returns markdown stdout and report writes", () => {
    const result = runFlakerUpstreamInventoryCli([
      "--json",
      "out/inventory.json",
      "--markdown",
      "out/inventory.md",
    ], {
      cwd: "/repo",
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# Metric CI Upstream Inventory");
    expect(result.writes).toEqual([
      {
        path: "/repo/out/inventory.md",
        content: expect.stringContaining("# Metric CI Upstream Inventory"),
      },
      {
        path: "/repo/out/inventory.json",
        content: expect.stringContaining('"schemaVersion": 1'),
      },
    ]);
  });
});
