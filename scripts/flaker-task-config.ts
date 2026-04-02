#!/usr/bin/env npx tsx

import fs from "node:fs";
import path from "node:path";
import {
  DEFAULT_CONFIG_PATH,
  DEFAULT_MANIFEST_PATH,
  DEFAULT_OWNER,
  DEFAULT_REPO,
} from "./flaker-defaults.ts";
import type { FlakerConfig, FlakerTask } from "./flaker-config-contract.ts";
import { parseFlakerStar } from "./flaker-config-parser.ts";
import {
  emitScriptExecutionResult,
  isMainModule,
  type ScriptExecutionResult,
} from "./script-runtime.ts";
import { assertRequiredOptions, parseCliFlags, renderUsage } from "./script-cli.ts";

export interface FlakerTaskConfigCliArgs {
  taskId: string;
  owner: string;
  repo: string;
  configPath: string;
  manifestPath: string;
  outputPath?: string;
}

interface BuildTaskConfigOptions {
  taskId: string;
  owner: string;
  repo: string;
  manifestPath: string;
  repoRoot?: string;
  absolutePaths?: boolean;
  storagePath?: string;
}

function usage(): string {
  return renderUsage({
    summary: "Generate flaker.toml for a crater task",
    command: "npx tsx scripts/flaker-task-config.ts --task <task-id> [options]",
    optionLines: [
      "  --task <id>        Task id from flaker.star",
      `  --config <file>    flaker.star path (default: ${DEFAULT_CONFIG_PATH})`,
      `  --owner <owner>    GitHub owner (default: ${DEFAULT_OWNER})`,
      `  --repo <name>      GitHub repo name (default: ${DEFAULT_REPO})`,
      `  --manifest <file>  quarantine manifest path (default: ${DEFAULT_MANIFEST_PATH})`,
      "  --write <file>     Write TOML to file instead of stdout",
    ],
    helpLine: "  --help             Show this help",
  });
}

export function parseFlakerTaskConfigArgs(args: string[]): FlakerTaskConfigCliArgs {
  const options = parseCliFlags(args, {
    taskId: "",
    owner: DEFAULT_OWNER,
    repo: DEFAULT_REPO,
    configPath: DEFAULT_CONFIG_PATH,
    manifestPath: DEFAULT_MANIFEST_PATH,
  }, {
    usage,
    handlers: {
      "--task": {
        set: (target, value) => {
          target.taskId = value ?? "";
        },
      },
      "--config": {
        set: (target, value) => {
          target.configPath = value ?? "";
        },
      },
      "--owner": {
        set: (target, value) => {
          target.owner = value ?? "";
        },
      },
      "--repo": {
        set: (target, value) => {
          target.repo = value ?? "";
        },
      },
      "--manifest": {
        set: (target, value) => {
          target.manifestPath = value ?? "";
        },
      },
      "--write": {
        set: (target, value) => {
          target.outputPath = value;
        },
      },
    },
  });

  assertRequiredOptions(options, [
    {
      select: (candidate) => candidate.taskId,
      errorMessage: "--task is required",
    },
    {
      select: (candidate) => candidate.owner,
      errorMessage: "--owner requires a value",
    },
    {
      select: (candidate) => candidate.repo,
      errorMessage: "--repo requires a value",
    },
    {
      select: (candidate) => candidate.configPath,
      errorMessage: "--config requires a file path",
    },
    {
      select: (candidate) => candidate.manifestPath,
      errorMessage: "--manifest requires a file path",
    },
  ]);

  return options;
}

