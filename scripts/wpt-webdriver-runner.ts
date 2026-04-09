#!/usr/bin/env npx tsx
/**
 * WPT WebDriver BiDi Test Runner for Crater
 *
 * Runs WPT WebDriver BiDi tests against Crater's BiDi server.
 *
 * Usage:
 *   npx tsx scripts/wpt-webdriver-runner.ts --list
 *   npx tsx scripts/wpt-webdriver-runner.ts session/status
 *   npx tsx scripts/wpt-webdriver-runner.ts --subset     # Alias of --profile strict
 *   npx tsx scripts/wpt-webdriver-runner.ts --profile strict
 *   npx tsx scripts/wpt-webdriver-runner.ts --quick      # Skip timeout-prone tests
 */

import { spawn, execSync, ChildProcess } from "child_process";
import fs from "fs";
import path from "path";
import { pathToFileURL } from "url";
import { resolveBidiUrl } from "./bidi-url.ts";

const WPT_TESTS_ROOT = "wpt/webdriver/tests";
const WPT_BIDI_TESTS = `${WPT_TESTS_ROOT}/bidi`;
const WPT_SUPPORT_TESTS = `${WPT_TESTS_ROOT}/support`;
const CRATER_BIDI_PORT = 9222;
const CRATER_BIDI_STATUS_URL = `http://127.0.0.1:${CRATER_BIDI_PORT}/`;
const SUBSET_CONFIG = "scripts/wpt-bidi-subset.json";
const DEFAULT_PROFILE_NAME = "strict";

interface CliOptions {
  args: string[];
  jsonOutput?: string;
}

interface TestProfile {
  description?: string;
  targets: string[];
  skip_patterns?: string[];
  quick?: boolean;
  timeout?: number;
}

interface SubsetConfig {
  tests?: Record<string, Record<string, string[]>>;
  skip_patterns?: string[];
  default_skip_patterns?: string[];
  profiles?: Record<string, TestProfile>;
}

interface PytestSummary {
  passed: number;
  failed: number;
  errors: number;
  total: number;
}

interface RunOutcome {
  exitCode: number;
  summary: PytestSummary;
}

interface WptCompatShardReport {
  schemaVersion: 1;
  suite: "wpt-webdriver";
  target: string;
  passed: number;
  failed: number;
  errors: number;
  total: number;
  passRate: number;
  generatedAt: string;
}

// Load subset configuration
function loadSubsetConfig(): SubsetConfig | null {
  const configPath = path.join(process.cwd(), SUBSET_CONFIG);
  if (!fs.existsSync(configPath)) return null;
  return JSON.parse(fs.readFileSync(configPath, "utf-8"));
}

