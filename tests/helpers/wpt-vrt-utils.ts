import fs from "node:fs";
import path from "node:path";
import { getTestFiles, prepareHtmlContent } from "../../scripts/wpt-html-utils.ts";

export interface WptVrtConfig {
  modules: string[];
  limitPerModule: number;
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

export function collectWptVrtTests(config: WptVrtConfig): WptVrtTestEntry[] {
  const entries: WptVrtTestEntry[] = [];
  for (const moduleName of config.modules) {
    const files = getTestFiles(moduleName);
    const limited = files.slice(0, config.limitPerModule);
    for (const testPath of limited) {
      const relativePath = testPath
        .replace(/^wpt\/css\//, "")
        .replace(/^wpt[/\\]css[/\\]/, "");
      entries.push({ testPath, relativePath, moduleName });
    }
  }
  return entries;
}

export { prepareHtmlContent };
