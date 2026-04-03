import { describe, expect, it } from "vitest";
import type { FlakerConfig } from "./flaker-config.ts";
import { buildFlakerConfigSummary } from "./flaker-config-summary-core.ts";
import type { ResolvedFlakerTask } from "./flaker-config-task.ts";

function makeTask(
  id: string,
  spec: string,
  overrides?: Partial<ResolvedFlakerTask>,
): ResolvedFlakerTask {
  return {
    id,
    node: "browser",
    specs: [spec],
    grep: undefined,
    grepInvert: undefined,
    trigger: "auto",
    needs: [],
    srcCount: 1,
    command: ["pnpm", "exec", "playwright", "test", spec],
    srcs: ["src/**"],
    ...overrides,
  };
}

describe("buildFlakerConfigSummary", () => {
  it("validates duplicate ownership, missing specs, and unmanaged specs from prepared inputs", () => {
    const config: FlakerConfig = {
      workflow: { name: "example", maxParallel: 1 },
      nodes: [{ id: "browser", dependsOn: [] }],
      tasks: [
        {
          id: "task-a",
          node: "browser",
          cmd: ["pnpm", "exec", "playwright", "test", "tests/a.test.ts"],
          srcs: ["src/**"],
          needs: [],
          trigger: "auto",
        },
        {
          id: "task-b",
          node: "browser",
          cmd: ["pnpm", "exec", "playwright", "test", "tests/a.test.ts"],
          srcs: ["src/**"],
          needs: [],
          trigger: "auto",
        },
      ],
    };

    const summary = buildFlakerConfigSummary({
      config,
      tasks: [
        makeTask("task-a", "tests/a.test.ts"),
        makeTask("task-b", "tests/a.test.ts"),
        makeTask("task-c", "tests/missing.test.ts", {
          node: "missing-node",
        }),
      ],
      discoveredSpecs: ["tests/a.test.ts", "tests/c.test.ts"],
      existingSpecs: new Set(["tests/a.test.ts"]),
    });

    expect(summary.taskCount).toBe(2);
    expect(summary.managedSpecs).toEqual(["tests/a.test.ts", "tests/missing.test.ts"]);
    expect(summary.unmanagedSpecs).toEqual(["tests/c.test.ts"]);
    expect(summary.errors.map((issue) => issue.code)).toEqual([
      "missing-spec-file",
      "duplicate-spec-ownership",
    ]);
    expect(summary.warnings.map((issue) => issue.code)).toEqual(["unmanaged-spec"]);
  });
});
