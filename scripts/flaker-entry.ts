#!/usr/bin/env node

import path from "node:path";
import { runFlakerBatchPlanCli } from "./flaker-batch-plan.ts";
import { runFlakerBatchSummaryCli } from "./flaker-batch-summary.ts";
import { runFlakerConfigCli } from "./flaker-config.ts";
import { runFlakerQuarantineCli } from "./flaker-quarantine.ts";
import { runFlakerTaskConfigCli } from "./flaker-task-config.ts";
import { runFlakerTaskRecordCli } from "./flaker-task-record.ts";
import { runFlakerTaskRunCli } from "./flaker-task-run.ts";
import { runFlakerTaskSummaryCli } from "./flaker-task-summary.ts";
import { runFlakerUpstreamExportCli } from "./flaker-upstream-export.ts";
import { runFlakerUpstreamInventoryCli } from "./flaker-upstream-inventory.ts";
import {
  emitScriptExecutionResult,
  isMainModule,
  type ScriptExecutionResult,
} from "./script-runtime.ts";

export interface FlakerEntryHandlers {
  runConfigCli: (args: string[]) => ScriptExecutionResult;
  runTaskConfigCli: (args: string[]) => ScriptExecutionResult;
  runTaskRunCli: (args: string[]) => ScriptExecutionResult;
  runTaskRecordCli: (args: string[]) => ScriptExecutionResult;
  runTaskSummaryCli: (args: string[]) => ScriptExecutionResult;
  runBatchPlanCli: (args: string[]) => ScriptExecutionResult;
  runBatchSummaryCli: (args: string[]) => ScriptExecutionResult;
  runQuarantineCli: (args: string[]) => ScriptExecutionResult;
  runUpstreamInventoryCli: (args: string[]) => ScriptExecutionResult;
  runUpstreamExportCli: (args: string[]) => ScriptExecutionResult;
}

function createDefaultHandlers(): FlakerEntryHandlers {
  return {
    runConfigCli: runFlakerConfigCli,
    runTaskConfigCli: runFlakerTaskConfigCli,
    runTaskRunCli: runFlakerTaskRunCli,
    runTaskRecordCli: runFlakerTaskRecordCli,
    runTaskSummaryCli: runFlakerTaskSummaryCli,
    runBatchPlanCli: runFlakerBatchPlanCli,
    runBatchSummaryCli: runFlakerBatchSummaryCli,
    runQuarantineCli: runFlakerQuarantineCli,
    runUpstreamInventoryCli: runFlakerUpstreamInventoryCli,
    runUpstreamExportCli: runFlakerUpstreamExportCli,
  };
}

function helpText(): string {
  return [
    "Flaker compact entrypoint",
    "",
    "Usage:",
    "  just flaker <command> [args...]",
    "  node scripts/flaker-entry.ts <command> [args...]",
    "",
    "Commands:",
    "  api",
    "  config list",
    "  config check",
    "  config report [output-dir]",
    "  config affected <paths...>",
    "  task config <task-id> [output-file]",
    "  task exec <task-id> <flaker args...>",
    "  task import <task-id> <playwright-report.json> [flaker args...]",
    "  task record <task-id> [playwright args...]",
    "  task summary <task-id> [output-dir]",
    "  task sample <task-id> [flaker args...]",
    "  task run <task-id> [flaker args...]",
    "  batch plan [output-dir]",
    "  batch summary <input-dir> [output-dir]",
    "  quarantine check",
    "  quarantine report [output-dir]",
    "  upstream inventory [output-dir]",
    "  upstream export <group|all> [output-dir]",
    "",
    "Notes:",
    "  - compact entrypoint は日常運用向けの短い入口",
    "  - `config report` が推奨形で、`list/check/report/affected` は legacy alias",
    "  - `task exec` は任意の `flaker` サブコマンド、`task sample/run` はその shorthand",
    "  - generic な flaker logic は基本 `metric-ci` へ寄せる",
    "  - 高度な flag が必要なときは既存の scripts/just recipe を直接使う",
    "  - 参照: docs/flaker-runbook.md",
    "",
  ].join("\n");
}

