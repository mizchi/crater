import fs from "node:fs";
import path from "node:path";
import type { FlakerConfig, FlakerSummary } from "./flaker-config-contract.ts";
import {
  buildFlakerConfigSummary,
  type BuildFlakerConfigSummaryInputs,
} from "./flaker-config-summary-core.ts";
import { resolveTaskSummaries } from "./flaker-config-task.ts";

const DEFAULT_TESTS_DIR = "tests";
const DEFAULT_EXCLUDED_SPECS = ["tests/playwright-benchmark.test.ts"];

export * from "./flaker-config-summary-core.ts";

export interface SummarizeOptions {
  cwd: string;
  testsDir?: string;
  excludedSpecs?: string[];
}

export function discoverPlaywrightSpecs(
  rootDir: string,
  testsDir = DEFAULT_TESTS_DIR,
  excludedSpecs = DEFAULT_EXCLUDED_SPECS,
): string[] {
  const baseDir = path.join(rootDir, testsDir);
  if (!fs.existsSync(baseDir)) {
    return [];
  }

  const excluded = new Set(excludedSpecs);
  const entries = fs.readdirSync(baseDir, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".test.ts"))
    .map((entry) => `${testsDir}/${entry.name}`)
    .filter((spec) => !excluded.has(spec))
    .sort();
}

export function loadFlakerConfigSummaryInputs(
  config: FlakerConfig,
  options: SummarizeOptions,
): BuildFlakerConfigSummaryInputs {
  const cwd = options.cwd;
  const tasks = resolveTaskSummaries(config, cwd);
  const discoveredSpecs = discoverPlaywrightSpecs(
    cwd,
    options.testsDir ?? DEFAULT_TESTS_DIR,
    options.excludedSpecs ?? DEFAULT_EXCLUDED_SPECS,
  );
  const existingSpecs = new Set(
    tasks
      .flatMap((task) => task.specs)
      .filter((spec) => fs.existsSync(path.join(cwd, spec))),
  );

  return {
    config,
    tasks,
    discoveredSpecs,
    existingSpecs,
  };
}

export function summarizeFlakerConfig(
  config: FlakerConfig,
  options: SummarizeOptions,
): FlakerSummary {
  return buildFlakerConfigSummary(
    loadFlakerConfigSummaryInputs(config, options),
  );
}
