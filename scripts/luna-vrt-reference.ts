#!/usr/bin/env node

import { execFile as nodeExecFile } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

export type LunaReferenceVrtViewport = {
  width: number;
  height: number;
};

export type LunaReferenceVrtScenario = {
  html?: string;
  htmlFile?: string;
  id: string;
  outputPath?: string;
  targetId?: string;
  targetSelector?: string;
  viewport?: LunaReferenceVrtViewport;
};

export type LunaReferenceVrtSuite = {
  outputDir?: string;
  scenarios: LunaReferenceVrtScenario[];
  targetId?: string;
  targetSelector?: string;
  viewport?: LunaReferenceVrtViewport;
};

export type LunaReferenceVrtCliInvocation = {
  args: string[];
  command: string;
};

export type LunaReferenceVrtExecFileOptions = {
  cwd?: string;
  maxBuffer?: number;
  timeout?: number;
};

export type LunaReferenceVrtExecFile = (
  command: string,
  args: string[],
  options?: LunaReferenceVrtExecFileOptions,
) => Promise<{ stderr: string; stdout: string }>;

export type LunaReferenceVrtRunnerOptions = {
  craterBin?: string;
  cwd?: string;
  execFile?: LunaReferenceVrtExecFile;
  fixtureCacheDir?: string;
  maxBuffer?: number;
  nodeBin?: string;
  outputDir?: string;
  timeoutMs?: number;
};

export type LunaReferenceVrtCapture = {
  bytes: number;
  fixturePath: string;
  height: number;
  id: string;
  outputPath: string;
  targetId?: string;
  targetSelector?: string;
  viewport: LunaReferenceVrtViewport;
  width: number;
};

export type LunaReferenceVrtResult = {
  captures: LunaReferenceVrtCapture[];
  fixtureCacheDir: string;
  outputDir: string;
};

export type LunaReferenceVrtCliArgs = {
  craterBin: string;
  fixture?: string;
  fixturesDir: string;
  json: boolean;
  outputDir: string;
  targetId?: string;
  targetSelector?: string;
  timeoutMs: number;
  viewport: LunaReferenceVrtViewport;
};

type CraterImageArtifact = {
  artifact: "image";
  data: string;
  encoding: "png-base64";
  height: number;
  targetId?: string;
  viewport?: LunaReferenceVrtViewport;
  width: number;
};

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DEFAULT_FIXTURES_DIR = "browser/tests/luna-vrt/fixtures";
const DEFAULT_OUTPUT_DIR = "browser/tests/luna-vrt/output";
const DEFAULT_FIXTURE_CACHE_DIR = ".fixture-cache";
const DEFAULT_CRATER_BIN = "browser/dist/crater.js";
const DEFAULT_TARGET_ID = "target";
const DEFAULT_VIEWPORT: LunaReferenceVrtViewport = {
  height: 720,
  width: 432,
};

export async function discoverLunaReferenceFixtures(
  fixturesDir: string,
  options: { fixture?: string } = {},
): Promise<LunaReferenceVrtScenario[]> {
  const entries = await readdir(fixturesDir, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".html"))
    .map((entry) => ({
      htmlFile: path.join(fixturesDir, entry.name),
      id: path.basename(entry.name, ".html"),
    }))
    .filter((scenario) => !options.fixture || scenario.id === options.fixture)
    .sort((a, b) => a.id.localeCompare(b.id));
}

export function buildLunaReferenceCraterInvocation(args: {
  craterBin: string;
  fixturePath: string;
  nodeBin?: string;
  scenario: LunaReferenceVrtScenario;
  suite?: Pick<LunaReferenceVrtSuite, "targetId" | "targetSelector" | "viewport">;
}): LunaReferenceVrtCliInvocation {
  const viewport = resolveViewport(args.scenario, args.suite);
  const target = resolveTarget(args.scenario, args.suite);
  const craterArgs = [
    "--artifact",
    "image",
    target.flag,
    target.value,
    "--html-file",
    args.fixturePath,
    "--viewport-width",
    String(viewport.width),
    "--viewport-height",
    String(viewport.height),
  ];
  if (isJavaScriptEntrypoint(args.craterBin)) {
    return {
      args: [args.craterBin, ...craterArgs],
      command: args.nodeBin ?? process.execPath,
    };
  }
  return {
    args: craterArgs,
    command: args.craterBin,
  };
}

