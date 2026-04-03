import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  discoverPlaywrightSpecs,
  loadFlakerConfigSummaryInputs,
  parseFlakerConfigArgs,
  parseFlakerStar,
  runFlakerConfigCli,
  selectAffectedTasks,
  summarizeFlakerConfig,
} from "./flaker-config.ts";

const tmpDirs: string[] = [];

function makeTempDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-"));
  tmpDirs.push(dir);
  return dir;
}

function writeFile(root: string, relativePath: string, content = ""): void {
  const filePath = path.join(root, relativePath);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, "utf8");
}

afterEach(() => {
  while (tmpDirs.length > 0) {
    fs.rmSync(tmpDirs.pop()!, { recursive: true, force: true });
  }
});

describe("parseFlakerConfigArgs", () => {
  it("parses check/list/json flags", () => {
    const options = parseFlakerConfigArgs([
      "--tests-dir",
      "custom-tests",
      "--json",
      "out.json",
      "--check",
      "--list",
    ]);

    expect(options).toMatchObject({
      configPath: "flaker.star",
      testsDir: "custom-tests",
      jsonOutput: "out.json",
      check: true,
      listOnly: true,
      selectMode: false,
      changedPaths: [],
    });
  });

  it("treats remaining args after --select as changed paths", () => {
    const options = parseFlakerConfigArgs([
      "--config",
      "alt.star",
      "--select",
      "src/layout/block.mbt",
      "--not-a-flag",
    ]);

    expect(options).toMatchObject({
      configPath: "alt.star",
      selectMode: true,
      changedPaths: ["src/layout/block.mbt", "--not-a-flag"],
    });
  });
});

describe("parseFlakerStar", () => {
  it("parses workflow, nodes, and task commands with grep filters", () => {
    const config = parseFlakerStar(`
workflow(name="example", max_parallel=2)

node(id="browser", depends_on=[])

task(
  id="website-loading",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/website-loading.test.ts", "--grep", "Website Loading Tests"],
  srcs=["src/bidi/**"],
  trigger="auto",
)
`);

    expect(config.workflow?.name).toBe("example");
    expect(config.workflow?.maxParallel).toBe(2);
    expect(config.nodes).toEqual([
      { id: "browser", dependsOn: [] },
    ]);
    expect(config.tasks).toHaveLength(1);
    expect(config.tasks[0]?.cmd).toEqual([
      "pnpm",
      "exec",
      "playwright",
      "test",
      "tests/website-loading.test.ts",
      "--grep",
      "Website Loading Tests",
    ]);
  });
});

describe("summarizeFlakerConfig", () => {
  it("reports duplicate unfiltered ownership and unmanaged specs", () => {
    const root = makeTempDir();
    writeFile(root, "tests/a.test.ts");
    writeFile(root, "tests/b.test.ts");
    writeFile(root, "tests/c.test.ts");

    const config = parseFlakerStar(`
workflow(name="example", max_parallel=1)
node(id="browser", depends_on=[])
task(
  id="task-a",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/a.test.ts"],
  srcs=["src/**"],
  trigger="auto",
)
task(
  id="task-b",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/a.test.ts"],
  srcs=["src/**"],
  trigger="auto",
)
task(
  id="task-c",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/b.test.ts"],
  srcs=["src/**"],
  trigger="auto",
)
`);

    const summary = summarizeFlakerConfig(config, { cwd: root });

    expect(summary.errors.map((issue) => issue.code)).toContain("duplicate-spec-ownership");
    expect(summary.unmanagedSpecs).toEqual(["tests/c.test.ts"]);
  });

  it("allows shared specs when commands are split by grep", () => {
    const root = makeTempDir();
    writeFile(root, "tests/website-loading.test.ts");

    const config = parseFlakerStar(`
workflow(name="example", max_parallel=1)
node(id="browser", depends_on=[])
task(
  id="website-loading",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/website-loading.test.ts", "--grep", "Website Loading Tests"],
  srcs=["src/**"],
  trigger="auto",
)
task(
  id="script-edge-cases",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/website-loading.test.ts", "--grep", "Script Execution Edge Cases"],
  srcs=["src/**"],
  trigger="auto",
)
`);

    const summary = summarizeFlakerConfig(config, { cwd: root });

    expect(summary.errors).toEqual([]);
    expect(summary.unmanagedSpecs).toEqual([]);
  });
});

