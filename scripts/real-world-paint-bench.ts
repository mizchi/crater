#!/usr/bin/env npx tsx

import fs from "node:fs/promises";
import net from "node:net";
import path from "node:path";
import { spawn, type ChildProcess } from "node:child_process";
import { chromium } from "playwright";
import WebSocket from "ws";
import {
  listRealWorldSnapshotNames,
  loadRealWorldSnapshot,
  type RealWorldSnapshot,
} from "./real-world-snapshot.ts";

const BIDI_HOST = "127.0.0.1";
const BIDI_PORT = 9222;
const BIDI_URL = `ws://${BIDI_HOST}:${BIDI_PORT}`;
const OUTPUT_DIR = path.join(process.cwd(), "output", "playwright", "real-world-paint");
const BLANK_HTML = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body></body></html>";

interface CliOptions {
  names: string[];
  iterations: number;
  warmup: number;
  saveImages: boolean;
  ensureServer: boolean;
}

interface BidiResponse {
  id: number;
  type: "success" | "error";
  result?: unknown;
  error?: string;
  message?: string;
}

interface BenchStats {
  avgMs: number;
  minMs: number;
  maxMs: number;
  iterations: number;
}

interface ScreenshotBenchStats extends BenchStats {
  bytes: number;
}

interface TargetBench {
  load: BenchStats;
  screenshot: ScreenshotBenchStats;
  loadAndScreenshot: ScreenshotBenchStats;
}

interface SnapshotBenchResult {
  name: string;
  title: string;
  viewport: { width: number; height: number };
  htmlBytes: number;
  chromium: TargetBench;
  crater: TargetBench;
}

interface SnapshotBenchTimeout {
  name: string;
  title: string;
  viewport: { width: number; height: number };
  htmlBytes: number;
  chromium: TargetBench;
  error: string;
}

function usage(): string {
  return [
    "Real-world paint benchmark",
    "",
    "Usage:",
    "  npx tsx scripts/real-world-paint-bench.ts [snapshot...] [--iterations 5] [--warmup 1] [--save-images] [--list]",
  ].join("\n");
}

function parseArgs(argv: string[]): CliOptions {
  const positional: string[] = [];
  const options: CliOptions = {
    names: [],
    iterations: 5,
    warmup: 1,
    saveImages: false,
    ensureServer: true,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--") {
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      console.log(usage());
      process.exit(0);
    }
    if (arg === "--list") {
      for (const name of listRealWorldSnapshotNames()) {
        console.log(name);
      }
      process.exit(0);
    }
    if (arg === "--iterations") {
      options.iterations = Number(argv[++i]);
      continue;
    }
    if (arg === "--warmup") {
      options.warmup = Number(argv[++i]);
      continue;
    }
    if (arg === "--save-images") {
      options.saveImages = true;
      continue;
    }
    if (arg === "--no-server") {
      options.ensureServer = false;
      continue;
    }
    if (arg.startsWith("--")) {
      throw new Error(`Unknown argument: ${arg}`);
    }
    positional.push(arg);
  }

  options.names = positional.length > 0 ? positional : listRealWorldSnapshotNames();
  return options;
}

function buildHtmlDataUrl(html: string): string {
  return `data:text/html;charset=utf-8;base64,${Buffer.from(html).toString("base64")}`;
}

function measureStats(times: number[]): BenchStats {
  const total = times.reduce((sum, value) => sum + value, 0);
  return {
    avgMs: total / times.length,
    minMs: Math.min(...times),
    maxMs: Math.max(...times),
    iterations: times.length,
  };
}

async function benchmark<T>(iterations: number, warmup: number, fn: () => Promise<T>): Promise<{ stats: BenchStats; lastValue: T }> {
  let lastValue!: T;
  for (let i = 0; i < warmup; i++) {
    lastValue = await fn();
  }
  const times: number[] = [];
  for (let i = 0; i < iterations; i++) {
    const start = performance.now();
    lastValue = await fn();
    times.push(performance.now() - start);
  }
  return { stats: measureStats(times), lastValue };
}

function portOpen(host: string, port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    socket.setTimeout(500);
    socket.once("connect", () => {
      socket.destroy();
      resolve(true);
    });
    socket.once("error", () => resolve(false));
    socket.once("timeout", () => {
      socket.destroy();
      resolve(false);
    });
    socket.connect(port, host);
  });
}

async function waitForPort(host: string, port: number, timeoutMs: number): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await portOpen(host, port)) return;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`Timed out waiting for ${host}:${port}`);
}

function runCommand(command: string, args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: process.cwd(),
      stdio: "inherit",
    });
    child.once("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${command} ${args.join(" ")} exited with ${code}`));
    });
    child.once("error", reject);
  });
}

async function ensureBidiServer(enabled: boolean): Promise<ChildProcess | null> {
  if (!enabled) return null;
  if (await portOpen(BIDI_HOST, BIDI_PORT)) return null;
  await runCommand("just", ["build-bidi"]);
  const child = spawn("just", ["start-bidi"], {
    cwd: process.cwd(),
    stdio: "ignore",
  });
  try {
    await waitForPort(BIDI_HOST, BIDI_PORT, 30000);
    return child;
  } catch (error) {
    child.kill("SIGTERM");
    throw error;
  }
}

