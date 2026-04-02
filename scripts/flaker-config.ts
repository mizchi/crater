#!/usr/bin/env npx tsx

import fs from "node:fs";
import path from "node:path";
export * from "./flaker-config-contract.ts";
import type { FlakerConfig } from "./flaker-config-contract.ts";
import { parseFlakerStar } from "./flaker-config-parser.ts";
import {
  renderAffectedTaskList,
  renderAffectedTasksMarkdown,
  renderMarkdownSummary,
  renderTaskList,
} from "./flaker-config-report.ts";
import { selectAffectedTasks } from "./flaker-config-selection.ts";
import { summarizeFlakerConfig } from "./flaker-config-summary.ts";
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

const DEFAULT_CONFIG_PATH = "flaker.star";
const DEFAULT_TESTS_DIR = "tests";

interface CliOptions {
  configPath: string;
  testsDir: string;
  jsonOutput?: string;
  markdownOutput?: string;
  check: boolean;
  listOnly: boolean;
  selectMode: boolean;
  changedPaths: string[];
}

function usage(): string {
  return renderUsage({
    summary: "Flaker config summary",
    command: "npx tsx scripts/flaker-config.ts [options]",
    optionLines: [
      `  --config <file>      flaker.star path (default: ${DEFAULT_CONFIG_PATH})`,
      `  --tests-dir <dir>    Playwright tests directory (default: ${DEFAULT_TESTS_DIR})`,
      "  --json <file>        Write JSON summary",
      "  --markdown <file>    Write Markdown summary",
      "  --check              Exit non-zero when validation errors exist",
      "  --list               Print managed task ids and resolved specs",
      "  --select <paths...>  Print affected tasks for changed repo paths",
    ],
    helpLine: "  --help               Show this help",
  });
}

export function parseFlakerConfigArgs(args: string[]): CliOptions {
  const selectIndex = args.indexOf("--select");
  const head = selectIndex >= 0 ? args.slice(0, selectIndex + 1) : args;
  const changedPaths = selectIndex >= 0 ? args.slice(selectIndex + 1) : [];

  const options = parseCliFlags(head, {
    configPath: DEFAULT_CONFIG_PATH,
    testsDir: DEFAULT_TESTS_DIR,
    check: false,
    listOnly: false,
    selectMode: false,
    changedPaths: [],
  }, {
    usage,
    handlers: {
      "--config": {
        set: (target, value) => {
          target.configPath = value ?? "";
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
      "--list": createBooleanFlagHandler((target) => {
        target.listOnly = true;
      }),
      "--select": createBooleanFlagHandler((target) => {
          target.selectMode = true;
          target.changedPaths = [...changedPaths];
      }),
    },
  });

  assertRequiredOptions(options, [
    {
      select: (candidate) => candidate.configPath,
      errorMessage: "--config requires a file path",
    },
    {
      select: (candidate) => candidate.testsDir,
      errorMessage: "--tests-dir requires a directory path",
    },
  ]);
  if (options.selectMode && options.changedPaths.length === 0) {
    throw new Error("--select requires at least one changed path");
  }

  return options;
}
export { parseFlakerStar } from "./flaker-config-parser.ts";
export {
  discoverPlaywrightSpecs,
  loadFlakerConfigSummaryInputs,
  summarizeFlakerConfig,
} from "./flaker-config-summary.ts";
export {
  buildFlakerSelection,
  loadFlakerSelectionInputs,
  normalizeFlakerSelectionPath,
  selectAffectedTasks,
} from "./flaker-config-selection.ts";

export function runFlakerConfigCli(
  args: string[],
  options?: {
    cwd?: string;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseFlakerConfigArgs(args);
    const cwd = options?.cwd ?? process.cwd();
    const writes: ScriptExecutionResult["writes"] = [];
    const configSource = fs.readFileSync(path.resolve(cwd, parsed.configPath), "utf8");
    const config = parseFlakerStar(configSource);
    const summary = summarizeFlakerConfig(config, {
      cwd,
      testsDir: parsed.testsDir,
    });

    if (parsed.selectMode) {
      const selection = selectAffectedTasks(config, parsed.changedPaths, cwd);
      const stdout = renderAffectedTaskList(selection);
      appendReportWrites(writes, {
        cwd,
        markdownPath: parsed.markdownOutput,
        markdownContent: renderAffectedTasksMarkdown(selection),
        jsonPath: parsed.jsonOutput,
        jsonValue: selection,
      });
      return {
        exitCode: parsed.check && summary.errors.length > 0 ? 1 : 0,
        stdout,
        writes,
      };
    }

    if (parsed.listOnly) {
      return {
        exitCode: parsed.check && summary.errors.length > 0 ? 1 : 0,
        stdout: renderTaskList(summary),
        writes,
      };
    }

    {
      const markdown = renderMarkdownSummary(summary);
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
    }
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
  emitScriptExecutionResult(runFlakerConfigCli(process.argv.slice(2)));
}