export async function runLunaReferenceVrtScenario(
  scenario: LunaReferenceVrtScenario,
  suite: Pick<LunaReferenceVrtSuite, "outputDir" | "targetId" | "targetSelector" | "viewport">,
  options: LunaReferenceVrtRunnerOptions = {},
): Promise<LunaReferenceVrtCapture> {
  validateScenario(scenario);
  const outputDir = path.resolve(options.cwd ?? REPO_ROOT, options.outputDir ?? suite.outputDir ?? DEFAULT_OUTPUT_DIR);
  const fixtureCacheDir = path.resolve(outputDir, options.fixtureCacheDir ?? DEFAULT_FIXTURE_CACHE_DIR);
  await mkdir(outputDir, { recursive: true });
  await mkdir(fixtureCacheDir, { recursive: true });

  const fixturePath = await resolveFixturePath(scenario, fixtureCacheDir);
  const craterBin = path.resolve(options.cwd ?? REPO_ROOT, options.craterBin ?? DEFAULT_CRATER_BIN);
  const invocation = buildLunaReferenceCraterInvocation({
    craterBin,
    fixturePath,
    nodeBin: options.nodeBin,
    scenario,
    suite,
  });
  const execFile = options.execFile ?? defaultExecFile;
  const { stdout } = await execFile(invocation.command, invocation.args, {
    cwd: options.cwd ?? REPO_ROOT,
    maxBuffer: options.maxBuffer,
    timeout: options.timeoutMs,
  });
  const artifact = parseCraterImageArtifact(stdout);
  const png = Buffer.from(artifact.data, "base64");
  const outputPath = path.resolve(outputDir, scenario.outputPath ?? `${safeFileName(scenario.id)}.png`);
  await writeFile(outputPath, png);
  const target = resolveTarget(scenario, suite);
  return {
    bytes: png.byteLength,
    fixturePath,
    height: artifact.height,
    id: scenario.id,
    outputPath,
    ...(target.flag === "--target-id" ? { targetId: target.value } : { targetSelector: target.value }),
    viewport: resolveViewport(scenario, suite),
    width: artifact.width,
  };
}

export async function runLunaReferenceVrtSuite(
  suite: LunaReferenceVrtSuite,
  options: LunaReferenceVrtRunnerOptions = {},
): Promise<LunaReferenceVrtResult> {
  if (!Array.isArray(suite.scenarios) || suite.scenarios.length === 0) {
    throw new Error("suite.scenarios must contain at least one scenario");
  }
  const outputDir = path.resolve(options.cwd ?? REPO_ROOT, options.outputDir ?? suite.outputDir ?? DEFAULT_OUTPUT_DIR);
  const fixtureCacheDir = path.resolve(outputDir, options.fixtureCacheDir ?? DEFAULT_FIXTURE_CACHE_DIR);
  const captures: LunaReferenceVrtCapture[] = [];
  for (const scenario of suite.scenarios) {
    captures.push(await runLunaReferenceVrtScenario(scenario, suite, {
      ...options,
      outputDir,
    }));
  }
  return {
    captures,
    fixtureCacheDir,
    outputDir,
  };
}

