import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  discoverPlaywrightSpecs,
  parseFlakerStar,
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