function apiText(): string {
  return [
    "# Flaker API Map",
    "",
    "## Command Groups",
    "- `config`: `list`, `check`, `report`, `affected`",
    "- `task`: `config`, `exec`, `import`, `record`, `summary`, `sample`, `run`",
    "- `batch`: `plan`, `summary`",
    "- `quarantine`: `check`, `report`",
    "- `upstream`: `inventory`, `export`",
    "",
    "## Layers",
    "- `contract`: 型契約だけを持つ",
    "- `core`: pure な build / summarize / render",
    "- `loader`: repo 上の file / artifact を解決する",
    "- `adapter`: crater 固有の task/workspace bridge",
    "- `cli`: compact entrypoint と各 wrapper",
    "",
    "## Ownership",
    "- `metric-ci (flaker)` に寄せる: `parser/contract/core`",
    "- `crater` に残す: `loader/adapter/domain`",
    "",
    "## Preferred CLI Shape",
    "- `config <list|check|report|affected>`",
    "- `task exec <task-id> <flaker subcommand...>`",
    "- `task sample/run` は `task exec` の shorthand",
    "",
    "See also: `docs/flaker-runbook.md`",
    "",
  ].join("\n");
}

function ok(stdout: string): ScriptExecutionResult {
  return {
    exitCode: 0,
    stdout,
    writes: [],
  };
}

function err(message: string): ScriptExecutionResult {
  return {
    exitCode: 1,
    stderr: `${message}\n`,
    writes: [],
  };
}

function withReportDir(args: string[], outputDir: string, baseName: string): string[] {
  return [
    ...args,
    "--json",
    path.join(outputDir, `${baseName}.json`),
    "--markdown",
    path.join(outputDir, `${baseName}.md`),
  ];
}

function dispatchTaskCommand(
  args: string[],
  handlers: FlakerEntryHandlers,
): ScriptExecutionResult {
  const [subcommand, taskId, ...rest] = args;
  if (!subcommand || !taskId) {
    return err("Usage: flaker task <config|exec|import|record|summary|sample|run> <task-id> ...");
  }

  if (subcommand === "config") {
    if (rest.length > 0) {
      return handlers.runTaskConfigCli(["--task", taskId, "--write", rest[0]!]);
    }
    return handlers.runTaskConfigCli(["--task", taskId]);
  }

  if (subcommand === "exec") {
    if (rest.length === 0) {
      return err("Usage: flaker task exec <task-id> <flaker args...>");
    }
    return handlers.runTaskRunCli(["--task", taskId, "--", ...rest]);
  }

  if (subcommand === "import") {
    const [reportPath, ...importArgs] = rest;
    if (!reportPath) {
      return err("Usage: flaker task import <task-id> <playwright-report.json> [flaker args...]");
    }
    return handlers.runTaskRunCli(["--task", taskId, "--", "import", reportPath, ...importArgs]);
  }

  if (subcommand === "record") {
    return handlers.runTaskRecordCli(["--task", taskId, "--", ...rest]);
  }

  if (subcommand === "summary") {
    if (rest.length > 0) {
      return handlers.runTaskSummaryCli(
        withReportDir(["--task", taskId], rest[0]!, taskId),
      );
    }
    return handlers.runTaskSummaryCli(["--task", taskId]);
  }

  if (subcommand === "sample") {
    return handlers.runTaskRunCli(["--task", taskId, "--", "sample", ...rest]);
  }

  if (subcommand === "run") {
    return handlers.runTaskRunCli(["--task", taskId, "--", "run", ...rest]);
  }

  return err(`Unknown flaker task command: ${subcommand}`);
}

function dispatchConfigCommand(
  args: string[],
  handlers: FlakerEntryHandlers,
): ScriptExecutionResult {
  const [subcommand, ...rest] = args;
  if (!subcommand) {
    return err("Usage: flaker config <list|check|report|affected> ...");
  }

  if (subcommand === "list") {
    return handlers.runConfigCli(["--list"]);
  }

  if (subcommand === "check") {
    return handlers.runConfigCli(["--check"]);
  }

  if (subcommand === "report") {
    if (rest.length > 0) {
      return handlers.runConfigCli(
        withReportDir(["--check"], rest[0]!, "summary"),
      );
    }
    return handlers.runConfigCli(["--check"]);
  }

  if (subcommand === "affected") {
    if (rest.length === 0) {
      return err("Usage: flaker config affected <paths...>");
    }
    return handlers.runConfigCli(["--select", ...rest]);
  }

  return err("Usage: flaker config <list|check|report|affected> ...");
}