// Check if uv is available
function checkUv(): boolean {
  try {
    execSync("uv --version", { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

// Start Crater BiDi server
export function resolveBidiServerPath(cwd: string = process.cwd()): string | null {
  const candidates = [
    path.join(cwd, "browser/jsbidi/_build/js/release/build/bidi_main/bidi_main.js"),
    path.join(cwd, "browser/target/js/release/build/bidi_main/bidi_main.js"),
    path.join(cwd, "browser/_build/js/release/build/bidi_main/bidi_main.js"),
  ];

  for (const serverPath of candidates) {
    if (fs.existsSync(serverPath)) {
      return serverPath;
    }
  }
  return null;
}

function startServer(): ChildProcess {
  console.log("Starting Crater BiDi server...");
  const serverPath = resolveBidiServerPath();

  if (!serverPath) {
    console.error("BiDi server not built. Run: just build-bidi");
    console.error("Expected one of:");
    console.error("  browser/jsbidi/_build/js/release/build/bidi_main/bidi_main.js");
    console.error("  browser/target/js/release/build/bidi_main/bidi_main.js");
    console.error("  browser/_build/js/release/build/bidi_main/bidi_main.js");
    process.exit(1);
  }

  const server = spawn("deno", ["run", "-A", serverPath], {
    stdio: ["ignore", "pipe", "pipe"],
    detached: false,
  });

  server.stdout?.on("data", (data) => {
    const msg = data.toString().trim();
    if (msg) console.log(`[server] ${msg}`);
  });

  server.stderr?.on("data", (data) => {
    const msg = data.toString().trim();
    if (msg) console.error(`[server] ${msg}`);
  });

  return server;
}

// Wait for server to be ready
async function waitForServer(timeout = 5000): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    try {
      const res = await fetch(`http://127.0.0.1:${CRATER_BIDI_PORT}/`);
      if (res.ok) return true;
    } catch {
      // Server not ready yet
    }
    await new Promise((r) => setTimeout(r, 100));
  }
  return false;
}

// List available test modules
function listTests(): void {
  const testsDir = path.join(process.cwd(), WPT_BIDI_TESTS);
  if (!fs.existsSync(testsDir)) {
    console.error(`WPT tests not found at ${testsDir}`);
    console.error("Run: git submodule update --init --recursive");
    process.exit(1);
  }

  const modules = fs
    .readdirSync(testsDir)
    .filter((f) => {
      const fullPath = path.join(testsDir, f);
      return fs.statSync(fullPath).isDirectory() && !f.startsWith("_");
    })
    .sort();

  console.log("Available WPT WebDriver BiDi test modules:\n");
  for (const mod of modules) {
    const modPath = path.join(testsDir, mod);
    const testCount = countTests(modPath);
    console.log(`  ${mod} (${testCount} tests)`);
  }
  console.log(`\nTotal: ${modules.length} modules`);

  // Show subset info
  const config = loadSubsetConfig();
  const strict = resolveProfileConfig(config, DEFAULT_PROFILE_NAME);
  if (strict) {
    console.log(`\nKnown passing targets (--subset / --profile ${DEFAULT_PROFILE_NAME}):`);
    for (const mod of strict.targets) {
      console.log(`  ${mod}`);
    }
  }
  listProfiles(config);
}

// Count test files in a directory
function countTests(dir: string): number {
  let count = 0;
  const items = fs.readdirSync(dir);
  for (const item of items) {
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      count += countTests(fullPath);
    } else if (item.endsWith(".py") && !item.startsWith("_") && !item.startsWith("conftest")) {
      count++;
    }
  }
  return count;
}

function normalizePathForGlob(input: string): string {
  return input.replaceAll(path.sep, "/").replace(/^\.\//, "");
}

export function shouldSkipPath(relativePath: string, skipPatterns: string[]): boolean {
  const normalizedPath = normalizePathForGlob(relativePath);
  return skipPatterns.some((pattern) => {
    const normalizedPattern = normalizePathForGlob(pattern);
    return path.matchesGlob(normalizedPath, normalizedPattern);
  });
}

export function resolveRequestedTargetPath(testPath: string, baseDir: string): string | null {
  if (!testPath) return "";
  const normalized = normalizePathForGlob(testPath);
  const directPath = path.join(baseDir, normalized);
  if (fs.existsSync(directPath)) return normalized;
  if (!normalized.endsWith(".py")) {
    const withPy = `${normalized}.py`;
    if (fs.existsSync(path.join(baseDir, withPy))) return withPy;
  }
  return null;
}

function getDefaultSkipPatterns(config?: SubsetConfig | null): string[] {
  const legacy = config?.skip_patterns ?? [];
  const explicit = config?.default_skip_patterns ?? [];
  return [...explicit, ...legacy];
}

function resolveProfileConfig(config: SubsetConfig | null, profileName: string): TestProfile | null {
  if (!config) return null;
  if (config.profiles?.[profileName]) return config.profiles[profileName];

  // Backward compatibility for old subset config.
  if (profileName === DEFAULT_PROFILE_NAME && config.tests) {
    return {
      targets: Object.keys(config.tests),
      skip_patterns: config.skip_patterns ?? [],
      quick: true,
      timeout: 10,
    };
  }

  return null;
}

function listProfiles(config: SubsetConfig | null): void {
  if (!config?.profiles) return;
  const profileEntries = Object.entries(config.profiles).sort(([a], [b]) => a.localeCompare(b));
  if (profileEntries.length === 0) return;

  console.log("\nAvailable profiles:");
  for (const [name, profile] of profileEntries) {
    const desc = profile.description ? ` - ${profile.description}` : "";
    console.log(`  ${name} (${profile.targets.length} targets)${desc}`);
  }
}

function emptySummary(): PytestSummary {
  return {
    passed: 0,
    failed: 0,
    errors: 0,
    total: 0,
  };
}

function stripAnsi(input: string): string {
  return input.replace(/\x1B\[[0-9;]*m/g, "");
}

export function parsePytestSummary(output: string): PytestSummary {
  const cleaned = stripAnsi(output).replace(/\r/g, "");
  const lines = cleaned.split("\n").map((line) => line.trim());
  const summaryLine = [...lines].reverse().find((line) => {
    if (!/=+/.test(line)) return false;
    return /(passed|failed|error|errors|skipped|xfailed|xpassed)/.test(line);
  });

  if (!summaryLine) {
    if (/no tests ran/i.test(cleaned)) return emptySummary();
    return emptySummary();
  }

  const counts = {
    passed: 0,
    failed: 0,
    errors: 0,
    skipped: 0,
    xfailed: 0,
    xpassed: 0,
  };

  const tokenRegex = /(\d+)\s+(passed|failed|error|errors|skipped|xfailed|xpassed)\b/g;
  let match: RegExpExecArray | null;
  while ((match = tokenRegex.exec(summaryLine)) !== null) {
    const value = Number.parseInt(match[1], 10);
    const key = match[2];
    if (!Number.isFinite(value)) continue;
    if (key === "error" || key === "errors") {
      counts.errors += value;
      continue;
    }
    if (key in counts) {
      counts[key as keyof typeof counts] += value;
    }
  }

  return {
    passed: counts.passed,
    failed: counts.failed,
    errors: counts.errors,
    total: counts.passed + counts.failed + counts.errors,
  };
}

function mergeSummaries(base: PytestSummary, item: PytestSummary): PytestSummary {
  return {
    passed: base.passed + item.passed,
    failed: base.failed + item.failed,
    errors: base.errors + item.errors,
    total: base.total + item.total,
  };
}

function parseCliArgs(rawArgs: string[]): CliOptions {
  const options: CliOptions = { args: [] };

  for (let i = 0; i < rawArgs.length; i++) {
    const arg = rawArgs[i];
    if (arg === "--json") {
      options.jsonOutput = rawArgs[++i];
      continue;
    }
    if (arg.startsWith("--json=")) {
      options.jsonOutput = arg.slice("--json=".length);
      continue;
    }
    options.args.push(arg);
  }

  return options;
}

function detectTarget(args: string[]): string {
  if (args.length === 0) return "all";
  if (args[0] === "--subset") return "subset";
  if (args[0] === "--profile") {
    return args[1] ? `profile ${args[1]}` : "profile";
  }
  if (args[0] === "--all") return "all";
  if (args[0] === "--quick") {
    return args[1] ? `quick ${args[1]}` : "quick";
  }
  return args[0];
}

function writeShardReport(jsonOutput: string | undefined, target: string, summary: PytestSummary): void {
  if (!jsonOutput) return;
  const report: WptCompatShardReport = {
    schemaVersion: 1,
    suite: "wpt-webdriver",
    target,
    passed: summary.passed,
    failed: summary.failed,
    errors: summary.errors,
    total: summary.total,
    passRate: summary.total > 0 ? summary.passed / summary.total : 0,
    generatedAt: new Date().toISOString(),
  };
  fs.mkdirSync(path.dirname(jsonOutput), { recursive: true });
  fs.writeFileSync(jsonOutput, JSON.stringify(report, null, 2), "utf-8");
}

function collectPythonFiles(targetPath: string): string[] {
  if (!fs.existsSync(targetPath)) return [];
  const stat = fs.statSync(targetPath);
  if (stat.isFile()) return [targetPath];

  const files: string[] = [];
  const stack = [targetPath];
  while (stack.length > 0) {
    const current = stack.pop()!;
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name === "__pycache__") continue;
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(full);
        continue;
      }
      if (!entry.isFile()) continue;
      if (!entry.name.endsWith(".py")) continue;
      if (entry.name === "conftest.py" || entry.name === "__init__.py" || entry.name.startsWith("_")) {
        continue;
      }
      files.push(full);
    }
  }
  return files.sort();
}

