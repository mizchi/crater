import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildPlaywrightSummary,
  renderPlaywrightMarkdown,
  type PlaywrightJsonReport,
} from "./playwright-report-summary-core.ts";
import { runPlaywrightReportSummaryCli } from "./playwright-report-summary.ts";

function makeReport(): PlaywrightJsonReport {
  return {
    config: {},
    suites: [
      {
        title: "tests/playwright-adapter.test.ts",
        file: "tests/playwright-adapter.test.ts",
        suites: [
          {
            title: "Playwright Adapter Tests",
            file: "tests/playwright-adapter.test.ts",
            specs: [
              {
                title: "goto and evaluate work together",
                ok: true,
                tags: [],
                tests: [
                  {
                    projectName: "chromium",
                    expectedStatus: "passed",
                    status: "expected",
                    results: [
                      {
                        retry: 0,
                        workerIndex: 0,
                        status: "passed",
                        duration: 18,
                        errors: [],
                        startTime: "2026-04-01T00:00:00.000Z",
                      },
                    ],
                  },
                ],
              },
              {
                title: "locator count",
                ok: true,
                tags: [],
                tests: [
                  {
                    projectName: "chromium",
                    expectedStatus: "passed",
                    status: "flaky",
                    results: [
                      {
                        retry: 0,
                        workerIndex: 0,
                        status: "failed",
                        duration: 120,
                        errors: [{ message: "first failure" }],
                        startTime: "2026-04-01T00:00:01.000Z",
                      },
                      {
                        retry: 1,
                        workerIndex: 1,
                        status: "passed",
                        duration: 33,
                        errors: [],
                        startTime: "2026-04-01T00:00:02.000Z",
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
      {
        title: "tests/paint-vrt.test.ts",
        file: "tests/paint-vrt.test.ts",
        specs: [
          {
            title: "fixture: cards and controls stay within relaxed visual diff budget",
            ok: false,
            tags: [],
            tests: [
              {
                projectName: "chromium",
                expectedStatus: "passed",
                status: "unexpected",
                results: [
                  {
                    retry: 0,
                    workerIndex: 0,
                    status: "failed",
                    duration: 210,
                    errors: [{ message: "visual diff exceeded" }],
                    startTime: "2026-04-01T00:00:05.000Z",
                  },
                ],
              },
            ],
          },
          {
            title: "fixture: footer with multi-column links",
            ok: true,
            tags: [],
            tests: [
              {
                projectName: "chromium",
                expectedStatus: "skipped",
                status: "skipped",
                annotations: [{ type: "skip", description: "temporarily disabled" }],
                results: [
                  {
                    retry: 0,
                    workerIndex: 0,
                    status: "skipped",
                    duration: 0,
                    errors: [],
                    startTime: "2026-04-01T00:00:06.000Z",
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
    errors: [],
    stats: {
      startTime: "2026-04-01T00:00:00.000Z",
      duration: 381,
      expected: 2,
      skipped: 1,
      unexpected: 1,
      flaky: 1,
    },
  };
}

describe("buildPlaywrightSummary", () => {
  it("normalizes rows, emits stable identities, and groups by file", () => {
    const summary = buildPlaywrightSummary(makeReport(), "playwright-bidi");

    expect(summary.totals.total).toBe(4);
    expect(summary.totals.passed).toBe(1);
    expect(summary.totals.failed).toBe(1);
    expect(summary.totals.flaky).toBe(1);
    expect(summary.totals.skipped).toBe(1);
    expect(summary.totals.retries).toBe(1);
    expect(summary.files).toHaveLength(2);
    expect(summary.files[0]?.file).toBe("tests/paint-vrt.test.ts");
    expect(summary.files[0]?.failed).toBe(1);

    const flakyRow = summary.tests.find((row) => row.title === "locator count");
    expect(flakyRow?.outcome).toBe("flaky");
    expect(flakyRow?.attempts).toEqual(["failed", "passed"]);
    expect(flakyRow?.retryCount).toBe(1);
    expect(flakyRow?.identityKey).toBe(flakyRow?.identity?.key);
    expect(flakyRow?.identity).toMatchObject({
      suite: "Playwright Adapter Tests",
      testName: "locator count",
      spec: "tests/playwright-adapter.test.ts",
      titlePath: ["locator count"],
      variant: { project: "chromium" },
    });
  });
});

describe("renderPlaywrightMarkdown", () => {
  it("renders totals, file table, and flaky section", () => {
    const markdown = renderPlaywrightMarkdown(
      buildPlaywrightSummary(makeReport(), "paint-vrt"),
    );

    expect(markdown).toContain("# Playwright Report Summary");
    expect(markdown).toContain("| Label | paint-vrt |");
    expect(markdown).toContain("| tests/paint-vrt.test.ts | 2 | 0 | 1 | 0 | 1 |");
    expect(markdown).toContain("## Flaky / Retried Tests");
    expect(markdown).toContain("locator count");
    expect(markdown).toContain("failed -> passed");
  });
});

describe("runPlaywrightReportSummaryCli", () => {
  it("writes collect-compatible copies when report outputs are requested", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-playwright-summary-"));
    fs.writeFileSync(
      path.join(root, "playwright-report.json"),
      `${JSON.stringify(makeReport())}\n`,
      "utf8",
    );

    const result = runPlaywrightReportSummaryCli([
      "--input",
      "playwright-report.json",
      "--label",
      "paint-vrt",
      "--json",
      "out/paint-vrt.json",
      "--markdown",
      "out/paint-vrt.md",
    ], {
      cwd: root,
    });

    expect(result.exitCode).toBe(0);
    expect(result.writes?.map((write) => path.relative(root, write.path))).toEqual([
      "out/paint-vrt.md",
      "out/paint-vrt.json",
      "out/paint-vrt/playwright-summary/paint-vrt.md",
      "out/paint-vrt/playwright-summary/paint-vrt.json",
    ]);
  });

  it("supports a separate collect task id from the display label", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-playwright-summary-task-id-"));
    fs.writeFileSync(
      path.join(root, "playwright-report.json"),
      `${JSON.stringify(makeReport())}\n`,
      "utf8",
    );

    const result = runPlaywrightReportSummaryCli([
      "--input",
      "playwright-report.json",
      "--label",
      "paint-vrt-artifacts",
      "--collect-task-id",
      "paint-vrt",
      "--json",
      "out/paint-vrt-artifacts.json",
      "--markdown",
      "out/paint-vrt-artifacts.md",
    ], {
      cwd: root,
    });

    expect(result.exitCode).toBe(0);
    expect(result.writes?.map((write) => path.relative(root, write.path))).toEqual([
      "out/paint-vrt-artifacts.md",
      "out/paint-vrt-artifacts.json",
      "out/paint-vrt/playwright-summary/paint-vrt.md",
      "out/paint-vrt/playwright-summary/paint-vrt.json",
    ]);
  });
});
