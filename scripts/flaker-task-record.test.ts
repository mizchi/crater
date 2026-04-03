import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildFlakerTaskRecordImportArgs,
  detectGitMetadata,
  parseFlakerTaskRecordArgs,
  recordFlakerTask,
  runFlakerTaskRecordCli,
} from "./flaker-task-record.ts";

const REPO_ROOT = path.resolve(import.meta.dirname, "..");
const FLAKER_STAR = fs.readFileSync(path.join(REPO_ROOT, "flaker.star"), "utf8");

const PLAYWRIGHT_REPORT = JSON.stringify({
  suites: [
    {
      title: "tests/paint-vrt.test.ts",
      file: "tests/paint-vrt.test.ts",
      specs: [
        {
          title: "fixture: cards and controls stay within relaxed visual diff budget",
          tests: [
            {
              projectName: "chromium",
              expectedStatus: "passed",
              status: "passed",
              results: [
                {
                  retry: 0,
                  status: "passed",
                  duration: 123,
                },
              ],
            },
          ],
        },
      ],
    },
  ],
});

describe("parseFlakerTaskRecordArgs", () => {
  it("parses task options and forwards extra playwright args after --", () => {
    const args = parseFlakerTaskRecordArgs([
      "--task",
      "paint-vrt",
      "--report-path",
      ".flaker/report.json",
      "--",
      "--workers",
      "1",
    ]);

    expect(args).toMatchObject({
      taskId: "paint-vrt",
      reportPath: ".flaker/report.json",
      taskArgs: ["--workers", "1"],
    });
  });
});

describe("detectGitMetadata", () => {
  it("reads branch and commit from git commands", () => {
    const calls: Array<{ command: string; args: string[] }> = [];
    const metadata = detectGitMetadata("/tmp/repo", (command, args) => {
      calls.push({ command, args });
      if (args[0] === "rev-parse") {
        return { status: 0, stdout: "abc123\n" };
      }
      return { status: 0, stdout: "main\n" };
    });

    expect(calls).toEqual([
      { command: "git", args: ["rev-parse", "HEAD"] },
      { command: "git", args: ["branch", "--show-current"] },
    ]);
    expect(metadata).toEqual({
      commitSha: "abc123",
      branch: "main",
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

describe("recordFlakerTask", () => {
  it("runs the task, writes report artifacts, and imports them into flaker", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-record-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");

    let taskInvocation:
      | {
          command: string;
          args: string[];
          cwd: string;
        }
      | undefined;
    let importInvocation:
      | {
          args: string[];
          repoRoot: string;
        }
      | undefined;

    const result = recordFlakerTask(
      parseFlakerTaskRecordArgs([
        "--task",
        "paint-vrt",
        "--flaker-cli",
        "/tmp/flaker-cli.js",
        "--",
        "--workers",
        "1",
      ]),
      {
        repoRoot,
        spawnTask: (command, args, options) => {
          taskInvocation = { command, args, cwd: options.cwd };
          return {
            status: 0,
            stdout: PLAYWRIGHT_REPORT,
            stderr: "debug stderr",
          };
        },
        importTaskRun: (importArgs, runOptions) => {
          importInvocation = {
            args: importArgs.flakerArgs,
            repoRoot: runOptions.repoRoot,
          };
          return 0;
        },
        detectGitMetadata: () => ({
          commitSha: "abc123",
          branch: "main",
        }),
      },
    );

    expect(result.exitCode).toBe(0);
    expect(result.taskExitCode).toBe(0);
    expect(result.importExitCode).toBe(0);
    expect(taskInvocation).toEqual({
      command: "pnpm",
      args: [
        "--dir",
        repoRoot,
        "exec",
        "playwright",
        "test",
        "tests/paint-vrt.test.ts",
        "--workers",
        "1",
        "--reporter",
        "json",
      ],
      cwd: repoRoot,
    });
    expect(importInvocation).toEqual({
      args: [
        "import",
        result.reportPath,
        "--adapter",
        "playwright",
        "--commit",
        "abc123",
        "--branch",
        "main",
      ],
      repoRoot,
    });
    expect(fs.readFileSync(result.reportPath, "utf8")).toBe(PLAYWRIGHT_REPORT);
    expect(result.summaryJsonPath).toBeTruthy();
    expect(result.summaryMarkdownPath).toBeTruthy();
    expect(fs.readFileSync(result.summaryJsonPath!, "utf8")).toContain('"label": "paint-vrt"');
    expect(fs.readFileSync(result.summaryMarkdownPath!, "utf8")).toContain("# Playwright Report Summary");
    expect(
      fs.readFileSync(
        path.join(path.dirname(result.reportPath), "playwright.stderr.log"),
        "utf8",
      ),
    ).toBe("debug stderr");
  });

  it("returns the task exit code even when import succeeds", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-record-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");

    const result = recordFlakerTask(
      parseFlakerTaskRecordArgs([
        "--task",
        "paint-vrt",
        "--flaker-cli",
        "/tmp/flaker-cli.js",
      ]),
      {
        repoRoot,
        spawnTask: () => ({
          status: 1,
          stdout: PLAYWRIGHT_REPORT,
          stderr: "",
        }),
        detectGitMetadata: () => ({
          commitSha: "abc123",
          branch: "main",
        }),
        importTaskRun: () => 0,
      },
    );

    expect(result.exitCode).toBe(1);
    expect(result.taskExitCode).toBe(1);
    expect(result.importExitCode).toBe(0);
  });
});

describe("runFlakerTaskRecordCli", () => {
  it("returns a text summary and exit code from recordFlakerTask", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-record-cli-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");

    const result = runFlakerTaskRecordCli(
      [
        "--task",
        "paint-vrt",
        "--flaker-cli",
        "/tmp/flaker-cli.js",
      ],
      {
        repoRoot,
        spawnTask: () => ({
          status: 0,
          stdout: PLAYWRIGHT_REPORT,
          stderr: "",
        }),
        detectGitMetadata: () => ({
          commitSha: "abc123",
          branch: "main",
        }),
        importTaskRun: () => 0,
      },
    );

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("task: paint-vrt");
    expect(result.stdout).toContain("task_exit: 0");
    expect(result.stdout).toContain("import_exit: 0");
  });
});