describe("discoverPlaywrightSpecs", () => {
  it("ignores benchmark specs by default", () => {
    const root = makeTempDir();
    writeFile(root, "tests/alpha.test.ts");
    writeFile(root, "tests/playwright-benchmark.test.ts");

    expect(discoverPlaywrightSpecs(root)).toEqual(["tests/alpha.test.ts"]);
  });
});

describe("loadFlakerConfigSummaryInputs", () => {
  it("resolves task summaries and existing spec set from disk", () => {
    const root = makeTempDir();
    writeFile(root, "tests/alpha.test.ts");
    const config = parseFlakerStar(`
workflow(name="example", max_parallel=1)
node(id="browser", depends_on=[])
task(
  id="task-a",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "./tests/alpha.test.ts"],
  srcs=["src/**"],
  trigger="auto",
)
task(
  id="task-b",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/missing.test.ts"],
  srcs=["src/**"],
  trigger="auto",
)
`);

    const inputs = loadFlakerConfigSummaryInputs(config, { cwd: root });

    expect(inputs.discoveredSpecs).toEqual(["tests/alpha.test.ts"]);
    expect(inputs.tasks.map((task) => ({ id: task.id, specs: task.specs }))).toEqual([
      { id: "task-a", specs: ["tests/alpha.test.ts"] },
      { id: "task-b", specs: ["tests/missing.test.ts"] },
    ]);
    expect(inputs.existingSpecs).toEqual(new Set(["tests/alpha.test.ts"]));
  });
});

describe("selectAffectedTasks", () => {
  it("selects tasks from src globs and expands task dependencies", () => {
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
    expect(selection.selectedTasks.find((task) => task.id === "website-loading")?.matchReasons).toEqual([
      "srcs:src/layout/** <= src/layout/block.mbt",
    ]);
    expect(selection.selectedTasks.find((task) => task.id === "playwright-adapter")?.includedBy).toEqual([
      "website-loading",
    ]);
  });

  it("selects owning task when a Playwright spec changes directly", () => {
    const config = parseFlakerStar(`
workflow(name="example", max_parallel=1)
node(id="layout", depends_on=[])
task(
  id="paint-vrt",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
  srcs=["src/layout/**"],
  trigger="auto",
)
`);

    const selection = selectAffectedTasks(config, ["tests/paint-vrt.test.ts"]);

    expect(selection.selectedTaskIds).toEqual(["paint-vrt"]);
    expect(selection.selectedTasks[0]?.matchReasons).toEqual([
      "spec:tests/paint-vrt.test.ts",
    ]);
  });

  it("reports unmatched paths when no task owns the change", () => {
    const config = parseFlakerStar(`
workflow(name="example", max_parallel=1)
node(id="layout", depends_on=[])
task(
  id="paint-vrt",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
  srcs=["src/layout/**"],
  trigger="auto",
)
`);

    const selection = selectAffectedTasks(config, ["docs/notes.md"]);

    expect(selection.selectedTaskIds).toEqual([]);
    expect(selection.unmatchedPaths).toEqual(["docs/notes.md"]);
  });
});

describe("repo flaker config", () => {
  it("covers all managed Playwright specs without validation errors", () => {
    const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
    const star = fs.readFileSync(path.join(repoRoot, "flaker.star"), "utf8");
    const config = parseFlakerStar(star);
    const summary = summarizeFlakerConfig(config, { cwd: repoRoot });

    expect(summary.errors).toEqual([]);
    expect(summary.unmanagedSpecs).toEqual([]);
  });
});

describe("runFlakerConfigCli", () => {
  it("renders list output without side effects when requested", () => {
    const root = makeTempDir();
    writeFile(root, "tests/a.test.ts");
    writeFile(
      root,
      "flaker.star",
      `
workflow(name="example", max_parallel=1)
node(id="browser", depends_on=[])
task(
  id="task-a",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/a.test.ts"],
  srcs=["src/**"],
  trigger="auto",
)
`,
    );

    const result = runFlakerConfigCli(["--list"], { cwd: root });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toBe("task-a\ttests/a.test.ts\n");
    expect(result.writes).toEqual([]);
  });
});
