#!/usr/bin/env npx tsx

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const DEFAULT_CONFIG_PATH = "flaker.star";
const DEFAULT_TESTS_DIR = "tests";
const DEFAULT_EXCLUDED_SPECS = ["tests/playwright-benchmark.test.ts"];

type FlakerScalar = string | number;
type FlakerValue = FlakerScalar | FlakerValue[];

interface CliOptions {
  configPath: string;
  testsDir: string;
  jsonOutput?: string;
  markdownOutput?: string;
  check: boolean;
  listOnly: boolean;
}

interface RawCall {
  name: string;
  argsSource: string;
}

interface WorkflowArgs {
  name: string;
  max_parallel?: number;
}

interface NodeArgs {
  id: string;
  depends_on?: string[];
}

interface TaskArgs {
  id: string;
  node: string;
  cmd: string[];
  srcs?: string[];
  needs?: string[];
  trigger?: string;
}

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

interface SummarizeOptions {
  cwd: string;
  testsDir?: string;
  excludedSpecs?: string[];
}

function usage(): string {
  return [
    "Flaker config summary",
    "",
    "Usage:",
    "  npx tsx scripts/flaker-config.ts [options]",
    "",
    "Options:",
    `  --config <file>      flaker.star path (default: ${DEFAULT_CONFIG_PATH})`,
    `  --tests-dir <dir>    Playwright tests directory (default: ${DEFAULT_TESTS_DIR})`,
    "  --json <file>        Write JSON summary",
    "  --markdown <file>    Write Markdown summary",
    "  --check              Exit non-zero when validation errors exist",
    "  --list               Print managed task ids and resolved specs",
    "  --help               Show this help",
  ].join("\n");
}

function parseCliArgs(args: string[]): CliOptions {
  const options: CliOptions = {
    configPath: DEFAULT_CONFIG_PATH,
    testsDir: DEFAULT_TESTS_DIR,
    check: false,
    listOnly: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--help" || arg === "-h") {
      console.log(usage());
      process.exit(0);
    }
    if (arg === "--config") {
      options.configPath = args[++i] ?? "";
      continue;
    }
    if (arg === "--tests-dir") {
      options.testsDir = args[++i] ?? "";
      continue;
    }
    if (arg === "--json") {
      options.jsonOutput = args[++i];
      continue;
    }
    if (arg === "--markdown") {
      options.markdownOutput = args[++i];
      continue;
    }
    if (arg === "--check") {
      options.check = true;
      continue;
    }
    if (arg === "--list") {
      options.listOnly = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!options.configPath) {
    throw new Error("--config requires a file path");
  }
  if (!options.testsDir) {
    throw new Error("--tests-dir requires a directory path");
  }

  return options;
}

function normalizeRepoPath(root: string, target: string): string {
  return path.relative(root, path.resolve(root, target)).split(path.sep).join("/");
}

function escapeMarkdownCell(value: string): string {
  return value.replace(/\|/g, "\\|");
}

function writeOutput(filePath: string, content: string): void {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, "utf8");
}

function splitTopLevel(source: string, separator: string): string[] {
  const items: string[] = [];
  let current = "";
  let depth = 0;
  let quote: '"' | "'" | null = null;

  for (let i = 0; i < source.length; i++) {
    const ch = source[i]!;
    if (quote) {
      current += ch;
      if (ch === "\\") {
        const next = source[i + 1];
        if (next !== undefined) {
          current += next;
          i++;
        }
        continue;
      }
      if (ch === quote) {
        quote = null;
      }
      continue;
    }
    if (ch === '"' || ch === "'") {
      quote = ch;
      current += ch;
      continue;
    }
    if (ch === "#") {
      while (i < source.length && source[i] !== "\n") {
        i++;
      }
      continue;
    }
    if (ch === "(" || ch === "[" || ch === "{") {
      depth++;
      current += ch;
      continue;
    }
    if (ch === ")" || ch === "]" || ch === "}") {
      depth--;
      current += ch;
      continue;
    }
    if (depth === 0 && ch === separator) {
      const trimmed = current.trim();
      if (trimmed.length > 0) {
        items.push(trimmed);
      }
      current = "";
      continue;
    }
    current += ch;
  }

  const trailing = current.trim();
  if (trailing.length > 0) {
    items.push(trailing);
  }

  return items;
}

