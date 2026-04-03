import type { FlakerTask } from "./flaker-config-contract.ts";
import { parseFlakerStar } from "./flaker-config-parser.ts";

export interface FlakerBatchPlanTask {
  id: string;
  node: string;
  trigger?: string;
  needs: string[];
  command: string[];
}

export interface FlakerBatchPlan {
  schemaVersion: 1;
  generatedAt: string;
  workflowName?: string;
  tasks: FlakerBatchPlanTask[];
}

function shouldIncludeTask(
  task: FlakerTask,
  selectedTasks?: string[],
  selectedNodes?: string[],
): boolean {
  if (task.trigger && task.trigger !== "auto") {
    return false;
  }
  if (selectedTasks && !selectedTasks.includes(task.id)) {
    return false;
  }
  if (selectedNodes && !selectedNodes.includes(task.node)) {
    return false;
  }
  return true;
}

export function buildFlakerBatchPlan(
  source: string,
  options?: {
    tasks?: string[];
    nodes?: string[];
  },
): FlakerBatchPlan {
  const config = parseFlakerStar(source);
  const tasks = config.tasks
    .filter((task) => shouldIncludeTask(task, options?.tasks, options?.nodes))
    .map((task) => ({
      id: task.id,
      node: task.node,
      trigger: task.trigger,
      needs: [...task.needs],
      command: [...task.cmd],
    }))
    .sort((a, b) => a.id.localeCompare(b.id));

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    workflowName: config.workflow?.name,
    tasks,
  };
}

export function renderFlakerBatchPlanMarkdown(plan: FlakerBatchPlan): string {
  const lines: string[] = [];
  lines.push("# Flaker Batch Plan");
  lines.push("");
  lines.push("| Task | Node | Needs | Command |");
  lines.push("| --- | --- | --- | --- |");
  for (const task of plan.tasks) {
    lines.push(
      `| ${task.id} | ${task.node} | ${task.needs.join(", ")} | ${task.command.join(" ")} |`,
    );
  }
  return `${lines.join("\n")}\n`;
}

export function renderGitHubMatrix(plan: FlakerBatchPlan): string {
  return JSON.stringify({
    include: plan.tasks.map((task) => ({
      task_id: task.id,
      node: task.node,
    })),
  });
}