class CraterPage {
  private ws: WebSocket | null = null;
  private commandId = 0;
  private contextId: string | null = null;
  private readonly pending = new Map<number, {
    resolve: (value: BidiResponse) => void;
    reject: (error: Error) => void;
  }>();

  async connect(): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      this.ws = new WebSocket(BIDI_URL);
      this.ws.once("open", () => resolve());
      this.ws.once("error", reject);
      this.ws.on("message", (data) => this.handleMessage(data.toString()));
    });
    const response = await this.send("browsingContext.create", { type: "tab" });
    this.contextId = (response.result as { context: string }).context;
    await this.send("browsingContext.navigate", {
      context: this.contextId,
      url: buildHtmlDataUrl(BLANK_HTML),
      wait: "complete",
    });
  }

  private handleMessage(data: string): void {
    const message = JSON.parse(data) as BidiResponse & { type: string };
    if (message.type === "event") return;
    const pending = this.pending.get(message.id);
    if (!pending) return;
    this.pending.delete(message.id);
    pending.resolve(message);
  }

  private async send(method: string, params: unknown = {}): Promise<BidiResponse> {
    if (!this.ws) throw new Error("Not connected");
    const id = ++this.commandId;
    const payload = JSON.stringify({ id, method, params });
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws!.send(payload);
      setTimeout(() => {
        if (!this.pending.has(id)) return;
        this.pending.delete(id);
        reject(new Error(`Timeout waiting for ${method}`));
      }, 60000);
    });
  }

  async setViewport(width: number, height: number): Promise<void> {
    await this.send("browsingContext.setViewport", {
      context: this.contextId,
      viewport: { width, height },
    });
  }

  async setContent(html: string): Promise<void> {
    await this.send("script.evaluate", {
      expression: `__loadHTML(${JSON.stringify(html)})`,
      target: { context: this.contextId },
      awaitPromise: false,
    });
  }

  async captureScreenshot(): Promise<Buffer> {
    const response = await this.send("browsingContext.captureScreenshotData", {
      context: this.contextId,
      origin: "viewport",
    });
    if (response.type === "error") {
      throw new Error(response.message || response.error || "captureScreenshotData failed");
    }
    return Buffer.from(String(response.result || ""), "base64");
  }

  async close(): Promise<void> {
    try {
      if (this.contextId) {
        await this.send("browsingContext.close", { context: this.contextId });
      }
    } catch {
      // Ignore cleanup errors.
    }
    this.ws?.close();
    this.ws = null;
    this.contextId = null;
  }
}

async function measureChromium(
  snapshot: RealWorldSnapshot,
  iterations: number,
  warmup: number,
): Promise<TargetBench & { firstShot: Buffer }> {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: snapshot.viewport, deviceScaleFactor: 1 });
    const load = await benchmark(iterations, warmup, async () => {
      await page.setContent(snapshot.html, { waitUntil: "load" });
      return 0;
    });
    await page.setContent(snapshot.html, { waitUntil: "load" });
    const screenshot = await benchmark(iterations, warmup, async () => page.screenshot({ type: "png" }));
    const loadAndScreenshot = await benchmark(iterations, warmup, async () => {
      await page.setContent(snapshot.html, { waitUntil: "load" });
      return page.screenshot({ type: "png" });
    });
    return {
      load: load.stats,
      screenshot: { ...screenshot.stats, bytes: screenshot.lastValue.byteLength },
      loadAndScreenshot: { ...loadAndScreenshot.stats, bytes: loadAndScreenshot.lastValue.byteLength },
      firstShot: screenshot.lastValue,
    };
  } finally {
    await browser.close();
  }
}

async function measureCrater(
  snapshot: RealWorldSnapshot,
  iterations: number,
  warmup: number,
): Promise<TargetBench & { firstShot: Buffer }> {
  const page = new CraterPage();
  await page.connect();
  try {
    await page.setViewport(snapshot.viewport.width, snapshot.viewport.height);
    const load = await benchmark(iterations, warmup, async () => {
      await page.setContent(snapshot.html);
      return 0;
    });
    await page.setContent(snapshot.html);
    const screenshot = await benchmark(iterations, warmup, async () => page.captureScreenshot());
    const loadAndScreenshot = await benchmark(iterations, warmup, async () => {
      await page.setContent(snapshot.html);
      return page.captureScreenshot();
    });
    return {
      load: load.stats,
      screenshot: { ...screenshot.stats, bytes: screenshot.lastValue.byteLength },
      loadAndScreenshot: { ...loadAndScreenshot.stats, bytes: loadAndScreenshot.lastValue.byteLength },
      firstShot: screenshot.lastValue,
    };
  } finally {
    await page.close();
  }
}

async function saveImages(
  name: string,
  chromiumPng: Buffer,
  craterPng?: Buffer,
): Promise<void> {
  const dir = path.join(OUTPUT_DIR, name);
  await fs.mkdir(dir, { recursive: true });
  let jobs = [fs.writeFile(path.join(dir, "chromium.png"), chromiumPng)];
  if (craterPng) {
    jobs.push(fs.writeFile(path.join(dir, "crater.png"), craterPng));
  }
  await Promise.all(jobs);
}

