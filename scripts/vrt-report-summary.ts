#!/usr/bin/env npx tsx

import path from "node:path";
import {
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
import {
  buildVrtArtifactSummary,
  renderVrtArtifactSummaryMarkdown,
} from "./vrt-report-summary-core.ts";
import { loadVrtArtifactReports } from "./vrt-report-loader.ts";

const DEFAULT_INPUT = path.join("output", "playwright", "vrt");
export * from "./vrt-report-summary-core.ts";
export { loadVrtArtifactReports } from "./vrt-report-loader.ts";

interface VrtReportSummaryCliArgs extends ReportOutputCliOptions {
  inputDir?: string;
  label?: string;
  collectTaskId?: string;
}

function usage(): string {
  return renderUsage({
    summary: "Aggregate VRT artifact report.json files",
    command: "npx tsx scripts/vrt-report-summary.ts [options]",
    optionLines: [
      `  --input <dir>       Directory containing VRT artifact report.json files (default: ${DEFAULT_INPUT})`,
      "  --label <name>      Summary label override",
      "  --collect-task-id <task-id>  Task id used for collect-compatible copies (defaults to label)",
      "  --json <file>       Write JSON summary",
      "  --markdown <file>   Write markdown summary",
    ],
    helpLine: "  --help              Show this help",
  });
}

export function parseVrtReportSummaryArgs(args: string[]): VrtReportSummaryCliArgs {
  const options = parseCliFlags(args, {} as VrtReportSummaryCliArgs, {
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

  if (!options.inputDir) {
    options.inputDir = DEFAULT_INPUT;
  }

  return options;
}
export function runVrtReportSummaryCli(
  args: string[],
  options?: {
    cwd?: string;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseVrtReportSummaryArgs(args);
    const cwd = options?.cwd ?? process.cwd();
    const inputDir = path.resolve(cwd, parsed.inputDir ?? DEFAULT_INPUT);
    const reports = loadVrtArtifactReports(inputDir);
    const label = parsed.label ?? (path.basename(inputDir) || "vrt");
    const collectTaskId = parsed.collectTaskId?.trim() || label;
    const summary = buildVrtArtifactSummary(reports, label);
    const markdown = renderVrtArtifactSummaryMarkdown(summary);
    const jsonContent = `${JSON.stringify(summary, null, 2)}\n`;
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
      kind: "vrt-summary",
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
  emitScriptExecutionResult(runVrtReportSummaryCli(process.argv.slice(2)));
}
