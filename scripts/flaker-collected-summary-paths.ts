import path from "node:path";

export type FlakerCollectedSummaryKind =
  | "playwright-summary"
  | "flaker-summary"
  | "vrt-summary"
  | "batch-summary"
  | "wpt-vrt-summary";

export interface FlakerCollectedSummaryPaths {
  jsonPath: string;
  markdownPath: string;
}

export interface FlakerCollectedSummaryWrite {
  path: string;
  content: string;
}

export function appendWriteIfMissing(
  writes: FlakerCollectedSummaryWrite[],
  write: FlakerCollectedSummaryWrite,
): void {
  if (writes.some((entry) => entry.path === write.path)) {
    return;
  }
  writes.push(write);
}

function resolveFlakerCollectedSummaryBaseDir(
  baseDir: string,
  taskId: string,
  kind: FlakerCollectedSummaryKind,
): string {
  if (path.basename(baseDir) !== kind) {
    return baseDir;
  }
  const taskDir = path.dirname(baseDir);
  return path.basename(taskDir) === taskId ? path.dirname(taskDir) : taskDir;
}

export function resolveFlakerCollectedSummaryPaths(
  baseDir: string,
  taskId: string,
  kind: FlakerCollectedSummaryKind,
): FlakerCollectedSummaryPaths {
  const summaryDir = path.join(
    resolveFlakerCollectedSummaryBaseDir(baseDir, taskId, kind),
    taskId,
    kind,
  );
  return {
    jsonPath: path.join(summaryDir, `${taskId}.json`),
    markdownPath: path.join(summaryDir, `${taskId}.md`),
  };
}

export function appendFlakerCollectedSummaryWrites(
  writes: FlakerCollectedSummaryWrite[],
  options: {
    cwd: string;
    taskId: string;
    kind: FlakerCollectedSummaryKind;
    jsonOutput?: string;
    markdownOutput?: string;
    jsonContent: string;
    markdownContent: string;
  },
): void {
  const baseDirs = new Set<string>();
  if (options.jsonOutput) {
    baseDirs.add(path.dirname(path.resolve(options.cwd, options.jsonOutput)));
  }
  if (options.markdownOutput) {
    baseDirs.add(path.dirname(path.resolve(options.cwd, options.markdownOutput)));
  }

  for (const baseDir of baseDirs) {
    const collectPaths = resolveFlakerCollectedSummaryPaths(
      baseDir,
      options.taskId,
      options.kind,
    );
    appendWriteIfMissing(writes, {
      path: collectPaths.markdownPath,
      content: options.markdownContent,
    });
    appendWriteIfMissing(writes, {
      path: collectPaths.jsonPath,
      content: options.jsonContent,
    });
  }
}
