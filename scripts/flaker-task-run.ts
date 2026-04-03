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
  assertValidFlakerTaskRuntimeOptions,
  createFlakerTaskRuntimeDefaults,
  isMainModule,
  prepareFlakerTaskWorkspace,
  resolveDefaultFlakerCliPath,
  type FlakerTaskRuntimeCliArgs,
} from "./flaker-task-runtime.ts";
import {
  emitScriptExecutionResult,
  type ScriptExecutionResult,
} from "./script-runtime.ts";

export {
  prepareFlakerTaskWorkspace,
  resolveDefaultFlakerCliPath,
} from "./flaker-task-runtime.ts";

export interface FlakerTaskRunCliArgs extends FlakerTaskRuntimeCliArgs {
  flakerArgs: string[];
}

interface SpawnResult {
  status: number | null;
}

type SpawnFn = (
  command: string,
  args: string[],
  options: { cwd: string; stdio: "inherit" },
) => SpawnResult;

function usage(): string {
  return renderFlakerTaskUsage({
    summary: "Run flaker with a task-scoped config generated from flaker.star",
    command: "node scripts/flaker-task-run.ts --task <task-id> [options] -- <flaker args...>",
    defaultFlakerCliPath: resolveDefaultFlakerCliPath(process.cwd()),
  });
}

export function parseFlakerTaskRunArgs(args: string[]): FlakerTaskRunCliArgs {
  const { head, tail } = splitCliArgsOnSeparator(args);

  const options = parseFlakerTaskCliFlags(head, {
    ...createFlakerTaskRuntimeDefaults(process.cwd()),
    flakerArgs: tail,
  }, {
    usage,
  });

  assertValidFlakerTaskRuntimeOptions(options);
  if (options.flakerArgs.length === 0) {
    throw new Error("Provide flaker arguments after `--`, for example `-- sample --count 10`");
  }

  return options;
}

export function runFlakerTask(
  args: FlakerTaskRunCliArgs,
  options?: {
    spawn?: SpawnFn;
    repoRoot?: string;
    exists?: (targetPath: string) => boolean;
    warn?: (message: string) => void;
  },
): number {
  const repoRoot = options?.repoRoot ?? process.cwd();
  const configSource = fs.readFileSync(path.resolve(repoRoot, args.configPath), "utf8");
  const workspace = prepareFlakerTaskWorkspace(repoRoot, configSource, {
    taskId: args.taskId,
    owner: args.owner,
    repo: args.repo,
    manifestPath: args.manifestPath,
    workspaceRoot: args.workspaceRoot,
  });
  const exists = options?.exists ?? fs.existsSync;
  const warn = options?.warn ?? console.warn;
  const primaryCommand = args.flakerArgs[0];
  if ((primaryCommand === "sample" || primaryCommand === "run") && !exists(workspace.storagePath)) {
    warn(
      `No flaker metrics found at ${workspace.storagePath}. Seed it with \`just flaker task import ${args.taskId} <playwright-report.json>\` or \`just flaker task record ${args.taskId}\`.`,
    );
  }
  const spawnFn = options?.spawn ?? spawnSync;
  const result = spawnFn(process.execPath, [args.flakerCliPath, ...args.flakerArgs], {
    cwd: workspace.workspaceDir,
    stdio: "inherit",
  });
  return result.status ?? 1;
}

export function runFlakerTaskRunCli(
  args: string[],
  options?: {
    spawn?: SpawnFn;
    repoRoot?: string;
    exists?: (targetPath: string) => boolean;
    warn?: (message: string) => void;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseFlakerTaskRunArgs(args);
    const warnings: string[] = [];
    const exitCode = runFlakerTask(parsed, {
      ...options,
      warn: (message) => {
        warnings.push(`${message}\n`);
        options?.warn?.(message);
      },
    });
    return {
      exitCode,
      stderr: warnings.length > 0 ? warnings.join("") : undefined,
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
  emitScriptExecutionResult(runFlakerTaskRunCli(process.argv.slice(2)));
}
