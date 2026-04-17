import fs from "node:fs";
import path from "node:path";
import {
  buildPlaywrightSummary,
  renderPlaywrightMarkdown,
  type PlaywrightJsonReport,
} from "./playwright-report-summary-core.ts";
import {
  appendWriteIfMissing,
  resolveFlakerCollectedSummaryPaths,
} from "./flaker-collected-summary-paths.ts";
import type { ScriptOutputFile } from "./script-runtime.ts";
import { loadVrtArtifactReports } from "./vrt-report-loader.ts";
import {
  buildVrtArtifactSummary,
  renderVrtArtifactSummaryMarkdown,
} from "./vrt-report-summary-core.ts";
import {
  buildWptVrtShardSummary,
  renderWptVrtShardMarkdown,
  type WptVrtRawReport,
} from "./wpt-vrt-summary-core.ts";

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

export interface FlakerTaskRecordVrtArtifacts {
  writes: ScriptOutputFile[];
  summaryJsonPath?: string;
  summaryMarkdownPath?: string;
}

export interface FlakerTaskRecordWptVrtArtifacts {
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
  const summaryJsonContent = `${JSON.stringify(summary, null, 2)}\n`;
  const summaryMarkdownContent = renderPlaywrightMarkdown(summary);
  writes.push({
    path: paths.summaryJsonPath,
    content: summaryJsonContent,
  });
  writes.push({
    path: paths.summaryMarkdownPath,
    content: summaryMarkdownContent,
  });
  const collectPaths = resolveFlakerCollectedSummaryPaths(
    paths.latestDir,
    taskId,
    "playwright-summary",
  );
  appendWriteIfMissing(writes, {
    path: collectPaths.jsonPath,
    content: summaryJsonContent,
  });
  appendWriteIfMissing(writes, {
    path: collectPaths.markdownPath,
    content: summaryMarkdownContent,
  });
  return {
    writes,
    summaryJsonPath: paths.summaryJsonPath,
    summaryMarkdownPath: paths.summaryMarkdownPath,
  };
}

export function buildFlakerTaskRecordVrtArtifacts(
  repoRoot: string,
  taskId: string,
  summaryDir: string,
  options?: {
    inputDir?: string;
    label?: string;
  },
): FlakerTaskRecordVrtArtifacts {
  const inputDir = path.resolve(repoRoot, options?.inputDir ?? path.join("output", "playwright", "vrt"));
  const reports = loadVrtArtifactReports(inputDir);
  if (reports.length === 0) {
    return {
      writes: [],
    };
  }

  const resolvedSummaryDir = path.resolve(repoRoot, summaryDir);
  const summaryJsonPath = path.join(resolvedSummaryDir, `${taskId}.json`);
  const summaryMarkdownPath = path.join(resolvedSummaryDir, `${taskId}.md`);
  const summary = buildVrtArtifactSummary(reports, options?.label ?? `${taskId}-artifacts`);
  const summaryJsonContent = `${JSON.stringify(summary, null, 2)}\n`;
  const summaryMarkdownContent = renderVrtArtifactSummaryMarkdown(summary);
  const collectPaths = resolveFlakerCollectedSummaryPaths(
    resolvedSummaryDir,
    taskId,
    "vrt-summary",
  );

  const writes: ScriptOutputFile[] = [
    {
      path: summaryJsonPath,
      content: summaryJsonContent,
    },
    {
      path: summaryMarkdownPath,
      content: summaryMarkdownContent,
    },
  ];
  appendWriteIfMissing(writes, {
    path: collectPaths.markdownPath,
    content: summaryMarkdownContent,
  });
  appendWriteIfMissing(writes, {
    path: collectPaths.jsonPath,
    content: summaryJsonContent,
  });

  return {
    writes,
    summaryJsonPath,
    summaryMarkdownPath,
  };
}

function resolveWptVrtSummaryDir(
  repoRoot: string,
  summaryDir: string,
): string {
  const resolved = path.resolve(repoRoot, summaryDir);
  if (path.basename(resolved) === "vrt-summary") {
    return path.join(path.dirname(resolved), "wpt-vrt-summary");
  }
  return resolved;
}

export function buildFlakerTaskRecordWptVrtArtifacts(
  repoRoot: string,
  taskId: string,
  summaryDir: string,
  options?: {
    inputFile?: string;
    label?: string;
  },
): FlakerTaskRecordWptVrtArtifacts {
  const inputFile = path.resolve(
    repoRoot,
    options?.inputFile ?? path.join("output", "playwright", "vrt", "wpt", "wpt-vrt-results.json"),
  );
  if (!fs.existsSync(inputFile)) {
    return {
      writes: [],
    };
  }

  let report: WptVrtRawReport;
  try {
    report = JSON.parse(fs.readFileSync(inputFile, "utf8")) as WptVrtRawReport;
  } catch {
    return {
      writes: [],
    };
  }

  const resolvedSummaryDir = resolveWptVrtSummaryDir(repoRoot, summaryDir);
  const summaryJsonPath = path.join(resolvedSummaryDir, `${taskId}.json`);
  const summaryMarkdownPath = path.join(resolvedSummaryDir, `${taskId}.md`);
  const summary = buildWptVrtShardSummary(report, options?.label ?? taskId);
  const summaryJsonContent = `${JSON.stringify(summary, null, 2)}\n`;
  const summaryMarkdownContent = renderWptVrtShardMarkdown(summary);
  const collectPaths = resolveFlakerCollectedSummaryPaths(
    resolvedSummaryDir,
    taskId,
    "wpt-vrt-summary",
  );

  const writes: ScriptOutputFile[] = [
    {
      path: summaryJsonPath,
      content: summaryJsonContent,
    },
    {
      path: summaryMarkdownPath,
      content: summaryMarkdownContent,
    },
  ];
  appendWriteIfMissing(writes, {
    path: collectPaths.markdownPath,
    content: summaryMarkdownContent,
  });
  appendWriteIfMissing(writes, {
    path: collectPaths.jsonPath,
    content: summaryJsonContent,
  });

  return {
    writes,
    summaryJsonPath,
    summaryMarkdownPath,
  };
}
