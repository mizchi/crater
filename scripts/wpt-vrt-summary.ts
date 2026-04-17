#!/usr/bin/env npx tsx

import fs from "node:fs";
import path from "node:path";
import {
  createReportOutputHandlers,
  parseCliFlags,
  renderUsage,
  type ReportOutputCliOptions,
} from "./script-cli.ts";
import {
  appendReportWrites,
  emitScriptExecutionResult,
  isMainModule,
  type ScriptExecutionResult,
} from "./script-runtime.ts";
import { appendFlakerCollectedSummaryWrites } from "./flaker-collected-summary-paths.ts";
import {
  aggregateWptVrtSummaries,
  asWptVrtShardSummary,
  buildWptVrtShardSummary,
  renderWptVrtAggregateMarkdown,
  renderWptVrtShardMarkdown,
  type WptVrtRawReport,
  type WptVrtShardSummary,
} from "./wpt-vrt-summary-core.ts";

export * from "./wpt-vrt-summary-core.ts";

const DEFAULT_INPUT = path.join("output", "playwright", "vrt", "wpt", "wpt-vrt-results.json");
const DEFAULT_INPUT_DIR = "wpt-vrt-summary";

interface WptVrtSummaryCliArgs extends ReportOutputCliOptions {
  input?: string;
  inputDir?: string;
  label?: string;
  collectTaskId?: string;
}

function usage(): string {
  return renderUsage({
    summary: "WPT VRT Summary",
    command: "npx tsx scripts/wpt-vrt-summary.ts [options]",
    optionLines: [
      `  --input <file>       Raw WPT VRT results JSON (default: ${DEFAULT_INPUT})`,
      `  --aggregate <dir>    Aggregate shard summary JSON files from a directory (default: ${DEFAULT_INPUT_DIR})`,
      "  --label <name>       Shard label override",
      "  --collect-task-id <task-id>  Task id used for collect-compatible copies",
      "  --json <file>        Write JSON summary",
      "  --markdown <file>    Write markdown summary",
    ],
    helpLine: "  --help               Show this help",
  });
}

export function parseWptVrtSummaryArgs(args: string[]): WptVrtSummaryCliArgs {
  const options = parseCliFlags(args, {} as WptVrtSummaryCliArgs, {
    usage,
    handlers: {
      "--input": {
        set: (target, value) => {
          target.input = value ?? "";
        },
      },
      "--aggregate": {
        set: (target, value) => {
          target.inputDir = value ?? "";
        },
      },
      "--label": {
        set: (target, value) => {
          target.label = value;
        },
      },
      "--collect-task-id": {
        set: (target, value) => {
          target.collectTaskId = value;
        },
      },
      ...createReportOutputHandlers(),
    },
  });

  if (!options.input && !options.inputDir) {
    options.input = DEFAULT_INPUT;
  }
  if (options.input && options.inputDir) {
    throw new Error("--input and --aggregate cannot be used together");
  }

  return options;
}

function collectJsonFilesRecursive(
  dir: string,
  existsSync: (targetPath: string) => boolean,
  readdirSync: (targetPath: string) => fs.Dirent[],
): string[] {
  if (!existsSync(dir)) return [];
  const files: string[] = [];
  const stack = [dir];

  while (stack.length > 0) {
    const current = stack.pop()!;
    for (const entry of readdirSync(current)) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(fullPath);
      } else if (entry.isFile() && entry.name.endsWith(".json")) {
        files.push(fullPath);
      }
    }
  }

  return files.sort();
}

export function loadWptVrtSummariesFromDir(
  inputDir: string,
  options?: {
    existsSync?: (targetPath: string) => boolean;
    readdirSync?: (targetPath: string) => fs.Dirent[];
    readFile?: (targetPath: string) => string;
  },
): WptVrtShardSummary[] {
  const existsSync = options?.existsSync ?? fs.existsSync;
  const readdirSync = options?.readdirSync ?? ((targetPath: string) =>
    fs.readdirSync(targetPath, { withFileTypes: true }));
  const readFile = options?.readFile ?? ((targetPath: string) => fs.readFileSync(targetPath, "utf8"));
  const rows: WptVrtShardSummary[] = [];
  for (const file of collectJsonFilesRecursive(inputDir, existsSync, readdirSync)) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(readFile(file));
    } catch {
      continue;
    }
    const row = asWptVrtShardSummary(parsed);
    if (row) {
      rows.push(row);
    }
  }
  return rows.sort((a, b) => a.label.localeCompare(b.label));
}

