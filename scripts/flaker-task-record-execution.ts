import { spawnSync } from "node:child_process";
import {
  createSpawnTextOptions,
  readText,
  type SpawnTextFn,
} from "./flaker-task-runtime.ts";
import {
  buildFlakerTaskRecordImportRunArgs,
  type FlakerTaskRecordPlan,
  type FlakerTaskRecordPlanArgs,
} from "./flaker-task-record-plan.ts";
import { runFlakerTask, type FlakerTaskRunCliArgs } from "./flaker-task-run.ts";

const DEFAULT_MAX_OUTPUT_BUFFER = 64 * 1024 * 1024;

export interface FlakerTaskRecordGitMetadata {
  commitSha?: string;
  branch?: string;
}

export interface FlakerTaskRecordImportCliArgs extends FlakerTaskRecordPlanArgs {
  commitSha?: string;
  branch?: string;
}

export interface ExecutedFlakerTaskRecordPlan {
  taskExitCode: number;
  reportText: string;
  stderrText: string;
}

export interface FlakerTaskRecordImportResult {
  exitCode: number;
  importArgs: string[];
}

export function executeFlakerTaskRecordPlan(
  plan: FlakerTaskRecordPlan,
  options?: {
    spawnTask?: SpawnTextFn;
    maxBuffer?: number;
  },
): ExecutedFlakerTaskRecordPlan {
  const spawnTask = options?.spawnTask ?? spawnSync;
  const taskResult = spawnTask(
    plan.taskCommand[0]!,
    plan.taskCommand.slice(1),
    createSpawnTextOptions(plan.repoRoot, options?.maxBuffer ?? DEFAULT_MAX_OUTPUT_BUFFER),
  );
  if (taskResult.error) {
    throw taskResult.error;
  }

  return {
    taskExitCode: taskResult.status ?? 1,
    reportText: readText(taskResult.stdout),
    stderrText: readText(taskResult.stderr),
  };
}

export function buildFlakerTaskRecordImportArgs(
  reportPath: string,
  args: {
    commitSha?: string;
    branch?: string;
  },
  gitMetadata: FlakerTaskRecordGitMetadata,
): string[] {
  const importArgs = ["import", reportPath, "--adapter", "playwright"];
  if (args.commitSha ?? gitMetadata.commitSha) {
    importArgs.push("--commit", args.commitSha ?? gitMetadata.commitSha ?? "");
  }
  if (args.branch ?? gitMetadata.branch) {
    importArgs.push("--branch", args.branch ?? gitMetadata.branch ?? "");
  }
  return importArgs;
}

export function runFlakerTaskRecordImport(
  args: FlakerTaskRecordImportCliArgs,
  reportPath: string,
  gitMetadata: FlakerTaskRecordGitMetadata,
  options?: {
    repoRoot?: string;
    importTaskRun?: (
      importArgs: FlakerTaskRunCliArgs,
      runOptions: { repoRoot: string; exists: (targetPath: string) => boolean },
    ) => number;
  },
): FlakerTaskRecordImportResult {
  const repoRoot = options?.repoRoot ?? process.cwd();
  const importArgs = buildFlakerTaskRecordImportArgs(reportPath, args, gitMetadata);
  const importTaskRun = options?.importTaskRun ?? runFlakerTask;
  const exitCode = importTaskRun(
    buildFlakerTaskRecordImportRunArgs(args, importArgs),
    {
      repoRoot,
      exists: () => true,
    },
  );

  return {
    exitCode,
    importArgs,
  };
}
