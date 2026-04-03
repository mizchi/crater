import { describe, expect, it } from "vitest";
import { buildFlakerSelection } from "./flaker-config-selection-core.ts";
import type { ResolvedFlakerTask } from "./flaker-config-task.ts";

function makeTask(
  id: string,
  overrides?: Partial<ResolvedFlakerTask>,
): ResolvedFlakerTask {
  return {
    id,
    node: "browser",
    specs: [`tests/${id}.test.ts`],
    grep: undefined,
    grepInvert: undefined,
    trigger: "auto",
    needs: [],
    srcCount: 1,
    command: ["pnpm", "exec", "playwright", "test", `tests/${id}.test.ts`],
    srcs: [`src/${id}/**`],
    ...overrides,
  };
}

describe("buildFlakerSelection", () => {
  it("selects direct matches and expands task dependencies from prepared inputs", () => {
    const selection = buildFlakerSelection({
      changedPaths: ["src/layout/block.mbt", "docs/notes.md"],
      tasks: [
        makeTask("paint-vrt", {
          node: "layout",
          specs: ["tests/paint-vrt.test.ts"],
          srcs: ["src/layout/**"],
        }),
        makeTask("playwright-adapter", {
          node: "browser",
          specs: ["tests/playwright-adapter.test.ts"],
          srcs: ["browser/**"],
        }),
        makeTask("website-loading", {
          node: "fullstack",
          specs: ["tests/website-loading.test.ts"],
          srcs: ["src/layout/**", "tests/helpers/**"],
          needs: ["paint-vrt", "playwright-adapter"],
        }),
      ],
    });

    expect(selection.changedPaths).toEqual(["src/layout/block.mbt", "docs/notes.md"]);
    expect(selection.matchedTaskIds).toEqual(["paint-vrt", "website-loading"]);
    expect(selection.selectedTaskIds).toEqual([
      "paint-vrt",
      "playwright-adapter",
      "website-loading",
    ]);
    expect(selection.unmatchedPaths).toEqual(["docs/notes.md"]);
    expect(selection.selectedTasks.find((task) => task.id === "website-loading")?.matchReasons).toEqual([
      "srcs:src/layout/** <= src/layout/block.mbt",
    ]);
    expect(selection.selectedTasks.find((task) => task.id === "playwright-adapter")?.includedBy).toEqual([
      "website-loading",
    ]);
  });
});
