export type PlaywrightOutcome =
  | "passed"
  | "failed"
  | "flaky"
  | "skipped"
  | "timedout"
  | "interrupted"
  | "unknown";

export interface PlaywrightStableIdentity {
  key: string;
  suite: string;
  testName: string;
  spec: string;
  titlePath: string[];
  variant: Record<string, string>;
}

export interface PlaywrightTestRow {
  id: string;
  file: string;
  title: string;
  titlePath: string[];
  identityKey: string;
  identity?: PlaywrightStableIdentity;
  projectName: string;
  expectedStatus: string;
  rawStatus: string;
  outcome: PlaywrightOutcome;
  attempts: string[];
  retryCount: number;
  durationMs: number;
  errorMessages: string[];
}

export interface PlaywrightFileSummary {
  file: string;
  total: number;
  passed: number;
  failed: number;
  flaky: number;
  skipped: number;
  retries: number;
  durationMs: number;
}

export interface PlaywrightSummaryTotals {
  total: number;
  passed: number;
  failed: number;
  flaky: number;
  skipped: number;
  timedout: number;
  interrupted: number;
  unknown: number;
  retries: number;
  durationMs: number;
}

export interface PlaywrightSummary {
  schemaVersion: 1;
  generatedAt: string;
  label: string;
  sourceFile?: string;
  totals: PlaywrightSummaryTotals;
  files: PlaywrightFileSummary[];
  tests: PlaywrightTestRow[];
}

export function normalizePlaywrightVariant(
  variant: Record<string, string> | null | undefined,
): Record<string, string> {
  if (!variant) {
    return {};
  }
  return Object.fromEntries(
    Object.entries(variant)
      .filter((entry) => entry[1].length > 0)
      .sort((a, b) => a[0].localeCompare(b[0])),
  );
}

export function buildStablePlaywrightIdentity(input: {
  suite: string;
  testName: string;
  spec: string;
  titlePath: string[];
  variant?: Record<string, string> | null;
}): PlaywrightStableIdentity {
  const variant = normalizePlaywrightVariant(input.variant);
  const keyPayload: Record<string, unknown> = {
    spec: input.spec,
    suite: input.suite,
    testName: input.testName,
    titlePath: [...input.titlePath],
  };
  if (Object.keys(variant).length > 0) {
    keyPayload.variant = variant;
  }
  return {
    key: JSON.stringify(keyPayload),
    suite: input.suite,
    testName: input.testName,
    spec: input.spec,
    titlePath: [...input.titlePath],
    variant,
  };
}

export function resolvePlaywrightTestIdentityKey(
  row: Pick<PlaywrightTestRow, "id" | "identityKey" | "identity">,
): string {
  return row.identityKey || row.identity?.key || row.id;
}

export function createEmptyPlaywrightSummaryTotals(): PlaywrightSummaryTotals {
  return {
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
}

export function createEmptyPlaywrightFileSummary(
  file: string,
): PlaywrightFileSummary {
  return {
    file,
    total: 0,
    passed: 0,
    failed: 0,
    flaky: 0,
    skipped: 0,
    retries: 0,
    durationMs: 0,
  };
}

function pushCount(
  totals: PlaywrightSummaryTotals,
  outcome: PlaywrightOutcome,
): void {
  totals.total += 1;
  if (outcome === "passed") totals.passed += 1;
  else if (outcome === "failed") totals.failed += 1;
  else if (outcome === "flaky") totals.flaky += 1;
  else if (outcome === "skipped") totals.skipped += 1;
  else if (outcome === "timedout") totals.timedout += 1;
  else if (outcome === "interrupted") totals.interrupted += 1;
  else totals.unknown += 1;
}

export function accumulatePlaywrightSummaryTotals(
  totals: PlaywrightSummaryTotals,
  row: Pick<PlaywrightTestRow, "outcome" | "retryCount" | "durationMs">,
): void {
  pushCount(totals, row.outcome);
  totals.retries += row.retryCount;
  totals.durationMs += row.durationMs;
}

export function accumulatePlaywrightFileSummary(
  summary: PlaywrightFileSummary,
  row: Pick<PlaywrightTestRow, "outcome" | "retryCount" | "durationMs">,
): void {
  summary.total += 1;
  if (row.outcome === "passed") summary.passed += 1;
  else if (row.outcome === "failed") summary.failed += 1;
  else if (row.outcome === "flaky") summary.flaky += 1;
  else if (row.outcome === "skipped") summary.skipped += 1;
  summary.retries += row.retryCount;
  summary.durationMs += row.durationMs;
}

export function playwrightOutcomeSeverity(
  outcome: PlaywrightOutcome | undefined,
): number {
  if (!outcome || outcome === "passed" || outcome === "skipped") {
    return 0;
  }
  if (outcome === "flaky") {
    return 1;
  }
  return 2;
}

export function isPlaywrightOutcomeUnstable(
  outcome: PlaywrightOutcome | undefined,
): boolean {
  return playwrightOutcomeSeverity(outcome) > 0;
}