export function parseLunaReferenceVrtArgs(args: string[]): LunaReferenceVrtCliArgs {
  const parsed: LunaReferenceVrtCliArgs = {
    craterBin: DEFAULT_CRATER_BIN,
    fixturesDir: DEFAULT_FIXTURES_DIR,
    json: false,
    outputDir: DEFAULT_OUTPUT_DIR,
    timeoutMs: 30_000,
    viewport: { ...DEFAULT_VIEWPORT },
  };
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    switch (arg) {
      case "--":
        break;
      case "--crater-bin":
        parsed.craterBin = readFlag(args, index, arg);
        index += 1;
        break;
      case "--fixture":
        parsed.fixture = readFlag(args, index, arg);
        index += 1;
        break;
      case "--fixtures":
      case "--fixtures-dir":
        parsed.fixturesDir = readFlag(args, index, arg);
        index += 1;
        break;
      case "--json":
        parsed.json = true;
        break;
      case "--output-dir":
        parsed.outputDir = readFlag(args, index, arg);
        index += 1;
        break;
      case "--target-id":
        parsed.targetId = readFlag(args, index, arg);
        index += 1;
        break;
      case "--target-selector":
        parsed.targetSelector = readFlag(args, index, arg);
        index += 1;
        break;
      case "--timeout-ms":
        parsed.timeoutMs = readPositiveInt(readFlag(args, index, arg), arg);
        index += 1;
        break;
      case "--viewport-width":
        parsed.viewport.width = readPositiveInt(readFlag(args, index, arg), arg);
        index += 1;
        break;
      case "--viewport-height":
        parsed.viewport.height = readPositiveInt(readFlag(args, index, arg), arg);
        index += 1;
        break;
      case "--help":
      case "-h":
        printUsage();
        process.exit(0);
      default:
        if (!arg.startsWith("--") && !parsed.fixture) {
          parsed.fixture = arg;
          break;
        }
        throw new Error(`Unknown argument: ${arg}`);
    }
  }
  if (parsed.targetId && parsed.targetSelector) {
    throw new Error("Specify either --target-id or --target-selector, not both");
  }
  return parsed;
}

export async function runLunaReferenceVrtCli(
  args: string[],
  options: LunaReferenceVrtRunnerOptions = {},
): Promise<LunaReferenceVrtResult> {
  const cli = parseLunaReferenceVrtArgs(args);
  const fixturesDir = path.resolve(REPO_ROOT, cli.fixturesDir);
  const scenarios = await discoverLunaReferenceFixtures(fixturesDir, {
    fixture: cli.fixture,
  });
  if (scenarios.length === 0) {
    throw new Error(cli.fixture ? `No Luna fixture found: ${cli.fixture}` : `No Luna fixtures found in ${fixturesDir}`);
  }
  const result = await runLunaReferenceVrtSuite({
    outputDir: cli.outputDir,
    scenarios,
    targetId: cli.targetSelector ? undefined : cli.targetId ?? DEFAULT_TARGET_ID,
    targetSelector: cli.targetSelector,
    viewport: cli.viewport,
  }, {
    ...options,
    craterBin: cli.craterBin,
    timeoutMs: cli.timeoutMs,
  });
  if (cli.json) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    printSummary(result);
  }
  return result;
}

function resolveViewport(
  scenario: Pick<LunaReferenceVrtScenario, "viewport">,
  suite?: Pick<LunaReferenceVrtSuite, "viewport">,
): LunaReferenceVrtViewport {
  return scenario.viewport ?? suite?.viewport ?? DEFAULT_VIEWPORT;
}

function resolveTarget(
  scenario: Pick<LunaReferenceVrtScenario, "targetId" | "targetSelector">,
  suite?: Pick<LunaReferenceVrtSuite, "targetId" | "targetSelector">,
): { flag: "--target-id" | "--target-selector"; value: string } {
  const targetId = scenario.targetId ?? suite?.targetId;
  const targetSelector = scenario.targetSelector ?? suite?.targetSelector;
  if (targetId && targetSelector) {
    throw new Error("Specify either targetId or targetSelector, not both");
  }
  if (targetSelector) {
    return { flag: "--target-selector", value: targetSelector };
  }
  return { flag: "--target-id", value: targetId ?? DEFAULT_TARGET_ID };
}

async function resolveFixturePath(
  scenario: LunaReferenceVrtScenario,
  fixtureCacheDir: string,
): Promise<string> {
  if (scenario.htmlFile) {
    return path.resolve(scenario.htmlFile);
  }
  const html = scenario.html;
  if (html === undefined) {
    throw new Error(`scenario.html or scenario.htmlFile is required: ${scenario.id}`);
  }
  const fixturePath = path.join(fixtureCacheDir, `${safeFileName(scenario.id)}-${hashContent(html)}.html`);
  await writeFile(fixturePath, html);
  return fixturePath;
}

