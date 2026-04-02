#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import {
  parseFlakerTaskCliFlags,
  renderFlakerTaskUsage,
  splitCliArgsOnSeparator,
} from "./flaker-task-cli.ts";
import {
  buildFlakerTaskRecordArtifacts,
} from "./flaker-task-record-artifacts.ts";
import {
  buildFlakerTaskRecordImportArgs,
  executeFlakerTaskRecordPlan,
  runFlakerTaskRecordImport,
  type FlakerTaskRecordGitMetadata,
} from "./flaker-task-record-execution.ts";
import {
  prepareFlakerTaskRecordPlan,
  type FlakerTaskRecordPlanArgs,
} from "./flaker-task-record-plan.ts";
import {
  assertValidFlakerTaskRuntimeOptions,
  createSpawnTextOptions,
  createFlakerTaskRuntimeDefaults,
  isMainModule,
  readText,
  resolveDefaultFlakerCliPath,
  type SpawnTextFn,
  writeOutput,
} from "./flaker-task-runtime.ts";
import {
  emitScriptExecutionResult,
  type ScriptExecutionResult,
} from "./script-runtime.ts";
import type { FlakerTaskRunCliArgs } from "./flaker-task-run.ts";

export interface FlakerTaskRecordCliArgs extends FlakerTaskRecordPlanArgs {
  commitSha?: string;
  branch?: string;
}
export type { FlakerTaskRecordPlanArgs };
export { buildFlakerTaskRecordImportArgs } from "./flaker-task-record-execution.ts";

export interface FlakerTaskRecordResult {
  taskId: string;
  exitCode: number;
  taskExitCode: number;
  importExitCode: number;
  reportPath: string;
  summaryJsonPath?: string;
  summaryMarkdownPath?: string;
  workspaceDir: string;
  taskCommand: string[];
}

function renderFlakerTaskRecordResult(result: FlakerTaskRecordResult): string {
  const lines = [
    `task: ${result.taskId}`,
    `task_exit: ${result.taskExitCode}`,
    `import_exit: ${result.importExitCode}`,
    `report_path: ${result.reportPath}`,
    `workspace_dir: ${result.workspaceDir}`,
  ];
  if (result.summaryJsonPath) {
    lines.push(`summary_json: ${result.summaryJsonPath}`);
  }
  if (result.summaryMarkdownPath) {
    lines.push(`summary_markdown: ${result.summaryMarkdownPath}`);
  }
  return `${lines.join("\n")}\n`;
}

function usage(): string {
  return renderFlakerTaskUsage({
    summary:
      "Run a Playwright task from flaker.star, persist the JSON report, and import it into flaker",
    command:
      "node scripts/flaker-task-record.ts --task <task-id> [options] -- [extra playwright args...]",
    defaultFlakerCliPath: resolveDefaultFlakerCliPath(process.cwd()),
    extraOptions: [
      "  --commit <sha>         Commit SHA recorded in flaker import",
      "  --branch <name>        Branch name recorded in flaker import",
      "  --report-path <file>   Persist raw Playwright JSON report to this path",
      "  --summary-dir <dir>    Persist normalized summary JSON/Markdown to this directory",
    ],
  });
}

export function parseFlakerTaskRecordArgs(args: string[]): FlakerTaskRecordCliArgs {
  const { head, tail } = splitCliArgsOnSeparator(args);

  const options = parseFlakerTaskCliFlags(head, {
    ...createFlakerTaskRuntimeDefaults(process.cwd()),
    taskArgs: tail,
  }, {
    usage,
    extraHandlers: {
      "--commit": {
        set: (target, value) => {
          target.commitSha = value;
        },
      },
      "--branch": {
        set: (target, value) => {
          target.branch = value;
        },
      },
      "--report-path": {
        set: (target, value) => {
          target.reportPath = value;
        },
      },
      "--summary-dir": {
        set: (target, value) => {
          target.summaryDir = value;
        },
      },
    },
  });

  assertValidFlakerTaskRuntimeOptions(options);

  return options;
}

export function detectGitMetadata(
  repoRoot: string,
  spawnText: SpawnTextFn = spawnSync,
): FlakerTaskRecordGitMetadata {
  const runGit = (gitArgs: string[]): string | undefined => {
    const result = spawnText("git", gitArgs, createSpawnTextOptions(repoRoot, 1024 * 1024));
    if ((result.status ?? 1) !== 0) {
      return undefined;
    }
    const text = readText(result.stdout).trim();
    return text.length > 0 ? text : undefined;
  };

  return {
    commitSha: runGit(["rev-parse", "HEAD"]),
    branch: runGit(["branch", "--show-current"]),
  };
}

export function recordFlakerTask(
  args: FlakerTaskRecordCliArgs,
  options?: {
    repoRoot?: string;
    spawnTask?: SpawnTextFn;
    detectGitMetadata?: (repoRoot: string) => FlakerTaskRecordGitMetadata;
    importTaskRun?: (
      importArgs: FlakerTaskRunCliArgs,
      runOptions: { repoRoot: string; exists: (targetPath: string) => boolean },
    ) => number;
  },
): FlakerTaskRecordResult {
  const repoRoot = options?.repoRoot ?? process.cwd();
  const plan = prepareFlakerTaskRecordPlan(args, repoRoot);
  const execution = executeFlakerTaskRecordPlan(plan, {
    spawnTask: options?.spawnTask,
  });
  const artifacts = buildFlakerTaskRecordArtifacts(
    repoRoot,
    args.taskId,
    plan.paths,
    execution.reportText,
    execution.stderrText,
  );
  for (const output of artifacts.writes) {
    writeOutput(output.path, output.content);
  }

  const gitMetadata = options?.detectGitMetadata?.(repoRoot) ?? detectGitMetadata(repoRoot);
  const importResult = runFlakerTaskRecordImport(args, plan.paths.reportPath, gitMetadata, {
    repoRoot,
    importTaskRun: options?.importTaskRun,
  });

  const taskExitCode = execution.taskExitCode;
  return {
    taskId: args.taskId,
    exitCode: taskExitCode !== 0 ? taskExitCode : importResult.exitCode,
    taskExitCode,
    importExitCode: importResult.exitCode,
    reportPath: plan.paths.reportPath,
    summaryJsonPath: artifacts.summaryJsonPath,
    summaryMarkdownPath: artifacts.summaryMarkdownPath,
    workspaceDir: plan.workspace.workspaceDir,
    taskCommand: plan.taskCommand,
  };
}

export function runFlakerTaskRecordCli(
  args: string[],
  options?: {
    repoRoot?: string;
    spawnTask?: SpawnTextFn;
    detectGitMetadata?: (repoRoot: string) => FlakerTaskRecordGitMetadata;
    importTaskRun?: (
      importArgs: FlakerTaskRunCliArgs,
      runOptions: { repoRoot: string; exists: (targetPath: string) => boolean },
    ) => number;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseFlakerTaskRecordArgs(args);
    const result = recordFlakerTask(parsed, options);
    return {
      exitCode: result.exitCode,
      stdout: renderFlakerTaskRecordResult(result),
      writes: [],
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
  emitScriptExecutionResult(runFlakerTaskRecordCli(process.argv.slice(2)));
}
