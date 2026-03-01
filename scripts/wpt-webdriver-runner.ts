#!/usr/bin/env npx tsx
/**
 * WPT WebDriver BiDi Test Runner for Crater
 *
 * Runs WPT WebDriver BiDi tests against Crater's BiDi server.
 *
 * Usage:
 *   npx tsx scripts/wpt-webdriver-runner.ts --list
 *   npx tsx scripts/wpt-webdriver-runner.ts session/status
 *   npx tsx scripts/wpt-webdriver-runner.ts --subset     # Run only known-passing tests
 *   npx tsx scripts/wpt-webdriver-runner.ts --quick      # Skip timeout-prone tests
 */

import { spawn, execSync, ChildProcess } from "child_process";
import fs from "fs";
import path from "path";
import { pathToFileURL } from "url";

const WPT_BIDI_TESTS = "wpt/webdriver/tests/bidi";
const CRATER_BIDI_PORT = 9222;
const CRATER_BIDI_URL = `ws://127.0.0.1:${CRATER_BIDI_PORT}`;
const SUBSET_CONFIG = "scripts/wpt-bidi-subset.json";

interface CliOptions {
  args: string[];
  jsonOutput?: string;
}

interface SubsetConfig {
  tests: Record<string, Record<string, string[]>>;
  skip_patterns: string[];
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
  if (config) {
    console.log("\nKnown passing test modules (--subset):");
    for (const mod of Object.keys(config.tests)) {
      console.log(`  ${mod}`);
    }
  }
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

// Check if file should be skipped
function shouldSkipFile(filename: string, skipPatterns: string[]): boolean {
  for (const pattern of skipPatterns) {
    const name = pattern.replace("**/", "");
    if (filename === name || filename.endsWith(name)) {
      return true;
    }
  }
  return false;
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

// Copy test files to temp directory
function copySimpleTests(
  testPath: string,
  options: { skipPatterns?: string[]; quick?: boolean } = {}
): { tempDir: string; copied: number; skipped: string[] } {
  const fullPath = path.join(process.cwd(), WPT_BIDI_TESTS, testPath);
  const tempDir = path.join(process.cwd(), ".wpt-temp");

  // Clean up old temp dir
  if (fs.existsSync(tempDir)) {
    fs.rmSync(tempDir, { recursive: true });
  }
  fs.mkdirSync(tempDir, { recursive: true });

  let copied = 0;
  const skipped: string[] = [];
  const skipPatterns = options.skipPatterns || [];

  // Quick mode skips tests known to timeout
  const quickSkipFiles = options.quick ? [
    "original_opener.py",
    "user_activation.py",
    "sandbox.py",
  ] : [];

  // Copy test files that don't have relative imports
  const copyFile = (src: string, dest: string) => {
    const filename = path.basename(src);

    // Skip based on patterns
    if (shouldSkipFile(filename, skipPatterns) || quickSkipFiles.includes(filename)) {
      skipped.push(filename + " (skip pattern)");
      return;
    }

    const content = fs.readFileSync(src, "utf-8");

    // Skip files with relative imports or WPT support imports
    if (
      content.includes("from ..") ||
      content.includes("import ..") ||
      content.includes("from tests.") ||
      content.includes("import tests.")
    ) {
      skipped.push(filename + " (relative import)");
      return;
    }

    fs.copyFileSync(src, dest);
    copied++;
  };

  if (!fs.existsSync(fullPath)) {
    return { tempDir, copied: 0, skipped: [] };
  }

  const stat = fs.statSync(fullPath);
  if (stat.isDirectory()) {
    // Find all .py files recursively
    const findPyFiles = (dir: string): string[] => {
      const files: string[] = [];
      for (const item of fs.readdirSync(dir)) {
        if (item === "conftest.py" || item === "__init__.py" || item.startsWith("_")) continue;
        const itemPath = path.join(dir, item);
        const itemStat = fs.statSync(itemPath);
        if (itemStat.isDirectory()) {
          files.push(...findPyFiles(itemPath));
        } else if (item.endsWith(".py")) {
          files.push(itemPath);
        }
      }
      return files;
    };

    const pyFiles = findPyFiles(fullPath);
    for (const file of pyFiles) {
      const destPath = path.join(tempDir, path.basename(file));
      copyFile(file, destPath);
    }
  } else if (fullPath.endsWith(".py")) {
    copyFile(fullPath, path.join(tempDir, path.basename(fullPath)));
  }

  return { tempDir, copied, skipped };
}

// Run tests
async function runTests(
  testPath: string,
  options: { skipPatterns?: string[]; quick?: boolean; timeout?: number } = {}
): Promise<RunOutcome> {
  const fullPath = path.join(process.cwd(), WPT_BIDI_TESTS, testPath);

  if (testPath && !fs.existsSync(fullPath)) {
    console.error(`Test path not found: ${fullPath}`);
    return { exitCode: 1, summary: { passed: 0, failed: 1, errors: 0, total: 1 } };
  }

  // Copy simple tests (without relative imports)
  const { tempDir, copied, skipped } = copySimpleTests(testPath, options);

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

  // Run pytest with our adapter
  const env = {
    ...process.env,
    CRATER_BIDI_URL,
    PYTHONPATH: path.join(process.cwd(), "scripts"),
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
        tempDir,
        "-v",
        `--timeout=${timeout}`,
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

// Run subset of known-passing tests
async function runSubset(): Promise<RunOutcome> {
  const config = loadSubsetConfig();
  if (!config) {
    console.error("Subset config not found: " + SUBSET_CONFIG);
    return { exitCode: 1, summary: { passed: 0, failed: 1, errors: 0, total: 1 } };
  }

  console.log("Running known-passing test subset...\n");

  let moduleFailures = 0;
  let totalSummary = emptySummary();

  for (const [modulePath, files] of Object.entries(config.tests)) {
    void files;
    console.log(`\n=== ${modulePath} ===`);
    const outcome = await runTests(modulePath, {
      skipPatterns: config.skip_patterns,
      quick: true,
      timeout: 10,
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
    console.log("  npx tsx scripts/wpt-webdriver-runner.ts --subset     # Known-passing tests only");
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
      outcome = await runSubset();
    } else if (args[0] === "--quick") {
      const testPath = args[1] || "";
      const config = loadSubsetConfig();
      outcome = await runTests(testPath, {
        skipPatterns: config?.skip_patterns,
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
