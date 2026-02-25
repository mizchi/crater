import { describe, expect, it } from "vitest";
import {
  buildTimingSummary,
  renderTimingMarkdown,
  type GithubJobLike,
} from "./ci-timing-summary.ts";

function makeJob(overrides: Partial<GithubJobLike>): GithubJobLike {
  return {
    name: "job-a",
    status: "completed",
    conclusion: "success",
    createdAt: "2026-02-25T15:00:00Z",
    startedAt: "2026-02-25T15:00:10Z",
    completedAt: "2026-02-25T15:01:10Z",
    ...overrides,
  };
}

describe("buildTimingSummary", () => {
  it("computes duration/queue and sorts by duration desc", () => {
    const jobs: GithubJobLike[] = [
      makeJob({
        name: "wpt-css (css-flexbox)",
        createdAt: "2026-02-25T15:00:00Z",
        startedAt: "2026-02-25T15:00:20Z",
        completedAt: "2026-02-25T15:02:20Z",
      }),
      makeJob({
        name: "wpt-dom (dom)",
        createdAt: undefined,
        startedAt: undefined,
        completedAt: undefined,
        created_at: "2026-02-25T15:00:00Z",
        started_at: "2026-02-25T15:00:05Z",
        completed_at: "2026-02-25T15:00:35Z",
      }),
      makeJob({
        name: "wpt-webdriver (session-status)",
        conclusion: "failure",
        createdAt: "2026-02-25T15:00:00Z",
        startedAt: "2026-02-25T15:00:15Z",
        completedAt: "2026-02-25T15:01:00Z",
      }),
    ];

    const summary = buildTimingSummary(jobs, 123);
    expect(summary.rows[0]?.name).toBe("wpt-css (css-flexbox)");
    expect(summary.rows[0]?.durationSec).toBe(120);
    expect(summary.rows[0]?.queueSec).toBe(20);
    expect(summary.totals.failedJobs).toBe(1);
    expect(summary.totals.completedJobs).toBe(3);
    expect(summary.byGroup.find((g) => g.group === "wpt-css")?.durationSec).toBe(120);
  });
});

describe("renderTimingMarkdown", () => {
  it("renders timing tables", () => {
    const jobs: GithubJobLike[] = [
      makeJob({ name: "wpt-css (css-flexbox)" }),
      makeJob({
        name: "test",
        createdAt: "2026-02-25T15:00:00Z",
        startedAt: "2026-02-25T15:00:02Z",
        completedAt: "2026-02-25T15:00:32Z",
      }),
    ];
    const summary = buildTimingSummary(jobs);
    const markdown = renderTimingMarkdown(summary);

    expect(markdown).toContain("# CI Timing Summary");
    expect(markdown).toContain("| Job | Status | Conclusion | Queue (s) | Run (s) |");
    expect(markdown).toContain("| Group | Jobs | Completed | Failed | Queue Total (s) | Run Total (s) |");
  });
});
