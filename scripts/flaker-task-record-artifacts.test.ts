import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildFlakerTaskRecordArtifacts,
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
  it("renders report, stderr log, and normalized summaries", () => {
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
    ]);
  });
});