function findTopLevelAssignment(source: string): number {
  let depth = 0;
  let quote: '"' | "'" | null = null;

  for (let i = 0; i < source.length; i++) {
    const ch = source[i]!;
    if (quote) {
      if (ch === "\\") {
        i++;
        continue;
      }
      if (ch === quote) {
        quote = null;
      }
      continue;
    }
    if (ch === '"' || ch === "'") {
      quote = ch;
      continue;
    }
    if (ch === "(" || ch === "[" || ch === "{") {
      depth++;
      continue;
    }
    if (ch === ")" || ch === "]" || ch === "}") {
      depth--;
      continue;
    }
    if (depth === 0 && ch === "=") {
      return i;
    }
  }

  return -1;
}

function parseString(source: string): string {
  if (source.length < 2) {
    throw new Error(`Invalid string literal: ${source}`);
  }
  const quote = source[0];
  const body = source.slice(1, -1);
  if (quote === '"') {
    return JSON.parse(source);
  }
  return body.replace(/\\'/g, "'").replace(/\\\\/g, "\\");
}

function parseValue(source: string): FlakerValue {
  const trimmed = source.trim();
  if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
    const inner = trimmed.slice(1, -1);
    if (inner.trim().length === 0) {
      return [];
    }
    return splitTopLevel(inner, ",").map(parseValue);
  }
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return parseString(trimmed);
  }
  if (/^-?\d+$/.test(trimmed)) {
    return Number.parseInt(trimmed, 10);
  }
  return trimmed;
}

function parseKeywordArgs(source: string): Record<string, FlakerValue> {
  const fields: Record<string, FlakerValue> = {};
  for (const entry of splitTopLevel(source, ",")) {
    const eqIndex = findTopLevelAssignment(entry);
    if (eqIndex < 0) {
      throw new Error(`Unsupported positional argument: ${entry}`);
    }
    const key = entry.slice(0, eqIndex).trim();
    const value = entry.slice(eqIndex + 1).trim();
    fields[key] = parseValue(value);
  }
  return fields;
}

function extractCalls(source: string): RawCall[] {
  const calls: RawCall[] = [];

  for (let i = 0; i < source.length; i++) {
    const ch = source[i]!;
    if (/\s/.test(ch)) {
      continue;
    }
    if (ch === "#") {
      while (i < source.length && source[i] !== "\n") {
        i++;
      }
      continue;
    }
    if (!/[A-Za-z_]/.test(ch)) {
      continue;
    }

    let j = i + 1;
    while (j < source.length && /[A-Za-z0-9_]/.test(source[j]!)) {
      j++;
    }
    const name = source.slice(i, j);
    while (j < source.length && /\s/.test(source[j]!)) {
      j++;
    }
    if (source[j] !== "(") {
      i = j;
      continue;
    }

    let depth = 1;
    let quote: '"' | "'" | null = null;
    let k = j + 1;
    while (k < source.length && depth > 0) {
      const current = source[k]!;
      if (quote) {
        if (current === "\\") {
          k += 2;
          continue;
        }
        if (current === quote) {
          quote = null;
        }
        k++;
        continue;
      }
      if (current === '"' || current === "'") {
        quote = current;
        k++;
        continue;
      }
      if (current === "#") {
        while (k < source.length && source[k] !== "\n") {
          k++;
        }
        continue;
      }
      if (current === "(" || current === "[" || current === "{") {
        depth++;
      } else if (current === ")" || current === "]" || current === "}") {
        depth--;
      }
      k++;
    }

    if (depth !== 0) {
      throw new Error(`Unterminated call: ${name}`);
    }

    calls.push({
      name,
      argsSource: source.slice(j + 1, k - 1),
    });
    i = k - 1;
  }

  return calls;
}

function asString(value: FlakerValue | undefined, field: string): string {
  if (typeof value !== "string") {
    throw new Error(`Expected string for ${field}`);
  }
  return value;
}

