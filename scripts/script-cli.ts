export type CliFlagSetter<T> = (options: T, value?: string) => void;

export interface CliFlagHandler<T> {
  set: CliFlagSetter<T>;
  takesValue?: boolean;
}

export type CliFlagHandlerMap<T> = Record<string, CliFlagHandler<T>>;

export interface ParseCliFlagsOptions<T> {
  usage: () => string;
  handlers: CliFlagHandlerMap<T>;
  printUsage?: (message: string) => void;
  exit?: (code: number) => never;
}

export interface RenderUsageOptions {
  summary: string;
  command: string;
  optionLines: string[];
  helpLine?: string;
}

export interface RequiredOptionCheck<T> {
  select: (options: T) => string | undefined;
  errorMessage: string;
}

export interface ReportOutputCliOptions {
  jsonOutput?: string;
  markdownOutput?: string;
}

function defaultExit(code: number): never {
  process.exit(code);
}

export function parseCliFlags<T>(
  args: string[],
  initial: T,
  options: ParseCliFlagsOptions<T>,
): T {
  const printUsage = options.printUsage ?? console.log;
  const exit = options.exit ?? defaultExit;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--help" || arg === "-h") {
      printUsage(options.usage());
      exit(0);
    }
    const handler = options.handlers[arg];
    if (!handler) {
      throw new Error(`Unknown argument: ${arg}`);
    }
    if (handler.takesValue === false) {
      handler.set(initial);
      continue;
    }
    handler.set(initial, args[++i] ?? "");
  }

  return initial;
}

export function renderUsage(options: RenderUsageOptions): string {
  return [
    options.summary,
    "",
    "Usage:",
    `  ${options.command}`,
    "",
    "Options:",
    ...options.optionLines,
    options.helpLine ?? "  --help           Show this help",
  ].join("\n");
}

export function assertRequiredOptions<T>(
  options: T,
  checks: RequiredOptionCheck<T>[],
): void {
  for (const check of checks) {
    if (!check.select(options)) {
      throw new Error(check.errorMessage);
    }
  }
}

export function createBooleanFlagHandler<T>(
  set: (options: T) => void,
): CliFlagHandler<T> {
  return {
    takesValue: false,
    set,
  };
}

export function createReportOutputHandlers<T extends ReportOutputCliOptions>(): CliFlagHandlerMap<T> {
  return {
    "--json": {
      set: (target, value) => {
        target.jsonOutput = value;
      },
    },
    "--markdown": {
      set: (target, value) => {
        target.markdownOutput = value;
      },
    },
  };
}
