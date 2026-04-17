import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildFlakerTaskRecordArtifacts,
  buildFlakerTaskRecordVrtArtifacts,
  buildFlakerTaskRecordWptVrtArtifacts,
  resolveFlakerTaskRecordPaths,
} from "./flaker-task-record-artifacts.ts";

const PLAYWRIGHT_REPORT = JSON.stringify({
  suites: [
    {
      title: "tests/paint-vrt.test.ts",
      file: "tests/paint-vrt.test.ts",
      specs: [
        {
          title: "fixture: cards",
          tests: [
            {
              projectName: "chromium",
              expectedStatus: "passed",
              status: "passed",
              results: [{ retry: 0, status: "passed", duration: 123 }],
            },
          ],
        },
      ],
    },
  ],
});

describe("resolveFlakerTaskRecordPaths", () => {
  it("resolves default latest paths inside the task workspace", () => {
    const repoRoot = path.join(os.tmpdir(), "repo");
    const workspaceDir = path.join(repoRoot, ".flaker/tasks/paint-vrt");

    expect(resolveFlakerTaskRecordPaths(repoRoot, "paint-vrt", workspaceDir)).toEqual({
      latestDir: path.join(workspaceDir, "latest"),
      reportPath: path.join(workspaceDir, "latest", "playwright-report.json"),
      summaryJsonPath: path.join(workspaceDir, "latest", "paint-vrt.json"),
      summaryMarkdownPath: path.join(workspaceDir, "latest", "paint-vrt.md"),
      stderrLogPath: path.join(workspaceDir, "latest", "playwright.stderr.log"),
    });
  });
});

describe("buildFlakerTaskRecordArtifacts", () => {
  it("renders report, stderr log, normalized summaries, and collect-compatible copies", () => {
    const repoRoot = path.join(os.tmpdir(), "repo");
    const paths = resolveFlakerTaskRecordPaths(
      repoRoot,
      "paint-vrt",
      path.join(repoRoot, ".flaker/tasks/paint-vrt"),
    );

    const artifacts = buildFlakerTaskRecordArtifacts(
      repoRoot,
      "paint-vrt",
      paths,
      PLAYWRIGHT_REPORT,
      "debug stderr",
    );

    expect(artifacts.summaryJsonPath).toBe(paths.summaryJsonPath);
    expect(artifacts.summaryMarkdownPath).toBe(paths.summaryMarkdownPath);
    expect(artifacts.writes).toEqual([
      {
        path: paths.reportPath,
        content: PLAYWRIGHT_REPORT,
      },
      {
        path: paths.stderrLogPath,
        content: "debug stderr",
      },
      {
        path: paths.summaryJsonPath,
        content: expect.stringContaining('"label": "paint-vrt"'),
      },
      {
        path: paths.summaryMarkdownPath,
        content: expect.stringContaining("# Playwright Report Summary"),
      },
      {
        path: path.join(paths.latestDir, "paint-vrt", "playwright-summary", "paint-vrt.json"),
        content: expect.stringContaining('"label": "paint-vrt"'),
      },
      {
        path: path.join(paths.latestDir, "paint-vrt", "playwright-summary", "paint-vrt.md"),
        content: expect.stringContaining("# Playwright Report Summary"),
      },
    ]);
  });

  it("roots collect-compatible copies at the task artifact directory when summaryDir already names the summary kind", () => {
    const repoRoot = path.join(os.tmpdir(), "repo");
    const paths = resolveFlakerTaskRecordPaths(
      repoRoot,
      "paint-vrt",
      path.join(repoRoot, ".flaker/tasks/paint-vrt"),
      {
        summaryDir: "flaker-daily/paint-vrt/playwright-summary",
      },
    );

    const artifacts = buildFlakerTaskRecordArtifacts(
      repoRoot,
      "paint-vrt",
      paths,
      PLAYWRIGHT_REPORT,
      "",
    );

    expect(artifacts.writes).toEqual([
      {
        path: path.resolve(repoRoot, "flaker-daily/paint-vrt/playwright-summary/playwright-report.json"),
        content: PLAYWRIGHT_REPORT,
      },
      {
        path: path.resolve(repoRoot, "flaker-daily/paint-vrt/playwright-summary/paint-vrt.json"),
        content: expect.stringContaining('"label": "paint-vrt"'),
      },
      {
        path: path.resolve(repoRoot, "flaker-daily/paint-vrt/playwright-summary/paint-vrt.md"),
        content: expect.stringContaining("# Playwright Report Summary"),
      },
    ]);
  });
});

