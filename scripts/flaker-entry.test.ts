import { describe, expect, it } from "vitest";
import {
  runFlakerEntryCli,
  type FlakerEntryHandlers,
} from "./flaker-entry.ts";
import type { ScriptExecutionResult } from "./script-runtime.ts";

function ok(stdout: string): ScriptExecutionResult {
  return { exitCode: 0, stdout, writes: [] };
}

function createHandlers(log: Array<{ name: string; args: string[] }>): FlakerEntryHandlers {
  const call = (name: string) => (args: string[]) => {
    log.push({ name, args });
    return ok(name);
  };

  return {
    runConfigCli: call("config"),
    runTaskConfigCli: call("task-config"),
    runTaskRunCli: call("task-run"),
    runTaskRecordCli: call("task-record"),
    runTaskSummaryCli: call("task-summary"),
    runBatchPlanCli: call("batch-plan"),
    runBatchSummaryCli: call("batch-summary"),
    runQuarantineCli: call("quarantine"),
    runUpstreamInventoryCli: call("upstream-inventory"),
    runUpstreamExportCli: call("upstream-export"),
  };
}

describe("runFlakerEntryCli", () => {
  it("prints help with command groups", () => {
    const result = runFlakerEntryCli([]);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("Flaker compact entrypoint");
    expect(result.stdout).toContain("api");
    expect(result.stdout).toContain("config");
    expect(result.stdout).toContain("task");
    expect(result.stdout).toContain("config report [output-dir]");
    expect(result.stdout).toContain("legacy alias");
    expect(result.stdout).toContain("metric-ci");
    expect(result.stdout).toContain("docs/flaker-runbook.md");
  });

  it("prints API map", () => {
    const result = runFlakerEntryCli(["api"]);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# Flaker API Map");
    expect(result.stdout).toContain("contract");
    expect(result.stdout).toContain("task");
    expect(result.stdout).toContain("metric-ci (flaker)");
  });

  it("dispatches config check", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    const result = runFlakerEntryCli(["config", "check"], {
      handlers: createHandlers(calls),
    });

    expect(result.stdout).toBe("config");
    expect(calls).toEqual([
      { name: "config", args: ["--check"] },
    ]);
  });

  it("dispatches config affected paths", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["config", "affected", "src/layout/block.mbt", "tests/paint-vrt.test.ts"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "config",
        args: ["--select", "src/layout/block.mbt", "tests/paint-vrt.test.ts"],
      },
    ]);
  });

  it("dispatches config report", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["config", "report", ".flaker/report"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "config",
        args: [
          "--check",
          "--json",
          ".flaker/report/summary.json",
          "--markdown",
          ".flaker/report/summary.md",
        ],
      },
    ]);
  });

  it("keeps top-level config aliases for backwards compatibility", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["report", ".flaker/report"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "config",
        args: [
          "--check",
          "--json",
          ".flaker/report/summary.json",
          "--markdown",
          ".flaker/report/summary.md",
        ],
      },
    ]);
  });

  it("dispatches task record", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["task", "record", "paint-vrt", "--workers", "1"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "task-record",
        args: ["--task", "paint-vrt", "--", "--workers", "1"],
      },
    ]);
  });

  it("dispatches task exec through task-run cli", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["task", "exec", "paint-vrt", "flaky", "--limit", "20"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "task-run",
        args: ["--task", "paint-vrt", "--", "flaky", "--limit", "20"],
      },
    ]);
  });

  it("dispatches task import through task-run cli", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["task", "import", "paint-vrt", "paint-vrt-report.json", "--branch", "main"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "task-run",
        args: ["--task", "paint-vrt", "--", "import", "paint-vrt-report.json", "--branch", "main"],
      },
    ]);
  });

  it("dispatches task sample through task-run cli", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["task", "sample", "paint-vrt", "--count", "20"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "task-run",
        args: ["--task", "paint-vrt", "--", "sample", "--count", "20"],
      },
    ]);
  });

  it("dispatches batch summary with positional input dir", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["batch", "summary", "flaker-daily-artifacts"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "batch-summary",
        args: ["--input", "flaker-daily-artifacts"],
      },
    ]);
  });

  it("dispatches batch summary with positional output dir and collect task id", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli([
      "batch",
      "summary",
      "flaker-daily-artifacts",
      ".flaker/batch-summary",
      "flaker-daily",
    ], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "batch-summary",
        args: [
          "--input",
          "flaker-daily-artifacts",
          "--json",
          ".flaker/batch-summary/summary.json",
          "--markdown",
          ".flaker/batch-summary/summary.md",
          "--collect-task-id",
          "flaker-daily",
        ],
      },
    ]);
  });

  it("dispatches quarantine report", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["quarantine", "report"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "quarantine",
        args: ["--check"],
      },
    ]);
  });

  it("dispatches upstream export", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["upstream", "export", "playwright-report-core"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "upstream-export",
        args: ["--group", "playwright-report-core", "--output", ".flaker/upstream-export"],
      },
    ]);
  });

  it("dispatches upstream export all", () => {
    const calls: Array<{ name: string; args: string[] }> = [];
    runFlakerEntryCli(["upstream", "export", "all", "from-crater"], {
      handlers: createHandlers(calls),
    });

    expect(calls).toEqual([
      {
        name: "upstream-export",
        args: ["--all", "--output", "from-crater"],
      },
    ]);
  });

  it("returns an error for unknown command", () => {
    const result = runFlakerEntryCli(["wat"]);

    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain("Unknown flaker command");
  });
});
