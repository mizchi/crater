import fs from "node:fs";
import path from "node:path";
import type { PlaywrightSummary } from "./playwright-report-contract.ts";
import type { FlakerTaskSummaryReport } from "./flaker-task-summary-contract.ts";
import type { FlakerBatchSummaryInputs } from "./flaker-batch-summary-core.ts";

function readJsonIfExists<T>(targetPath: string): T | undefined {
  if (!fs.existsSync(targetPath)) {
    return undefined;
  }
  return JSON.parse(fs.readFileSync(targetPath, "utf8")) as T;
}

function walkJsonFiles(rootDir: string): string[] {
  if (!fs.existsSync(rootDir)) {
    return [];
  }
  const results: string[] = [];
  for (const entry of fs.readdirSync(rootDir, { withFileTypes: true })) {
    const targetPath = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkJsonFiles(targetPath));
      continue;
    }
    if (entry.isFile() && entry.name.endsWith(".json")) {
      results.push(targetPath);
    }
  }
  return results;
}

export function loadFlakerBatchSummaryInputs(
  inputDir: string,
): FlakerBatchSummaryInputs {
  const playwrightSummaries = new Map<string, PlaywrightSummary>();
  const flakerSummaries = new Map<string, FlakerTaskSummaryReport>();

  for (const filePath of walkJsonFiles(inputDir)) {
    const parent = path.basename(path.dirname(filePath));
    const taskId = path.basename(filePath, ".json");
    if (parent === "playwright-summary") {
      const summary = readJsonIfExists<PlaywrightSummary>(filePath);
      if (summary) {
        playwrightSummaries.set(taskId, summary);
      }
      continue;
    }
    if (parent === "flaker-summary") {
      const summary = readJsonIfExists<FlakerTaskSummaryReport>(filePath);
      if (summary) {
        flakerSummaries.set(taskId, summary);
      }
    }
  }

  return {
    playwrightSummaries,
    flakerSummaries,
  };
}
