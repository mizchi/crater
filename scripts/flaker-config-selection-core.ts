import path from "node:path";
import type { FlakerSelectedTask, FlakerSelection } from "./flaker-config-contract.ts";
import type { ResolvedFlakerTask } from "./flaker-config-task.ts";

export interface BuildFlakerSelectionInputs {
  changedPaths: string[];
  tasks: ResolvedFlakerTask[];
}

function createSelectionTask(task: ResolvedFlakerTask): FlakerSelectedTask {
  return {
    id: task.id,
    node: task.node,
    specs: [...task.specs],
    needs: [...task.needs],
    command: [...task.command],
    matchReasons: [],
    includedBy: [],
  };
}

export function buildFlakerSelection(
  inputs: BuildFlakerSelectionInputs,
): FlakerSelection {
  const selected = new Map<string, FlakerSelectedTask>();
  const matchedTaskIds = new Set<string>();
  const matchedPaths = new Set<string>();
  const dependentsQueue: string[] = [];

  for (const task of inputs.tasks) {
    const reasons = new Set<string>();
    for (const changedPath of inputs.changedPaths) {
      if (task.specs.includes(changedPath)) {
        reasons.add(`spec:${changedPath}`);
        matchedPaths.add(changedPath);
        continue;
      }
      for (const src of task.srcs) {
        if (path.matchesGlob(changedPath, src)) {
          reasons.add(`srcs:${src} <= ${changedPath}`);
          matchedPaths.add(changedPath);
        }
      }
    }
    if (reasons.size === 0) {
      continue;
    }

    matchedTaskIds.add(task.id);
    const entry = selected.get(task.id) ?? createSelectionTask(task);
    entry.matchReasons = [...new Set([...entry.matchReasons, ...reasons])].sort();
    selected.set(task.id, entry);
    dependentsQueue.push(task.id);
  }

  const taskById = new Map(inputs.tasks.map((task) => [task.id, task]));
  while (dependentsQueue.length > 0) {
    const taskId = dependentsQueue.shift()!;
    const task = taskById.get(taskId);
    if (!task) {
      continue;
    }
    for (const dependencyId of task.needs) {
      const dependency = taskById.get(dependencyId);
      if (!dependency) {
        continue;
      }
      const dependencyEntry = selected.get(dependencyId) ?? createSelectionTask(dependency);
      dependencyEntry.includedBy = [...new Set([...dependencyEntry.includedBy, task.id])].sort();
      const wasSelected = selected.has(dependencyId);
      selected.set(dependencyId, dependencyEntry);
      if (!wasSelected) {
        dependentsQueue.push(dependencyId);
      }
    }
  }

  const selectedTasks = [...selected.values()].sort((a, b) => a.id.localeCompare(b.id));
  return {
    changedPaths: [...inputs.changedPaths],
    matchedTaskIds: [...matchedTaskIds].sort(),
    selectedTaskIds: selectedTasks.map((task) => task.id),
    unmatchedPaths: inputs.changedPaths.filter((changedPath) => !matchedPaths.has(changedPath)),
    selectedTasks,
    generatedAt: new Date().toISOString(),
  };
}
