import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { parseFlakerStar } from "./flaker-config-parser.ts";
import {
  discoverPlaywrightSpecs,
  summarizeFlakerConfig,
} from "./flaker-config-summary.ts";

const tmpDirs: string[] = [];

function makeTempDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-summary-"));
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

describe("flaker-config-summary", () => {
  it("discovers specs while excluding benchmark fixtures", () => {
    const root = makeTempDir();
    writeFile(root, "tests/alpha.test.ts");
    writeFile(root, "tests/beta.spec.ts");
    writeFile(root, "tests/gamma.test.tsx");
    writeFile(root, "tests/delta.spec.tsx");
    writeFile(root, "tests/playwright-benchmark.test.ts");

    expect(discoverPlaywrightSpecs(root)).toEqual([
      "tests/alpha.test.ts",
      "tests/beta.spec.ts",
      "tests/delta.spec.tsx",
      "tests/gamma.test.tsx",
    ]);
  });

  it("summarizes ownership and unmanaged specs directly", () => {
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
});
