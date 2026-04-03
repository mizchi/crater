import type { FlakerConfig, FlakerIssue, FlakerSummary } from "./flaker-config-contract.ts";
import {
  isFilteredTask,
  type ResolvedFlakerTask,
} from "./flaker-config-task.ts";

function createIssue(issue: FlakerIssue): FlakerIssue {
  return issue;
}

export interface BuildFlakerConfigSummaryInputs {
  config: FlakerConfig;
  tasks: ResolvedFlakerTask[];
  discoveredSpecs: string[];
  existingSpecs: Set<string>;
}

export function buildFlakerConfigSummary(
  inputs: BuildFlakerConfigSummaryInputs,
): FlakerSummary {
  const errors: FlakerIssue[] = [];
  const warnings: FlakerIssue[] = [];
  const nodeIds = new Set<string>();
  const taskIds = new Set<string>();

  for (const node of inputs.config.nodes) {
    if (nodeIds.has(node.id)) {
      errors.push(createIssue({
        severity: "error",
        code: "duplicate-node-id",
        message: `Duplicate node id: ${node.id}`,
      }));
    }
    nodeIds.add(node.id);
  }

  for (const node of inputs.config.nodes) {
    for (const dependency of node.dependsOn) {
      if (!nodeIds.has(dependency)) {
        errors.push(createIssue({
          severity: "error",
          code: "unknown-node-dependency",
          message: `Node ${node.id} depends on missing node ${dependency}`,
        }));
      }
    }
  }

  for (const task of inputs.config.tasks) {
    if (taskIds.has(task.id)) {
      errors.push(createIssue({
        severity: "error",
        code: "duplicate-task-id",
        message: `Duplicate task id: ${task.id}`,
        taskId: task.id,
      }));
    }
    taskIds.add(task.id);

    if (!nodeIds.has(task.node)) {
      errors.push(createIssue({
        severity: "error",
        code: "unknown-task-node",
        message: `Task ${task.id} references missing node ${task.node}`,
        taskId: task.id,
      }));
    }
  }

  for (const task of inputs.config.tasks) {
    for (const dependency of task.needs) {
      if (!taskIds.has(dependency)) {
        errors.push(createIssue({
          severity: "error",
          code: "unknown-task-dependency",
          message: `Task ${task.id} depends on missing task ${dependency}`,
          taskId: task.id,
        }));
      }
    }
  }

  for (const task of inputs.tasks) {
    if (task.specs.length === 0) {
      warnings.push(createIssue({
        severity: "warning",
        code: "no-spec-files",
        message: `Task ${task.id} does not reference a Playwright spec file`,
        taskId: task.id,
      }));
      continue;
    }
    for (const spec of task.specs) {
      if (!inputs.existingSpecs.has(spec)) {
        errors.push(createIssue({
          severity: "error",
          code: "missing-spec-file",
          message: `Task ${task.id} references missing spec ${spec}`,
          taskId: task.id,
          spec,
        }));
      }
    }
  }

  const specOwners = new Map<string, ResolvedFlakerTask[]>();
  for (const task of inputs.tasks) {
    for (const spec of task.specs) {
      const owners = specOwners.get(spec) ?? [];
      owners.push(task);
      specOwners.set(spec, owners);
    }
  }

  for (const [spec, owners] of specOwners.entries()) {
    if (owners.length < 2) {
      continue;
    }
    const filteredOwners = owners.filter(isFilteredTask);
    if (filteredOwners.length !== owners.length) {
      errors.push(createIssue({
        severity: "error",
        code: "duplicate-spec-ownership",
        message: `Spec ${spec} is owned by multiple tasks without explicit grep partition: ${owners.map((owner) => owner.id).join(", ")}`,
        spec,
      }));
      continue;
    }
    const selectorKeys = new Set(
      owners.map((owner) => `${owner.grep ?? ""}::${owner.grepInvert ?? ""}`),
    );
    if (selectorKeys.size !== owners.length) {
      errors.push(createIssue({
        severity: "error",
        code: "duplicate-spec-selector",
        message: `Spec ${spec} has duplicate filtered ownership: ${owners.map((owner) => owner.id).join(", ")}`,
        spec,
      }));
    }
  }

  const managedSpecs = [...specOwners.keys()].sort();
  const managedSet = new Set(managedSpecs);
  const unmanagedSpecs = inputs.discoveredSpecs.filter((spec) => !managedSet.has(spec));

  for (const spec of unmanagedSpecs) {
    warnings.push(createIssue({
      severity: "warning",
      code: "unmanaged-spec",
      message: `Playwright spec is not managed by flaker: ${spec}`,
      spec,
    }));
  }

  return {
    workflow: inputs.config.workflow,
    nodeCount: inputs.config.nodes.length,
    taskCount: inputs.config.tasks.length,
    managedSpecs,
    unmanagedSpecs,
    tasks: [...inputs.tasks].sort((a, b) => a.id.localeCompare(b.id)),
    errors,
    warnings,
    generatedAt: new Date().toISOString(),
  };
}
