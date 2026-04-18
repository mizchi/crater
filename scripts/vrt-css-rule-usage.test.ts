import { describe, expect, it } from "vitest";
import {
  summarizeCssRuleUsageResult,
  summarizeCssRuleUsageRules,
} from "./vrt-css-rule-usage.ts";

describe("summarizeCssRuleUsageRules", () => {
  it("counts dead css categories and no-effect reasons", () => {
    expect(summarizeCssRuleUsageRules([
      { matched: false, overridden: false },
      { matched: true, overridden: true },
      { matched: true, overridden: false, noEffect: true, noEffectReason: "same_as_inherited" },
      { matched: true, overridden: false, noEffect: true, noEffectReason: "same_as_fallback" },
      { matched: true, overridden: false },
    ])).toEqual({
      totalRules: 5,
      matchedRules: 4,
      unusedRules: 1,
      overriddenRules: 1,
      noEffectRules: 2,
      deadRules: 4,
      sameAsInheritedRules: 1,
      sameAsInitialRules: 0,
      sameAsFallbackRules: 1,
    });
  });
});

describe("summarizeCssRuleUsageResult", () => {
  it("normalizes BiDi command results into VRT css usage metrics", () => {
    expect(summarizeCssRuleUsageResult({
      rules: [
        { selector: ".unused", matched: false, elements: 0, overridden: false },
        { selector: ".card", matched: true, elements: 1, overridden: true },
        {
          selector: "div.card",
          matched: true,
          elements: 1,
          overridden: false,
          noEffect: true,
          noEffectReason: "same_as_initial",
        },
      ],
      elements: {},
    })).toEqual({
      totalRules: 3,
      matchedRules: 2,
      unusedRules: 1,
      overriddenRules: 1,
      noEffectRules: 1,
      deadRules: 3,
      sameAsInheritedRules: 0,
      sameAsInitialRules: 1,
      sameAsFallbackRules: 0,
    });
  });

  it("returns undefined for non-command payloads", () => {
    expect(summarizeCssRuleUsageResult({})).toBeUndefined();
    expect(summarizeCssRuleUsageResult(null)).toBeUndefined();
  });
});