function collectConftestFiles(targetPath: string): string[] {
  if (!fs.existsSync(targetPath)) return [];
  const stat = fs.statSync(targetPath);
  const conftests = new Set<string>();

  const addParentConftests = (startDir: string): void => {
    let current = startDir;
    const bidiRoot = path.join(process.cwd(), WPT_BIDI_TESTS);
    while (current.startsWith(bidiRoot)) {
      const conftest = path.join(current, "conftest.py");
      if (fs.existsSync(conftest)) {
        conftests.add(conftest);
      }
      if (current === bidiRoot) break;
      current = path.dirname(current);
    }
  };

  if (stat.isDirectory()) {
    const stack = [targetPath];
    while (stack.length > 0) {
      const current = stack.pop()!;
      const entries = fs.readdirSync(current, { withFileTypes: true });
      for (const entry of entries) {
        const full = path.join(current, entry.name);
        if (entry.isDirectory()) {
          stack.push(full);
          continue;
        }
        if (entry.isFile() && entry.name === "conftest.py") {
          conftests.add(full);
        }
      }
    }
    addParentConftests(targetPath);
  } else {
    addParentConftests(path.dirname(targetPath));
  }

  return [...conftests].sort();
}

function copyFileEnsuringDir(src: string, dest: string): void {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
}

