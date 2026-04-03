#!/usr/bin/env npx tsx

import fs from "node:fs";
import path from "node:path";
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
import {
  buildPlaywrightSummary,
  renderPlaywrightMarkdown,
  type PlaywrightJsonReport,
} from "./playwright-report-summary-core.ts";

export * from "./playwright-report-contract.ts";
export * from "./playwright-report-summary-core.ts";

export interface PlaywrightReportSummaryCliArgs extends ReportOutputCliOptions {
  input: string;
  label?: string;
}

const DEFAULT_INPUT = "playwright-report.json";

function basenameWithoutExt(filePath: string): string {
  const base = path.basename(filePath);
  return base.replace(/\.[^.]+$/, "");
}

function usage(): string {
  return renderUsage({
    summary: "Playwright Report Summary",
    command: "npx tsx scripts/playwright-report-summary.ts [options]",
    optionLines: [
      `  --input <file>      Playwright JSON report (default: ${DEFAULT_INPUT})`,
      "  --label <name>      Summary label shown in markdown/json",
      "  --json <file>       Write normalized summary JSON",
      "  --markdown <file>   Write markdown summary",
    ],
    helpLine: "  --help              Show this help",
  });
}

export function parsePlaywrightReportSummaryArgs(
  args: string[],
): PlaywrightReportSummaryCliArgs {
  const options = parseCliFlags(args, {
    input: DEFAULT_INPUT,
  } as PlaywrightReportSummaryCliArgs, {
    usage,
    handlers: {
      "--input": {
        set: (target, value) => {
          target.input = value ?? "";
        },
      },
      "--label": {
        set: (target, value) => {
          target.label = value;
        },
      },
      ...createReportOutputHandlers(),
    },
  });

  assertRequiredOptions(options, [
    {
      select: (candidate) => candidate.input,
      errorMessage: "--input is required",
    },
  ]);

  return options;
}

export function runPlaywrightReportSummaryCli(
  args: string[],
  options?: {
    cwd?: string;
    readFile?: (targetPath: string) => string;
  },
): ScriptExecutionResult {
  try {
    const parsed = parsePlaywrightReportSummaryArgs(args);
    const cwd = options?.cwd ?? process.cwd();
    const inputPath = path.resolve(cwd, parsed.input);
    const readFile = options?.readFile ?? ((targetPath: string) => fs.readFileSync(targetPath, "utf8"));
    const report = JSON.parse(readFile(inputPath)) as PlaywrightJsonReport;
    const summary = buildPlaywrightSummary(
      report,
      parsed.label ?? basenameWithoutExt(inputPath),
      path.relative(cwd, inputPath),
    );
    const markdown = renderPlaywrightMarkdown(summary);
    const writes: ScriptExecutionResult["writes"] = [];
    appendReportWrites(writes, {
      cwd,
      markdownPath: parsed.markdownOutput,
      markdownContent: markdown,
      jsonPath: parsed.jsonOutput,
      jsonValue: summary,
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
  emitScriptExecutionResult(runPlaywrightReportSummaryCli(process.argv.slice(2)));
}
