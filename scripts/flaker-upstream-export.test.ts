import path from "node:path";
import { describe, expect, it } from "vitest";
import { buildFlakerUpstreamInventory } from "./flaker-upstream-inventory.ts";
import {
  buildFlakerUpstreamExportStage,
  parseFlakerUpstreamExportArgs,
  renderFlakerUpstreamExportMarkdown,
  runFlakerUpstreamExportCli,
} from "./flaker-upstream-export.ts";

describe("parseFlakerUpstreamExportArgs", () => {
  it("parses group and output directory", () => {
    const args = parseFlakerUpstreamExportArgs([
      "--group",
      "playwright-report-core",
      "--output",
      ".flaker/upstream-export",
    ]);

    expect(args).toEqual({
      groupId: "playwright-report-core",
      outputDir: ".flaker/upstream-export",
    });
  });

  it("parses all export mode", () => {
    const args = parseFlakerUpstreamExportArgs([
      "--all",
      "--output",
      "from-crater",
    ]);

    expect(args).toEqual({
      exportAll: true,
      outputDir: "from-crater",
    });
  });
});

describe("buildFlakerUpstreamExportStage", () => {
  it("builds staged source writes and manifest for a ready group", () => {
    const group = buildFlakerUpstreamInventory().groups.find((candidate) =>
      candidate.id === "playwright-report-core"
    );
    expect(group).toBeDefined();

    const stage = buildFlakerUpstreamExportStage(group!, {
      cwd: "/repo",
      outputDir: ".flaker/upstream-export",
      readFile: (targetPath) => `// ${path.relative("/repo", targetPath)}\n`,
    });

    expect(stage.manifest.group.id).toBe("playwright-report-core");
    expect(stage.manifest.stageRoot).toBe(
      "/repo/.flaker/upstream-export/playwright-report-core",
    );
    expect(stage.manifest.fileCount).toBe(3);
    expect(stage.manifest.testFileCount).toBe(3);
    expect(stage.writes).toEqual([
      {
        path: "/repo/.flaker/upstream-export/playwright-report-core/scripts/playwright-report-contract.ts",
        content: "// scripts/playwright-report-contract.ts\n",
      },
      {
        path: "/repo/.flaker/upstream-export/playwright-report-core/scripts/playwright-report-summary-core.ts",
        content: "// scripts/playwright-report-summary-core.ts\n",
      },
      {
        path: "/repo/.flaker/upstream-export/playwright-report-core/scripts/playwright-report-diff-core.ts",
        content: "// scripts/playwright-report-diff-core.ts\n",
      },
      {
        path: "/repo/.flaker/upstream-export/playwright-report-core/scripts/playwright-report-contract.test.ts",
        content: "// scripts/playwright-report-contract.test.ts\n",
      },
      {
        path: "/repo/.flaker/upstream-export/playwright-report-core/scripts/playwright-report-summary.test.ts",
        content: "// scripts/playwright-report-summary.test.ts\n",
      },
      {
        path: "/repo/.flaker/upstream-export/playwright-report-core/scripts/playwright-report-diff.test.ts",
        content: "// scripts/playwright-report-diff.test.ts\n",
      },
      {
        path: "/repo/.flaker/upstream-export/playwright-report-core/manifest.md",
        content: expect.stringContaining("# Metric CI Upstream Export"),
      },
      {
        path: "/repo/.flaker/upstream-export/playwright-report-core/manifest.json",
        content: expect.stringContaining('"group": {'),
      },
    ]);
  });
});

describe("renderFlakerUpstreamExportMarkdown", () => {
  it("renders group metadata and staged file list", () => {
    const group = buildFlakerUpstreamInventory().groups.find((candidate) =>
      candidate.id === "flaker-batch-summary-core"
    );
    expect(group).toBeDefined();

    const stage = buildFlakerUpstreamExportStage(group!, {
      cwd: "/repo",
      outputDir: "out",
      readFile: () => "// exported\n",
    });

    const markdown = renderFlakerUpstreamExportMarkdown(stage.manifest);

    expect(markdown).toContain("# Metric CI Upstream Export");
    expect(markdown).toContain("| Group | flaker-batch-summary-core |");
    expect(markdown).toContain("| Test files | 1 |");
    expect(markdown).toContain("scripts/flaker-batch-summary-core.ts");
    expect(markdown).toContain("| Kind | Source | Staged | Bytes |");
  });
});

describe("runFlakerUpstreamExportCli", () => {
  it("returns staged writes for ready-to-upstream groups", () => {
    const result = runFlakerUpstreamExportCli([
      "--group",
      "flaker-task-summary-core",
      "--output",
      "out",
    ], {
      cwd: "/repo",
      readFile: (targetPath) => `// ${path.relative("/repo", targetPath)}\n`,
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# Metric CI Upstream Export");
    expect(result.writes).toEqual([
      {
        path: "/repo/out/flaker-task-summary-core/scripts/flaker-task-summary-contract.ts",
        content: "// scripts/flaker-task-summary-contract.ts\n",
      },
      {
        path: "/repo/out/flaker-task-summary-core/scripts/flaker-task-summary-core.ts",
        content: "// scripts/flaker-task-summary-core.ts\n",
      },
      {
        path: "/repo/out/flaker-task-summary-core/scripts/flaker-task-summary-core.test.ts",
        content: "// scripts/flaker-task-summary-core.test.ts\n",
      },
      {
        path: "/repo/out/flaker-task-summary-core/manifest.md",
        content: expect.stringContaining("| Group | flaker-task-summary-core |"),
      },
      {
        path: "/repo/out/flaker-task-summary-core/manifest.json",
        content: expect.stringContaining('"status": "ready-to-upstream"'),
      },
    ]);
  });

  it("rejects groups that are kept in crater", () => {
    const result = runFlakerUpstreamExportCli([
      "--group",
      "wpt-vrt-summary-core",
      "--output",
      "out",
    ], {
      cwd: "/repo",
      readFile: () => "// unused\n",
    });

    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain("ready-to-upstream");
    expect(result.writes).toEqual([]);
  });

  it("exports all ready-to-upstream groups into one root", () => {
    const result = runFlakerUpstreamExportCli([
      "--all",
      "--output",
      "from-crater",
    ], {
      cwd: "/repo",
      readFile: (targetPath) => `// ${path.relative("/repo", targetPath)}\n`,
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# Metric CI From Crater");
    expect(result.writes).toEqual(
      expect.arrayContaining([
        {
          path: "/repo/from-crater/README.md",
          content: expect.stringContaining("MoonBit"),
        },
        {
          path: "/repo/from-crater/playwright-report-core/scripts/playwright-report-contract.ts",
          content: "// scripts/playwright-report-contract.ts\n",
        },
        {
          path: "/repo/from-crater/flaker-config-core/scripts/flaker-config-parser.ts",
          content: "// scripts/flaker-config-parser.ts\n",
        },
        {
          path: "/repo/from-crater/flaker-config-core/scripts/flaker-config-task.test.ts",
          content: "// scripts/flaker-config-task.test.ts\n",
        },
      ]),
    );
  });
});
