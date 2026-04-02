import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildFlakerTaskConfigToml,
  parseFlakerTaskConfigArgs,
  runFlakerTaskConfigCli,
} from "./flaker-task-config.ts";
import { parseFlakerStar } from "./flaker-config.ts";

const REPO_ROOT = path.resolve(import.meta.dirname, "..");
const FLAKER_STAR = fs.readFileSync(path.join(REPO_ROOT, "flaker.star"), "utf8");

describe("parseFlakerTaskConfigArgs", () => {
  it("parses task and output options", () => {
    const args = parseFlakerTaskConfigArgs([
      "--task",
      "paint-vrt",
      "--write",
      ".flaker/paint-vrt.toml",
    ]);

    expect(args).toMatchObject({
      taskId: "paint-vrt",
      outputPath: ".flaker/paint-vrt.toml",
      owner: "mizchi",
      repo: "crater",
      configPath: "flaker.star",
      manifestPath: "flaker-quarantine.json",
    });
  });
});

describe("buildFlakerTaskConfigToml", () => {
  it("generates a flaker runtime config for paint-vrt", () => {
    const config = parseFlakerStar(FLAKER_STAR);
    const toml = buildFlakerTaskConfigToml(config, {
      taskId: "paint-vrt",
      owner: "mizchi",
      repo: "crater",
      manifestPath: "flaker-quarantine.json",
    });

    expect(toml).toContain('owner = "mizchi"');
    expect(toml).toContain('name = "crater"');
    expect(toml).toContain('type = "playwright"');
    expect(toml).toContain('command = "pnpm exec playwright test tests/paint-vrt.test.ts"');
    expect(toml).toContain('manifest = "flaker-quarantine.json"');
    expect(toml).toContain('task_id = "paint-vrt"');
    expect(toml).toContain("runtime_apply = true");
    expect(toml).toContain('path = ".flaker/data"');
  });

  it("preserves grep filters for describe-split tasks", () => {
    const config = parseFlakerStar(FLAKER_STAR);
    const toml = buildFlakerTaskConfigToml(config, {
      taskId: "website-loading",
      owner: "mizchi",
      repo: "crater",
      manifestPath: "flaker-quarantine.json",
    });

    expect(toml).toContain(
      'command = "pnpm exec playwright test tests/website-loading.test.ts --grep \'Website Loading Tests\'"',
    );
    expect(toml).toContain('task_id = "website-loading"');
  });
});

describe("runFlakerTaskConfigCli", () => {
  it("returns toml on stdout by default", () => {
    const result = runFlakerTaskConfigCli(["--task", "paint-vrt"], {
      repoRoot: REPO_ROOT,
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('task_id = "paint-vrt"');
    expect(result.writes).toEqual([]);
  });

  it("returns a write artifact when --write is provided", () => {
    const result = runFlakerTaskConfigCli([
      "--task",
      "paint-vrt",
      "--write",
      "out/flaker.toml",
    ], {
      repoRoot: REPO_ROOT,
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toBeUndefined();
    expect(result.writes).toEqual([
      {
        path: path.resolve(REPO_ROOT, "out/flaker.toml"),
        content: expect.stringContaining('task_id = "paint-vrt"'),
      },
    ]);
  });
});
