import fs from "node:fs";
import path from "node:path";
import { getTestFiles, prepareHtmlContent } from "../../scripts/wpt-html-utils.ts";

export interface WptVrtConfig {
  modules: string[];
  limitPerModule: number;
  explicitTests?: string[];
  viewport: { width: number; height: number };
  pixelmatchThreshold: number;
  defaultMaxDiffRatio: number;
}

export interface WptVrtBaseline {
  schemaVersion: 1;
  updatedAt: string;
  config: {
    viewport: { width: number; height: number };
    pixelmatchThreshold: number;
    defaultMaxDiffRatio: number;
  };
  summary: {
    total: number;
    passed: number;
    failed: number;
  };
  tests: Record<string, { diffRatio: number; status: "pass" | "fail" }>;
}

export interface WptVrtTestEntry {
  testPath: string;
  relativePath: string;
  moduleName: string;
}

const CONFIG_PATH = path.join(process.cwd(), "wpt-vrt.json");
const BASELINE_PATH = path.join(process.cwd(), "tests", "wpt-vrt-baseline.json");

export function loadWptVrtConfig(): WptVrtConfig {
  const raw = fs.readFileSync(CONFIG_PATH, "utf-8");
  return JSON.parse(raw) as WptVrtConfig;
}

export function loadWptVrtBaseline(): WptVrtBaseline | null {
  try {
    const raw = fs.readFileSync(BASELINE_PATH, "utf-8");
    return JSON.parse(raw) as WptVrtBaseline;
  } catch {
    return null;
  }
}

export function saveWptVrtBaseline(baseline: WptVrtBaseline): void {
  fs.writeFileSync(BASELINE_PATH, JSON.stringify(baseline, null, 2) + "\n");
}

function toRelativePath(testPath: string): string {
  return testPath
    .replace(/^wpt\/css\//, "")
    .replace(/^wpt[/\\]css[/\\]/, "");
}

function moduleNameFromTestPath(testPath: string): string {
  const relativePath = toRelativePath(testPath);
  const [moduleName = ""] = relativePath.split(/[/\\]/);
  return moduleName;
}

function pushUniqueEntry(
  entries: WptVrtTestEntry[],
  seen: Set<string>,
  testPath: string,
  moduleName: string,
): void {
  const relativePath = toRelativePath(testPath);
  if (seen.has(relativePath)) return;
  seen.add(relativePath);
  entries.push({ testPath, relativePath, moduleName });
}

export function collectWptVrtTests(
  config: WptVrtConfig,
  getFiles: (moduleName: string) => string[] = getTestFiles,
): WptVrtTestEntry[] {
  const entries: WptVrtTestEntry[] = [];
  const seen = new Set<string>();
  for (const moduleName of config.modules) {
    const files = getFiles(moduleName);
    const limited = files.slice(0, config.limitPerModule);
    for (const testPath of limited) {
      pushUniqueEntry(entries, seen, testPath, moduleName);
    }
  }
  for (const testPath of config.explicitTests ?? []) {
    pushUniqueEntry(entries, seen, testPath, moduleNameFromTestPath(testPath));
  }
  return entries;
}

export function createWptVrtBatches(
  entries: WptVrtTestEntry[],
  batchSize: number,
): WptVrtTestEntry[][] {
  if (batchSize <= 0) {
    throw new Error("batchSize must be positive");
  }
  const batches: WptVrtTestEntry[][] = [];
  for (let i = 0; i < entries.length; i += batchSize) {
    batches.push(entries.slice(i, i + batchSize));
  }
  return batches;
}

export { prepareHtmlContent };
