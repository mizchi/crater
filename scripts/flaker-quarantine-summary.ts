import type { FlakerConfig } from "./flaker-config-contract.ts";
import {
  loadFlakerQuarantineSummaryInputs,
  type SummarizeOptions,
} from "./flaker-quarantine-loader.ts";
import {
  buildFlakerQuarantineSummary,
} from "./flaker-quarantine-summary-core.ts";
import type {
  FlakerQuarantineConfig,
  FlakerQuarantineSummary,
} from "./flaker-quarantine-contract.ts";

export * from "./flaker-quarantine-summary-core.ts";
export { loadFlakerQuarantineSummaryInputs } from "./flaker-quarantine-loader.ts";
export type { SummarizeOptions } from "./flaker-quarantine-loader.ts";

export function summarizeFlakerQuarantine(
  quarantine: FlakerQuarantineConfig,
  flakerConfig: FlakerConfig,
  options: SummarizeOptions,
): FlakerQuarantineSummary {
  return buildFlakerQuarantineSummary(
    loadFlakerQuarantineSummaryInputs(quarantine, flakerConfig, options),
  );
}
