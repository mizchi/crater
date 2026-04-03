import { describe, expect, it } from "vitest";
import {
  buildFlakerUpstreamInventory,
  renderFlakerUpstreamInventoryMarkdown,
  runFlakerUpstreamInventoryCli,
} from "./flaker-upstream-inventory.ts";

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
      "crater-domain:wpt-vrt-summary-core",
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
    expect(inventory.groups[8]?.reason).toContain("VRT");
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
