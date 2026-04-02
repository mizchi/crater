import path from "node:path";
import type { FlakerConfig, FlakerSelection } from "./flaker-config-contract.ts";
import { buildFlakerSelection, type BuildFlakerSelectionInputs } from "./flaker-config-selection-core.ts";
import { resolveTaskSummaries } from "./flaker-config-task.ts";

export * from "./flaker-config-selection-core.ts";

export function normalizeFlakerSelectionPath(
  cwd: string,
  inputPath: string,
): string {
  const resolved = path.isAbsolute(inputPath)
    ? inputPath
    : path.resolve(cwd, inputPath);
  const relative = path.relative(cwd, resolved);
  const normalized = relative.length > 0 ? relative : inputPath;
  return normalized.split(path.sep).join("/").replace(/^\.\//, "");
}

export function loadFlakerSelectionInputs(
  config: FlakerConfig,
  changedPaths: string[],
  cwd = process.cwd(),
): BuildFlakerSelectionInputs {
  return {
    tasks: resolveTaskSummaries(config, cwd),
    changedPaths: changedPaths.map((changedPath) =>
      normalizeFlakerSelectionPath(cwd, changedPath),
    ),
  };
}

export function selectAffectedTasks(
  config: FlakerConfig,
  changedPaths: string[],
  cwd = process.cwd(),
): FlakerSelection {
  return buildFlakerSelection(
    loadFlakerSelectionInputs(config, changedPaths, cwd),
  );
}
