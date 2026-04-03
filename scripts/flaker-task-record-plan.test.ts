import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildFlakerTaskRecordImportRunArgs,
  prepareFlakerTaskRecordPlan,
  type FlakerTaskRecordPlanArgs,
} from "./flaker-task-record-plan.ts";

const REPO_ROOT = path.resolve(import.meta.dirname, "..");
const FLAKER_STAR = fs.readFileSync(path.join(REPO_ROOT, "flaker.star"), "utf8");

function buildArgs(): FlakerTaskRecordPlanArgs {
  return {
    taskId: "paint-vrt",
    owner: "mizchi",
    repo: "crater",
    configPath: "flaker.star",
    manifestPath: "flaker-quarantine.json",
    workspaceRoot: ".flaker/tasks",
    flakerCliPath: "/tmp/flaker-cli.js",
    taskArgs: ["--workers", "1"],
  };
}

describe("prepareFlakerTaskRecordPlan", () => {
  it("builds workspace, paths, and task command from flaker.star", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-plan-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");

    const plan = prepareFlakerTaskRecordPlan(buildArgs(), repoRoot);

    expect(plan.taskId).toBe("paint-vrt");
    expect(plan.workspace.workspaceDir).toBe(path.join(repoRoot, ".flaker/tasks/paint-vrt"));
    expect(plan.paths.reportPath).toBe(
      path.join(repoRoot, ".flaker/tasks/paint-vrt/latest/playwright-report.json"),
    );
    expect(plan.taskCommand).toEqual([
      "pnpm",
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
    ]);
  });
});

describe("buildFlakerTaskRecordImportRunArgs", () => {
  it("wraps import args into task-scoped flaker run arguments", () => {
    const runArgs = buildFlakerTaskRecordImportRunArgs(buildArgs(), [
      "import",
      "/tmp/report.json",
      "--adapter",
      "playwright",
    ]);

    expect(runArgs).toEqual({
      taskId: "paint-vrt",
      owner: "mizchi",
      repo: "crater",
      configPath: "flaker.star",
      manifestPath: "flaker-quarantine.json",
      workspaceRoot: ".flaker/tasks",
      flakerCliPath: "/tmp/flaker-cli.js",
      flakerArgs: [
        "import",
        "/tmp/report.json",
        "--adapter",
        "playwright",
      ],
    });
  });
});
