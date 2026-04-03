import { describe, expect, it } from "vitest";
import {
  accumulatePlaywrightFileSummary,
  accumulatePlaywrightSummaryTotals,
  buildStablePlaywrightIdentity,
  createEmptyPlaywrightFileSummary,
  createEmptyPlaywrightSummaryTotals,
  isPlaywrightOutcomeUnstable,
  playwrightOutcomeSeverity,
  resolvePlaywrightTestIdentityKey,
  type PlaywrightTestRow,
} from "./playwright-report-contract.ts";

function makeRow(
  outcome: PlaywrightTestRow["outcome"],
  overrides?: Partial<PlaywrightTestRow>,
): PlaywrightTestRow {
  return {
    id: "tests/example.test.ts::works [chromium]",
    file: "tests/example.test.ts",
    title: "works",
    titlePath: ["Example Suite", "works"],
    identityKey: '{"spec":"tests/example.test.ts","suite":"Example Suite","testName":"works","titlePath":["works"],"variant":{"project":"chromium"}}',
    identity: {
      key: '{"spec":"tests/example.test.ts","suite":"Example Suite","testName":"works","titlePath":["works"],"variant":{"project":"chromium"}}',
      suite: "Example Suite",
      testName: "works",
      spec: "tests/example.test.ts",
      titlePath: ["works"],
      variant: { project: "chromium" },
    },
    projectName: "chromium",
    expectedStatus: "passed",
    rawStatus: outcome,
    outcome,
    attempts: [outcome],
    retryCount: 0,
    durationMs: 10,
    errorMessages: [],
    ...overrides,
  };
}

describe("buildStablePlaywrightIdentity", () => {
  it("drops empty variant values and sorts keys before building the key", () => {
    const identity = buildStablePlaywrightIdentity({
      suite: "Example Suite",
      testName: "works",
      spec: "tests/example.test.ts",
      titlePath: ["works"],
      variant: {
        browser: "chromium",
        empty: "",
        shard: "2/4",
      },
    });

    expect(identity.variant).toEqual({
      browser: "chromium",
      shard: "2/4",
    });
    expect(identity.key).toBe(
      '{"spec":"tests/example.test.ts","suite":"Example Suite","testName":"works","titlePath":["works"],"variant":{"browser":"chromium","shard":"2/4"}}',
    );
  });
});

describe("resolvePlaywrightTestIdentityKey", () => {
  it("prefers identityKey, then stable identity key, then row id", () => {
    expect(resolvePlaywrightTestIdentityKey(makeRow("passed"))).toBe(
      '{"spec":"tests/example.test.ts","suite":"Example Suite","testName":"works","titlePath":["works"],"variant":{"project":"chromium"}}',
    );
    expect(
      resolvePlaywrightTestIdentityKey(
        makeRow("passed", {
          identityKey: "",
        }),
      ),
    ).toBe(
      '{"spec":"tests/example.test.ts","suite":"Example Suite","testName":"works","titlePath":["works"],"variant":{"project":"chromium"}}',
    );
    expect(
      resolvePlaywrightTestIdentityKey(
        makeRow("passed", {
          identityKey: "",
          identity: undefined,
        }),
      ),
    ).toBe("tests/example.test.ts::works [chromium]");
  });
});

describe("playwright report accumulators", () => {
  it("updates totals, file summary, and unstable severity consistently", () => {
    const flakyRow = makeRow("flaky", {
      attempts: ["failed", "passed"],
      retryCount: 1,
      durationMs: 42,
    });
    const totals = createEmptyPlaywrightSummaryTotals();
    const fileSummary = createEmptyPlaywrightFileSummary(flakyRow.file);

    accumulatePlaywrightSummaryTotals(totals, flakyRow);
    accumulatePlaywrightFileSummary(fileSummary, flakyRow);

    expect(totals).toMatchObject({
      total: 1,
      flaky: 1,
      retries: 1,
      durationMs: 42,
    });
    expect(fileSummary).toMatchObject({
      file: "tests/example.test.ts",
      total: 1,
      flaky: 1,
      retries: 1,
      durationMs: 42,
    });
    expect(playwrightOutcomeSeverity("passed")).toBe(0);
    expect(playwrightOutcomeSeverity("flaky")).toBe(1);
    expect(playwrightOutcomeSeverity("failed")).toBe(2);
    expect(isPlaywrightOutcomeUnstable("passed")).toBe(false);
    expect(isPlaywrightOutcomeUnstable("flaky")).toBe(true);
  });
});
