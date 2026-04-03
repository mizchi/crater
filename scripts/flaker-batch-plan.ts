#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import {
  buildFlakerBatchPlan,
  renderFlakerBatchPlanMarkdown,
  renderGitHubMatrix,
} from "./flaker-batch-plan-core.ts";
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

export interface FlakerBatchPlanCliArgs {
  configPath: string;
  tasks?: string[];
  nodes?: string[];
  jsonOutput?: string;
  markdownOutput?: string;
  githubMatrix: boolean;
}

export * from "./flaker-batch-plan-core.ts";

function usage(): string {
  return renderUsage({
    summary: "Render flaker batch execution plan",
    command: "node scripts/flaker-batch-plan.ts [options]",
    optionLines: [
      `  --config <file>      flaker.star path (default: ${DEFAULT_CONFIG_PATH})`,
      "  --tasks <ids>        Comma-separated task ids to include",
      "  --nodes <ids>        Comma-separated node ids to include",
      "  --json <file>        Write JSON plan",
      "  --markdown <file>    Write Markdown plan",
      "  --github-matrix      Print GitHub Actions matrix JSON to stdout",
    ],
    helpLine: "  --help               Show this help",
  });
}

function parseCsv(value: string | undefined): string[] | undefined {
  if (!value) {
    return undefined;
  }
  const items = value.split(",").map((item) => item.trim()).filter(Boolean);
  return items.length > 0 ? items : undefined;
}

export function parseFlakerBatchPlanArgs(args: string[]): FlakerBatchPlanCliArgs {
  const options = parseCliFlags(args, {
    configPath: DEFAULT_CONFIG_PATH,
    githubMatrix: false,
  }, {
    usage,
    handlers: {
      "--config": {
        set: (target, value) => {
          target.configPath = value ?? "";
        },
      },
      "--tasks": {
        set: (target, value) => {
          target.tasks = parseCsv(value);
        },
      },
      "--nodes": {
        set: (target, value) => {
          target.nodes = parseCsv(value);
        },
      },
      ...createReportOutputHandlers(),
      "--github-matrix": createBooleanFlagHandler((target) => {
        target.githubMatrix = true;
      }),
    },
  });

  assertRequiredOptions(options, [
    {
      select: (candidate) => candidate.configPath,
      errorMessage: "--config requires a file path",
    },
  ]);

  return options;
}

export function runFlakerBatchPlanCli(
  args: string[],
  options?: {
    cwd?: string;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseFlakerBatchPlanArgs(args);
    const cwd = options?.cwd ?? process.cwd();
    const writes: ScriptExecutionResult["writes"] = [];
    const source = fs.readFileSync(path.resolve(cwd, parsed.configPath), "utf8");
    const plan = buildFlakerBatchPlan(source, {
      tasks: parsed.tasks,
      nodes: parsed.nodes,
    });
    const markdown = renderFlakerBatchPlanMarkdown(plan);
    appendReportWrites(writes, {
      cwd,
      markdownPath: parsed.markdownOutput,
      markdownContent: markdown,
      jsonPath: parsed.jsonOutput,
      jsonValue: plan,
    });

    return {
      exitCode: 0,
      stdout: parsed.githubMatrix ? renderGitHubMatrix(plan) : markdown,
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
  emitScriptExecutionResult(runFlakerBatchPlanCli(process.argv.slice(2)));
}