function copyInitChain(
  bidiRoot: string,
  testsRoot: string,
  relativeFromBidi: string,
): void {
  const bidiInit = path.join(bidiRoot, "__init__.py");
  if (fs.existsSync(bidiInit)) {
    copyFileEnsuringDir(bidiInit, path.join(testsRoot, "bidi", "__init__.py"));
  }

  const dirParts = path.dirname(relativeFromBidi).split(path.sep).filter(Boolean);
  let sourceDir = bidiRoot;
  let destDir = path.join(testsRoot, "bidi");

  for (const part of dirParts) {
    sourceDir = path.join(sourceDir, part);
    destDir = path.join(destDir, part);
    const initPath = path.join(sourceDir, "__init__.py");
    if (fs.existsSync(initPath)) {
      copyFileEnsuringDir(initPath, path.join(destDir, "__init__.py"));
    }
  }
}

function copySupportModules(testsRoot: string): void {
  const sourceTestsRoot = path.join(process.cwd(), WPT_TESTS_ROOT);
  const testsInit = path.join(sourceTestsRoot, "__init__.py");
  if (fs.existsSync(testsInit)) {
    copyFileEnsuringDir(testsInit, path.join(testsRoot, "__init__.py"));
  }

  const supportRoot = path.join(process.cwd(), WPT_SUPPORT_TESTS);
  if (!fs.existsSync(supportRoot)) return;

  const files = collectPythonFiles(supportRoot);
  const stack = [supportRoot];
  const inits: string[] = [];
  while (stack.length > 0) {
    const current = stack.pop()!;
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(full);
        continue;
      }
      if (entry.isFile() && entry.name === "__init__.py") {
        inits.push(full);
      }
    }
  }

  for (const file of [...files, ...inits]) {
    const rel = path.relative(supportRoot, file);
    copyFileEnsuringDir(file, path.join(testsRoot, "support", rel));
  }
}

interface CopiedTests {
  tempDir: string;
  runPath: string;
  copied: number;
  skipped: string[];
}

// Copy test files to temp directory while preserving package structure.
function copyTestsToTemp(
  testPath: string,
  options: { skipPatterns?: string[]; quick?: boolean } = {}
): CopiedTests {
  const bidiRoot = path.join(process.cwd(), WPT_BIDI_TESTS);
  const tempDir = path.join(process.cwd(), ".wpt-temp");
  const testsRoot = path.join(tempDir, "tests");
  const skipPatterns = options.skipPatterns ?? [];
  const quickSkipFiles = options.quick
    ? ["original_opener.py", "user_activation.py", "sandbox.py"]
    : [];

  if (fs.existsSync(tempDir)) {
    fs.rmSync(tempDir, { recursive: true });
  }
  fs.mkdirSync(testsRoot, { recursive: true });

  const resolvedTestPath = resolveRequestedTargetPath(testPath, bidiRoot);
  if (resolvedTestPath === null) {
    return { tempDir, runPath: "", copied: 0, skipped: [] };
  }

  const sourceTargetPath = resolvedTestPath
    ? path.join(bidiRoot, resolvedTestPath)
    : bidiRoot;
  const runPath = resolvedTestPath
    ? path.join(testsRoot, "bidi", resolvedTestPath)
    : path.join(testsRoot, "bidi");

  const candidates = collectPythonFiles(sourceTargetPath);
  const skipped: string[] = [];
  let copied = 0;

  for (const sourcePath of candidates) {
    const relFromBidi = path.relative(bidiRoot, sourcePath);
    const relFromBidiPosix = normalizePathForGlob(relFromBidi);
    const filename = path.basename(sourcePath);
    if (shouldSkipPath(relFromBidiPosix, skipPatterns) || quickSkipFiles.includes(filename)) {
      skipped.push(`${relFromBidiPosix} (skip pattern)`);
      continue;
    }
    const destination = path.join(testsRoot, "bidi", relFromBidi);
    copyFileEnsuringDir(sourcePath, destination);
    copyInitChain(bidiRoot, testsRoot, relFromBidi);
    copied++;
  }

  const conftestCandidates = collectConftestFiles(sourceTargetPath);
  for (const conftestPath of conftestCandidates) {
    const relFromBidi = path.relative(bidiRoot, conftestPath);
    const destination = path.join(testsRoot, "bidi", relFromBidi);
    copyFileEnsuringDir(conftestPath, destination);
    copyInitChain(bidiRoot, testsRoot, relFromBidi);
  }

  copySupportModules(testsRoot);
  return { tempDir, runPath, copied, skipped };
}

