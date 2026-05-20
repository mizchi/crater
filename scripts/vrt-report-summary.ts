#!/usr/bin/env npx tsx

import fs from "node:fs";
import path from "node:path";
import {
  createBooleanFlagHandler,
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
  includeTaskIds?: string[];
  excludeFilters?: string[];
  checkFresh?: boolean;
}

function usage(): string {
  return renderUsage({
    summary: "Aggregate VRT artifact report.json files",
    command: "npx tsx scripts/vrt-report-summary.ts [options]",
    optionLines: [
      `  --input <dir>       Directory containing VRT artifact report.json files (default: ${DEFAULT_INPUT})`,
      "  --label <name>      Summary label override",
      "  --collect-task-id <task-id>  Task id used for collect-compatible copies (defaults to label)",
      "  --include-task-id <task-id>  Include only reports with this stable task id (repeatable)",
      "  --exclude-filter <filter>    Exclude reports with this stable filter/title/label (repeatable)",
      "  --check-fresh       Do not write; fail if summary outputs are older than selected reports",
      "  --json <file>       Write JSON summary",
      "  --markdown <file>   Write markdown summary",
    ],
    helpLine: "  --help              Show this help",
  });
}

function pushOptionValue(target: string[] | undefined, value: string | undefined): string[] {
  const trimmed = value?.trim();
  if (!trimmed) {
    return target ?? [];
  }
  return [...(target ?? []), trimmed];
}

function toDisplayPath(cwd: string, filePath: string): string {
  const relative = path.relative(cwd, filePath);
  return relative.length > 0 && !relative.startsWith("..") ? relative : filePath;
}

function statMtimeMs(filePath: string): number | undefined {
  try {
    return fs.statSync(filePath).mtimeMs;
  } catch {
    return undefined;
  }
}

function checkSummaryFreshness(input: {
  cwd: string;
  outputPaths: string[];
  reportPaths: string[];
}): string | null {
  if (input.outputPaths.length === 0) {
    return "--check-fresh requires --json or --markdown output path";
  }

  let latestReport: { path: string; mtimeMs: number } | undefined;
  for (const reportPath of input.reportPaths) {
    const mtimeMs = statMtimeMs(reportPath);
    if (mtimeMs === undefined) {
      continue;
    }
    if (!latestReport || mtimeMs > latestReport.mtimeMs) {
      latestReport = { path: reportPath, mtimeMs };
    }
  }

  for (const outputPath of input.outputPaths) {
    const outputMtimeMs = statMtimeMs(outputPath);
    if (outputMtimeMs === undefined) {
      return `VRT summary is stale: ${toDisplayPath(input.cwd, outputPath)} does not exist`;
    }
    if (latestReport && outputMtimeMs < latestReport.mtimeMs) {
      return [
        "VRT summary is stale:",
        `${toDisplayPath(input.cwd, outputPath)} is older than`,
        toDisplayPath(input.cwd, latestReport.path),
      ].join(" ");
    }
  }

  return null;
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
      "--include-task-id": {
        set: (target, value) => {
          target.includeTaskIds = pushOptionValue(target.includeTaskIds, value);
        },
      },
      "--exclude-filter": {
        set: (target, value) => {
          target.excludeFilters = pushOptionValue(target.excludeFilters, value);
        },
      },
      "--check-fresh": createBooleanFlagHandler((target) => {
        target.checkFresh = true;
      }),
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
    const reports = loadVrtArtifactReports(inputDir, {
      includeTaskIds: parsed.includeTaskIds,
      excludeFilters: parsed.excludeFilters,
    });
    const label = parsed.label ?? (path.basename(inputDir) || "vrt");
    const collectTaskId = parsed.collectTaskId?.trim() || label;
    if (parsed.checkFresh) {
      const outputPaths = [
        parsed.jsonOutput,
        parsed.markdownOutput,
      ]
        .filter((value): value is string => typeof value === "string" && value.length > 0)
        .map((value) => path.resolve(cwd, value));
      const staleMessage = checkSummaryFreshness({
        cwd,
        outputPaths,
        reportPaths: reports.map((report) => report.reportPath),
      });
      if (staleMessage) {
        return {
          exitCode: 1,
          stderr: `${staleMessage}\n`,
          writes: [],
        };
      }
      return {
        exitCode: 0,
        stdout: `VRT summary is fresh: ${outputPaths.map((filePath) => toDisplayPath(cwd, filePath)).join(", ")} covers ${reports.length} report(s).\n`,
        writes: [],
      };
    }
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
