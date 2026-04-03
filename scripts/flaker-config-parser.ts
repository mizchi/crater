import type { FlakerConfig } from "./flaker-config-contract.ts";

type FlakerScalar = string | number;
type FlakerValue = FlakerScalar | FlakerValue[];

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
