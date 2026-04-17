import { describe, expect, it } from "vitest";
import { runPlaywrightReportSummaryCli } from "./playwright-report-summary.ts";

describe("runPlaywrightReportSummaryCli", () => {
  it("builds report writes and stdout without touching the filesystem", () => {
    const result = runPlaywrightReportSummaryCli(
      [
        "--input",
        "fixtures/playwright-report.json",
        "--label",
        "paint-vrt",
        "--json",
        "out/summary.json",
        "--markdown",
        "out/summary.md",
      ],
      {
        cwd: "/repo",
        readFile: () =>
          JSON.stringify({
            suites: [
              {
                title: "tests/example.test.ts",
                file: "tests/example.test.ts",
                specs: [
                  {
                    title: "renders",
                    tests: [
                      {
                        projectName: "chromium",
                        expectedStatus: "passed",
                        status: "expected",
                        results: [{ status: "passed", duration: 12, errors: [] }],
                      },
                    ],
                  },
                ],
              },
            ],
          }),
      },
    );

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# Playwright Report Summary");
    expect(result.writes).toHaveLength(4);
    expect(result.writes?.map((write) => write.path)).toEqual([
      "/repo/out/summary.md",
      "/repo/out/summary.json",
      "/repo/out/paint-vrt/playwright-summary/paint-vrt.md",
      "/repo/out/paint-vrt/playwright-summary/paint-vrt.json",
    ]);
    expect(result.writes?.[0]?.content).toContain("| Label | paint-vrt |");
  });
});
