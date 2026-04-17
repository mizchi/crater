#!/usr/bin/env node

import path from "node:path";
import {
  buildFlakerBatchSummary,
  renderFlakerBatchSummaryMarkdown,
} from "./flaker-batch-summary-core.ts";
import { loadFlakerBatchSummaryInputs } from "./flaker-batch-summary-loader.ts";
import {
  assertRequiredOptions,
  createReportOutputHandlers,
  parseCliFlags,
  renderUsage,
  type ReportOutputCliOptions,
} from "./script-cli.ts";
import {
  appendReportWrites,
  emitScriptExecutionResult,
  isMainModule,
  type ScriptExecutionResult,
} from "./script-runtime.ts";
import { appendFlakerCollectedSummaryWrites } from "./flaker-collected-summary-paths.ts";

export * from "./flaker-batch-summary-core.ts";
export { loadFlakerBatchSummaryInputs } from "./flaker-batch-summary-loader.ts";

export interface FlakerBatchSummaryCliArgs extends ReportOutputCliOptions {
  inputDir: string;
  label?: string;
  collectTaskId?: string;
}

function usage(): string {
  return renderUsage({
    summary: "Aggregate flaker daily batch outputs",
    command: "node scripts/flaker-batch-summary.ts --input <dir> [options]",
    optionLines: [
      "  --input <dir>       Downloaded nightly artifacts root",
      "  --label <name>      Summary label used for collect-compatible copies",
      "  --collect-task-id <task-id>  Task id used for collect-compatible copies (defaults to label)",
      "  --json <file>       Write JSON summary",
      "  --markdown <file>   Write markdown summary",
    ],
    helpLine: "  --help              Show this help",
  });
}

export function parseFlakerBatchSummaryArgs(
  args: string[],
): FlakerBatchSummaryCliArgs {
  const options = parseCliFlags(args, {
    inputDir: "",
  } as FlakerBatchSummaryCliArgs, {
    usage,
    handlers: {
      "--input": {
        set: (target, value) => {
          target.inputDir = value ?? "";
        },
      },
      "--label": {
        set: (target, value) => {
          target.label = value;
        },
      },
      "--collect-task-id": {
        set: (target, value) => {
          target.collectTaskId = value;
        },
      },
      ...createReportOutputHandlers(),
    },
  });

  assertRequiredOptions(options, [
    {
      select: (candidate) => candidate.inputDir,
      errorMessage: "--input is required",
    },
  ]);

  return options;
}

export function runFlakerBatchSummaryCli(
  args: string[],
  options?: {
    cwd?: string;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseFlakerBatchSummaryArgs(args);
    const cwd = options?.cwd ?? process.cwd();
    const inputs = loadFlakerBatchSummaryInputs(path.resolve(cwd, parsed.inputDir));
    const summary = buildFlakerBatchSummary(inputs);
    const markdown = renderFlakerBatchSummaryMarkdown(summary);
    const jsonContent = `${JSON.stringify(summary, null, 2)}\n`;
    const label = parsed.label?.trim() || path.basename(path.resolve(cwd, parsed.inputDir)) || "batch-summary";
    const collectTaskId = parsed.collectTaskId?.trim() || label;
    const writes: ScriptExecutionResult["writes"] = [];
    appendReportWrites(writes, {
      cwd,
      markdownPath: parsed.markdownOutput,
      markdownContent: markdown,
      jsonPath: parsed.jsonOutput,
      jsonValue: summary,
    });
    appendFlakerCollectedSummaryWrites(writes, {
      cwd,
      taskId: collectTaskId,
      kind: "batch-summary",
      jsonOutput: parsed.jsonOutput,
      markdownOutput: parsed.markdownOutput,
      jsonContent,
      markdownContent: markdown,
    });
    return {
      exitCode: 0,
      stdout: markdown,
      writes,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      exitCode: 1,
      stderr: `${message}\n`,
      writes: [],
    };
  }
}

if (isMainModule(import.meta.url)) {
  emitScriptExecutionResult(runFlakerBatchSummaryCli(process.argv.slice(2)));
}
