import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { parseFlakerStar } from "./flaker-config.ts";
import { parseFlakerQuarantine } from "./flaker-quarantine-parser.ts";
import { loadFlakerQuarantineSummaryInputs } from "./flaker-quarantine-loader.ts";

const tmpDirs: string[] = [];

function makeTempDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-quarantine-loader-"));
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

describe("loadFlakerQuarantineSummaryInputs", () => {
  it("normalizes spec paths and resolves existing specs from disk", () => {
    const root = makeTempDir();
    writeFile(root, "tests/paint-vrt.test.ts");
    const flaker = parseFlakerStar(`
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
    const quarantine = parseFlakerQuarantine(`
{
  "schemaVersion": 1,
  "entries": [
    {
      "id": "paint-vrt-entry",
      "taskId": "paint-vrt",
      "spec": "./tests/paint-vrt.test.ts",
      "titlePattern": "^fixture:",
      "mode": "skip",
      "scope": "environment",
      "owner": "mizchi",
      "reason": "Example",
      "condition": "Never",
      "introducedAt": "2026-04-01",
      "expiresAt": "2026-04-30"
    }
  ]
}
`);

    const inputs = loadFlakerQuarantineSummaryInputs(quarantine, flaker, {
      cwd: root,
    });

    expect(inputs.tasks).toEqual([
      {
        id: "paint-vrt",
        specs: ["tests/paint-vrt.test.ts"],
      },
    ]);
    expect(inputs.quarantine.entries[0]?.spec).toBe("tests/paint-vrt.test.ts");
    expect(inputs.existingSpecs.has("tests/paint-vrt.test.ts")).toBe(true);
  });
});