describe("buildFlakerTaskRecordVrtArtifacts", () => {
  it("renders task-scoped VRT summary files and collect-compatible copies", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-vrt-"));
    const reportDir = path.join(repoRoot, "output", "playwright", "vrt", "fixture-card");
    fs.mkdirSync(reportDir, { recursive: true });
    fs.writeFileSync(
      path.join(reportDir, "report.json"),
      JSON.stringify({
        width: 960,
        height: 720,
        diffPixels: 1200,
        totalPixels: 691200,
        diffRatio: 0.03,
        threshold: 0.3,
        maxDiffRatio: 0.15,
      }),
      "utf8",
    );

    const artifacts = buildFlakerTaskRecordVrtArtifacts(
      repoRoot,
      "paint-vrt",
      "flaker-daily/paint-vrt/vrt-summary",
    );

    expect(artifacts.summaryJsonPath).toBe(
      path.resolve(repoRoot, "flaker-daily/paint-vrt/vrt-summary/paint-vrt.json"),
    );
    expect(artifacts.summaryMarkdownPath).toBe(
      path.resolve(repoRoot, "flaker-daily/paint-vrt/vrt-summary/paint-vrt.md"),
    );
    expect(artifacts.writes).toEqual([
      {
        path: path.resolve(repoRoot, "flaker-daily/paint-vrt/vrt-summary/paint-vrt.json"),
        content: expect.stringContaining('"suite": "vrt-artifact-summary"'),
      },
      {
        path: path.resolve(repoRoot, "flaker-daily/paint-vrt/vrt-summary/paint-vrt.md"),
        content: expect.stringContaining("# VRT Artifact Summary"),
      },
    ]);
  });

  it("skips VRT summary writes when the task produced no report.json files", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-no-vrt-"));

    const artifacts = buildFlakerTaskRecordVrtArtifacts(
      repoRoot,
      "playwright-adapter",
      "flaker-daily/playwright-adapter/vrt-summary",
    );

    expect(artifacts).toEqual({
      writes: [],
    });
  });
});

describe("buildFlakerTaskRecordWptVrtArtifacts", () => {
  it("renders WPT VRT summary files under a sibling wpt-vrt-summary directory", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-wpt-vrt-"));
    const reportDir = path.join(repoRoot, "output", "playwright", "vrt", "wpt");
    fs.mkdirSync(reportDir, { recursive: true });
    fs.writeFileSync(
      path.join(reportDir, "wpt-vrt-results.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "wpt-vrt",
        generatedAt: "2026-04-02T00:00:00.000Z",
        shard: {
          name: "wpt-vrt",
          modules: ["css-flexbox"],
          offset: 0,
          limit: 10,
        },
        summary: {
          total: 2,
          expectedTotal: 3,
          passed: 1,
          failed: 1,
          regressions: 1,
        },
        tests: {
          "css-flexbox/gap-001.html": {
            diffRatio: 0.02,
            status: "pass",
            baselineDiffRatio: 0.01,
            regressionLimit: 0.03,
            headroom: 0.01,
          },
          "css-flexbox/gap-002.html": {
            diffRatio: 0.08,
            status: "fail",
            baselineDiffRatio: 0.03,
            regressionLimit: 0.04,
            headroom: -0.04,
          },
        },
      }),
      "utf8",
    );

    const artifacts = buildFlakerTaskRecordWptVrtArtifacts(
      repoRoot,
      "wpt-vrt",
      "flaker-daily/wpt-vrt/vrt-summary",
    );

    expect(artifacts.summaryJsonPath).toBe(
      path.resolve(repoRoot, "flaker-daily/wpt-vrt/wpt-vrt-summary/wpt-vrt.json"),
    );
    expect(artifacts.summaryMarkdownPath).toBe(
      path.resolve(repoRoot, "flaker-daily/wpt-vrt/wpt-vrt-summary/wpt-vrt.md"),
    );
    expect(artifacts.writes).toEqual([
      {
        path: path.resolve(repoRoot, "flaker-daily/wpt-vrt/wpt-vrt-summary/wpt-vrt.json"),
        content: expect.stringContaining('"suite": "wpt-vrt"'),
      },
      {
        path: path.resolve(repoRoot, "flaker-daily/wpt-vrt/wpt-vrt-summary/wpt-vrt.md"),
        content: expect.stringContaining("# WPT VRT Shard Summary"),
      },
    ]);
  });

  it("skips WPT VRT summary writes when the task produced no wpt-vrt-results.json", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-no-wpt-vrt-"));

    const artifacts = buildFlakerTaskRecordWptVrtArtifacts(
      repoRoot,
      "wpt-vrt",
      "flaker-daily/wpt-vrt/vrt-summary",
    );

    expect(artifacts).toEqual({
      writes: [],
    });
  });
});
