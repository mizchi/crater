import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  parseFlakerBatchPlanArgs,
  runFlakerBatchPlanCli,
} from "./flaker-batch-plan.ts";

describe("parseFlakerBatchPlanArgs", () => {
  it("parses tasks, nodes, and output flags", () => {
    const args = parseFlakerBatchPlanArgs([
      "--tasks",
      "paint-vrt,wpt-vrt",
      "--nodes",
      "layout",
      "--json",
      "out/plan.json",
      "--github-matrix",
    ]);

    expect(args).toMatchObject({
      tasks: ["paint-vrt", "wpt-vrt"],
      nodes: ["layout"],
      jsonOutput: "out/plan.json",
      githubMatrix: true,
    });
  });
});

describe("runFlakerBatchPlanCli", () => {
  it("returns markdown stdout and optional artifact writes", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-batch-plan-"));
    fs.writeFileSync(
      path.join(root, "flaker.star"),
      `
workflow(name="example", max_parallel=1)
node(id="layout", depends_on=[])
task(
  id="paint-vrt",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
  srcs=["src/layout/**"],
  trigger="auto",
)
`,
      "utf8",
    );

    const result = runFlakerBatchPlanCli([
      "--markdown",
      "out/plan.md",
      "--json",
      "out/plan.json",
    ], { cwd: root });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# Flaker Batch Plan");
    expect(result.writes).toEqual([
      {
        path: path.resolve(root, "out/plan.md"),
        content: expect.stringContaining("# Flaker Batch Plan"),
      },
      {
        path: path.resolve(root, "out/plan.json"),
        content: expect.stringContaining('"schemaVersion": 1'),
      },
    ]);
  });

  it("prints GitHub matrix JSON when requested", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-batch-plan-"));
    fs.writeFileSync(
      path.join(root, "flaker.star"),
      `
workflow(name="example", max_parallel=1)
node(id="layout", depends_on=[])
task(
  id="paint-vrt",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
  srcs=["src/layout/**"],
  trigger="auto",
)
`,
      "utf8",
    );

    const result = runFlakerBatchPlanCli(["--github-matrix"], { cwd: root });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toBe(
      JSON.stringify({
        include: [{ task_id: "paint-vrt", node: "layout" }],
      }),
    );
  });
});
