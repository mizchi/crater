import { describe, expect, it } from "vitest";
import {
  renderAffectedTaskList,
  renderAffectedTasksMarkdown,
  renderMarkdownSummary,
  renderTaskList,
} from "./flaker-config-report.ts";
import type { FlakerSelection, FlakerSummary } from "./flaker-config.ts";

const SUMMARY: FlakerSummary = {
  workflow: {
    name: "crater-tests",
    maxParallel: 4,
  },
  nodeCount: 2,
  taskCount: 1,
  managedSpecs: ["tests/paint-vrt.test.ts"],
  unmanagedSpecs: ["tests/unmanaged.test.ts"],
  tasks: [
    {
      id: "paint-vrt",
      node: "layout",
      specs: ["tests/paint-vrt.test.ts"],
      grep: "Paint VRT",
      needs: ["wpt-vrt"],
      trigger: "auto",
      srcCount: 2,
      command: ["pnpm", "exec", "playwright", "test"],
    },
  ],
  errors: [
    {
      severity: "error",
      code: "duplicate-spec-ownership",
      message: "duplicate ownership",
    },
  ],
  warnings: [
    {
      severity: "warning",
      code: "unmanaged-spec",
      message: "unmanaged spec",
    },
  ],
  generatedAt: "2026-04-02T00:00:00.000Z",
};

const SELECTION: FlakerSelection = {
  changedPaths: ["src/layout/block.mbt", "docs/notes.md"],
  matchedTaskIds: ["paint-vrt"],
  selectedTaskIds: ["paint-vrt", "wpt-vrt"],
  unmatchedPaths: ["docs/notes.md"],
  selectedTasks: [
    {
      id: "paint-vrt",
      node: "layout",
      specs: ["tests/paint-vrt.test.ts"],
      needs: [],
      command: ["pnpm", "exec", "playwright", "test"],
      matchReasons: ["srcs:src/layout/** <= src/layout/block.mbt"],
      includedBy: [],
    },
    {
      id: "wpt-vrt",
      node: "layout",
      specs: ["tests/wpt-vrt.test.ts"],
      needs: [],
      command: ["pnpm", "exec", "playwright", "test"],
      matchReasons: [],
      includedBy: ["paint-vrt"],
    },
  ],
  generatedAt: "2026-04-02T00:00:00.000Z",
};

describe("flaker-config-report", () => {
  it("renders summary markdown", () => {
    const markdown = renderMarkdownSummary(SUMMARY);

    expect(markdown).toContain("# Flaker Config Summary");
    expect(markdown).toContain("| Workflow | crater-tests |");
    expect(markdown).toContain("| paint-vrt | layout |");
    expect(markdown).toContain("## Errors");
    expect(markdown).toContain("## Warnings");
    expect(markdown).toContain("## Unmanaged Specs");
  });

  it("renders affected selection markdown and plain list", () => {
    const markdown = renderAffectedTasksMarkdown(SELECTION);
    const list = renderAffectedTaskList(SELECTION);

    expect(markdown).toContain("# Flaker Affected Tasks");
    expect(markdown).toContain("| Changed paths | 2 |");
    expect(markdown).toContain("| paint-vrt |  | srcs:src/layout/** <= src/layout/block.mbt |");
    expect(markdown).toContain("## Unmatched Paths");
    expect(list).toContain("paint-vrt\tsrcs:src/layout/** <= src/layout/block.mbt");
    expect(list).toContain("wpt-vrt\tdependency [included-by=paint-vrt]");
    expect(list).toContain("UNMATCHED\tdocs/notes.md");
  });

  it("renders managed task list", () => {
    const list = renderTaskList(SUMMARY);

    expect(list).toBe("paint-vrt\ttests/paint-vrt.test.ts [grep=Paint VRT]\n");
  });
});