function resolveAggregateCollectTaskId(
  parsed: WptVrtSummaryCliArgs,
  cwd: string,
): string {
  return parsed.collectTaskId?.trim()
    || parsed.label?.trim()
    || path.basename(path.resolve(cwd, parsed.inputDir ?? DEFAULT_INPUT_DIR))
    || DEFAULT_INPUT_DIR;
}

export function runWptVrtSummaryCli(
  args: string[],
  options?: {
    cwd?: string;
    readFile?: (targetPath: string) => string;
    existsSync?: (targetPath: string) => boolean;
    readdirSync?: (targetPath: string) => fs.Dirent[];
    jsonFilesByDir?: Map<string, string[]>;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseWptVrtSummaryArgs(args);
    const cwd = options?.cwd ?? process.cwd();
    const readFile = options?.readFile ?? ((targetPath: string) => fs.readFileSync(targetPath, "utf8"));
    const existsSync = options?.existsSync ?? ((targetPath: string) =>
      options?.jsonFilesByDir?.has(targetPath) || fs.existsSync(targetPath));
    const readdirSync = options?.readdirSync ?? ((targetPath: string) => {
      const injected = options?.jsonFilesByDir?.get(targetPath);
      if (injected) {
        return injected.map((filePath) => ({
          name: path.basename(filePath),
          isDirectory: () => false,
          isFile: () => true,
        })) as fs.Dirent[];
      }
      return fs.readdirSync(targetPath, { withFileTypes: true });
    });

    const writes: ScriptExecutionResult["writes"] = [];

    if (parsed.inputDir) {
      const summaries = loadWptVrtSummariesFromDir(path.resolve(cwd, parsed.inputDir), {
        existsSync,
        readdirSync,
        readFile,
      });
      const aggregate = aggregateWptVrtSummaries(summaries);
      const markdown = renderWptVrtAggregateMarkdown(aggregate);
      const jsonContent = `${JSON.stringify(aggregate, null, 2)}\n`;
      appendReportWrites(writes, {
        cwd,
        markdownPath: parsed.markdownOutput,
        markdownContent: markdown,
        jsonPath: parsed.jsonOutput,
        jsonValue: aggregate,
      });
      appendFlakerCollectedSummaryWrites(writes, {
        cwd,
        taskId: resolveAggregateCollectTaskId(parsed, cwd),
        kind: "wpt-vrt-summary",
        jsonOutput: parsed.jsonOutput,
        markdownOutput: parsed.markdownOutput,
        jsonContent,
        markdownContent: markdown,
      });
      return {
        exitCode: 0,
        stdout: markdown,
        writes,
      };
    }

    const inputPath = path.resolve(cwd, parsed.input ?? DEFAULT_INPUT);
    const raw = JSON.parse(readFile(inputPath)) as WptVrtRawReport;
    const summary = buildWptVrtShardSummary(raw, parsed.label);
    const markdown = renderWptVrtShardMarkdown(summary);
    const jsonContent = `${JSON.stringify(summary, null, 2)}\n`;
    appendReportWrites(writes, {
      cwd,
      markdownPath: parsed.markdownOutput,
      markdownContent: markdown,
      jsonPath: parsed.jsonOutput,
      jsonValue: summary,
    });
    appendFlakerCollectedSummaryWrites(writes, {
      cwd,
      taskId: parsed.collectTaskId?.trim() || summary.label,
      kind: "wpt-vrt-summary",
      jsonOutput: parsed.jsonOutput,
      markdownOutput: parsed.markdownOutput,
      jsonContent,
      markdownContent: markdown,
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
  emitScriptExecutionResult(runWptVrtSummaryCli(process.argv.slice(2)));
}
