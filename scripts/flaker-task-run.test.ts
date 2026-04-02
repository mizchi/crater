import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  parseFlakerTaskRunArgs,
  prepareFlakerTaskWorkspace,
  resolveDefaultFlakerCliPath,
  runFlakerTask,
  runFlakerTaskRunCli,
} from "./flaker-task-run.ts";

const REPO_ROOT = path.resolve(import.meta.dirname, "..");
const FLAKER_STAR = fs.readFileSync(path.join(REPO_ROOT, "flaker.star"), "utf8");

describe("parseFlakerTaskRunArgs", () => {
  it("parses task options and forwards flaker args after --", () => {
    const args = parseFlakerTaskRunArgs([
      "--task",
      "paint-vrt",
      "--workspace-root",
      ".flaker/tasks",
      "--",
      "sample",
      "--count",
      "5",
      "--skip-quarantined",
    ]);

    expect(args).toMatchObject({
      taskId: "paint-vrt",
      workspaceRoot: ".flaker/tasks",
      flakerArgs: ["sample", "--count", "5", "--skip-quarantined"],
    });
  });
});

describe("prepareFlakerTaskWorkspace", () => {
  it("writes absolute-path flaker.toml for task-scoped execution", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-run-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");

    const prepared = prepareFlakerTaskWorkspace(repoRoot, FLAKER_STAR, {
      taskId: "paint-vrt",
      owner: "mizchi",
      repo: "crater",
      manifestPath: "flaker-quarantine.json",
      workspaceRoot: ".flaker/tasks",
    });

    expect(prepared.workspaceDir).toBe(path.join(repoRoot, ".flaker/tasks/paint-vrt"));
    expect(prepared.storagePath).toBe(path.join(repoRoot, ".flaker/data"));
    expect(prepared.toml).toContain(
      `command = "pnpm --dir ${repoRoot} exec playwright test tests/paint-vrt.test.ts"`,
    );
    expect(prepared.toml).toContain(`path = "${path.join(repoRoot, ".flaker/data")}"`);
    expect(prepared.toml).toContain(
      `manifest = "${path.join(repoRoot, "flaker-quarantine.json")}"`,
    );
    expect(fs.existsSync(prepared.configPath)).toBe(true);
  });
});

describe("resolveDefaultFlakerCliPath", () => {
  it("falls back to sibling metric-ci source when dist is not available", () => {
    const resolved = resolveDefaultFlakerCliPath("/Users/mz/ghq/github.com/mizchi/crater", (candidate) => {
      if (candidate.endsWith("/dist/cli/main.js")) {
        return false;
      }
      return candidate.endsWith("/src/cli/main.ts");
    });

    expect(resolved).toBe("/Users/mz/ghq/github.com/mizchi/metric-ci/src/cli/main.ts");
  });
});

describe("runFlakerTask", () => {
  it("invokes the built flaker CLI inside the generated workspace", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-run-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");

    let captured:
      | {
          command: string;
          args: string[];
          cwd: string;
          stdio: "inherit";
        }
      | undefined;

    const exitCode = runFlakerTask(
      parseFlakerTaskRunArgs([
        "--task",
        "paint-vrt",
        "--workspace-root",
        ".flaker/tasks",
        "--flaker-cli",
        "/tmp/flaker-cli.js",
        "--",
        "sample",
        "--count",
        "1",
      ]),
      {
        repoRoot,
        exists: () => true,
        spawn: (command, args, options) => {
          captured = { command, args, cwd: options.cwd, stdio: options.stdio };
          return { status: 0 };
        },
      },
    );

    expect(exitCode).toBe(0);
    expect(captured).toEqual({
      command: process.execPath,
      args: ["/tmp/flaker-cli.js", "sample", "--count", "1"],
      cwd: path.join(repoRoot, ".flaker/tasks/paint-vrt"),
      stdio: "inherit",
    });
  });

  it("warns when sample/run uses an empty shared metrics store", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-run-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");

    const warnings: string[] = [];

    const exitCode = runFlakerTask(
      parseFlakerTaskRunArgs([
        "--task",
        "paint-vrt",
        "--flaker-cli",
        "/tmp/flaker-cli.js",
        "--",
        "sample",
        "--count",
        "1",
      ]),
      {
        repoRoot,
        exists: () => false,
        warn: (message) => {
          warnings.push(message);
        },
        spawn: () => ({ status: 0 }),
      },
    );

    expect(exitCode).toBe(0);
    expect(warnings).toEqual([
      `No flaker metrics found at ${path.join(repoRoot, ".flaker/data")}. Seed it with \`just flaker task import paint-vrt <playwright-report.json>\` or \`just flaker task record paint-vrt\`.`,
    ]);
  });
});

describe("runFlakerTaskRunCli", () => {
  it("returns exit code and forwarded warnings", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-run-cli-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");

    const result = runFlakerTaskRunCli([
      "--task",
      "paint-vrt",
      "--flaker-cli",
      "/tmp/flaker-cli.js",
      "--",
      "sample",
      "--count",
      "1",
    ], {
      repoRoot,
      exists: () => false,
      warn: () => {},
      spawn: () => ({ status: 0 }),
    });

    expect(result.exitCode).toBe(0);
    expect(result.stderr).toContain("No flaker metrics found");
    expect(result.stderr).toContain("just flaker task import paint-vrt");
    expect(result.writes).toEqual([]);
  });
});
