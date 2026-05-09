import {
  buildFlakerBatchSummary as buildBaseFlakerBatchSummary,
  type FlakerBatchSummaryInputs as BaseFlakerBatchSummaryInputs,
} from "@mizchi/flaker/reporting/flaker-batch-summary-core";
import {
  applyFlakerBatchVrtExtension,
  renderFlakerBatchVrtMarkdown,
  type FlakerBatchSummary,
  type FlakerBatchVrtSummary,
} from "./flaker-batch-vrt-extension.ts";

export type {
  FlakerBatchSummary,
  FlakerBatchTaskSummary,
  FlakerBatchVrtSummary,
} from "./flaker-batch-vrt-extension.ts";

export interface FlakerBatchSummaryInputs extends BaseFlakerBatchSummaryInputs {
  vrtSummaries: Map<string, FlakerBatchVrtSummary>;
}

export function buildFlakerBatchSummary(
  inputs: FlakerBatchSummaryInputs,
): FlakerBatchSummary {
  const baseSummary = buildBaseFlakerBatchSummary({
    playwrightSummaries: inputs.playwrightSummaries,
    flakerSummaries: inputs.flakerSummaries,
  });
  return applyFlakerBatchVrtExtension(baseSummary, inputs.vrtSummaries);
}

export const renderFlakerBatchSummaryMarkdown = renderFlakerBatchVrtMarkdown;
