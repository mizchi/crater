import { describe, expect, it } from "vitest";
import {
  buildPlaywrightDiff,
  renderPlaywrightDiffMarkdown,
} from "./playwright-report-diff-core.ts";
import type {
  PlaywrightFileSummary,
  PlaywrightStableIdentity,
  PlaywrightOutcome,
  PlaywrightSummary,
  PlaywrightSummaryTotals,
  PlaywrightTestRow,
} from "./playwright-report-contract.ts";

function makeIdentity(
  file: string,
  title: string,
  projectName: string,
): PlaywrightStableIdentity {
  const variant = projectName ? { project: projectName } : {};
  const keyPayload: Record<string, unknown> = {
    spec: file,
    suite: file,
    testName: title,
    titlePath: [title],
  };
  if (projectName) {
    keyPayload.variant = variant;
  }
  return {
    key: JSON.stringify(keyPayload),
    suite: file,
    testName: title,
    spec: file,
    titlePath: [title],
    variant,
  };
}

function makeRow(
  id: string,
  file: string,
  title: string,
  outcome: PlaywrightOutcome,
  attempts: string[],
): PlaywrightTestRow {
  const identity = makeIdentity(file, title, "chromium");
  return {
    id,
    file,
    title,
    titlePath: [file, title],
    identityKey: identity.key,
    identity,
    projectName: "chromium",
    expectedStatus: "passed",
    rawStatus: outcome,
    outcome,
    attempts,
    retryCount: Math.max(0, attempts.length - 1),
    durationMs: attempts.length * 10,
    errorMessages: [],
  };
}

function makeSummary(label: string, tests: PlaywrightTestRow[]): PlaywrightSummary {
  const totals: PlaywrightSummaryTotals = {
    total: 0,
    passed: 0,
    failed: 0,
    flaky: 0,
    skipped: 0,
    timedout: 0,
    interrupted: 0,
    unknown: 0,
    retries: 0,
    durationMs: 0,
  };
  const byFile = new Map<string, PlaywrightFileSummary>();

  for (const row of tests) {
    totals.total += 1;
    totals.durationMs += row.durationMs;
    totals.retries += row.retryCount;
    if (row.outcome === "passed") totals.passed += 1;
    else if (row.outcome === "failed") totals.failed += 1;
    else if (row.outcome === "flaky") totals.flaky += 1;
    else if (row.outcome === "skipped") totals.skipped += 1;
    else if (row.outcome === "timedout") totals.timedout += 1;
    else if (row.outcome === "interrupted") totals.interrupted += 1;
    else totals.unknown += 1;

    const fileSummary = byFile.get(row.file) ?? {
      file: row.file,
      total: 0,
      passed: 0,
      failed: 0,
      flaky: 0,
      skipped: 0,
      retries: 0,
      durationMs: 0,
    };
    fileSummary.total += 1;
    if (row.outcome === "passed") fileSummary.passed += 1;
    else if (row.outcome === "failed") fileSummary.failed += 1;
    else if (row.outcome === "flaky") fileSummary.flaky += 1;
    else if (row.outcome === "skipped") fileSummary.skipped += 1;
    fileSummary.retries += row.retryCount;
    fileSummary.durationMs += row.durationMs;
    byFile.set(row.file, fileSummary);
  }

  return {
    schemaVersion: 1,
    generatedAt: "2026-04-01T00:00:00.000Z",
    label,
    totals,
    files: [...byFile.values()].sort((a, b) => a.file.localeCompare(b.file)),
    tests: [...tests].sort((a, b) => a.id.localeCompare(b.id)),
  };
}

function makeBaseSummary(): PlaywrightSummary {
  return makeSummary("base", [
    makeRow("tests/a.test.ts::smoke [chromium]", "tests/a.test.ts", "smoke", "passed", ["passed"]),
    makeRow("tests/a.test.ts::retry [chromium]", "tests/a.test.ts", "retry", "flaky", ["failed", "passed"]),
    makeRow("tests/b.test.ts::render [chromium]", "tests/b.test.ts", "render", "failed", ["failed"]),
    makeRow("tests/c.test.ts::legacy [chromium]", "tests/c.test.ts", "legacy", "flaky", ["failed", "passed"]),
    makeRow("tests/d.test.ts::removed [chromium]", "tests/d.test.ts", "removed", "failed", ["failed"]),
  ]);
}

function makeHeadSummary(): PlaywrightSummary {
  return makeSummary("head", [
    makeRow("HEAD::tests/a.test.ts::smoke [chromium]", "tests/a.test.ts", "smoke", "failed", ["failed"]),
    makeRow("HEAD::tests/a.test.ts::retry [chromium]", "tests/a.test.ts", "retry", "passed", ["passed"]),
    makeRow("HEAD::tests/b.test.ts::render [chromium]", "tests/b.test.ts", "render", "flaky", ["failed", "passed"]),
    makeRow("HEAD::tests/c.test.ts::legacy [chromium]", "tests/c.test.ts", "legacy", "flaky", ["failed", "passed"]),
    makeRow("HEAD::tests/e.test.ts::new flaky [chromium]", "tests/e.test.ts", "new flaky", "flaky", ["failed", "passed"]),
  ]);
}

describe("buildPlaywrightDiff", () => {
  it("detects regressions, improvements, and persistent unstable tests", () => {
    const diff = buildPlaywrightDiff(makeBaseSummary(), makeHeadSummary(), "paint-vrt");

    expect(diff.totals.baseTotal).toBe(5);
    expect(diff.totals.headTotal).toBe(5);
    expect(diff.totals.addedTests).toBe(1);
    expect(diff.totals.removedTests).toBe(1);
    expect(diff.totals.regressions).toBe(2);
    expect(diff.totals.newFailures).toBe(1);
    expect(diff.totals.newFlaky).toBe(1);
    expect(diff.totals.improvements).toBe(3);
    expect(diff.totals.resolved).toBe(1);
    expect(diff.totals.improved).toBe(1);
    expect(diff.totals.removedUnstable).toBe(1);
    expect(diff.totals.persistentUnstable).toBe(1);
    expect(diff.regressions.map((row) => row.kind)).toEqual(["new_failure", "new_flaky"]);
    expect(diff.improvements.map((row) => row.kind)).toEqual([
      "resolved",
      "improved",
      "removed_unstable",
    ]);
    expect(diff.persistentUnstable.map((row) => row.kind)).toEqual(["persistent_flaky"]);
  });
});

describe("renderPlaywrightDiffMarkdown", () => {
  it("renders regression and improvement sections", () => {
    const markdown = renderPlaywrightDiffMarkdown(
      buildPlaywrightDiff(makeBaseSummary(), makeHeadSummary(), "paint-vrt"),
    );

    expect(markdown).toContain("# Playwright Baseline Diff");
    expect(markdown).toContain("| Label | paint-vrt |");
    expect(markdown).toContain("| Base | base |");
    expect(markdown).toContain("| Head | head |");
    expect(markdown).toContain("## Regressions");
    expect(markdown).toContain("new_failure");
    expect(markdown).toContain("## Improvements");
    expect(markdown).toContain("removed_unstable");
    expect(markdown).toContain("## Persistent Unstable");
    expect(markdown).toContain("persistent_flaky");
  });
});