function formatMs(ms: number): string {
  return `${ms.toFixed(2)}ms`;
}

function formatKb(bytes: number): string {
  return `${(bytes / 1024).toFixed(1)}KB`;
}

function printResult(result: SnapshotBenchResult): void {
  console.log(`\n# ${result.name} (${result.viewport.width}x${result.viewport.height}, html ${(result.htmlBytes / 1024).toFixed(1)}KB)`);
  console.log(`title: ${result.title}`);
  console.log("target      load        shot        load+shot   png");
  console.log(
    `chromium   ${formatMs(result.chromium.load.avgMs).padEnd(10)} ${formatMs(result.chromium.screenshot.avgMs).padEnd(10)} ${formatMs(result.chromium.loadAndScreenshot.avgMs).padEnd(10)} ${formatKb(result.chromium.screenshot.bytes)}`,
  );
  console.log(
    `crater     ${formatMs(result.crater.load.avgMs).padEnd(10)} ${formatMs(result.crater.screenshot.avgMs).padEnd(10)} ${formatMs(result.crater.loadAndScreenshot.avgMs).padEnd(10)} ${formatKb(result.crater.screenshot.bytes)}`,
  );
  console.log(
    `ratio      ${(result.crater.load.avgMs / Math.max(result.chromium.load.avgMs, 0.01)).toFixed(2)}x       ${(result.crater.screenshot.avgMs / Math.max(result.chromium.screenshot.avgMs, 0.01)).toFixed(2)}x       ${(result.crater.loadAndScreenshot.avgMs / Math.max(result.chromium.loadAndScreenshot.avgMs, 0.01)).toFixed(2)}x`,
  );
}

function printTimeoutResult(result: SnapshotBenchTimeout): void {
  console.log(`\n# ${result.name} (${result.viewport.width}x${result.viewport.height}, html ${(result.htmlBytes / 1024).toFixed(1)}KB)`);
  console.log(`title: ${result.title}`);
  console.log("target      load        shot        load+shot   png");
  console.log(
    `chromium   ${formatMs(result.chromium.load.avgMs).padEnd(10)} ${formatMs(result.chromium.screenshot.avgMs).padEnd(10)} ${formatMs(result.chromium.loadAndScreenshot.avgMs).padEnd(10)} ${formatKb(result.chromium.screenshot.bytes)}`,
  );
  console.log("crater     n/a        timeout>60s timeout>60s -");
  console.log(`note       ${result.error}`);
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const spawnedServer = await ensureBidiServer(options.ensureServer);

  try {
    console.log(
      "note: Crater の browsingContext.captureScreenshotData は現状 synthetic screenshot で、actual paint benchmark ではありません.",
    );
    const results: SnapshotBenchResult[] = [];
    const timeouts: SnapshotBenchTimeout[] = [];
    for (const name of options.names) {
      const snapshot = loadRealWorldSnapshot(name);
      const chromium = await measureChromium(snapshot, options.iterations, options.warmup);
      try {
        const crater = await measureCrater(snapshot, options.iterations, options.warmup);
        if (options.saveImages) {
          await saveImages(name, chromium.firstShot, crater.firstShot);
        }
        const result: SnapshotBenchResult = {
          name: snapshot.name,
          title: snapshot.title,
          viewport: snapshot.viewport,
          htmlBytes: Buffer.byteLength(snapshot.html),
          chromium,
          crater,
        };
        results.push(result);
        printResult(result);
      } catch (error) {
        if (options.saveImages) {
          await saveImages(name, chromium.firstShot);
        }
        const timeoutResult: SnapshotBenchTimeout = {
          name: snapshot.name,
          title: snapshot.title,
          viewport: snapshot.viewport,
          htmlBytes: Buffer.byteLength(snapshot.html),
          chromium,
          error: error instanceof Error ? error.message : String(error),
        };
        timeouts.push(timeoutResult);
        printTimeoutResult(timeoutResult);
      }
    }

    console.log("\n## Paint-layer opportunities");
    for (const result of results) {
      const shotRatio = result.crater.screenshot.avgMs / Math.max(result.chromium.screenshot.avgMs, 0.01);
      const loadRatio = result.crater.load.avgMs / Math.max(result.chromium.load.avgMs, 0.01);
      if (shotRatio > loadRatio * 1.2) {
        console.log(`- ${result.name}: screenshot 側が支配的。paint tree 構築、stacking sort、viewport culling、PNG encode を優先。`);
        continue;
      }
      console.log(`- ${result.name}: load 側も重い。renderer/node build と paint を分けて追うべき。`);
    }
    for (const result of timeouts) {
      console.log(`- ${result.name}: Crater screenshot が 60 秒超で timeout。最優先は captureScreenshotData の paint/PNG encode path。`);
    }
  } finally {
    spawnedServer?.kill("SIGTERM");
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack || error.message : error);
  process.exit(1);
});
