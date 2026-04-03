import { describe, expect, it } from "vitest";
import { parseFlakerStar } from "./flaker-config-parser.ts";
import {
  loadFlakerSelectionInputs,
  selectAffectedTasks,
} from "./flaker-config-selection.ts";

describe("flaker-config-selection", () => {
  it("normalizes changed paths and resolves task summaries before selection", () => {
    const config = parseFlakerStar(`
workflow(name="example", max_parallel=1)
node(id="layout", depends_on=[])
task(
  id="paint-vrt",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "./tests/paint-vrt.test.ts"],
  srcs=["src/layout/**"],
  trigger="auto",
)
`);

    const inputs = loadFlakerSelectionInputs(
      config,
      ["/repo/src/layout/block.mbt", "./tests/paint-vrt.test.ts"],
      "/repo",
    );

    expect(inputs.changedPaths).toEqual([
      "src/layout/block.mbt",
      "tests/paint-vrt.test.ts",
    ]);
    expect(inputs.tasks.map((task) => ({ id: task.id, specs: task.specs }))).toEqual([
      {
        id: "paint-vrt",
        specs: ["tests/paint-vrt.test.ts"],
      },
    ]);
  });

  it("selects matching tasks and expands task dependencies directly", () => {
    const config = parseFlakerStar(`
workflow(name="example", max_parallel=1)
node(id="layout", depends_on=[])
node(id="browser", depends_on=[])
node(id="fullstack", depends_on=["layout", "browser"])
task(
  id="paint-vrt",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
  srcs=["src/layout/**"],
  trigger="auto",
)
task(
  id="playwright-adapter",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/playwright-adapter.test.ts"],
  srcs=["browser/**"],
  trigger="auto",
)
task(
  id="website-loading",
  node="fullstack",
  cmd=["pnpm", "exec", "playwright", "test", "tests/website-loading.test.ts"],
  srcs=["src/layout/**", "tests/helpers/**"],
  needs=["paint-vrt", "playwright-adapter"],
  trigger="auto",
)
`);

    const selection = selectAffectedTasks(config, ["src/layout/block.mbt"]);

    expect(selection.selectedTaskIds).toEqual([
      "paint-vrt",
      "playwright-adapter",
      "website-loading",
    ]);
    expect(selection.matchedTaskIds).toEqual(["paint-vrt", "website-loading"]);
  });
});