// Run tests
async function runTests(
  testPath: string,
  options: { skipPatterns?: string[]; quick?: boolean; timeout?: number } = {}
): Promise<RunOutcome> {
  const resolvedPath = resolveRequestedTargetPath(testPath, path.join(process.cwd(), WPT_BIDI_TESTS));
  if (resolvedPath === null) {
    const fullPath = path.join(process.cwd(), WPT_BIDI_TESTS, testPath);
    console.error(`Test path not found: ${fullPath}`);
    return { exitCode: 1, summary: { passed: 0, failed: 1, errors: 0, total: 1 } };
  }

  const { tempDir, runPath, copied, skipped } = copyTestsToTemp(resolvedPath, options);

  if (copied === 0) {
    console.error("No compatible tests found");
    if (skipped.length > 0) {
      console.log(`Skipped: ${skipped.slice(0, 5).join(", ")}${skipped.length > 5 ? ` and ${skipped.length - 5} more` : ""}`);
    }
    return { exitCode: 1, summary: { passed: 0, failed: 1, errors: 0, total: 1 } };
  }

  console.log(`Copied ${copied} tests to ${tempDir}`);
  if (skipped.length > 0) {
    console.log(`Skipped ${skipped.length} tests\n`);
  }

  const craterBidiUrl = await resolveBidiUrl({
    statusUrl: CRATER_BIDI_STATUS_URL,
  });

  // Run pytest with our adapter
  const env = {
    ...process.env,
    CRATER_BIDI_URL: craterBidiUrl,
    PYTHONPATH: [path.join(process.cwd(), "scripts"), tempDir, process.env.PYTHONPATH]
      .filter(Boolean)
      .join(path.delimiter),
  };

  const timeout = options.timeout || 30;

  return new Promise((resolve) => {
    const stdoutChunks: string[] = [];
    const stderrChunks: string[] = [];

    const pytest = spawn(
      "uv",
      [
        "run",
        "--",
        "pytest",
        runPath,
        "-v",
        `--timeout=${timeout}`,
        "-p", "tests.support.fixtures_bidi",
        "-p", "tests.support.fixtures_http",
        "-p", "crater_bidi_adapter",
        "-c", path.join(process.cwd(), "pyproject.toml"),
        "--tb=short",
      ],
      {
        stdio: ["ignore", "pipe", "pipe"],
        env,
        cwd: process.cwd(),
      }
    );

    pytest.stdout?.on("data", (data) => {
      const text = data.toString();
      stdoutChunks.push(text);
      process.stdout.write(text);
    });

    pytest.stderr?.on("data", (data) => {
      const text = data.toString();
      stderrChunks.push(text);
      process.stderr.write(text);
    });

    pytest.on("close", (code) => {
      // Clean up temp dir
      fs.rmSync(tempDir, { recursive: true, force: true });
      const exitCode = code ?? 1;
      const output = `${stdoutChunks.join("")}\n${stderrChunks.join("")}`;
      let summary = parsePytestSummary(output);
      if (summary.total === 0 && exitCode !== 0) {
        // pytest summary line can be missing when process crashes/interrupted
        summary = { passed: 0, failed: 1, errors: 0, total: 1 };
      }
      resolve({ exitCode, summary });
    });
  });
}

