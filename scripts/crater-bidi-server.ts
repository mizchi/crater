import {
  spawn,
  type ChildProcess,
  type SpawnOptions,
} from "node:child_process";
import { once } from "node:events";
import { unlink } from "node:fs/promises";
import path from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import {
  BIDI_URL_FILE_NAME,
  discoverBidiUrl,
  type ResolveBidiUrlOptions,
} from "./bidi-url.ts";

const DEFAULT_CRATER_ROOT = path.resolve(fileURLToPath(new URL("..", import.meta.url)));

export type DiscoverBidiUrlImpl = (
  options?: ResolveBidiUrlOptions,
) => Promise<string | null>;

export type CraterBidiServerCommand = {
  command: string;
  args: string[];
  cwd: string;
  env: NodeJS.ProcessEnv;
};

export type BuildCraterBidiServerCommandOptions = {
  craterRoot?: string;
  denoBin?: string;
  env?: NodeJS.ProcessEnv;
};

export type WaitForCraterBidiUrlOptions = {
  craterRoot?: string;
  env?: NodeJS.ProcessEnv;
  statusTimeoutMs?: number;
  statusUrl?: string;
  timeoutMs?: number;
  pollIntervalMs?: number;
  readUrlFile?: boolean;
  discoverBidiUrlImpl?: DiscoverBidiUrlImpl;
  isProcessExited?: () => boolean;
};

export type StartCraterBidiServerOptions = BuildCraterBidiServerCommandOptions & {
  timeoutMs?: number;
  pollIntervalMs?: number;
  statusTimeoutMs?: number;
  statusUrl?: string;
  stdio?: SpawnOptions["stdio"];
  spawnImpl?: typeof spawn;
  discoverBidiUrlImpl?: DiscoverBidiUrlImpl;
  readUrlFile?: boolean;
  shutdownTimeoutMs?: number;
};

export type EnsureCraterBidiServerOptions = StartCraterBidiServerOptions;

export interface CraterBidiServerHandle {
  readonly url: string;
  readonly process: ChildProcess | null;
  close(): Promise<void>;
}

export function resolveCraterRoot(craterRoot?: string): string {
  return path.resolve(craterRoot ?? DEFAULT_CRATER_ROOT);
}

export function buildCraterBidiServerCommand(
  options: BuildCraterBidiServerCommandOptions = {},
): CraterBidiServerCommand {
  const craterRoot = resolveCraterRoot(options.craterRoot);
  return {
    command: options.denoBin ?? "deno",
    args: ["run", "-A", path.join(craterRoot, "webdriver/bidi_main/start-with-font.ts")],
    cwd: craterRoot,
    env: options.env ?? process.env,
  };
}

export async function waitForCraterBidiUrl(
  options: WaitForCraterBidiUrlOptions = {},
): Promise<string> {
  const craterRoot = resolveCraterRoot(options.craterRoot);
  const discover = options.discoverBidiUrlImpl ?? discoverBidiUrl;
  const timeoutMs = options.timeoutMs ?? 15_000;
  const pollIntervalMs = options.pollIntervalMs ?? 50;
  const startedAt = Date.now();
  const deadline = startedAt + timeoutMs;

  while (Date.now() <= deadline) {
    const url = await discover({
      cwd: craterRoot,
      env: options.env,
      statusTimeoutMs: options.statusTimeoutMs,
      statusUrl: options.statusUrl,
      readUrlFile: options.readUrlFile,
    });
    if (url) {
      return url;
    }
    if (options.isProcessExited?.()) {
      throw new Error("Crater BiDi server exited before publishing a websocket URL");
    }

    const remainingMs = Math.max(0, deadline - Date.now());
    if (remainingMs === 0) {
      break;
    }
    await delay(Math.min(pollIntervalMs, remainingMs));
  }

  throw new Error(`Timed out waiting for Crater BiDi server after ${timeoutMs}ms`);
}

class ExistingCraterBidiServer implements CraterBidiServerHandle {
  readonly process = null;

  constructor(readonly url: string) {}

  async close(): Promise<void> {}
}

class ManagedCraterBidiServer implements CraterBidiServerHandle {
  private closed = false;

  constructor(
    readonly url: string,
    readonly process: ChildProcess,
    private readonly shutdownTimeoutMs: number,
  ) {}

  async close(): Promise<void> {
    if (this.closed) {
      return;
    }
    this.closed = true;
    if (this.process.exitCode !== null || this.process.signalCode !== null) {
      return;
    }

    const exited = once(this.process, "exit");
    this.process.kill("SIGTERM");
    await Promise.race([
      exited,
      delay(this.shutdownTimeoutMs).then(async () => {
        if (this.process.exitCode === null && this.process.signalCode === null) {
          this.process.kill("SIGKILL");
          await once(this.process, "exit");
        }
      }),
    ]);
  }
}

export async function ensureCraterBidiServer(
  options: EnsureCraterBidiServerOptions = {},
): Promise<CraterBidiServerHandle> {
  const craterRoot = resolveCraterRoot(options.craterRoot);
  const discover = options.discoverBidiUrlImpl ?? discoverBidiUrl;
  const existingUrl = await discover({
    cwd: craterRoot,
    env: options.env,
    statusTimeoutMs: options.statusTimeoutMs,
    statusUrl: options.statusUrl,
    readUrlFile: false,
  });
  if (existingUrl) {
    return new ExistingCraterBidiServer(existingUrl);
  }

  return await startCraterBidiServer({
    ...options,
    craterRoot,
    discoverBidiUrlImpl: discover,
  });
}

export async function startCraterBidiServer(
  options: StartCraterBidiServerOptions = {},
): Promise<CraterBidiServerHandle> {
  const command = buildCraterBidiServerCommand(options);
  await unlink(path.join(command.cwd, BIDI_URL_FILE_NAME)).catch(() => {});
  const spawnImpl = options.spawnImpl ?? spawn;
  const child = spawnImpl(command.command, command.args, {
    cwd: command.cwd,
    env: command.env,
    stdio: options.stdio ?? "inherit",
  });

  try {
    const url = await waitForCraterBidiUrl({
      craterRoot: command.cwd,
      env: command.env,
      statusTimeoutMs: options.statusTimeoutMs,
      statusUrl: options.statusUrl,
      timeoutMs: options.timeoutMs,
      pollIntervalMs: options.pollIntervalMs,
      readUrlFile: options.readUrlFile,
      discoverBidiUrlImpl: options.discoverBidiUrlImpl,
      isProcessExited: () => child.exitCode !== null || child.signalCode !== null,
    });
    return new ManagedCraterBidiServer(
      url,
      child,
      options.shutdownTimeoutMs ?? 2_000,
    );
  } catch (error) {
    if (child.exitCode === null && child.signalCode === null) {
      child.kill("SIGTERM");
    }
    throw error;
  }
}
