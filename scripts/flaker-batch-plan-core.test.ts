import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildFlakerBatchPlan,
  renderFlakerBatchPlanMarkdown,
  renderGitHubMatrix,
} from "./flaker-batch-plan-core.ts";

const REPO_ROOT = path.resolve(import.meta.dirname, "..");
const FLAKER_STAR = fs.readFileSync(path.join(REPO_ROOT, "flaker.star"), "utf8");

describe("buildFlakerBatchPlan", () => {
  it("selects auto-trigger tasks by default", () => {
    const plan = buildFlakerBatchPlan(FLAKER_STAR);

    expect(plan.workflowName).toBe("crater-tests");
    expect(plan.tasks.map((task) => task.id)).toEqual([
      "bidi-e2e",
      "browser-user-scenarios",
      "crater-playwright-adapter",
      "paint-vrt",
      "paint-vrt-levels",
      "paint-vrt-responsive",
      "playwright-adapter",
      "playwright-adapter-user-scenarios",
      "preact-compat",
      "script-execution-edge-cases",
      "scroll-issue",
      "website-loading",
      "wpt-vrt",
    ]);
  });

  it("filters by task ids and nodes", () => {
    const plan = buildFlakerBatchPlan(FLAKER_STAR, {
      tasks: ["paint-vrt", "wpt-vrt", "playwright-adapter"],
      nodes: ["layout"],
    });

    expect(plan.tasks.map((task) => task.id)).toEqual(["paint-vrt", "wpt-vrt"]);
  });
});

describe("renderers", () => {
  it("renders markdown and GitHub matrix output", () => {
    const plan = buildFlakerBatchPlan(FLAKER_STAR, { tasks: ["paint-vrt", "wpt-vrt"] });

    expect(renderFlakerBatchPlanMarkdown(plan)).toContain("| paint-vrt | layout |");
    expect(renderGitHubMatrix(plan)).toBe(
      JSON.stringify({
        include: [
          { task_id: "paint-vrt", node: "layout" },
          { task_id: "wpt-vrt", node: "layout" },
        ],
      }),
    );
  });
});
