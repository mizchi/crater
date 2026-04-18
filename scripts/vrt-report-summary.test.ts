import { describe, expect, it } from "vitest";
import {
  buildVrtArtifactSummary,
  renderVrtArtifactSummaryMarkdown,
} from "./vrt-report-summary-core.ts";

describe("buildVrtArtifactSummary", () => {
  it("aggregates VRT artifact reports by budget status", () => {
    const summary = buildVrtArtifactSummary([
      {
        label: "fixture-blog-article",
        reportPath: "output/playwright/vrt/fixture-blog-article/report.json",
        report: {
          width: 960,
          height: 720,
          diffPixels: 1200,
          totalPixels: 691200,
          diffRatio: 0.04,
          threshold: 0.3,
          maxDiffRatio: 0.15,
          cssRuleUsage: {
            totalRules: 10,
            deadRules: 1,
            unusedRules: 1,
            overriddenRules: 0,
            noEffectRules: 0,
          },
        },
      },
      {
        label: "fixture-footer",
        reportPath: "output/playwright/vrt/fixture-footer/report.json",
        report: {
          width: 800,
          height: 600,
          diffPixels: 71520,
          totalPixels: 480000,
          diffRatio: 0.149,
          threshold: 0.3,
          maxDiffRatio: 0.15,
          cssRuleUsage: {
            totalRules: 4,
            deadRules: 1,
            unusedRules: 0,
            overriddenRules: 1,
            noEffectRules: 0,
          },
        },
      },
      {
        label: "example-com",
        reportPath: "output/playwright/vrt/example-com/report.json",
        report: {
          width: 1280,
          height: 720,
          diffPixels: 184320,
          totalPixels: 921600,
          diffRatio: 0.2,
          threshold: 0.3,
          maxDiffRatio: 0.12,
          cssRuleUsage: {
            totalRules: 6,
            deadRules: 4,
            unusedRules: 1,
            overriddenRules: 1,
            noEffectRules: 2,
          },
        },
      },
      {
        label: "url/google",
        reportPath: "output/playwright/vrt/url/google/report.json",
        report: {
          width: 1280,
          height: 720,
          diffPixels: 73728,
          totalPixels: 921600,
          diffRatio: 0.08,
          threshold: 0.3,
        },
      },
    ], "paint-vrt");

    expect(summary.label).toBe("paint-vrt");
    expect(summary.total).toBe(4);
    expect(summary.passed).toBe(2);
    expect(summary.failed).toBe(1);
    expect(summary.unknown).toBe(1);
    expect(summary.budgeted).toBe(3);
    expect(summary.maxObservedDiffRatio).toBe(0.2);
    expect(summary.averageDiffRatio).toBeCloseTo((0.04 + 0.149 + 0.2 + 0.08) / 4);
    expect(summary.failures.map((row) => row.label)).toEqual(["example-com"]);
    expect(summary.closestToBudget.slice(0, 3).map((row) => row.label)).toEqual([
      "fixture-footer",
      "example-com",
      "fixture-blog-article",
    ]);
    expect(summary.cssRuleUsage).toEqual({
      reports: 3,
      totalRules: 20,
      deadRules: 6,
      unusedRules: 2,
      overriddenRules: 2,
      noEffectRules: 2,
    });

    const markdown = renderVrtArtifactSummaryMarkdown(summary);
    expect(markdown).toContain("# VRT Artifact Summary");
    expect(markdown).toContain("| Label | paint-vrt |");
    expect(markdown).toContain("| CSS Rules (total/dead) | 20 / 6 |");
    expect(markdown).toContain("| example-com | fail | 0.2000 | 0.1200 | -0.0800 | 0.3000 | 4/6 | 1280x720 |");
  });
});
