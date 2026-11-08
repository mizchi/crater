import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { extractWorkflowJob, extractWorkflowStep } from "./ci-workflow-test-helpers";

function readRepoFile(relativePath: string): string {
  return readFileSync(new URL(`../${relativePath}`, import.meta.url), "utf8");
}

describe("CI VRT parallelization", () => {
  test("runs paint-vrt as a grep-based matrix and aggregates artifacts", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");
    const paintVrtJob = extractWorkflowJob(workflow, "playwright-paint-vrt");

    expect(workflow).toContain("name: paint-vrt (${{ matrix.name }})");
    expect(workflow).toContain("max-parallel: 5");
    expect(workflow).toContain("name: fixtures-a1");
    expect(workflow).toContain("name: fixtures-a2");
    expect(workflow).toContain("name: fixtures-b");
    expect(workflow).toContain("name: realworld");
    expect(workflow).toContain("name: url");
    expect(workflow).toContain("grep: 'fixture: (cards and controls|pricing cards|login form)'");
    expect(workflow).toContain("grep: 'fixture: (blog article|navigation bar|footer)'");
    expect(workflow).toContain("grep: 'fixture: (live form state|hackernews-style|canvas background|table with cellpadding and cellspacing|table with cellpadding=10)'");
    expect(workflow).toContain("grep: 'real-world snapshot:|example-com visual parity'");
    expect(workflow).toContain("grep: 'url snapshot:'");
    expect(paintVrtJob).toContain("Restore paint VRT reference fixtures");
    expect(paintVrtJob).toContain("path: .cache/paint-vrt-reference");
    expect(paintVrtJob).toContain("Restore Playwright Chromium browser cache");
    expect(paintVrtJob).toContain("id: paint_vrt_playwright_cache");
    expect(paintVrtJob.indexOf("Restore Playwright Chromium browser cache")).toBeLessThan(
      paintVrtJob.indexOf("Install Playwright browsers for VRT"),
    );
    const paintVrtInstall = extractWorkflowStep(paintVrtJob, "Install Playwright browsers for VRT");
    expect(paintVrtInstall).toContain("if: steps.paint_vrt_chromium_present.outputs.present != 'true'");
    expect(workflow).toContain("Restore WPT VRT reference fixtures");
    expect(workflow).toContain("path: .cache/wpt-vrt-reference");
    const wptVrtJob = extractWorkflowJob(workflow, "playwright-wpt-vrt");
    const wptVrtInstall = extractWorkflowStep(wptVrtJob, "Install Playwright browsers for VRT");
    expect(wptVrtInstall).toContain("if: steps.wpt_vrt_chromium_present.outputs.present != 'true'");
    expect(workflow).toContain("paint-vrt-summary:");
    expect(workflow).toContain("pattern: paint-vrt-artifacts-*");
  });

  test("uses the repository flaker dependency without overriding package exports", () => {
    const ciWorkflow = readRepoFile(".github/workflows/ci.yml");
    const dailyWorkflow = readRepoFile(".github/workflows/flaker-daily.yml");
    const combined = `${ciWorkflow}\n${dailyWorkflow}`;

    expect(combined).not.toContain("pnpm add --save-dev --save-exact --allow-build=duckdb @mizchi/flaker@");
    expect(combined).not.toContain("pnpm add --no-save @mizchi/flaker@latest");
    expect(combined).not.toContain("@mizchi/flaker@latest");
    expect(combined).not.toContain("@mizchi/flaker@0.10.6");
    expect(ciWorkflow).toContain("pnpm exec flaker --version");
    expect(dailyWorkflow).toContain("pnpm exec flaker --version");
  });

  test("installs repository dependencies before daily flaker planning scripts", () => {
    const workflow = readRepoFile(".github/workflows/flaker-daily.yml");
    const batchPlanJob = extractWorkflowJob(workflow, "batch-plan");
    const summaryJob = extractWorkflowJob(workflow, "flaker-daily-summary");

    for (const job of [batchPlanJob, summaryJob]) {
      expect(job).toContain("uses: actions/setup-node@v6");
      expect(job).toContain("uses: pnpm/action-setup@v5");
      expect(job).toContain("run: pnpm install");
    }
    expect(batchPlanJob.indexOf("run: pnpm install")).toBeLessThan(
      batchPlanJob.indexOf("node scripts/flaker-batch-plan.ts"),
    );
    expect(summaryJob.indexOf("run: pnpm install")).toBeLessThan(
      summaryJob.indexOf("node scripts/flaker-batch-summary.ts"),
    );
  });
});
