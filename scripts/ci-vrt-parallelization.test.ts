import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";

function readRepoFile(relativePath: string): string {
  return readFileSync(new URL(`../${relativePath}`, import.meta.url), "utf8");
}

function extractWorkflowJob(workflow: string, jobName: string): string {
  const start = workflow.indexOf(`  ${jobName}:\n`);
  expect(start).toBeGreaterThanOrEqual(0);
  const rest = workflow.slice(start + 1);
  const nextJob = rest.search(/\n  [a-zA-Z0-9_-]+:\n/);
  return nextJob === -1 ? rest : rest.slice(0, nextJob);
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
    expect(paintVrtJob).toContain("if: steps.paint_vrt_playwright_cache.outputs.cache-hit != 'true'");
    expect(workflow).toContain("Restore WPT VRT reference fixtures");
    expect(workflow).toContain("path: .cache/wpt-vrt-reference");
    expect(workflow).toContain("if: steps.wpt_vrt_playwright_cache.outputs.cache-hit != 'true'");
    expect(workflow).toContain("paint-vrt-summary:");
    expect(workflow).toContain("pattern: paint-vrt-artifacts-*");
  });

  test("uses pnpm v10-compatible flaker package install commands", () => {
    const ciWorkflow = readRepoFile(".github/workflows/ci.yml");
    const dailyWorkflow = readRepoFile(".github/workflows/flaker-daily.yml");
    const combined = `${ciWorkflow}\n${dailyWorkflow}`;

    expect(combined).not.toContain("pnpm add --no-save @mizchi/flaker@latest");
    expect(combined).not.toContain("@mizchi/flaker@latest");
    expect(ciWorkflow).toContain("pnpm add --save-dev --save-exact @mizchi/flaker@0.10.6");
    expect(dailyWorkflow).toContain("pnpm add --save-dev --save-exact @mizchi/flaker@0.10.6");
  });
});
