#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
export * from "./flaker-task-summary-contract.ts";
import {
  parseFlakerTaskCliFlags,
  renderFlakerTaskUsage,
  splitCliArgsOnSeparator,
} from "./flaker-task-cli.ts";
import { createReportOutputHandlers } from "./script-cli.ts";
import {
  assertValidFlakerTaskRuntimeOptions,
  createFlakerTaskRuntimeDefaults,
  isMainModule,
  prepareFlakerTaskWorkspace,
  resolveDefaultFlakerCliPath,
  runJsonTextCommand,
  type SpawnTextFn,
  type FlakerTaskRuntimeCliArgs,
} from "./flaker-task-runtime.ts";
import {
  appendReportWrites,
  emitScriptExecutionResult,
  type ScriptExecutionResult,
} from "./script-runtime.ts";
import type {
  FlakerEvalReport,
  FlakerReasonReport,
  FlakerTaskSummaryReport,
} from "./flaker-task-summary-contract.ts";
import {
  buildFlakerTaskSummaryReport,
  renderFlakerTaskSummaryMarkdown,
} from "./flaker-task-summary-core.ts";

export {
  buildFlakerTaskSummaryReport,
  renderFlakerTaskSummaryMarkdown,
} from "./flaker-task-summary-core.ts";

export interface FlakerTaskSummaryCliArgs extends FlakerTaskRuntimeCliArgs {
  jsonOutput?: string;
  markdownOutput?: string;
}

function usage(): string {
  return renderFlakerTaskUsage({
    summary: "Render task-scoped flaker eval/reason summary",
    command: "node scripts/flaker-task-summary.ts --task <task-id> [options]",
    defaultFlakerCliPath: resolveDefaultFlakerCliPath(process.cwd()),
    extraOptions: [
      "  --json <file>       Write JSON summary",
      "  --markdown <file>   Write markdown summary",
    ],
  });
}

export function parseFlakerTaskSummaryArgs(args: string[]): FlakerTaskSummaryCliArgs {
  const { head } = splitCliArgsOnSeparator(args);
  const options = parseFlakerTaskCliFlags(head, {
    ...createFlakerTaskRuntimeDefaults(process.cwd()),
  }, {
    usage,
    extraHandlers: {
      ...createReportOutputHandlers(),
    },
  });

  assertValidFlakerTaskRuntimeOptions(options);

  return options;
}

function runFlakerJsonCommand(
  workspaceDir: string,
  flakerCliPath: string,
  args: string[],
  spawnText: SpawnTextFn,
): unknown {
  return runJsonTextCommand(process.execPath, [flakerCliPath, ...args], {
    cwd: workspaceDir,
    maxBuffer: 16 * 1024 * 1024,
    commandLabel: `flaker ${args[0]}`,
    spawnText,
  });
}

export function collectFlakerTaskSummary(
  args: FlakerTaskSummaryCliArgs,
  options?: {
    repoRoot?: string;
    spawnText?: SpawnTextFn;
  },
): FlakerTaskSummaryReport {
  const repoRoot = options?.repoRoot ?? process.cwd();
  const configSource = fs.readFileSync(path.resolve(repoRoot, args.configPath), "utf8");
  const workspace = prepareFlakerTaskWorkspace(repoRoot, configSource, {
    taskId: args.taskId,
    owner: args.owner,
    repo: args.repo,
    manifestPath: args.manifestPath,
    workspaceRoot: args.workspaceRoot,
  });
  const spawnText = options?.spawnText ?? spawnSync;
  const evalReport = runFlakerJsonCommand(
    workspace.workspaceDir,
    args.flakerCliPath,
    ["eval", "--json"],
    spawnText,
  ) as FlakerEvalReport;
  const reasonReport = runFlakerJsonCommand(
    workspace.workspaceDir,
    args.flakerCliPath,
    ["reason", "--json"],
    spawnText,
  ) as FlakerReasonReport;

  return buildFlakerTaskSummaryReport({
    taskId: args.taskId,
    workspaceDir: workspace.workspaceDir,
    eval: evalReport,
    reason: reasonReport,
  });
}

export function runFlakerTaskSummaryCli(
  args: string[],
  options?: {
    repoRoot?: string;
    spawnText?: SpawnTextFn;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseFlakerTaskSummaryArgs(args);
    const repoRoot = options?.repoRoot ?? process.cwd();
    const summary = collectFlakerTaskSummary(parsed, {
      repoRoot,
      spawnText: options?.spawnText,
    });
    const markdown = renderFlakerTaskSummaryMarkdown(summary);
    const writes: ScriptExecutionResult["writes"] = [];
    appendReportWrites(writes, {
      cwd: repoRoot,
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
  emitScriptExecutionResult(runFlakerTaskSummaryCli(process.argv.slice(2)));
}
