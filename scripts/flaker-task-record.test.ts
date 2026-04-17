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
      "--vrt-summary-dir",
      ".flaker/vrt-summary",
      "--",
      "--workers",
      "1",
    ]);

    expect(args).toMatchObject({
      taskId: "paint-vrt",
      reportPath: ".flaker/report.json",
      vrtSummaryDir: ".flaker/vrt-summary",
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
  it("runs the task, writes report artifacts, writes VRT summaries, and imports them into flaker", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-record-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");
    fs.mkdirSync(path.join(repoRoot, "output", "playwright", "vrt", "fixture-card"), { recursive: true });
    fs.writeFileSync(
      path.join(repoRoot, "output", "playwright", "vrt", "fixture-card", "report.json"),
      JSON.stringify({
        width: 960,
        height: 720,
        diffPixels: 1200,
        totalPixels: 691200,
        diffRatio: 0.03,
        threshold: 0.3,
        maxDiffRatio: 0.15,
      }),
      "utf8",
    );

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
        "--vrt-summary-dir",
        "flaker-daily/paint-vrt/vrt-summary",
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
    expect(result.vrtSummaryJsonPath).toBeTruthy();
    expect(result.vrtSummaryMarkdownPath).toBeTruthy();
    expect(fs.readFileSync(result.vrtSummaryJsonPath!, "utf8")).toContain('"suite": "vrt-artifact-summary"');
    expect(fs.readFileSync(result.vrtSummaryMarkdownPath!, "utf8")).toContain("# VRT Artifact Summary");
    expect(
      fs.readFileSync(
        path.join(path.dirname(result.reportPath), "playwright.stderr.log"),
        "utf8",
      ),
    ).toBe("debug stderr");
  });

  it("writes WPT VRT summaries when wpt-vrt raw results exist", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-record-wpt-vrt-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");
    fs.mkdirSync(path.join(repoRoot, "output", "playwright", "vrt", "wpt"), { recursive: true });
    fs.writeFileSync(
      path.join(repoRoot, "output", "playwright", "vrt", "wpt", "wpt-vrt-results.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "wpt-vrt",
        generatedAt: "2026-04-02T00:00:00.000Z",
        shard: {
          name: "wpt-vrt",
          modules: ["css-flexbox"],
          offset: 0,
          limit: 10,
        },
        summary: {
          total: 2,
          expectedTotal: 3,
          passed: 1,
          failed: 1,
          regressions: 1,
        },
        tests: {
          "css-flexbox/gap-001.html": {
            diffRatio: 0.02,
            status: "pass",
            baselineDiffRatio: 0.01,
            regressionLimit: 0.03,
            headroom: 0.01,
          },
          "css-flexbox/gap-002.html": {
            diffRatio: 0.08,
            status: "fail",
            baselineDiffRatio: 0.03,
            regressionLimit: 0.04,
            headroom: -0.04,
          },
        },
      }),
      "utf8",
    );

    const result = recordFlakerTask(
      parseFlakerTaskRecordArgs([
        "--task",
        "wpt-vrt",
        "--flaker-cli",
        "/tmp/flaker-cli.js",
        "--vrt-summary-dir",
        "flaker-daily/wpt-vrt/vrt-summary",
      ]),
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

    expect(result.wptVrtSummaryJsonPath).toBe(
      path.resolve(repoRoot, "flaker-daily/wpt-vrt/wpt-vrt-summary/wpt-vrt.json"),
    );
    expect(result.wptVrtSummaryMarkdownPath).toBe(
      path.resolve(repoRoot, "flaker-daily/wpt-vrt/wpt-vrt-summary/wpt-vrt.md"),
    );
    expect(fs.readFileSync(result.wptVrtSummaryJsonPath!, "utf8")).toContain('"suite": "wpt-vrt"');
    expect(fs.readFileSync(result.wptVrtSummaryMarkdownPath!, "utf8")).toContain("# WPT VRT Shard Summary");
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
