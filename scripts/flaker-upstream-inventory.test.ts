import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildFlakerUpstreamInventory,
  renderFlakerUpstreamInventoryMarkdown,
  runFlakerUpstreamInventoryCli,
} from "./flaker-upstream-inventory.ts";

const SCRIPT_DIR = path.dirname(new URL(import.meta.url).pathname);

describe("buildFlakerUpstreamInventory", () => {
  it("groups files by upstream ownership and extraction unit", () => {
    const inventory = buildFlakerUpstreamInventory();

    expect(inventory.groups.map((group) => `${group.category}:${group.id}`)).toEqual([
      "metric-ci:playwright-report-core",
      "metric-ci:flaker-task-summary-core",
      "metric-ci:flaker-batch-summary-core",
      "metric-ci:flaker-batch-plan-core",
      "metric-ci:flaker-quarantine-core",
      "metric-ci:flaker-config-core",
      "crater-adapter:flaker-config-adapter",
      "crater-adapter:task-runner-adapter",
      "crater-adapter:flaker-report-loader-adapter",
      "crater-domain:vrt-report-core",
      "crater-domain:wpt-vrt-summary-core",
      "crater-tooling:report-cli-wrappers",
      "crater-tooling:flaker-cli-tooling",
      "crater-tooling:upstream-staging-tooling",
      "crater-tooling:script-runtime-boundary",
    ]);
    expect(inventory.groups[0]?.files).toContain("scripts/playwright-report-summary-core.ts");
    expect(inventory.groups[0]?.origin).toBe("crater-extracted");
    expect(inventory.groups[0]?.testFiles).toContain("scripts/playwright-report-summary.test.ts");
    expect(inventory.groups[3]?.files).toContain("scripts/flaker-batch-plan-core.ts");
    expect(inventory.groups[4]?.files).toContain("scripts/flaker-quarantine-contract.ts");
    expect(inventory.groups[5]?.files).toContain("scripts/flaker-config-parser.ts");
    expect(inventory.groups[5]?.files).toContain("scripts/flaker-config-summary-core.ts");
    expect(inventory.groups[5]?.files).toContain("scripts/flaker-config-task.ts");
    expect(inventory.groups[5]?.testFiles).toContain("scripts/flaker-config-task.test.ts");
    expect(inventory.groups[8]?.files).toContain("scripts/flaker-batch-summary-loader.ts");
    expect(inventory.groups[8]?.files).toContain("scripts/flaker-quarantine-loader.ts");
    expect(inventory.groups[8]?.testFiles).toContain("scripts/flaker-batch-summary-loader.test.ts");
    expect(inventory.groups[8]?.testFiles).toContain("scripts/flaker-quarantine-loader.test.ts");
    expect(inventory.groups[8]?.testFiles).toContain("scripts/vrt-report-loader.test.ts");
    expect(inventory.groups[9]?.files).toContain("scripts/vrt-report-contract.ts");
    expect(inventory.groups[9]?.files).toContain("scripts/vrt-report-summary-core.ts");
    expect(inventory.groups[9]?.testFiles).toContain("scripts/vrt-report-contract.test.ts");
    expect(inventory.groups[9]?.testFiles).toContain("scripts/vrt-report-summary.test.ts");
    expect(inventory.groups[9]?.reason).toContain("VRT");
    expect(inventory.groups[10]?.testFiles).toContain("scripts/wpt-vrt-summary.test.ts");
    expect(inventory.groups[10]?.reason).toContain("VRT");
    expect(inventory.groups[11]?.files).toContain("scripts/playwright-report-summary.ts");
    expect(inventory.groups[11]?.files).toContain("scripts/vrt-report-summary.ts");
    expect(inventory.groups[11]?.testFiles).toContain("scripts/playwright-report-summary-cli.test.ts");
    expect(inventory.groups[11]?.testFiles).toContain("scripts/vrt-report-summary-cli.test.ts");
    expect(inventory.groups[12]?.files).toContain("scripts/flaker-entry.ts");
    expect(inventory.groups[12]?.files).toContain("scripts/flaker-cli-path.ts");
    expect(inventory.groups[13]?.files).toContain("scripts/flaker-upstream-inventory.ts");
    expect(inventory.groups[13]?.testFiles).toContain("scripts/flaker-upstream-export.test.ts");
    expect(inventory.groups[14]?.files).toContain("scripts/flaker-collected-summary-paths.ts");
    expect(inventory.groups[14]?.testFiles).toContain("scripts/flaker-collected-summary-paths.test.ts");
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
