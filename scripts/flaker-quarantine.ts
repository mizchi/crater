#!/usr/bin/env npx tsx

import fs from "node:fs";
import path from "node:path";
export * from "./flaker-quarantine-contract.ts";
import type { FlakerIssue } from "./flaker-config-contract.ts";
import { parseFlakerStar } from "./flaker-config-parser.ts";
import {
  type FlakerQuarantineConfig,
  type FlakerQuarantineSummary,
} from "./flaker-quarantine-contract.ts";
import { parseFlakerQuarantine } from "./flaker-quarantine-parser.ts";
import { renderQuarantineMarkdown } from "./flaker-quarantine-report.ts";
import {
  loadFlakerQuarantineSummaryInputs,
  summarizeFlakerQuarantine,
} from "./flaker-quarantine-summary.ts";
import { findMatchingQuarantine } from "./flaker-quarantine-match.ts";
import {
  assertRequiredOptions,
  createBooleanFlagHandler,
  createReportOutputHandlers,
  parseCliFlags,
  renderUsage,
} from "./script-cli.ts";
import {
  appendReportWrites,
  emitScriptExecutionResult,
  isMainModule,
  type ScriptExecutionResult,
} from "./script-runtime.ts";

const DEFAULT_QUARANTINE_PATH = "flaker-quarantine.json";
const DEFAULT_FLAKER_CONFIG_PATH = "flaker.star";
const DEFAULT_TESTS_DIR = "tests";

interface CliOptions {
  quarantinePath: string;
  flakerConfigPath: string;
  testsDir: string;
  jsonOutput?: string;
  markdownOutput?: string;
  check: boolean;
}

function usage(): string {
  return renderUsage({
    summary: "Flaker quarantine summary",
    command: "npx tsx scripts/flaker-quarantine.ts [options]",
    optionLines: [
      `  --config <file>         quarantine manifest path (default: ${DEFAULT_QUARANTINE_PATH})`,
      `  --flaker-config <file> flaker.star path (default: ${DEFAULT_FLAKER_CONFIG_PATH})`,
      `  --tests-dir <dir>      Playwright tests directory (default: ${DEFAULT_TESTS_DIR})`,
      "  --json <file>          Write JSON summary",
      "  --markdown <file>      Write Markdown summary",
      "  --check                Exit non-zero when validation errors exist",
    ],
    helpLine: "  --help                 Show this help",
  });
}

export function parseFlakerQuarantineArgs(args: string[]): CliOptions {
  const options = parseCliFlags(args, {
    quarantinePath: DEFAULT_QUARANTINE_PATH,
    flakerConfigPath: DEFAULT_FLAKER_CONFIG_PATH,
    testsDir: DEFAULT_TESTS_DIR,
    check: false,
  }, {
    usage,
    handlers: {
      "--config": {
        set: (target, value) => {
          target.quarantinePath = value ?? "";
        },
      },
      "--flaker-config": {
        set: (target, value) => {
          target.flakerConfigPath = value ?? "";
        },
      },
      "--tests-dir": {
        set: (target, value) => {
          target.testsDir = value ?? "";
        },
      },
      ...createReportOutputHandlers(),
      "--check": createBooleanFlagHandler((target) => {
        target.check = true;
      }),
    },
  });

  assertRequiredOptions(options, [
    {
      select: (candidate) => candidate.quarantinePath,
      errorMessage: "--config requires a file path",
    },
    {
      select: (candidate) => candidate.flakerConfigPath,
      errorMessage: "--flaker-config requires a file path",
    },
    {
      select: (candidate) => candidate.testsDir,
      errorMessage: "--tests-dir requires a directory path",
    },
  ]);

  return options;
}

export { parseFlakerQuarantine } from "./flaker-quarantine-parser.ts";
export { renderQuarantineMarkdown } from "./flaker-quarantine-report.ts";
export { findMatchingQuarantine } from "./flaker-quarantine-match.ts";
export { loadFlakerQuarantineSummaryInputs } from "./flaker-quarantine-summary.ts";
export { summarizeFlakerQuarantine } from "./flaker-quarantine-summary.ts";

export function runFlakerQuarantineCli(
  args: string[],
  options?: {
    cwd?: string;
    now?: Date;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseFlakerQuarantineArgs(args);
    const cwd = options?.cwd ?? process.cwd();
    const writes: ScriptExecutionResult["writes"] = [];
    const flakerConfig = parseFlakerStar(
      fs.readFileSync(path.resolve(cwd, parsed.flakerConfigPath), "utf8"),
    );
    const quarantine = parseFlakerQuarantine(
      fs.readFileSync(path.resolve(cwd, parsed.quarantinePath), "utf8"),
    );
    const summary = summarizeFlakerQuarantine(quarantine, flakerConfig, {
      cwd,
      testsDir: parsed.testsDir,
      now: options?.now,
    });
    const markdown = renderQuarantineMarkdown(summary);
    appendReportWrites(writes, {
      cwd,
      markdownPath: parsed.markdownOutput,
      markdownContent: markdown,
      jsonPath: parsed.jsonOutput,
      jsonValue: summary,
    });
    return {
      exitCode: parsed.check && summary.errors.length > 0 ? 1 : 0,
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
  emitScriptExecutionResult(runFlakerQuarantineCli(process.argv.slice(2)));
}