function asNumber(value: FlakerValue | undefined, field: string, fallback = 0): number {
  if (value === undefined) {
    return fallback;
  }
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`Expected number for ${field}`);
  }
  return value;
}

function asStringArray(value: FlakerValue | undefined, field: string): string[] {
  if (value === undefined) {
    return [];
  }
  if (!Array.isArray(value)) {
    throw new Error(`Expected list for ${field}`);
  }
  return value.map((item) => {
    if (typeof item !== "string") {
      throw new Error(`Expected string list for ${field}`);
    }
    return item;
  });
}

export function parseFlakerStar(source: string): FlakerConfig {
  const config: FlakerConfig = {
    nodes: [],
    tasks: [],
  };

  for (const call of extractCalls(source)) {
    const args = parseKeywordArgs(call.argsSource);
    if (call.name === "workflow") {
      const workflowArgs = args as unknown as WorkflowArgs;
      config.workflow = {
        name: asString(workflowArgs.name as unknown as FlakerValue, "workflow.name"),
        maxParallel: asNumber(
          workflowArgs.max_parallel as unknown as FlakerValue,
          "workflow.max_parallel",
          1,
        ),
      };
      continue;
    }
    if (call.name === "node") {
      const nodeArgs = args as unknown as NodeArgs;
      config.nodes.push({
        id: asString(nodeArgs.id as unknown as FlakerValue, "node.id"),
        dependsOn: asStringArray(
          nodeArgs.depends_on as unknown as FlakerValue,
          "node.depends_on",
        ),
      });
      continue;
    }
    if (call.name === "task") {
      const taskArgs = args as unknown as TaskArgs;
      config.tasks.push({
        id: asString(taskArgs.id as unknown as FlakerValue, "task.id"),
        node: asString(taskArgs.node as unknown as FlakerValue, "task.node"),
        cmd: asStringArray(taskArgs.cmd as unknown as FlakerValue, "task.cmd"),
        srcs: asStringArray(taskArgs.srcs as unknown as FlakerValue, "task.srcs"),
        needs: asStringArray(taskArgs.needs as unknown as FlakerValue, "task.needs"),
        trigger: typeof taskArgs.trigger === "string" ? taskArgs.trigger : undefined,
      });
    }
  }

  return config;
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

function isFilteredTask(task: FlakerTaskSummary): boolean {
  return Boolean(task.grep || task.grepInvert);
}

function createIssue(issue: FlakerIssue): FlakerIssue {
  return issue;
}

export function summarizeFlakerConfig(
  config: FlakerConfig,
  options: SummarizeOptions,
): FlakerSummary {
  const cwd = options.cwd;
  const testsDir = options.testsDir ?? DEFAULT_TESTS_DIR;
  const excludedSpecs = options.excludedSpecs ?? DEFAULT_EXCLUDED_SPECS;

  const errors: FlakerIssue[] = [];
  const warnings: FlakerIssue[] = [];
  const nodeIds = new Set<string>();
  const taskIds = new Set<string>();

  for (const node of config.nodes) {
    if (nodeIds.has(node.id)) {
      errors.push(createIssue({
        severity: "error",
        code: "duplicate-node-id",
        message: `Duplicate node id: ${node.id}`,
      }));
    }
    nodeIds.add(node.id);
  }

  for (const node of config.nodes) {
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

  const tasks: FlakerTaskSummary[] = config.tasks.map((task) => {
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
    };
  });

  for (const task of config.tasks) {
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

  for (const task of tasks) {
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
      if (!fs.existsSync(path.join(cwd, spec))) {
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

  const specOwners = new Map<string, FlakerTaskSummary[]>();
  for (const task of tasks) {
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

  const discoveredSpecs = discoverPlaywrightSpecs(cwd, testsDir, excludedSpecs);
  const managedSpecs = [...specOwners.keys()].sort();
  const managedSet = new Set(managedSpecs);
  const unmanagedSpecs = discoveredSpecs.filter((spec) => !managedSet.has(spec));

  for (const spec of unmanagedSpecs) {
    warnings.push(createIssue({
      severity: "warning",
      code: "unmanaged-spec",
      message: `Playwright spec is not managed by flaker: ${spec}`,
      spec,
    }));
  }

  return {
    workflow: config.workflow,
    nodeCount: config.nodes.length,
    taskCount: config.tasks.length,
    managedSpecs,
    unmanagedSpecs,
    tasks: tasks.sort((a, b) => a.id.localeCompare(b.id)),
    errors,
    warnings,
    generatedAt: new Date().toISOString(),
  };
}

export function renderMarkdownSummary(summary: FlakerSummary): string {
  const lines: string[] = [];

  lines.push("# Flaker Config Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Workflow | ${escapeMarkdownCell(summary.workflow?.name ?? "unknown")} |`);
  lines.push(`| Nodes | ${summary.nodeCount} |`);
  lines.push(`| Tasks | ${summary.taskCount} |`);
  lines.push(`| Managed specs | ${summary.managedSpecs.length} |`);
  lines.push(`| Unmanaged specs | ${summary.unmanagedSpecs.length} |`);
  lines.push(`| Errors | ${summary.errors.length} |`);
  lines.push(`| Warnings | ${summary.warnings.length} |`);

  lines.push("");
  lines.push("## Tasks");
  lines.push("");
  lines.push("| Task | Node | Specs | Filter | Needs | Trigger | Srcs |");
  lines.push("| --- | --- | --- | --- | --- | --- | --- |");
  for (const task of summary.tasks) {
    lines.push(
      `| ${escapeMarkdownCell(task.id)} | ${escapeMarkdownCell(task.node)} | ${escapeMarkdownCell(task.specs.join("<br>"))} | ${escapeMarkdownCell(task.grep ?? task.grepInvert ?? "")} | ${escapeMarkdownCell(task.needs.join(", "))} | ${escapeMarkdownCell(task.trigger ?? "")} | ${task.srcCount} |`,
    );
  }

  if (summary.errors.length > 0) {
    lines.push("");
    lines.push("## Errors");
    lines.push("");
    lines.push("| Code | Message |");
    lines.push("| --- | --- |");
    for (const issue of summary.errors) {
      lines.push(`| ${escapeMarkdownCell(issue.code)} | ${escapeMarkdownCell(issue.message)} |`);
    }
  }

  if (summary.warnings.length > 0) {
    lines.push("");
    lines.push("## Warnings");
    lines.push("");
    lines.push("| Code | Message |");
    lines.push("| --- | --- |");
    for (const issue of summary.warnings) {
      lines.push(`| ${escapeMarkdownCell(issue.code)} | ${escapeMarkdownCell(issue.message)} |`);
    }
  }

  if (summary.unmanagedSpecs.length > 0) {
    lines.push("");
    lines.push("## Unmanaged Specs");
    lines.push("");
    for (const spec of summary.unmanagedSpecs) {
      lines.push(`- ${spec}`);
    }
  }

  return `${lines.join("\n")}\n`;
}

function printTaskList(summary: FlakerSummary): void {
  for (const task of summary.tasks) {
    const filter = task.grep ?? task.grepInvert;
    const suffix = filter ? ` [grep=${filter}]` : "";
    console.log(`${task.id}\t${task.specs.join(", ")}${suffix}`);
  }
}

function isMainModule(): boolean {
  if (!import.meta.url.startsWith("file:")) {
    return false;
  }
  return process.argv[1] === fileURLToPath(import.meta.url);
}

if (isMainModule()) {
  try {
    const options = parseCliArgs(process.argv.slice(2));
    const configSource = fs.readFileSync(path.resolve(process.cwd(), options.configPath), "utf8");
    const config = parseFlakerStar(configSource);
    const summary = summarizeFlakerConfig(config, {
      cwd: process.cwd(),
      testsDir: options.testsDir,
    });

    if (options.listOnly) {
      printTaskList(summary);
    } else {
      const markdown = renderMarkdownSummary(summary);
      process.stdout.write(markdown);
      if (options.markdownOutput) {
        writeOutput(options.markdownOutput, markdown);
      }
    }

    if (options.jsonOutput) {
      writeOutput(options.jsonOutput, `${JSON.stringify(summary, null, 2)}\n`);
    }

    if (options.check && summary.errors.length > 0) {
      process.exit(1);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(message);
    process.exit(1);
  }
}
