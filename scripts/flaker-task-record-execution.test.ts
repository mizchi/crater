import { describe, expect, it } from "vitest";
import {
  buildFlakerTaskRecordImportArgs,
  executeFlakerTaskRecordPlan,
  runFlakerTaskRecordImport,
  type FlakerTaskRecordImportCliArgs,
} from "./flaker-task-record-execution.ts";
import type { FlakerTaskRecordPlan } from "./flaker-task-record-plan.ts";

const TASK_ARGS: FlakerTaskRecordImportCliArgs = {
  taskId: "paint-vrt",
  owner: "mizchi",
  repo: "crater",
  configPath: "flaker.star",
  manifestPath: "flaker-quarantine.json",
  workspaceRoot: ".flaker/tasks",
  flakerCliPath: "/tmp/flaker-cli.js",
  taskArgs: [],
};

describe("executeFlakerTaskRecordPlan", () => {
  it("runs the prepared task command and captures stdout/stderr", () => {
    const invocations: Array<{ command: string; args: string[]; cwd: string }> = [];
    const result = executeFlakerTaskRecordPlan({
      repoRoot: "/repo",
      taskId: "paint-vrt",
      workspace: {
        workspaceDir: "/repo/.flaker/tasks/paint-vrt",
        configPath: "/repo/.flaker/tasks/paint-vrt/flaker.toml",
        storagePath: "/repo/.flaker/data",
        command: [process.execPath, "/tmp/flaker-cli.js"],
        toml: "",
      },
      paths: {
        latestDir: "/repo/.flaker/tasks/paint-vrt/latest",
        reportPath: "/repo/.flaker/tasks/paint-vrt/latest/playwright-report.json",
        summaryJsonPath: "/repo/.flaker/tasks/paint-vrt/latest/paint-vrt.json",
        summaryMarkdownPath: "/repo/.flaker/tasks/paint-vrt/latest/paint-vrt.md",
        stderrLogPath: "/repo/.flaker/tasks/paint-vrt/latest/playwright.stderr.log",
      },
      taskCommand: ["pnpm", "--dir", "/repo", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
    } satisfies FlakerTaskRecordPlan, {
      spawnTask: (command, args, options) => {
        invocations.push({ command, args, cwd: options.cwd });
        return {
          status: 0,
          stdout: "{\"ok\":true}",
          stderr: "debug stderr",
        };
      },
    });

    expect(invocations).toEqual([
      {
        command: "pnpm",
        args: ["--dir", "/repo", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
        cwd: "/repo",
      },
    ]);
    expect(result).toEqual({
      taskExitCode: 0,
      reportText: "{\"ok\":true}",
      stderrText: "debug stderr",
    });
  });
});

describe("buildFlakerTaskRecordImportArgs", () => {
  it("prefers explicit commit/branch and falls back to detected metadata", () => {
    expect(buildFlakerTaskRecordImportArgs("/tmp/report.json", {
      commitSha: undefined,
      branch: "topic",
    }, {
      commitSha: "abc123",
      branch: "main",
    })).toEqual([
      "import",
      "/tmp/report.json",
      "--adapter",
      "playwright",
      "--commit",
      "abc123",
      "--branch",
      "topic",
    ]);
  });
});

describe("runFlakerTaskRecordImport", () => {
  it("wraps import args into task-scoped flaker run invocation", () => {
    let received:
      | {
          args: string[];
          repoRoot: string;
        }
      | undefined;

    const result = runFlakerTaskRecordImport(
      {
        ...TASK_ARGS,
        commitSha: "abc123",
        branch: "main",
      },
      "/tmp/report.json",
      {},
      {
        repoRoot: "/repo",
        importTaskRun: (importArgs, runOptions) => {
          received = {
            args: importArgs.flakerArgs,
            repoRoot: runOptions.repoRoot,
          };
          return 0;
        },
      },
    );

    expect(result).toEqual({
      exitCode: 0,
      importArgs: [
        "import",
        "/tmp/report.json",
        "--adapter",
        "playwright",
        "--commit",
        "abc123",
        "--branch",
        "main",
      ],
    });
    expect(received).toEqual({
      args: result.importArgs,
      repoRoot: "/repo",
    });
  });
});
