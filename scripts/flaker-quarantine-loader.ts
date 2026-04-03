import fs from "node:fs";
import path from "node:path";
import type { FlakerConfig } from "./flaker-config-contract.ts";
import { summarizeFlakerConfig } from "./flaker-config-summary.ts";
import type { FlakerQuarantineConfig } from "./flaker-quarantine-contract.ts";
import type {
  BuildFlakerQuarantineSummaryInputs,
  FlakerQuarantineTaskOwnership,
} from "./flaker-quarantine-summary-core.ts";
import { normalizeRepoPath } from "./script-path.ts";

export interface SummarizeOptions {
  cwd: string;
  testsDir?: string;
  now?: Date;
  expiresSoonDays?: number;
}

export function loadFlakerQuarantineSummaryInputs(
  quarantine: FlakerQuarantineConfig,
  flakerConfig: FlakerConfig,
  options: SummarizeOptions,
): BuildFlakerQuarantineSummaryInputs {
  const cwd = options.cwd;
  const flakerSummary = summarizeFlakerConfig(flakerConfig, {
    cwd,
    testsDir: options.testsDir,
  });

  const tasks: FlakerQuarantineTaskOwnership[] = flakerSummary.tasks.map((task) => ({
    id: task.id,
    specs: [...task.specs],
  }));

  const normalizedQuarantine: FlakerQuarantineConfig = {
    ...quarantine,
    entries: quarantine.entries.map((entry) => ({
      ...entry,
      spec: normalizeRepoPath(cwd, entry.spec),
    })),
  };

  const existingSpecs = new Set(
    normalizedQuarantine.entries
      .map((entry) => entry.spec)
      .filter((spec) => fs.existsSync(path.resolve(cwd, spec))),
  );

  return {
    quarantine: normalizedQuarantine,
    tasks,
    existingSpecs,
    now: options.now,
    expiresSoonDays: options.expiresSoonDays,
  };
}
