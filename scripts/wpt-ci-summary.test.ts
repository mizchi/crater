import { describe, expect, it } from "vitest";
import {
  aggregateReports,
  reportCategoryKey,
  type WptCompatShardReport,
  renderMarkdownSummary,
} from "./wpt-ci-summary.ts";

function makeReport(overrides: Partial<WptCompatShardReport>): WptCompatShardReport {
  return {
    schemaVersion: 1,
    suite: "wpt-css",
    target: "css-flexbox",
    passed: 10,
    failed: 5,
    errors: 0,
    total: 15,
    passRate: 10 / 15,
    generatedAt: "2026-02-25T00:00:00.000Z",
    ...overrides,
  };
}

describe("aggregateReports", () => {
  it("aggregates rows and totals by suite", () => {
    const reports = [
      makeReport({ suite: "wpt-css", target: "css-flexbox", passed: 120, failed: 80, total: 200 }),
      makeReport({ suite: "wpt-css", target: "css-grid", passed: 30, failed: 20, total: 50 }),
      makeReport({ suite: "wpt-dom", target: "dom", passed: 40, failed: 5, errors: 2, total: 47 }),
    ];

    const summary = aggregateReports(reports);

    expect(summary.rows).toHaveLength(3);
    expect(summary.total.passed).toBe(190);
    expect(summary.total.failed).toBe(105);
    expect(summary.total.errors).toBe(2);
    expect(summary.total.total).toBe(297);
    expect(summary.bySuite["wpt-css"]?.total).toBe(250);
    expect(summary.bySuite["wpt-dom"]?.errors).toBe(2);
    expect(summary.byCategory["wpt-css/css-flexbox"]?.total).toBe(200);
    expect(summary.byCategory["wpt-dom/dom"]?.errors).toBe(2);
  });
});

describe("reportCategoryKey", () => {
  it("normalizes quick/profile prefixes and module paths", () => {
    expect(reportCategoryKey(makeReport({ suite: "wpt-webdriver", target: "quick script/get_realms" }))).toBe("wpt-webdriver/script");
    expect(reportCategoryKey(makeReport({ suite: "wpt-webdriver", target: "profile strict" }))).toBe("wpt-webdriver/strict");
  });
});

describe("renderMarkdownSummary", () => {
  it("renders table and baseline delta", () => {
    const reports = [
      makeReport({ suite: "wpt-css", target: "css-flexbox", passed: 120, failed: 80, total: 200 }),
      makeReport({ suite: "wpt-dom", target: "dom", passed: 40, failed: 5, errors: 2, total: 47 }),
    ];
    const summary = aggregateReports(reports);

    const markdown = renderMarkdownSummary(summary, {
      total: 300,
      passed: 100,
      failed: 200,
    });

    expect(markdown).toContain("| Suite | Target | Passed | Failed | Errors | Total | Pass Rate |");
    expect(markdown).toContain("| wpt-css | css-flexbox | 120 | 80 | 0 | 200 | 66.67% |");
    expect(markdown).toContain("## Category Totals");
    expect(markdown).toContain("| wpt-css/css-flexbox | 120 | 80 | 0 | 200 | 60.00% |");
    expect(markdown).toContain("Baseline delta (wpt-css)");
    expect(markdown).toContain("Passed: +");
  });
});
