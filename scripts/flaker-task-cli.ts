import {
  DEFAULT_CONFIG_PATH,
  DEFAULT_MANIFEST_PATH,
  DEFAULT_OWNER,
  DEFAULT_REPO,
  DEFAULT_WORKSPACE_ROOT,
  type FlakerTaskRuntimeOptions,
} from "./flaker-task-runtime.ts";
import {
  parseCliFlags,
  renderUsage,
  type CliFlagHandlerMap,
} from "./script-cli.ts";

export interface SplitCliArgsResult {
  head: string[];
  tail: string[];
}

export interface ParseFlakerTaskCliOptions<T extends FlakerTaskRuntimeOptions> {
  usage: () => string;
  extraHandlers?: CliFlagHandlerMap<T>;
  printUsage?: (message: string) => void;
  exit?: (code: number) => never;
}

export interface RenderFlakerTaskUsageOptions {
  summary: string;
  command: string;
  defaultFlakerCliPath: string;
  extraOptions?: string[];
}

export function splitCliArgsOnSeparator(args: string[]): SplitCliArgsResult {
  const separatorIndex = args.indexOf("--");
  if (separatorIndex < 0) {
    return {
      head: [...args],
      tail: [],
    };
  }
  return {
    head: args.slice(0, separatorIndex),
    tail: args.slice(separatorIndex + 1),
  };
}

function buildDefaultTaskRuntimeHandlers<T extends FlakerTaskRuntimeOptions>(): CliFlagHandlerMap<T> {
  return {
    "--task": {
      set: (options, value) => {
        options.taskId = value ?? "";
      },
    },
    "--config": {
      set: (options, value) => {
        options.configPath = value ?? "";
      },
    },
    "--owner": {
      set: (options, value) => {
        options.owner = value ?? "";
      },
    },
    "--repo": {
      set: (options, value) => {
        options.repo = value ?? "";
      },
    },
    "--manifest": {
      set: (options, value) => {
        options.manifestPath = value ?? "";
      },
    },
    "--workspace-root": {
      set: (options, value) => {
        options.workspaceRoot = value ?? "";
      },
    },
    "--flaker-cli": {
      set: (options, value) => {
        options.flakerCliPath = value ?? "";
      },
    },
  };
}

export function parseFlakerTaskCliFlags<T extends FlakerTaskRuntimeOptions>(
  args: string[],
  initial: T,
  options: ParseFlakerTaskCliOptions<T>,
): T {
  return parseCliFlags(args, initial, {
    usage: options.usage,
    printUsage: options.printUsage,
    exit: options.exit,
    handlers: {
      ...buildDefaultTaskRuntimeHandlers<T>(),
      ...(options.extraHandlers ?? {}),
    },
  });
}

export function renderFlakerTaskUsage(
  options: RenderFlakerTaskUsageOptions,
): string {
  return renderUsage({
    summary: options.summary,
    command: options.command,
    optionLines: [
      "  --task <id>           Task id from flaker.star",
      `  --config <file>       flaker.star path (default: ${DEFAULT_CONFIG_PATH})`,
      `  --owner <owner>       GitHub owner (default: ${DEFAULT_OWNER})`,
      `  --repo <name>         GitHub repo name (default: ${DEFAULT_REPO})`,
      `  --manifest <file>     quarantine manifest path (default: ${DEFAULT_MANIFEST_PATH})`,
      `  --workspace-root <dir> Generated flaker workspaces (default: ${DEFAULT_WORKSPACE_ROOT})`,
      `  --flaker-cli <file>   Metric CI / flaker CLI entry (default: ${options.defaultFlakerCliPath})`,
      ...(options.extraOptions ?? []),
    ],
    helpLine: "  --help                Show this help",
  });
}
