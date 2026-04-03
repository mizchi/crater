import fs from "node:fs";
import path from "node:path";
import {
  DEFAULT_CONFIG_PATH,
  DEFAULT_MANIFEST_PATH,
  DEFAULT_OWNER,
  DEFAULT_REPO,
  DEFAULT_WORKSPACE_ROOT,
} from "./flaker-defaults.ts";
import { resolveFlakerCliPath } from "./flaker-cli-path.ts";
import { parseFlakerStar } from "./flaker-config-parser.ts";
import { buildFlakerTaskConfigToml } from "./flaker-task-config.ts";
import { assertRequiredOptions } from "./script-cli.ts";
export { isMainModule, writeOutput } from "./script-runtime.ts";
export {
  DEFAULT_CONFIG_PATH,
  DEFAULT_MANIFEST_PATH,
  DEFAULT_OWNER,
  DEFAULT_REPO,
  DEFAULT_WORKSPACE_ROOT,
} from "./flaker-defaults.ts";

export interface FlakerTaskRuntimeOptions {
  taskId: string;
  owner: string;
  repo: string;
  configPath: string;
  manifestPath: string;
  workspaceRoot: string;
  flakerCliPath: string;
}

export type FlakerTaskRuntimeCliArgs = FlakerTaskRuntimeOptions;

export interface SpawnTextResult {
  status: number | null;
  stdout?: string | Buffer;
  stderr?: string | Buffer;
  error?: Error;
}

export interface SpawnTextOptions {
  cwd: string;
  encoding: "utf8";
  maxBuffer: number;
}

export type SpawnTextFn = (
  command: string,
  args: string[],
  options: SpawnTextOptions,
) => SpawnTextResult;

export interface PreparedFlakerTaskWorkspace {
  workspaceDir: string;
  configPath: string;
  storagePath: string;
  command: string[];
  toml: string;
}

export function resolveDefaultFlakerCliPath(
  repoRoot = process.cwd(),
  exists: (candidate: string) => boolean = fs.existsSync,
): string {
  return resolveFlakerCliPath(repoRoot, { exists });
}

export function createFlakerTaskRuntimeDefaults(
  repoRoot = process.cwd(),
): FlakerTaskRuntimeOptions {
  return {
    taskId: "",
    owner: DEFAULT_OWNER,
    repo: DEFAULT_REPO,
    configPath: DEFAULT_CONFIG_PATH,
    manifestPath: DEFAULT_MANIFEST_PATH,
    workspaceRoot: DEFAULT_WORKSPACE_ROOT,
    flakerCliPath: resolveDefaultFlakerCliPath(repoRoot),
  };
}

export function assertValidFlakerTaskRuntimeOptions(
  options: FlakerTaskRuntimeCliArgs,
): void {
  assertRequiredOptions(options, [
    {
      select: (candidate) => candidate.taskId,
      errorMessage: "--task is required",
    },
    {
      select: (candidate) => candidate.flakerCliPath,
      errorMessage: "--flaker-cli requires a file path",
    },
  ]);
}

export function createSpawnTextOptions(
  cwd: string,
  maxBuffer: number,
): SpawnTextOptions {
  return {
    cwd,
    encoding: "utf8",
    maxBuffer,
  };
}

export function prepareFlakerTaskWorkspace(
  repoRoot: string,
  configSource: string,
  options: FlakerTaskRuntimeOptions,
): PreparedFlakerTaskWorkspace {
  const workspaceDir = path.resolve(repoRoot, options.workspaceRoot, options.taskId);
  const configPath = path.join(workspaceDir, "flaker.toml");
  const storagePath = path.join(repoRoot, ".flaker", "data");
  const toml = buildFlakerTaskConfigToml(parseFlakerStar(configSource), {
    taskId: options.taskId,
    owner: options.owner,
    repo: options.repo,
    manifestPath: options.manifestPath,
    repoRoot,
    absolutePaths: true,
    storagePath,
  });

  fs.mkdirSync(workspaceDir, { recursive: true });
  fs.writeFileSync(configPath, toml, "utf8");

  return {
    workspaceDir,
    configPath,
    storagePath,
    command: [process.execPath, resolveDefaultFlakerCliPath(repoRoot)],
    toml,
  };
}

export function readText(value: string | Buffer | undefined): string {
  if (typeof value === "string") {
    return value;
  }
  if (Buffer.isBuffer(value)) {
    return value.toString("utf8");
  }
  return "";
}

export function runJsonTextCommand(
  command: string,
  args: string[],
  options: {
    cwd: string;
    maxBuffer: number;
    commandLabel: string;
    spawnText: SpawnTextFn;
  },
): unknown {
  const result = options.spawnText(
    command,
    args,
    createSpawnTextOptions(options.cwd, options.maxBuffer),
  );
  if (result.error) {
    throw result.error;
  }
  if ((result.status ?? 1) !== 0) {
    const stderr = readText(result.stderr).trim();
    throw new Error(`${options.commandLabel} failed: ${stderr || "unknown error"}`);
  }
  return JSON.parse(readText(result.stdout));
}
