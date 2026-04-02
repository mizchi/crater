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
import { type PlaywrightSummary } from "./playwright-report-contract.ts";
import {
  buildPlaywrightDiff,
  renderPlaywrightDiffMarkdown,
} from "./playwright-report-diff-core.ts";

export * from "./playwright-report-diff-core.ts";

export interface PlaywrightReportDiffCliArgs extends ReportOutputCliOptions {
  baseInput: string;
  headInput: string;
  label?: string;
}

const DEFAULT_BASE_INPUT = "playwright-base-summary.json";
const DEFAULT_HEAD_INPUT = "playwright-head-summary.json";

function usage(): string {
  return renderUsage({
    summary: "Playwright Baseline Diff",
    command: "npx tsx scripts/playwright-report-diff.ts [options]",
    optionLines: [
      `  --base <file>       Baseline normalized summary JSON (default: ${DEFAULT_BASE_INPUT})`,
      `  --head <file>       Current normalized summary JSON (default: ${DEFAULT_HEAD_INPUT})`,
      "  --label <name>      Diff label shown in markdown/json",
      "  --json <file>       Write diff JSON",
      "  --markdown <file>   Write markdown diff",
    ],
    helpLine: "  --help              Show this help",
  });
}

export function parsePlaywrightReportDiffArgs(
  args: string[],
): PlaywrightReportDiffCliArgs {
  const options = parseCliFlags(args, {
    baseInput: DEFAULT_BASE_INPUT,
    headInput: DEFAULT_HEAD_INPUT,
  } as PlaywrightReportDiffCliArgs, {
    usage,
    handlers: {
      "--base": {
        set: (target, value) => {
          target.baseInput = value ?? "";
        },
      },
      "--head": {
        set: (target, value) => {
          target.headInput = value ?? "";
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
      select: (candidate) => candidate.baseInput,
      errorMessage: "--base is required",
    },
    {
      select: (candidate) => candidate.headInput,
      errorMessage: "--head is required",
    },
  ]);

  return options;
}

export function runPlaywrightReportDiffCli(
  args: string[],
  options?: {
    cwd?: string;
    readFile?: (targetPath: string) => string;
  },
): ScriptExecutionResult {
  try {
    const parsed = parsePlaywrightReportDiffArgs(args);
    const cwd = options?.cwd ?? process.cwd();
    const basePath = path.resolve(cwd, parsed.baseInput);
    const headPath = path.resolve(cwd, parsed.headInput);
    const readFile = options?.readFile ?? ((targetPath: string) => fs.readFileSync(targetPath, "utf8"));
    const base = JSON.parse(readFile(basePath)) as PlaywrightSummary;
    const head = JSON.parse(readFile(headPath)) as PlaywrightSummary;
    const diff = buildPlaywrightDiff(base, head, parsed.label ?? head.label);
    const markdown = renderPlaywrightDiffMarkdown(diff);
    const writes: ScriptExecutionResult["writes"] = [];
    appendReportWrites(writes, {
      cwd,
      markdownPath: parsed.markdownOutput,
      markdownContent: markdown,
      jsonPath: parsed.jsonOutput,
      jsonValue: diff,
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
  emitScriptExecutionResult(runPlaywrightReportDiffCli(process.argv.slice(2)));
}
