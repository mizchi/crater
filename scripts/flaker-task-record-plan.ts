import fs from "node:fs";
import path from "node:path";
import { parseFlakerStar } from "./flaker-config-parser.ts";
import {
  buildFlakerTaskCommand,
  findFlakerTask,
} from "./flaker-task-config.ts";
import {
  resolveFlakerTaskRecordPaths,
  type FlakerTaskRecordPaths,
} from "./flaker-task-record-artifacts.ts";
import {
  prepareFlakerTaskWorkspace,
  type FlakerTaskRuntimeCliArgs,
  type PreparedFlakerTaskWorkspace,
} from "./flaker-task-runtime.ts";
import type { FlakerTaskRunCliArgs } from "./flaker-task-run.ts";

export interface FlakerTaskRecordPlanArgs extends FlakerTaskRuntimeCliArgs {
  reportPath?: string;
  summaryDir?: string;
  taskArgs: string[];
}

export interface FlakerTaskRecordPlan {
  repoRoot: string;
  taskId: string;
  workspace: PreparedFlakerTaskWorkspace;
  paths: FlakerTaskRecordPaths;
  taskCommand: string[];
}

export function prepareFlakerTaskRecordPlan(
  args: FlakerTaskRecordPlanArgs,
  repoRoot = process.cwd(),
): FlakerTaskRecordPlan {
  const configSource = fs.readFileSync(path.resolve(repoRoot, args.configPath), "utf8");
  const config = parseFlakerStar(configSource);
  const task = findFlakerTask(config, args.taskId);
  const workspace = prepareFlakerTaskWorkspace(repoRoot, configSource, {
    taskId: args.taskId,
    owner: args.owner,
    repo: args.repo,
    manifestPath: args.manifestPath,
    workspaceRoot: args.workspaceRoot,
  });
  const paths = resolveFlakerTaskRecordPaths(repoRoot, args.taskId, workspace.workspaceDir, {
    reportPath: args.reportPath,
    summaryDir: args.summaryDir,
  });
  const taskCommand = buildFlakerTaskCommand(task, {
    repoRoot,
    absolutePaths: true,
    extraArgs: [...args.taskArgs, "--reporter", "json"],
  });

  return {
    repoRoot,
    taskId: args.taskId,
    workspace,
    paths,
    taskCommand,
  };
}

export function buildFlakerTaskRecordImportRunArgs(
  args: FlakerTaskRecordPlanArgs,
  importArgs: string[],
): FlakerTaskRunCliArgs {
  return {
    taskId: args.taskId,
    owner: args.owner,
    repo: args.repo,
    configPath: args.configPath,
    manifestPath: args.manifestPath,
    workspaceRoot: args.workspaceRoot,
    flakerCliPath: args.flakerCliPath,
    flakerArgs: importArgs,
  };
}