// Run a named profile from scripts/wpt-bidi-subset.json.
async function runProfile(profileName: string): Promise<RunOutcome> {
  const config = loadSubsetConfig();
  const profile = resolveProfileConfig(config, profileName);
  if (!profile) {
    console.error(`Profile "${profileName}" not found in ${SUBSET_CONFIG}`);
    return { exitCode: 1, summary: { passed: 0, failed: 1, errors: 0, total: 1 } };
  }

  console.log(`Running profile: ${profileName}\n`);

  let moduleFailures = 0;
  let totalSummary = emptySummary();
  const defaultSkipPatterns = getDefaultSkipPatterns(config);
  const skipPatterns = [...defaultSkipPatterns, ...(profile.skip_patterns ?? [])];
  const quick = profile.quick ?? true;
  const timeout = profile.timeout ?? 10;

  for (const target of profile.targets) {
    console.log(`\n=== ${target} ===`);
    const outcome = await runTests(target, {
      skipPatterns,
      quick,
      timeout,
    });
    totalSummary = mergeSummaries(totalSummary, outcome.summary);
    if (outcome.exitCode !== 0) {
      moduleFailures++;
    }
  }

  console.log(`\n=== Summary ===`);
  console.log(`Total passed: ${totalSummary.passed}`);
  console.log(`Total failed: ${totalSummary.failed}`);
  console.log(`Total errors: ${totalSummary.errors}`);
  console.log(`Modules failed: ${moduleFailures}`);

  return {
    exitCode: moduleFailures > 0 ? 1 : 0,
    summary: totalSummary,
  };
}

// Main
async function main(): Promise<number> {
  const cliOptions = parseCliArgs(process.argv.slice(2));
  const args = cliOptions.args;
  const target = detectTarget(args);

  if (args.length === 0 || args[0] === "--help") {
    console.log("WPT WebDriver BiDi Test Runner for Crater\n");
    console.log("Usage:");
    console.log("  npx tsx scripts/wpt-webdriver-runner.ts --list");
    console.log("  npx tsx scripts/wpt-webdriver-runner.ts session/status");
    console.log("  npx tsx scripts/wpt-webdriver-runner.ts --subset     # Alias of --profile strict");
    console.log("  npx tsx scripts/wpt-webdriver-runner.ts --profile strict");
    console.log("  npx tsx scripts/wpt-webdriver-runner.ts --quick <module>  # Skip timeout tests");
    console.log("  npx tsx scripts/wpt-webdriver-runner.ts --all");
    console.log("  npx tsx scripts/wpt-webdriver-runner.ts session/status --json .wpt-reports/wpt-webdriver-session-status.json");
    return 0;
  }

  if (args[0] === "--list") {
    listTests();
    return 0;
  }

  if (!checkUv()) {
    console.error("uv not found. Install: curl -LsSf https://astral.sh/uv/install.sh | sh");
    writeShardReport(cliOptions.jsonOutput, target, { passed: 0, failed: 1, errors: 0, total: 1 });
    return 1;
  }

  // Start server
  const server = startServer();

  try {
    // Wait for server
    console.log("Waiting for server...");
    const ready = await waitForServer();
    if (!ready) {
      console.error("Server failed to start");
      writeShardReport(cliOptions.jsonOutput, target, { passed: 0, failed: 1, errors: 0, total: 1 });
      return 1;
    }
    console.log("Server ready.\n");

    let outcome: RunOutcome;

    if (args[0] === "--subset") {
      outcome = await runProfile(DEFAULT_PROFILE_NAME);
    } else if (args[0] === "--profile") {
      const profileName = args[1] ?? "";
      outcome = await runProfile(profileName);
    } else if (args[0] === "--quick") {
      const testPath = args[1] || "";
      const config = loadSubsetConfig();
      outcome = await runTests(testPath, {
        skipPatterns: getDefaultSkipPatterns(config),
        quick: true,
        timeout: 10,
      });
    } else {
      const testPath = args[0] === "--all" ? "" : args[0];
      outcome = await runTests(testPath);
    }

    writeShardReport(cliOptions.jsonOutput, target, outcome.summary);
    return outcome.exitCode;
  } catch (error) {
    writeShardReport(cliOptions.jsonOutput, target, { passed: 0, failed: 1, errors: 0, total: 1 });
    throw error;
  } finally {
    // Stop server
    server.kill("SIGTERM");
  }
}

const isMainModule =
  process.argv[1] !== undefined &&
  import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMainModule) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  }).then((code) => {
    if (typeof code === "number") {
      process.exitCode = code;
    }
  });
}
