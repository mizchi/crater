import { describe, expect, it } from "vitest";
import type { FlakerConfig, FlakerTask } from "./flaker-config-contract.ts";
import {
  isFilteredTask,
  resolveTaskSummaries,
  resolveTaskSummary,
} from "./flaker-config-task.ts";

describe("resolveTaskSummary", () => {
  it("extracts normalized specs, grep flags, and sorted needs", () => {
    const task: FlakerTask = {
      id: "website-loading",
      node: "browser",
      cmd: [
        "pnpm",
        "exec",
        "playwright",
        "test",
        "./tests/website-loading.test.ts",
        "--grep",
        "hero",
      ],
      srcs: ["src/layout/**", "tests/helpers/**"],
      needs: ["paint-vrt", "playwright-adapter"],
      trigger: "auto",
    };

    const resolved = resolveTaskSummary(task, "/repo");

    expect(resolved).toMatchObject({
      id: "website-loading",
      specs: ["tests/website-loading.test.ts"],
      grep: "hero",
      grepInvert: undefined,
      needs: ["paint-vrt", "playwright-adapter"],
      srcCount: 2,
    });
  });

  it("extracts Playwright spec files beyond .test.ts", () => {
    const task: FlakerTask = {
      id: "browser-ui",
      node: "browser",
      cmd: [
        "pnpm",
        "exec",
        "playwright",
        "test",
        "./tests/browser-ui.spec.ts",
        "tests/browser-ui.test.tsx",
        "tests/browser-ui.spec.tsx",
      ],
      srcs: ["src/browser/**"],
      needs: [],
      trigger: "auto",
    };

    const resolved = resolveTaskSummary(task, "/repo");

    expect(resolved.specs).toEqual([
      "tests/browser-ui.spec.ts",
      "tests/browser-ui.spec.tsx",
      "tests/browser-ui.test.tsx",
    ]);
  });
});

describe("resolveTaskSummaries", () => {
  it("maps every configured task", () => {
    const config: FlakerConfig = {
      workflow: { name: "example", maxParallel: 1 },
      nodes: [{ id: "browser", dependsOn: [] }],
      tasks: [
        {
          id: "paint-vrt",
          node: "browser",
          cmd: ["pnpm", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
          srcs: ["src/layout/**"],
          needs: [],
        },
      ],
    };

    expect(resolveTaskSummaries(config, "/repo")).toHaveLength(1);
    expect(resolveTaskSummaries(config, "/repo")[0]?.specs).toEqual([
      "tests/paint-vrt.test.ts",
    ]);
  });
});

describe("isFilteredTask", () => {
  it("returns true when grep or grepInvert is present", () => {
    expect(isFilteredTask({
      id: "paint-vrt",
      node: "browser",
      specs: ["tests/paint-vrt.test.ts"],
      grep: "hero",
      grepInvert: undefined,
      trigger: undefined,
      needs: [],
      srcCount: 1,
      command: ["pnpm"],
      srcs: ["src/**"],
    })).toBe(true);

    expect(isFilteredTask({
      id: "paint-vrt",
      node: "browser",
      specs: ["tests/paint-vrt.test.ts"],
      grep: undefined,
      grepInvert: undefined,
      trigger: undefined,
      needs: [],
      srcCount: 1,
      command: ["pnpm"],
      srcs: ["src/**"],
    })).toBe(false);
  });
});
