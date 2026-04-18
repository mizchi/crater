import type { VrtCssRuleUsageMetrics } from "./vrt-report-contract.ts";

export interface VrtCssRuleUsageRuleEntry {
  matched: boolean;
  overridden: boolean;
  noEffect?: boolean;
  noEffectReason?: string;
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null
    ? value as Record<string, unknown>
    : undefined;
}

function asRuleEntry(value: unknown): VrtCssRuleUsageRuleEntry | undefined {
  const record = asRecord(value);
  if (!record) {
    return undefined;
  }
  if (typeof record.matched !== "boolean" || typeof record.overridden !== "boolean") {
    return undefined;
  }
  return {
    matched: record.matched,
    overridden: record.overridden,
    noEffect: typeof record.noEffect === "boolean" ? record.noEffect : undefined,
    noEffectReason: typeof record.noEffectReason === "string" ? record.noEffectReason : undefined,
  };
}

export function summarizeCssRuleUsageRules(
  rules: readonly VrtCssRuleUsageRuleEntry[],
): VrtCssRuleUsageMetrics {
  const totalRules = rules.length;
  const matchedRules = rules.filter((rule) => rule.matched).length;
  const unusedRules = rules.filter((rule) => !rule.matched).length;
  const overriddenRules = rules.filter((rule) => rule.overridden).length;
  const noEffectRules = rules.filter((rule) => rule.noEffect === true).length;
  return {
    totalRules,
    matchedRules,
    unusedRules,
    overriddenRules,
    noEffectRules,
    deadRules: unusedRules + overriddenRules + noEffectRules,
    sameAsInheritedRules: rules.filter((rule) => rule.noEffectReason === "same_as_inherited").length,
    sameAsInitialRules: rules.filter((rule) => rule.noEffectReason === "same_as_initial").length,
    sameAsFallbackRules: rules.filter((rule) => rule.noEffectReason === "same_as_fallback").length,
  };
}

export function summarizeCssRuleUsageResult(
  value: unknown,
): VrtCssRuleUsageMetrics | undefined {
  const record = asRecord(value);
  if (!record || !Array.isArray(record.rules)) {
    return undefined;
  }
  const rules = record.rules
    .map((rule) => asRuleEntry(rule))
    .filter((rule): rule is VrtCssRuleUsageRuleEntry => rule !== undefined);
  return summarizeCssRuleUsageRules(rules);
}
