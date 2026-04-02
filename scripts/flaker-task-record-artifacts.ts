import path from "node:path";
import {
  buildPlaywrightSummary,
  renderPlaywrightMarkdown,
  type PlaywrightJsonReport,
} from "./playwright-report-summary-core.ts";
import type { ScriptOutputFile } from "./script-runtime.ts";

export interface FlakerTaskRecordPaths {
  latestDir: string;
  reportPath: string;
  summaryJsonPath: string;
  summaryMarkdownPath: string;
  stderrLogPath: string;
}

export interface FlakerTaskRecordArtifacts {
  writes: ScriptOutputFile[];
  summaryJsonPath?: string;
  summaryMarkdownPath?: string;
}

export function resolveFlakerTaskRecordPaths(
  repoRoot: string,
  taskId: string,
  workspaceDir: string,
  options?: {
    reportPath?: string;
    summaryDir?: string;
  },
): FlakerTaskRecordPaths {
  const latestDir = options?.summaryDir
    ? path.resolve(repoRoot, options.summaryDir)
    : path.join(workspaceDir, "latest");
  const reportPath = options?.reportPath
    ? path.resolve(repoRoot, options.reportPath)
    : path.join(latestDir, "playwright-report.json");
  return {
    latestDir,
    reportPath,
    summaryJsonPath: path.join(latestDir, `${taskId}.json`),
    summaryMarkdownPath: path.join(latestDir, `${taskId}.md`),
    stderrLogPath: path.join(latestDir, "playwright.stderr.log"),
  };
}

export function buildFlakerTaskRecordArtifacts(
  repoRoot: string,
  taskId: string,
  paths: FlakerTaskRecordPaths,
  reportText: string,
  stderrText: string,
): FlakerTaskRecordArtifacts {
  const writes: ScriptOutputFile[] = [
    {
      path: paths.reportPath,
      content: reportText,
    },
  ];

  if (stderrText.length > 0) {
    writes.push({
      path: paths.stderrLogPath,
      content: stderrText,
    });
  }

  if (reportText.trim().length === 0) {
    return {
      writes,
    };
  }

  const summary = buildPlaywrightSummary(
    JSON.parse(reportText) as PlaywrightJsonReport,
    taskId,
    path.relative(repoRoot, paths.reportPath),
  );
  writes.push({
    path: paths.summaryJsonPath,
    content: `${JSON.stringify(summary, null, 2)}\n`,
  });
  writes.push({
    path: paths.summaryMarkdownPath,
    content: renderPlaywrightMarkdown(summary),
  });
  return {
    writes,
    summaryJsonPath: paths.summaryJsonPath,
    summaryMarkdownPath: paths.summaryMarkdownPath,
  };
}
