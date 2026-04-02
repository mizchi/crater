import type { FlakerConfig, FlakerTask, FlakerTaskSummary } from "./flaker-config-contract.ts";
import { normalizeRepoPath } from "./script-path.ts";

export interface ResolvedFlakerTask extends FlakerTaskSummary {
  srcs: string[];
}

function findOptionValue(command: string[], optionName: string): string | undefined {
  const index = command.findIndex((part) => part === optionName);
  if (index < 0) {
    return undefined;
  }
  return command[index + 1];
}

function extractSpecs(command: string[]): string[] {
  return command.filter((part) => part.endsWith(".test.ts"));
}

export function isFilteredTask(task: FlakerTaskSummary): boolean {
  return Boolean(task.grep || task.grepInvert);
}

export function resolveTaskSummary(task: FlakerTask, cwd: string): ResolvedFlakerTask {
  return {
    id: task.id,
    node: task.node,
    specs: extractSpecs(task.cmd).map((spec) => normalizeRepoPath(cwd, spec)).sort(),
    grep: findOptionValue(task.cmd, "--grep"),
    grepInvert: findOptionValue(task.cmd, "--grep-invert"),
    trigger: task.trigger,
    needs: [...task.needs].sort(),
    srcCount: task.srcs.length,
    command: [...task.cmd],
    srcs: [...task.srcs],
  };
}

export function resolveTaskSummaries(config: FlakerConfig, cwd: string): ResolvedFlakerTask[] {
  return config.tasks.map((task) => resolveTaskSummary(task, cwd));
}
