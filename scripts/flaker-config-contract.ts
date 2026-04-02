export interface FlakerWorkflow {
  name: string;
  maxParallel: number;
}

export interface FlakerNode {
  id: string;
  dependsOn: string[];
}

export interface FlakerTask {
  id: string;
  node: string;
  cmd: string[];
  srcs: string[];
  needs: string[];
  trigger?: string;
}

export interface FlakerConfig {
  workflow?: FlakerWorkflow;
  nodes: FlakerNode[];
  tasks: FlakerTask[];
}

export interface FlakerIssue {
  severity: "error" | "warning";
  code: string;
  message: string;
  taskId?: string;
  spec?: string;
}

export interface FlakerTaskSummary {
  id: string;
  node: string;
  specs: string[];
  grep?: string;
  grepInvert?: string;
  trigger?: string;
  needs: string[];
  srcCount: number;
  command: string[];
}

export interface FlakerSummary {
  workflow?: FlakerWorkflow;
  nodeCount: number;
  taskCount: number;
  managedSpecs: string[];
  unmanagedSpecs: string[];
  tasks: FlakerTaskSummary[];
  errors: FlakerIssue[];
  warnings: FlakerIssue[];
  generatedAt: string;
}

export interface FlakerSelectedTask {
  id: string;
  node: string;
  specs: string[];
  needs: string[];
  command: string[];
  matchReasons: string[];
  includedBy: string[];
}

export interface FlakerSelection {
  changedPaths: string[];
  matchedTaskIds: string[];
  selectedTaskIds: string[];
  unmatchedPaths: string[];
  selectedTasks: FlakerSelectedTask[];
  generatedAt: string;
}