function validateScenario(scenario: LunaReferenceVrtScenario): void {
  if (!scenario.id) {
    throw new Error("scenario.id is required");
  }
  if (scenario.html !== undefined && scenario.htmlFile !== undefined) {
    throw new Error(`scenario.html and scenario.htmlFile are mutually exclusive: ${scenario.id}`);
  }
  if (scenario.html === undefined && scenario.htmlFile === undefined) {
    throw new Error(`scenario.html or scenario.htmlFile is required: ${scenario.id}`);
  }
  resolveTarget(scenario);
}

function parseCraterImageArtifact(stdout: string): CraterImageArtifact {
  const raw = stdout.trim();
  const jsonStart = raw.indexOf("{");
  const jsonEnd = raw.lastIndexOf("}");
  if (jsonStart < 0 || jsonEnd < jsonStart) {
    throw new Error("Crater CLI did not return JSON");
  }
  const parsed = JSON.parse(raw.slice(jsonStart, jsonEnd + 1)) as Partial<CraterImageArtifact>;
  if (parsed.artifact !== "image") {
    throw new Error(`Expected image artifact, got ${String(parsed.artifact)}`);
  }
  if (parsed.encoding !== "png-base64") {
    throw new Error(`Unsupported image encoding: ${String(parsed.encoding)}`);
  }
  if (typeof parsed.data !== "string" || parsed.data.length === 0) {
    throw new Error("Image artifact is missing data");
  }
  if (!Number.isFinite(parsed.width) || !Number.isFinite(parsed.height)) {
    throw new Error("Image artifact is missing dimensions");
  }
  return parsed as CraterImageArtifact;
}

function defaultExecFile(
  command: string,
  args: string[],
  options: LunaReferenceVrtExecFileOptions = {},
): Promise<{ stderr: string; stdout: string }> {
  return new Promise((resolve, reject) => {
    nodeExecFile(command, args, {
      cwd: options.cwd,
      encoding: "utf8",
      maxBuffer: options.maxBuffer ?? 20 * 1024 * 1024,
      timeout: options.timeout,
    }, (error, stdout, stderr) => {
      if (error) {
        const enriched = error as Error & { stderr?: string; stdout?: string };
        enriched.stderr = String(stderr ?? "");
        enriched.stdout = String(stdout ?? "");
        reject(enriched);
        return;
      }
      resolve({
        stderr: String(stderr ?? ""),
        stdout: String(stdout ?? ""),
      });
    });
  });
}

function isJavaScriptEntrypoint(file: string): boolean {
  const ext = path.extname(file).toLowerCase();
  return ext === ".js" || ext === ".mjs" || ext === ".cjs";
}

function hashContent(content: string): string {
  return createHash("sha256").update(content).digest("hex").slice(0, 16);
}

function safeFileName(value: string): string {
  const safe = value.trim().replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
  return safe || "fixture";
}

function readFlag(args: string[], index: number, flag: string): string {
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`Missing value for ${flag}`);
  }
  return value;
}

function readPositiveInt(value: string, flag: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${flag} must be a positive integer`);
  }
  return parsed;
}

function printSummary(result: LunaReferenceVrtResult): void {
  console.log(`Luna reference VRT: ${result.captures.length} capture(s)`);
  for (const capture of result.captures) {
    console.log(
      `- ${capture.id}: ${capture.width}x${capture.height}, ${capture.bytes} bytes -> ${capture.outputPath}`,
    );
  }
}

function printUsage(): void {
  console.log(`Usage: pnpm vrt:luna-reference -- [fixture] [options]

Options:
  --fixture <name>            Run one fixture by filename stem.
  --fixtures-dir <dir>        Fixture directory. Default: ${DEFAULT_FIXTURES_DIR}
  --output-dir <dir>          Output directory. Default: ${DEFAULT_OUTPUT_DIR}
  --crater-bin <path>         Crater CLI JS/binary. Default: ${DEFAULT_CRATER_BIN}
  --target-id <id>            Target element id. Default: ${DEFAULT_TARGET_ID}
  --target-selector <selector> Target selector instead of id.
  --viewport-width <px>       Viewport width. Default: ${DEFAULT_VIEWPORT.width}
  --viewport-height <px>      Viewport height. Default: ${DEFAULT_VIEWPORT.height}
  --timeout-ms <ms>           Crater CLI timeout. Default: 30000
  --json                      Print JSON result.
`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  runLunaReferenceVrtCli(process.argv.slice(2)).catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  });
}
