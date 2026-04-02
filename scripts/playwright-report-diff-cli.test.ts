import { describe, expect, it } from "vitest";
import { runPlaywrightReportDiffCli } from "./playwright-report-diff.ts";

describe("runPlaywrightReportDiffCli", () => {
  it("builds diff writes and stdout without touching the filesystem", () => {
    const baseSummary = {
      schemaVersion: 1,
      generatedAt: "2026-04-01T00:00:00.000Z",
      label: "base",
      totals: {
        total: 1,
        passed: 1,
        failed: 0,
        flaky: 0,
        skipped: 0,
        timedout: 0,
        interrupted: 0,
        unknown: 0,
        retries: 0,
        durationMs: 10,
      },
      files: [
        {
          file: "tests/example.test.ts",
          total: 1,
          passed: 1,
          failed: 0,
          flaky: 0,
          skipped: 0,
          retries: 0,
          durationMs: 10,
        },
      ],
      tests: [
        {
          id: "tests/example.test.ts::renders [chromium]",
          file: "tests/example.test.ts",
          title: "renders",
          titlePath: ["renders"],
          identityKey:
            '{"spec":"tests/example.test.ts","suite":"tests/example.test.ts","testName":"renders","titlePath":["renders"],"variant":{"project":"chromium"}}',
          identity: {
            key: '{"spec":"tests/example.test.ts","suite":"tests/example.test.ts","testName":"renders","titlePath":["renders"],"variant":{"project":"chromium"}}',
            suite: "tests/example.test.ts",
            testName: "renders",
            spec: "tests/example.test.ts",
            titlePath: ["renders"],
            variant: { project: "chromium" },
          },
          projectName: "chromium",
          expectedStatus: "passed",
          rawStatus: "passed",
          outcome: "passed",
          attempts: ["passed"],
          retryCount: 0,
          durationMs: 10,
          errorMessages: [],
        },
      ],
    };
    const headSummary = {
      ...baseSummary,
      label: "head",
      tests: [
        {
          ...baseSummary.tests[0],
          rawStatus: "failed",
          outcome: "failed",
          attempts: ["failed"],
        },
      ],
      totals: {
        ...baseSummary.totals,
        passed: 0,
        failed: 1,
      },
      files: [
        {
          ...baseSummary.files[0],
          passed: 0,
          failed: 1,
        },
      ],
    };

    const result = runPlaywrightReportDiffCli(
      [
        "--base",
        "out/base.json",
        "--head",
        "out/head.json",
        "--label",
        "paint-vrt",
        "--json",
        "out/diff.json",
        "--markdown",
        "out/diff.md",
      ],
      {
        cwd: "/repo",
        readFile: (targetPath) => {
          if (targetPath.endsWith("base.json")) {
            return JSON.stringify(baseSummary);
          }
          return JSON.stringify(headSummary);
        },
      },
    );

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# Playwright Baseline Diff");
    expect(result.writes).toHaveLength(2);
    expect(result.writes?.map((write) => write.path)).toEqual([
      "/repo/out/diff.md",
      "/repo/out/diff.json",
    ]);
    expect(result.writes?.[0]?.content).toContain("## Regressions");
  });
});
