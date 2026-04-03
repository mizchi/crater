import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { parseFlakerStar } from "./flaker-config.ts";
import {
  findMatchingQuarantine,
  loadFlakerQuarantineSummaryInputs,
  parseFlakerQuarantineArgs,
  parseFlakerQuarantine,
  renderQuarantineMarkdown,
  runFlakerQuarantineCli,
  summarizeFlakerQuarantine,
} from "./flaker-quarantine.ts";

const tmpDirs: string[] = [];

function makeTempDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-quarantine-"));
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

describe("parseFlakerQuarantineArgs", () => {
  it("parses config, outputs, and check flag", () => {
    const options = parseFlakerQuarantineArgs([
      "--config",
      "alt-quarantine.json",
      "--flaker-config",
      "alt.star",
      "--tests-dir",
      "custom-tests",
      "--json",
      "out.json",
      "--markdown",
      "out.md",
      "--check",
    ]);

    expect(options).toMatchObject({
      quarantinePath: "alt-quarantine.json",
      flakerConfigPath: "alt.star",
      testsDir: "custom-tests",
      jsonOutput: "out.json",
      markdownOutput: "out.md",
      check: true,
    });
  });
});

describe("summarizeFlakerQuarantine", () => {
  it("validates task ownership, expiry, and renders markdown", () => {
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
      "id": "paint-vrt-real-world-local-assets",
      "taskId": "paint-vrt",
      "spec": "tests/paint-vrt.test.ts",
      "titlePattern": "^real-world snapshot:",
      "mode": "skip",
      "scope": "environment",
      "owner": "mizchi",
      "reason": "Optional real-world fixtures are not always present locally.",
      "condition": "Skip only when the named real-world snapshot is missing from disk.",
      "introducedAt": "2026-04-01",
      "expiresAt": "2026-04-04"
    },
    {
      "id": "paint-vrt-url-local-assets",
      "taskId": "paint-vrt",
      "spec": "tests/paint-vrt.test.ts",
      "titlePattern": "^url snapshot:",
      "mode": "skip",
      "scope": "environment",
      "owner": "mizchi",
      "reason": "Optional captured URLs are not always present locally.",
      "condition": "Skip only when the named URL snapshot is missing from disk.",
      "introducedAt": "2026-03-01",
      "expiresAt": "2026-03-31"
    },
    {
      "id": "missing-task",
      "taskId": "does-not-exist",
      "spec": "tests/paint-vrt.test.ts",
      "titlePattern": "^fixture:",
      "mode": "skip",
      "scope": "environment",
      "owner": "mizchi",
      "reason": "Broken config fixture",
      "condition": "Never",
      "introducedAt": "2026-04-01",
      "expiresAt": "2026-05-01"
    }
  ]
}
`);

    const summary = summarizeFlakerQuarantine(quarantine, flaker, {
      cwd: root,
      now: new Date("2026-04-01T00:00:00Z"),
    });

    expect(summary.entryCount).toBe(3);
    expect(summary.errors.map((issue) => issue.code)).toEqual([
      "expired-quarantine",
      "unknown-task",
    ]);
    expect(summary.warnings.map((issue) => issue.code)).toEqual(["expires-soon"]);
    expect(summary.entries.find((entry) => entry.id === "paint-vrt-real-world-local-assets")?.expiryStatus)
      .toBe("expires-soon");
    expect(summary.entries.find((entry) => entry.id === "paint-vrt-url-local-assets")?.expiryStatus)
      .toBe("expired");

    const markdown = renderQuarantineMarkdown(summary);
    expect(markdown).toContain("# Flaker Quarantine Summary");
    expect(markdown).toContain("paint-vrt-real-world-local-assets");
    expect(markdown).toContain("expires-soon");
    expect(markdown).toContain("expired-quarantine");
  });
});

describe("findMatchingQuarantine", () => {
  it("matches by task, spec, and title pattern", () => {
    const quarantine = parseFlakerQuarantine(`
{
  "schemaVersion": 1,
  "entries": [
    {
      "id": "paint-vrt-real-world-local-assets",
      "taskId": "paint-vrt",
      "spec": "tests/paint-vrt.test.ts",
      "titlePattern": "^real-world snapshot:",
      "mode": "skip",
      "scope": "environment",
      "owner": "mizchi",
      "reason": "Optional real-world fixtures are not always present locally.",
      "condition": "Skip only when the named real-world snapshot is missing from disk.",
      "introducedAt": "2026-04-01",
      "expiresAt": "2026-06-30"
    }
  ]
}
`);

    const match = findMatchingQuarantine(quarantine, {
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      title: "real-world snapshot: playwright-intro stays within loose visual diff budget",
    });

    expect(match?.id).toBe("paint-vrt-real-world-local-assets");
  });
});

describe("repo flaker quarantine", () => {
  it("validates tracked quarantine entries against flaker.star", () => {
    const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
    const flaker = parseFlakerStar(fs.readFileSync(path.join(repoRoot, "flaker.star"), "utf8"));
    const quarantine = parseFlakerQuarantine(
      fs.readFileSync(path.join(repoRoot, "flaker-quarantine.json"), "utf8"),
    );

    const summary = summarizeFlakerQuarantine(quarantine, flaker, {
      cwd: repoRoot,
      now: new Date("2026-04-01T00:00:00Z"),
    });

    expect(summary.errors).toEqual([]);
    expect(summary.warnings).toEqual([]);
  });
});

describe("loadFlakerQuarantineSummaryInputs", () => {
  it("remains re-exported from the wrapper facade", () => {
    expect(typeof loadFlakerQuarantineSummaryInputs).toBe("function");
  });
});

describe("runFlakerQuarantineCli", () => {
  it("returns markdown output and non-zero exit when check fails", () => {
    const root = makeTempDir();
    writeFile(root, "tests/paint-vrt.test.ts");
    writeFile(
      root,
      "flaker.star",
      `
workflow(name="example", max_parallel=1)
node(id="layout", depends_on=[])
task(
  id="paint-vrt",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
  srcs=["src/layout/**"],
  trigger="auto",
)
`,
    );
    writeFile(
      root,
      "flaker-quarantine.json",
      `
{
  "schemaVersion": 1,
  "entries": [
    {
      "id": "expired-entry",
      "taskId": "paint-vrt",
      "spec": "tests/paint-vrt.test.ts",
      "titlePattern": "^fixture:",
      "mode": "skip",
      "scope": "environment",
      "owner": "mizchi",
      "reason": "Expired",
      "condition": "Never",
      "introducedAt": "2026-03-01",
      "expiresAt": "2026-03-31"
    }
  ]
}
`,
    );

    const result = runFlakerQuarantineCli(["--check"], {
      cwd: root,
      now: new Date("2026-04-01T00:00:00Z"),
    });

    expect(result.exitCode).toBe(1);
    expect(result.stdout).toContain("# Flaker Quarantine Summary");
    expect(result.stderr).toBeUndefined();
  });
});