function dispatchBatchCommand(
  args: string[],
  handlers: FlakerEntryHandlers,
): ScriptExecutionResult {
  const [subcommand, ...rest] = args;
  if (!subcommand) {
    return err("Usage: flaker batch <plan|summary> ...");
  }

  if (subcommand === "plan") {
    if (rest.length > 0) {
      return handlers.runBatchPlanCli(
        withReportDir([], rest[0]!, "plan"),
      );
    }
    return handlers.runBatchPlanCli([]);
  }

  if (subcommand === "summary") {
    const [inputDir, outputDir] = rest;
    if (!inputDir) {
      return err("Usage: flaker batch summary <input-dir> [output-dir]");
    }
    if (outputDir) {
      return handlers.runBatchSummaryCli(
        withReportDir(["--input", inputDir], outputDir, "summary"),
      );
    }
    return handlers.runBatchSummaryCli(["--input", inputDir]);
  }

  return err(`Unknown flaker batch command: ${subcommand}`);
}

function dispatchQuarantineCommand(
  args: string[],
  handlers: FlakerEntryHandlers,
): ScriptExecutionResult {
  const [subcommand, outputDir] = args;
  if (subcommand === "check") {
    return handlers.runQuarantineCli(["--check"]);
  }
  if (subcommand === "report") {
    if (outputDir) {
      return handlers.runQuarantineCli(
        withReportDir(["--check"], outputDir, "quarantine"),
      );
    }
    return handlers.runQuarantineCli(["--check"]);
  }
  return err("Usage: flaker quarantine <check|report> [output-dir]");
}

function dispatchUpstreamCommand(
  args: string[],
  handlers: FlakerEntryHandlers,
): ScriptExecutionResult {
  const [subcommand, ...rest] = args;
  if (subcommand === "inventory") {
    if (rest.length > 0) {
      return handlers.runUpstreamInventoryCli(
        withReportDir([], rest[0]!, "inventory"),
      );
    }
    return handlers.runUpstreamInventoryCli([]);
  }
  if (subcommand === "export") {
    const [groupId, outputDir] = rest;
    if (!groupId) {
      return err("Usage: flaker upstream export <group|all> [output-dir]");
    }
    if (groupId === "all") {
      return handlers.runUpstreamExportCli([
        "--all",
        "--output",
        outputDir ?? ".flaker/upstream-export",
      ]);
    }
    return handlers.runUpstreamExportCli([
      "--group",
      groupId,
      "--output",
      outputDir ?? ".flaker/upstream-export",
    ]);
  }
  return err("Usage: flaker upstream <inventory|export> ...");
}

export function runFlakerEntryCli(
  args: string[],
  options?: {
    handlers?: FlakerEntryHandlers;
  },
): ScriptExecutionResult {
  const handlers = options?.handlers ?? createDefaultHandlers();
  const [command, ...rest] = args;

  if (!command || command === "help" || command === "--help" || command === "-h") {
    return ok(helpText());
  }

  if (command === "api") {
    return ok(apiText());
  }

  if (command === "config") {
    return dispatchConfigCommand(rest, handlers);
  }

  if (command === "list") {
    return handlers.runConfigCli(["--list"]);
  }

  if (command === "check") {
    return handlers.runConfigCli(["--check"]);
  }

  if (command === "report") {
    if (rest.length > 0) {
      return handlers.runConfigCli(
        withReportDir(["--check"], rest[0]!, "summary"),
      );
    }
    return handlers.runConfigCli(["--check"]);
  }

  if (command === "affected") {
    if (rest.length === 0) {
      return err("Usage: flaker affected <paths...>");
    }
    return handlers.runConfigCli(["--select", ...rest]);
  }

  if (command === "task") {
    return dispatchTaskCommand(rest, handlers);
  }

  if (command === "batch") {
    return dispatchBatchCommand(rest, handlers);
  }

  if (command === "quarantine") {
    return dispatchQuarantineCommand(rest, handlers);
  }

  if (command === "upstream") {
    return dispatchUpstreamCommand(rest, handlers);
  }

  return err(`Unknown flaker command: ${command}`);
}

if (isMainModule(import.meta.url)) {
  emitScriptExecutionResult(runFlakerEntryCli(process.argv.slice(2)));
}
