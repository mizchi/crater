import fs from "node:fs";
import path from "node:path";

const DEFAULT_DIST_RELATIVE = path.join("dist", "cli", "main.js");
const DEFAULT_SOURCE_RELATIVE = path.join("src", "cli", "main.ts");
const DEFAULT_PACKAGE_DIST_RELATIVE = path.join(
  "node_modules",
  "@mizchi",
  "flaker",
  "dist",
  "cli",
  "main.js",
);

interface FlakerCliEnv {
  METRIC_CI_CLI_PATH?: string;
  METRIC_CI_ROOT?: string;
  FLAKER_CLI_PATH?: string;
  FLAKER_ROOT?: string;
}

function unique(items: string[]): string[] {
  return [...new Set(items)];
}

export function listFlakerCliCandidates(
  repoRoot: string,
  env: FlakerCliEnv = process.env,
): string[] {
  const candidates: string[] = [];
  for (const cliPath of [env.METRIC_CI_CLI_PATH, env.FLAKER_CLI_PATH]) {
    if (cliPath) {
      candidates.push(path.resolve(repoRoot, cliPath));
    }
  }

  const explicitRoots = unique([
    env.METRIC_CI_ROOT,
    env.FLAKER_ROOT,
  ]
    .filter((value): value is string => typeof value === "string" && value.length > 0)
    .map((value) => path.resolve(repoRoot, value)));

  const defaultRoots = unique([
    path.join(repoRoot, "..", "metric-ci"),
    path.join(repoRoot, "metric-ci"),
    path.join(repoRoot, "flaker"),
    path.join(repoRoot, "..", "flaker"),
  ]
    .filter((value): value is string => typeof value === "string" && value.length > 0)
    .map((value) => path.resolve(repoRoot, value)));

  for (const root of explicitRoots) {
    candidates.push(path.join(root, DEFAULT_DIST_RELATIVE));
    candidates.push(path.join(root, DEFAULT_SOURCE_RELATIVE));
  }

  candidates.push(path.resolve(repoRoot, DEFAULT_PACKAGE_DIST_RELATIVE));

  for (const root of defaultRoots) {
    candidates.push(path.join(root, DEFAULT_DIST_RELATIVE));
    candidates.push(path.join(root, DEFAULT_SOURCE_RELATIVE));
  }

  if (candidates.length === 0) {
    candidates.push(path.resolve(repoRoot, DEFAULT_PACKAGE_DIST_RELATIVE));
  }
  return unique(candidates);
}

export function resolveFlakerCliPath(
  repoRoot: string,
  options?: {
    env?: FlakerCliEnv;
    exists?: (candidate: string) => boolean;
  },
): string {
  const candidates = listFlakerCliCandidates(repoRoot, options?.env);
  const exists = options?.exists ?? fs.existsSync;
  for (const candidate of candidates) {
    if (exists(candidate)) {
      return candidate;
    }
  }
  return candidates[0]!;
}