function tomlEscape(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

function shellEscape(arg: string): string {
  if (/^[A-Za-z0-9_./:-]+$/.test(arg)) {
    return arg;
  }
  return `'${arg.replace(/'/g, `'\\''`)}'`;
}

function toShellCommand(cmd: string[]): string {
  return cmd.map((part) => shellEscape(part)).join(" ");
}

export function resolveFlakerTaskRunnerType(task: FlakerTask): "playwright" {
  if (
    task.cmd.length >= 4
    && task.cmd[0] === "pnpm"
    && task.cmd[1] === "exec"
    && task.cmd[2] === "playwright"
    && task.cmd[3] === "test"
  ) {
    return "playwright";
  }
  throw new Error(`Task ${task.id} is not a Playwright task`);
}

export function findFlakerTask(config: FlakerConfig, taskId: string): FlakerTask {
  const task = config.tasks.find((candidate) => candidate.id === taskId);
  if (!task) {
    throw new Error(`Unknown flaker task: ${taskId}`);
  }
  return task;
}

export function buildFlakerTaskCommand(
  task: FlakerTask,
  options?: {
    repoRoot?: string;
    absolutePaths?: boolean;
    extraArgs?: string[];
  },
): string[] {
  resolveFlakerTaskRunnerType(task);
  const repoRoot = options?.repoRoot ?? process.cwd();
  const baseCommand = options?.absolutePaths
    ? [
        "pnpm",
        "--dir",
        repoRoot,
        ...task.cmd.slice(1),
      ]
    : [...task.cmd];
  if (options?.extraArgs?.length) {
    baseCommand.push(...options.extraArgs);
  }
  return baseCommand;
}

export function buildFlakerTaskConfigToml(
  config: FlakerConfig,
  options: BuildTaskConfigOptions,
): string {
  const task = findFlakerTask(config, options.taskId);
  const runnerType = resolveFlakerTaskRunnerType(task);
  const repoRoot = options.repoRoot ?? process.cwd();
  const commandParts = buildFlakerTaskCommand(task, {
    repoRoot,
    absolutePaths: options.absolutePaths,
  });
  const runnerCommand = toShellCommand(commandParts);
  const storagePath = options.storagePath
    ?? (options.absolutePaths
      ? path.join(repoRoot, ".flaker", "data")
      : ".flaker/data");
  const manifestPath = options.absolutePaths
    ? path.resolve(repoRoot, options.manifestPath)
    : options.manifestPath;

  return [
    "[repo]",
    `owner = "${tomlEscape(options.owner)}"`,
    `name = "${tomlEscape(options.repo)}"`,
    "",
    "[storage]",
    `path = "${tomlEscape(storagePath)}"`,
    "",
    "[adapter]",
    `type = "${runnerType}"`,
    "",
    "[runner]",
    `type = "${runnerType}"`,
    `command = "${tomlEscape(runnerCommand)}"`,
    "",
    "[affected]",
    'resolver = "git"',
    'config = ""',
    "",
    "[quarantine]",
    "auto = true",
    "flaky_rate_threshold = 0.3",
    "min_runs = 5",
    `manifest = "${tomlEscape(manifestPath)}"`,
    `task_id = "${tomlEscape(task.id)}"`,
    "runtime_apply = true",
    "",
    "[flaky]",
    "window_days = 14",
    "detection_threshold = 0.1",
    "",
  ].join("\n");
}

export function runFlakerTaskConfigCli(
  args: string[],
  options?: {
    repoRoot?: string;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseFlakerTaskConfigArgs(args);
    const repoRoot = options?.repoRoot ?? process.cwd();
    const source = fs.readFileSync(path.resolve(repoRoot, parsed.configPath), "utf8");
    const toml = buildFlakerTaskConfigToml(parseFlakerStar(source), {
      taskId: parsed.taskId,
      owner: parsed.owner,
      repo: parsed.repo,
      manifestPath: parsed.manifestPath,
      repoRoot,
    });

    return {
      exitCode: 0,
      stdout: parsed.outputPath ? undefined : toml,
      writes: parsed.outputPath
        ? [{
            path: path.resolve(repoRoot, parsed.outputPath),
            content: toml,
          }]
        : [],
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
  emitScriptExecutionResult(runFlakerTaskConfigCli(process.argv.slice(2)));
}
