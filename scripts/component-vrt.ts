#!/usr/bin/env npx tsx

import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { deflateSync, inflateSync } from "node:zlib";

export type ComponentVrtBackend = "crater" | "chromium";

export interface ComponentVrtArgs {
  assetCacheDir?: string;
  backend: ComponentVrtBackend;
  backendOverride?: ComponentVrtBackend;
  config?: string;
  outputDir?: string;
  serverTimeoutMs: number;
  timeoutMs: number;
}

export interface ComponentVrtViewport {
  width: number;
  height: number;
}

export interface ComponentVrtClip {
  x: number;
  y: number;
  width: number;
  height: number;
}

type ComponentVrtResolvedClip = ComponentVrtClip & {
  viewport?: ComponentVrtViewport;
};

export interface ComponentVrtRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface ComponentVrtScenario {
  id: string;
  selector: string;
  url?: string;
  html?: string;
  viewport?: ComponentVrtViewport;
  waitForSelector?: string;
  waitUntil?: "commit" | "domcontentloaded" | "load" | "networkidle";
  settleMs?: number;
  padding?: number;
  outputPath?: string;
  timeoutMs?: number;
  type?: "png" | "jpeg";
  quality?: number;
}

export interface ComponentVrtConfig {
  schemaVersion?: 1;
  backend?: ComponentVrtBackend;
  outputDir?: string;
  timeoutMs?: number;
  serverTimeoutMs?: number;
  assets?: {
    cacheDir?: string;
    preload?: string[];
    revalidate?: boolean;
    ttlMs?: number;
    maxBodyBytes?: number;
    includeContentTypes?: string[];
  };
  scenarios: ComponentVrtScenario[];
}

export interface ComponentVrtCaptureResult {
  id: string;
  bytes: number;
  clip: ComponentVrtClip;
  durationMs: number;
  outputPath?: string;
}

export interface ComponentVrtSuiteResult {
  backend: ComponentVrtBackend;
  generatedAt: string;
  assetCache: ComponentVrtAssetCacheStats & {
    persist?: ComponentVrtPersistResult;
    prefetch?: ComponentVrtPrefetchResult;
    restore?: ComponentVrtRestoreResult;
    size: number;
  };
  captures: ComponentVrtCaptureResult[];
}

export interface ComponentVrtCacheEntry {
  body: string;
  headers: Record<string, string>;
  status: number;
  contentType?: string;
  storedAt: number;
}

export interface ComponentVrtPrefetchResult {
  cached: number;
  failed: number;
  skipped: number;
  total: number;
}

export interface ComponentVrtRestoreResult {
  failed: number;
  loaded: number;
  skipped: number;
  total: number;
}

export interface ComponentVrtPersistResult {
  failed: number;
  skipped: number;
  total: number;
  written: number;
}

export interface ComponentVrtAssetCacheStats {
  bypassed: number;
  hits: number;
  misses: number;
}

export interface ComponentVrtInstalledAssetCache {
  stats: ComponentVrtAssetCacheStats;
  uninstall: () => Promise<void>;
}

export interface ComponentVrtRequestLike {
  method(): string;
  url(): string;
}

export interface ComponentVrtRouteLike {
  continue(): Promise<void>;
  fulfill(options: {
    body: string;
    headers?: Record<string, string>;
    status?: number;
  }): Promise<void>;
  request(): ComponentVrtRequestLike;
}

export interface ComponentVrtLocatorLike {
  scrollIntoViewIfNeeded?: (options?: { timeout?: number }) => Promise<void>;
  waitFor?: (options?: { state?: "attached" | "visible"; timeout?: number }) => Promise<void>;
}

export interface ComponentVrtPageLike {
  evaluate<T, Arg = unknown>(
    expression: string | ((arg: Arg) => T | Promise<T>),
    arg?: Arg,
    options?: { awaitPromise?: boolean },
  ): Promise<T>;
  goto?: (
    url: string,
    options?: { timeout?: number; waitUntil?: ComponentVrtScenario["waitUntil"] },
  ) => Promise<unknown>;
  getComputedStylesForElement?: (
    selector: string,
    properties: string[],
  ) => Promise<Record<string, string>>;
  locator?: (selector: string) => ComponentVrtLocatorLike;
  route?: (
    matcher: RegExp,
    handler: (route: ComponentVrtRouteLike) => Promise<void> | void,
  ) => Promise<void>;
  screenshot(options: {
    clip?: ComponentVrtClip;
    path?: string;
    quality?: number;
    timeout?: number;
    type?: "png" | "jpeg";
  }): Promise<Buffer>;
  setContent?: (html: string) => Promise<void>;
  setContentWithScripts?: (html: string) => Promise<void>;
  setViewport?: (width: number, height: number) => Promise<void>;
  setViewportSize?: (viewport: ComponentVrtViewport) => Promise<void>;
  unroute?: (
    matcher: RegExp,
    handler?: (route: ComponentVrtRouteLike) => Promise<void> | void,
  ) => Promise<void>;
  waitForSelector?: (
    selector: string,
    options?: { state?: "attached" | "visible"; timeout?: number },
  ) => Promise<unknown>;
  waitForTimeout?: (timeout: number) => Promise<void>;
}

const DEFAULT_ARGS: ComponentVrtArgs = {
  assetCacheDir: undefined,
  backend: "crater",
  config: undefined,
  outputDir: undefined,
  serverTimeoutMs: 20_000,
  timeoutMs: 5_000,
};
const DEFAULT_OUTPUT_DIR = "component-vrt-output";

const DEFAULT_TEXT_CONTENT_TYPES = [
  "application/javascript",
  "application/json",
  "application/x-javascript",
  "image/svg+xml",
  "text/css",
  "text/html",
  "text/javascript",
  "text/plain",
  "text/xml",
];

const DEFAULT_TEXT_EXTENSIONS = [
  ".css",
  ".htm",
  ".html",
  ".js",
  ".json",
  ".mjs",
  ".svg",
  ".txt",
  ".xml",
];

const DEFAULT_MAX_BODY_BYTES = 5 * 1024 * 1024;
const DISK_CACHE_SCHEMA_VERSION = 1 as const;

interface ComponentVrtDiskCacheRecord {
  schemaVersion: typeof DISK_CACHE_SCHEMA_VERSION;
  entry: ComponentVrtCacheEntry;
  url: string;
}

export class ComponentVrtAssetCache {
  private readonly entries = new Map<string, ComponentVrtCacheEntry>();

  get size(): number {
    return this.entries.size;
  }

  clear(): void {
    this.entries.clear();
  }

  get(url: string): ComponentVrtCacheEntry | undefined {
    return this.entries.get(normalizeAssetCacheKey(url));
  }

  has(url: string): boolean {
    return this.entries.has(normalizeAssetCacheKey(url));
  }

  put(url: string, entry: {
    body: string;
    contentType?: string;
    headers?: Record<string, string>;
    status?: number;
    storedAt?: number;
  }): void {
    const headers = normalizeHeaders(entry.headers ?? {});
    const contentType = entry.contentType ?? headers["content-type"];
    if (contentType && !headers["content-type"]) {
      headers["content-type"] = contentType;
    }
    this.entries.set(normalizeAssetCacheKey(url), {
      body: entry.body,
      ...(contentType ? { contentType } : {}),
      headers,
      status: entry.status ?? 200,
      storedAt: entry.storedAt ?? Date.now(),
    });
  }

  async prefetch(urls: string[], options: {
    fetch?: typeof fetch;
    includeContentTypes?: string[];
    maxBodyBytes?: number;
    skipExisting?: boolean;
  } = {}): Promise<ComponentVrtPrefetchResult> {
    const fetchImpl = options.fetch ?? globalThis.fetch;
    if (typeof fetchImpl !== "function") {
      throw new Error("fetch is not available for ComponentVrtAssetCache.prefetch");
    }
    const includeContentTypes = options.includeContentTypes ?? DEFAULT_TEXT_CONTENT_TYPES;
    const maxBodyBytes = options.maxBodyBytes ?? DEFAULT_MAX_BODY_BYTES;
    const result: ComponentVrtPrefetchResult = {
      cached: 0,
      failed: 0,
      skipped: 0,
      total: urls.length,
    };

    for (const url of urls) {
      try {
        if (options.skipExisting && this.has(url)) {
          result.skipped += 1;
          continue;
        }
        const response = await fetchImpl(url);
        const headers = normalizeHeaders(response.headers);
        const contentType = headers["content-type"] ?? "";
        if (
          !isCacheableStatus(response.status) ||
          isNoStore(headers["cache-control"]) ||
          !isTextAsset(url, contentType, includeContentTypes)
        ) {
          result.skipped += 1;
          continue;
        }
        const body = await response.text();
        if (Buffer.byteLength(body) > maxBodyBytes) {
          result.skipped += 1;
          continue;
        }
        this.put(url, {
          body,
          contentType,
          headers,
          status: response.status,
        });
        result.cached += 1;
      } catch {
        result.failed += 1;
      }
    }
    return result;
  }

  async restoreFromDisk(urls: string[], options: {
    cacheDir: string;
    now?: number;
    ttlMs?: number;
  }): Promise<ComponentVrtRestoreResult> {
    const result: ComponentVrtRestoreResult = {
      failed: 0,
      loaded: 0,
      skipped: 0,
      total: urls.length,
    };
    const now = options.now ?? Date.now();
    for (const url of urls) {
      try {
        const record = await readDiskCacheRecord(options.cacheDir, url);
        if (!record || !isUsableDiskCacheRecord(record, url, now, options.ttlMs)) {
          result.skipped += 1;
          continue;
        }
        this.put(record.url, record.entry);
        result.loaded += 1;
      } catch {
        result.failed += 1;
      }
    }
    return result;
  }

  async persistToDisk(urls: string[], options: {
    cacheDir: string;
  }): Promise<ComponentVrtPersistResult> {
    await mkdir(options.cacheDir, { recursive: true });
    const result: ComponentVrtPersistResult = {
      failed: 0,
      skipped: 0,
      total: urls.length,
      written: 0,
    };
    for (const url of urls) {
      const entry = this.get(url);
      if (!entry) {
        result.skipped += 1;
        continue;
      }
      try {
        const record: ComponentVrtDiskCacheRecord = {
          entry,
          schemaVersion: DISK_CACHE_SCHEMA_VERSION,
          url: normalizeAssetCacheKey(url),
        };
        await writeFile(
          diskCacheRecordPath(options.cacheDir, url),
          JSON.stringify(record, null, 2),
        );
        result.written += 1;
      } catch {
        result.failed += 1;
      }
    }
    return result;
  }
}

export async function installComponentVrtAssetCache(
  page: Pick<ComponentVrtPageLike, "route" | "unroute">,
  cache: ComponentVrtAssetCache,
): Promise<ComponentVrtInstalledAssetCache> {
  if (!page.route) {
    return {
      stats: {
        bypassed: 0,
        hits: 0,
        misses: 0,
      },
      uninstall: async () => {},
    };
  }

  const matcher = /.*/;
  const stats: ComponentVrtAssetCacheStats = {
    bypassed: 0,
    hits: 0,
    misses: 0,
  };
  const handler = async (route: ComponentVrtRouteLike): Promise<void> => {
    const request = route.request();
    if (request.method().toUpperCase() !== "GET") {
      stats.bypassed += 1;
      await route.continue();
      return;
    }
    const cached = cache.get(request.url());
    if (!cached) {
      stats.misses += 1;
      await route.continue();
      return;
    }
    stats.hits += 1;
    const headers: Record<string, string> = {
      ...cached.headers,
      "x-crater-vrt-cache": "hit",
    };
    if (cached.contentType && !headers["content-type"]) {
      headers["content-type"] = cached.contentType;
    }
    await route.fulfill({
      body: cached.body,
      headers,
      status: cached.status,
    });
  };

  await page.route(matcher, handler);
  return {
    stats,
    uninstall: async () => {
      await page.unroute?.(matcher, handler);
    },
  };
}

export function normalizeComponentClip(
  rect: ComponentVrtRect,
  viewport?: ComponentVrtViewport,
  padding = 0,
): ComponentVrtClip {
  const safePadding = Math.max(0, Math.floor(padding));
  assertFinitePositive(rect.width, "component width");
  assertFinitePositive(rect.height, "component height");
  assertFiniteNumber(rect.x, "component x");
  assertFiniteNumber(rect.y, "component y");

  let x = Math.floor(rect.x - safePadding);
  let y = Math.floor(rect.y - safePadding);
  let right = Math.ceil(rect.x + rect.width + safePadding);
  let bottom = Math.ceil(rect.y + rect.height + safePadding);

  if (viewport) {
    assertFinitePositive(viewport.width, "viewport width");
    assertFinitePositive(viewport.height, "viewport height");
    x = Math.max(0, Math.min(x, Math.floor(viewport.width)));
    y = Math.max(0, Math.min(y, Math.floor(viewport.height)));
    right = Math.max(x + 1, Math.min(right, Math.ceil(viewport.width)));
    bottom = Math.max(y + 1, Math.min(bottom, Math.ceil(viewport.height)));
  }

  return {
    height: Math.max(1, bottom - y),
    width: Math.max(1, right - x),
    x,
    y,
  };
}

export async function resolveComponentClip(
  page: ComponentVrtPageLike,
  selector: string,
  options: {
    padding?: number;
    timeoutMs?: number;
  } = {},
): Promise<ComponentVrtClip> {
  const locator = page.locator?.(selector);
  if (locator?.waitFor) {
    await locator.waitFor({ state: "visible", timeout: options.timeoutMs });
  } else if (page.waitForSelector) {
    await page.waitForSelector(selector, { state: "visible", timeout: options.timeoutMs });
  }
  if (locator?.scrollIntoViewIfNeeded) {
    await locator.scrollIntoViewIfNeeded({ timeout: options.timeoutMs });
  }
  const domClip = await page.evaluate<ComponentVrtResolvedClip>(`
    (() => {
      const selector = ${jsonLiteral(selector)};
      const padding = ${jsonLiteral(options.padding ?? 0)};
      const element = document.querySelector(selector);
      if (!element) {
        throw new Error("Component root not found: " + selector);
      }
      const rect = element.getBoundingClientRect();
      const viewport = {
        height: window.innerHeight || document.documentElement.clientHeight || 0,
        width: window.innerWidth || document.documentElement.clientWidth || 0,
      };
      const finite = (value) => Number.isFinite(value) ? value : 0;
      const normalizedPadding = Math.max(0, Math.floor(finite(padding)));
      let x = Math.floor(finite(rect.left) - normalizedPadding);
      let y = Math.floor(finite(rect.top) - normalizedPadding);
      let right = Math.ceil(finite(rect.right) + normalizedPadding);
      let bottom = Math.ceil(finite(rect.bottom) + normalizedPadding);
      x = Math.max(0, Math.min(x, Math.floor(viewport.width)));
      y = Math.max(0, Math.min(y, Math.floor(viewport.height)));
      right = Math.max(x + 1, Math.min(right, Math.ceil(viewport.width)));
      bottom = Math.max(y + 1, Math.min(bottom, Math.ceil(viewport.height)));
      return {
        height: Math.max(1, bottom - y),
        viewport,
        width: Math.max(1, right - x),
        x,
        y,
      };
    })()
  `);
  if (!isStubComponentClip(domClip, options.padding ?? 0) || !page.getComputedStylesForElement) {
    return domClip;
  }
  const fallback = await resolveComputedStyleClip(page, selector, domClip, options.padding ?? 0);
  return fallback ?? domClip;
}

export async function captureComponentScreenshot(
  page: ComponentVrtPageLike,
  scenario: Pick<
    ComponentVrtScenario,
    "id" | "outputPath" | "padding" | "quality" | "selector" | "timeoutMs" | "type"
  >,
  options: {
    captureMode?: "clip" | "viewport-crop";
  } = {},
): Promise<ComponentVrtCaptureResult> {
  const startedAt = performance.now();
  const clip = await resolveComponentClip(page, scenario.selector, {
    padding: scenario.padding,
    timeoutMs: scenario.timeoutMs,
  });
  const screenshot = options.captureMode === "viewport-crop"
    ? await captureViewportCropScreenshot(page, clip, scenario)
    : await page.screenshot({
      clip,
      ...(scenario.outputPath ? { path: scenario.outputPath } : {}),
      ...(scenario.quality !== undefined ? { quality: scenario.quality } : {}),
      timeout: scenario.timeoutMs,
      type: scenario.type ?? "png",
    });
  return {
    bytes: screenshot.byteLength,
    clip,
    durationMs: performance.now() - startedAt,
    id: scenario.id,
    ...(scenario.outputPath ? { outputPath: scenario.outputPath } : {}),
  };
}

async function captureViewportCropScreenshot(
  page: ComponentVrtPageLike,
  clip: ComponentVrtClip,
  scenario: Pick<ComponentVrtScenario, "outputPath" | "quality" | "timeoutMs" | "type">,
): Promise<Buffer> {
  if (scenario.type === "jpeg") {
    throw new Error("viewport-crop mode only supports PNG screenshots");
  }
  const viewport = await page.screenshot({
    ...(scenario.quality !== undefined ? { quality: scenario.quality } : {}),
    timeout: scenario.timeoutMs,
    type: "png",
  });
  const cropped = cropPngToClip(viewport, clip, { colorType: "rgb" });
  if (scenario.outputPath) {
    await writeFile(scenario.outputPath, cropped);
  }
  return cropped;
}

export function cropPngToClip(
  input: Buffer,
  clip: ComponentVrtClip,
  options: {
    colorType?: "source" | "rgb";
  } = {},
): Buffer {
  const png = decodePng(input);
  const x = Math.max(0, Math.min(png.width - 1, Math.floor(clip.x)));
  const y = Math.max(0, Math.min(png.height - 1, Math.floor(clip.y)));
  const width = Math.max(1, Math.min(png.width - x, Math.floor(clip.width)));
  const height = Math.max(1, Math.min(png.height - y, Math.floor(clip.height)));
  if (options.colorType === "rgb") {
    return cropPngToRgb(png, { height, width, x, y });
  }
  const bytesPerPixel = pngBytesPerPixel(png.colorType);
  const croppedRows = Buffer.alloc((width * bytesPerPixel + 1) * height);
  const sourceStride = png.width * bytesPerPixel;
  const targetStride = width * bytesPerPixel;
  for (let row = 0; row < height; row += 1) {
    const targetOffset = row * (targetStride + 1);
    const sourceOffset = (y + row) * sourceStride + x * bytesPerPixel;
    croppedRows[targetOffset] = 0;
    png.pixels.copy(croppedRows, targetOffset + 1, sourceOffset, sourceOffset + targetStride);
  }
  return encodePng({
    bitDepth: png.bitDepth,
    colorType: png.colorType,
    height,
    palette: png.palette,
    transparency: png.transparency,
    width,
  }, croppedRows);
}

function cropPngToRgb(png: DecodedPng, clip: ComponentVrtClip): Buffer {
  const bytesPerPixel = pngBytesPerPixel(png.colorType);
  const targetStride = clip.width * 3;
  const rows = Buffer.alloc((targetStride + 1) * clip.height);
  for (let row = 0; row < clip.height; row += 1) {
    const targetOffset = row * (targetStride + 1);
    rows[targetOffset] = 0;
    for (let col = 0; col < clip.width; col += 1) {
      const sourceOffset = ((clip.y + row) * png.width + clip.x + col) * bytesPerPixel;
      const targetPixelOffset = targetOffset + 1 + col * 3;
      const rgb = pngPixelToRgb(png, sourceOffset);
      rows[targetPixelOffset] = rgb[0];
      rows[targetPixelOffset + 1] = rgb[1];
      rows[targetPixelOffset + 2] = rgb[2];
    }
  }
  return encodePng({
    bitDepth: 8,
    colorType: 2,
    height: clip.height,
    width: clip.width,
  }, rows);
}

function pngPixelToRgb(png: DecodedPng, offset: number): [number, number, number] {
  if (png.colorType === 2) {
    return [png.pixels[offset], png.pixels[offset + 1], png.pixels[offset + 2]];
  }
  if (png.colorType === 3) {
    if (!png.palette) {
      throw new Error("Palette PNG is missing PLTE chunk");
    }
    const index = png.pixels[offset];
    const paletteOffset = index * 3;
    if (paletteOffset + 2 >= png.palette.length) {
      throw new Error(`Palette index out of range: ${index}`);
    }
    return [
      png.palette[paletteOffset],
      png.palette[paletteOffset + 1],
      png.palette[paletteOffset + 2],
    ];
  }
  if (png.colorType === 6) {
    const alpha = png.pixels[offset + 3] / 255;
    return [
      compositeOverWhite(png.pixels[offset], alpha),
      compositeOverWhite(png.pixels[offset + 1], alpha),
      compositeOverWhite(png.pixels[offset + 2], alpha),
    ];
  }
  throw new Error(`Unsupported PNG color type: ${png.colorType}`);
}

function compositeOverWhite(value: number, alpha: number): number {
  return Math.round(value * alpha + 255 * (1 - alpha));
}

export async function runComponentVrtScenario(
  page: ComponentVrtPageLike,
  scenario: ComponentVrtScenario,
  options: {
    captureMode?: "clip" | "viewport-crop";
  } = {},
): Promise<ComponentVrtCaptureResult> {
  validateScenario(scenario);
  if (scenario.viewport) {
    await applyViewport(page, scenario.viewport);
  }
  if (scenario.html !== undefined) {
    await setPageHtml(page, scenario.html);
  } else if (scenario.url) {
    if (!page.goto) {
      throw new Error(`page.goto is not available for scenario: ${scenario.id}`);
    }
    await page.goto(scenario.url, {
      timeout: scenario.timeoutMs,
      waitUntil: scenario.waitUntil ?? "commit",
    });
  }
  if (scenario.waitForSelector) {
    await waitForSelector(page, scenario.waitForSelector, scenario.timeoutMs);
  }
  if (scenario.settleMs && scenario.settleMs > 0) {
    await waitForTimeout(page, scenario.settleMs);
  }
  return await captureComponentScreenshot(page, scenario, options);
}

export async function runComponentVrtSuite(
  page: ComponentVrtPageLike,
  config: ComponentVrtConfig,
  options: {
    backend?: ComponentVrtBackend;
    assetCacheDir?: string;
    fetch?: typeof fetch;
    outputDir?: string;
    timeoutMs?: number;
  } = {},
): Promise<ComponentVrtSuiteResult> {
  const cache = new ComponentVrtAssetCache();
  const preload = config.assets?.preload ?? [];
  const cacheDir = options.assetCacheDir ?? config.assets?.cacheDir;
  const restore = cacheDir && preload.length > 0
    ? await cache.restoreFromDisk(preload, {
      cacheDir,
      ttlMs: config.assets?.ttlMs,
    })
    : undefined;
  const shouldRevalidate = config.assets?.revalidate ?? false;
  const prefetchUrls = shouldRevalidate ? preload : preload.filter((url) => !cache.has(url));
  const prefetch = prefetchUrls.length > 0
    ? await cache.prefetch(prefetchUrls, {
      fetch: options.fetch,
      includeContentTypes: config.assets?.includeContentTypes,
      maxBodyBytes: config.assets?.maxBodyBytes,
    })
    : undefined;
  const installedCache = await installComponentVrtAssetCache(page, cache);
  const outputDir = options.outputDir ?? config.outputDir;
  const timeoutMs = options.timeoutMs ?? config.timeoutMs;
  const captureMode = (options.backend ?? config.backend) === "crater" ? "viewport-crop" : "clip";
  const captures: ComponentVrtCaptureResult[] = [];
  let persist: ComponentVrtPersistResult | undefined;

  try {
    if (outputDir) {
      await mkdir(outputDir, { recursive: true });
    }
    for (const scenario of config.scenarios) {
      const outputPath = scenario.outputPath ?? (
        outputDir ? path.join(outputDir, `${scenario.id}.${scenario.type === "jpeg" ? "jpg" : "png"}`) : undefined
      );
      captures.push(await runComponentVrtScenario(page, {
        ...scenario,
        ...(outputPath ? { outputPath } : {}),
        timeoutMs: scenario.timeoutMs ?? timeoutMs,
      }, { captureMode }));
    }
  } finally {
    if (cacheDir && preload.length > 0) {
      persist = await cache.persistToDisk(preload, { cacheDir });
    }
    await installedCache.uninstall();
  }

  return {
    assetCache: {
      ...installedCache.stats,
      ...(persist ? { persist } : {}),
      ...(prefetch ? { prefetch } : {}),
      ...(restore ? { restore } : {}),
      size: cache.size,
    },
    backend: options.backend ?? config.backend ?? "crater",
    captures,
    generatedAt: new Date().toISOString(),
  };
}

export function parseComponentVrtArgs(args: string[]): ComponentVrtArgs {
  const options: ComponentVrtArgs = { ...DEFAULT_ARGS };
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    switch (arg) {
      case "--":
        break;
      case "--backend": {
        const backend = readFlagValue(args, index, arg);
        if (backend !== "crater" && backend !== "chromium") {
          throw new Error(`Unsupported backend: ${backend}`);
        }
        options.backend = backend;
        options.backendOverride = backend;
        index += 1;
        break;
      }
      case "--asset-cache-dir":
        options.assetCacheDir = readFlagValue(args, index, arg);
        index += 1;
        break;
      case "--config":
        options.config = readFlagValue(args, index, arg);
        index += 1;
        break;
      case "--output-dir":
        options.outputDir = readFlagValue(args, index, arg);
        index += 1;
        break;
      case "--server-timeout-ms":
        options.serverTimeoutMs = readPositiveInteger(readFlagValue(args, index, arg), arg);
        index += 1;
        break;
      case "--timeout-ms":
        options.timeoutMs = readPositiveInteger(readFlagValue(args, index, arg), arg);
        index += 1;
        break;
      case "--help":
      case "-h":
        printUsage();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return options;
}

export async function readComponentVrtConfig(configPath: string): Promise<ComponentVrtConfig> {
  const raw = await readFile(configPath, "utf8");
  const parsed = JSON.parse(raw) as ComponentVrtConfig;
  validateConfig(parsed);
  return parsed;
}

export async function runComponentVrtCli(args: string[]): Promise<ComponentVrtSuiteResult> {
  const cli = parseComponentVrtArgs(args);
  if (!cli.config) {
    throw new Error("--config is required");
  }
  const config = await readComponentVrtConfig(cli.config);
  return await runComponentVrtCliConfig(cli, config);
}

export async function runComponentVrtCliConfig(
  cli: ComponentVrtArgs,
  config: ComponentVrtConfig,
): Promise<ComponentVrtSuiteResult> {
  const backend = cli.backendOverride ?? config.backend ?? cli.backend;
  const outputDir = cli.outputDir ?? config.outputDir ?? DEFAULT_OUTPUT_DIR;
  const assetCacheDir = cli.assetCacheDir ?? config.assets?.cacheDir;
  const browser = await launchBackend(backend, {
    serverTimeoutMs: config.serverTimeoutMs ?? cli.serverTimeoutMs,
    timeoutMs: config.timeoutMs ?? cli.timeoutMs,
  });
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    return await runComponentVrtSuite(page as ComponentVrtPageLike, {
      ...config,
      backend,
      timeoutMs: config.timeoutMs ?? cli.timeoutMs,
    }, {
      ...(assetCacheDir ? { assetCacheDir } : {}),
      backend,
      outputDir,
      timeoutMs: config.timeoutMs ?? cli.timeoutMs,
    });
  } finally {
    await browser.close();
  }
}

function normalizeAssetCacheKey(url: string): string {
  try {
    return new URL(url).href;
  } catch {
    return url;
  }
}

function jsonLiteral(value: unknown): string {
  return JSON.stringify(value);
}

async function readDiskCacheRecord(
  cacheDir: string,
  url: string,
): Promise<ComponentVrtDiskCacheRecord | null> {
  let raw: string;
  try {
    raw = await readFile(diskCacheRecordPath(cacheDir, url), "utf8");
  } catch (error) {
    const code = error && typeof error === "object" && "code" in error
      ? String((error as { code?: unknown }).code)
      : "";
    if (code === "ENOENT") {
      return null;
    }
    throw error;
  }
  const parsed = JSON.parse(raw) as Partial<ComponentVrtDiskCacheRecord>;
  if (parsed.schemaVersion !== DISK_CACHE_SCHEMA_VERSION || !parsed.entry || !parsed.url) {
    return null;
  }
  return parsed as ComponentVrtDiskCacheRecord;
}

function isUsableDiskCacheRecord(
  record: ComponentVrtDiskCacheRecord,
  url: string,
  now: number,
  ttlMs: number | undefined,
): boolean {
  if (normalizeAssetCacheKey(record.url) !== normalizeAssetCacheKey(url)) {
    return false;
  }
  if (!record.entry || typeof record.entry.body !== "string") {
    return false;
  }
  if (ttlMs !== undefined && now - record.entry.storedAt > ttlMs) {
    return false;
  }
  return true;
}

function diskCacheRecordPath(cacheDir: string, url: string): string {
  return path.join(cacheDir, `${assetCacheKeyHash(url)}.json`);
}

function assetCacheKeyHash(url: string): string {
  return createHash("sha256").update(normalizeAssetCacheKey(url)).digest("hex");
}

function normalizeHeaders(headers: Headers | Record<string, string>): Record<string, string> {
  const normalized: Record<string, string> = {};
  if (headers instanceof Headers) {
    headers.forEach((value, key) => {
      normalized[key.toLowerCase()] = value;
    });
    return normalized;
  }
  for (const [key, value] of Object.entries(headers)) {
    normalized[key.toLowerCase()] = String(value);
  }
  return normalized;
}

function isCacheableStatus(status: number): boolean {
  return status >= 200 && status < 300;
}

function isNoStore(cacheControl: string | undefined): boolean {
  return Boolean(cacheControl && /\bno-store\b/i.test(cacheControl));
}

function isTextAsset(url: string, contentType: string, includeContentTypes: string[]): boolean {
  const lowerContentType = contentType.toLowerCase().split(";")[0]?.trim() ?? "";
  if (lowerContentType && includeContentTypes.some((type) => lowerContentType === type)) {
    return true;
  }
  try {
    const pathname = new URL(url).pathname.toLowerCase();
    return DEFAULT_TEXT_EXTENSIONS.some((extension) => pathname.endsWith(extension));
  } catch {
    const lower = url.toLowerCase();
    return DEFAULT_TEXT_EXTENSIONS.some((extension) => lower.endsWith(extension));
  }
}

function assertFiniteNumber(value: number, label: string): void {
  if (!Number.isFinite(value)) {
    throw new Error(`${label} must be finite`);
  }
}

function assertFinitePositive(value: number, label: string): void {
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${label} must be positive`);
  }
}

function isStubComponentClip(clip: ComponentVrtClip, padding: number): boolean {
  const paddedStubSize = 2 + Math.max(0, Math.floor(padding)) * 2;
  return clip.width <= paddedStubSize || clip.height <= paddedStubSize;
}

async function resolveComputedStyleClip(
  page: ComponentVrtPageLike,
  selector: string,
  domClip: ComponentVrtResolvedClip,
  padding: number,
): Promise<ComponentVrtClip | null> {
  if (!page.getComputedStylesForElement) {
    return null;
  }
  const styles = await page.getComputedStylesForElement(selector, [
    "width",
    "height",
    "padding",
    "padding-top",
    "padding-right",
    "padding-bottom",
    "padding-left",
  ]);
  const width = parseCssPx(styles.width);
  const height = parseCssPx(styles.height);
  if (!width || !height) {
    return null;
  }
  const edges = parseCssBoxEdges(styles);
  const clip = normalizeComponentClip({
    height: height + edges.top + edges.bottom,
    width: width + edges.left + edges.right,
    x: domClip.x,
    y: domClip.y,
  }, domClip.viewport, padding);
  return {
    ...clip,
    x: Math.max(0, clip.x),
    y: Math.max(0, clip.y),
  };
}

function parseCssPx(value: string | undefined): number | null {
  if (!value) {
    return null;
  }
  const match = value.trim().match(/^(-?\d+(?:\.\d+)?)px$/);
  if (!match) {
    return null;
  }
  const parsed = Number(match[1]);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function parseCssBoxEdges(styles: Record<string, string>): {
  bottom: number;
  left: number;
  right: number;
  top: number;
} {
  const explicit = {
    bottom: parseCssPx(styles["padding-bottom"]),
    left: parseCssPx(styles["padding-left"]),
    right: parseCssPx(styles["padding-right"]),
    top: parseCssPx(styles["padding-top"]),
  };
  if (
    explicit.bottom !== null ||
    explicit.left !== null ||
    explicit.right !== null ||
    explicit.top !== null
  ) {
    return {
      bottom: explicit.bottom ?? 0,
      left: explicit.left ?? 0,
      right: explicit.right ?? 0,
      top: explicit.top ?? 0,
    };
  }
  const shorthand = parseCssPxList(styles.padding);
  return {
    bottom: shorthand.bottom,
    left: shorthand.left,
    right: shorthand.right,
    top: shorthand.top,
  };
}

function parseCssPxList(value: string | undefined): {
  bottom: number;
  left: number;
  right: number;
  top: number;
} {
  const parts = value?.trim().split(/\s+/).map(parseCssPx).filter((part): part is number => part !== null) ?? [];
  if (parts.length === 0) {
    return { bottom: 0, left: 0, right: 0, top: 0 };
  }
  if (parts.length === 1) {
    return { bottom: parts[0], left: parts[0], right: parts[0], top: parts[0] };
  }
  if (parts.length === 2) {
    return { bottom: parts[0], left: parts[1], right: parts[1], top: parts[0] };
  }
  if (parts.length === 3) {
    return { bottom: parts[2], left: parts[1], right: parts[1], top: parts[0] };
  }
  return { bottom: parts[2], left: parts[3], right: parts[1], top: parts[0] };
}

interface DecodedPng {
  bitDepth: number;
  colorType: number;
  height: number;
  palette?: Buffer;
  pixels: Buffer;
  transparency?: Buffer;
  width: number;
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function decodePng(input: Buffer): DecodedPng {
  if (input.length < 33 || !input.subarray(0, 8).equals(PNG_SIGNATURE)) {
    throw new Error("Invalid PNG signature");
  }
  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  let interlace = 0;
  let palette: Buffer | undefined;
  let transparency: Buffer | undefined;
  const idat: Buffer[] = [];

  while (offset + 12 <= input.length) {
    const length = input.readUInt32BE(offset);
    const type = input.toString("ascii", offset + 4, offset + 8);
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    if (dataEnd + 4 > input.length) {
      throw new Error("Invalid PNG chunk length");
    }
    const data = input.subarray(dataStart, dataEnd);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
      interlace = data[12];
    } else if (type === "PLTE") {
      palette = Buffer.from(data);
    } else if (type === "tRNS") {
      transparency = Buffer.from(data);
    } else if (type === "IDAT") {
      idat.push(Buffer.from(data));
    } else if (type === "IEND") {
      break;
    }
    offset = dataEnd + 4;
  }

  if (width <= 0 || height <= 0 || bitDepth !== 8 || interlace !== 0) {
    throw new Error("Unsupported PNG layout");
  }
  const bytesPerPixel = pngBytesPerPixel(colorType);
  const inflated = inflateSync(Buffer.concat(idat));
  const pixels = unfilterPngRows(inflated, width, height, bytesPerPixel);
  return {
    bitDepth,
    colorType,
    height,
    ...(palette ? { palette } : {}),
    pixels,
    ...(transparency ? { transparency } : {}),
    width,
  };
}

function pngBytesPerPixel(colorType: number): number {
  if (colorType === 2) {
    return 3;
  }
  if (colorType === 3) {
    return 1;
  }
  if (colorType === 6) {
    return 4;
  }
  throw new Error(`Unsupported PNG color type: ${colorType}`);
}

function unfilterPngRows(input: Buffer, width: number, height: number, bytesPerPixel: number): Buffer {
  const stride = width * bytesPerPixel;
  const expected = (stride + 1) * height;
  if (input.length < expected) {
    throw new Error("PNG IDAT payload is shorter than expected");
  }
  const output = Buffer.alloc(stride * height);
  for (let row = 0; row < height; row += 1) {
    const sourceOffset = row * (stride + 1);
    const targetOffset = row * stride;
    const filter = input[sourceOffset];
    for (let col = 0; col < stride; col += 1) {
      const raw = input[sourceOffset + 1 + col];
      const left = col >= bytesPerPixel ? output[targetOffset + col - bytesPerPixel] : 0;
      const up = row > 0 ? output[targetOffset + col - stride] : 0;
      const upperLeft = row > 0 && col >= bytesPerPixel
        ? output[targetOffset + col - stride - bytesPerPixel]
        : 0;
      output[targetOffset + col] = (raw + pngFilterValue(filter, left, up, upperLeft)) & 0xff;
    }
  }
  return output;
}

function pngFilterValue(filter: number, left: number, up: number, upperLeft: number): number {
  if (filter === 0) {
    return 0;
  }
  if (filter === 1) {
    return left;
  }
  if (filter === 2) {
    return up;
  }
  if (filter === 3) {
    return Math.floor((left + up) / 2);
  }
  if (filter === 4) {
    return paethPredictor(left, up, upperLeft);
  }
  throw new Error(`Unsupported PNG filter: ${filter}`);
}

function paethPredictor(left: number, up: number, upperLeft: number): number {
  const p = left + up - upperLeft;
  const pa = Math.abs(p - left);
  const pb = Math.abs(p - up);
  const pc = Math.abs(p - upperLeft);
  if (pa <= pb && pa <= pc) {
    return left;
  }
  return pb <= pc ? up : upperLeft;
}

function encodePng(
  header: {
    bitDepth: number;
    colorType: number;
    height: number;
    palette?: Buffer;
    transparency?: Buffer;
    width: number;
  },
  filteredRows: Buffer,
): Buffer {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(header.width, 0);
  ihdr.writeUInt32BE(header.height, 4);
  ihdr[8] = header.bitDepth;
  ihdr[9] = header.colorType;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  const chunks = [
    PNG_SIGNATURE,
    pngChunk("IHDR", ihdr),
    ...(header.palette ? [pngChunk("PLTE", header.palette)] : []),
    ...(header.transparency ? [pngChunk("tRNS", header.transparency)] : []),
    pngChunk("IDAT", deflateSync(filteredRows)),
    pngChunk("IEND", Buffer.alloc(0)),
  ];
  return Buffer.concat(chunks);
}

function pngChunk(type: string, data: Buffer): Buffer {
  const typeBytes = Buffer.from(type, "ascii");
  const chunk = Buffer.alloc(12 + data.length);
  chunk.writeUInt32BE(data.length, 0);
  typeBytes.copy(chunk, 4);
  data.copy(chunk, 8);
  chunk.writeUInt32BE(crc32(Buffer.concat([typeBytes, data])), 8 + data.length);
  return chunk;
}

function crc32(input: Buffer): number {
  let crc = 0xffffffff;
  for (const byte of input) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

async function applyViewport(page: ComponentVrtPageLike, viewport: ComponentVrtViewport): Promise<void> {
  if (page.setViewportSize) {
    await page.setViewportSize(viewport);
    return;
  }
  if (page.setViewport) {
    await page.setViewport(viewport.width, viewport.height);
  }
}

async function setPageHtml(page: ComponentVrtPageLike, html: string): Promise<void> {
  if (page.setContentWithScripts) {
    await page.setContentWithScripts(html);
    return;
  }
  if (page.setContent) {
    await page.setContent(html);
    return;
  }
  throw new Error("page.setContent is not available");
}

async function waitForSelector(
  page: ComponentVrtPageLike,
  selector: string,
  timeoutMs: number | undefined,
): Promise<void> {
  if (page.waitForSelector) {
    await page.waitForSelector(selector, { state: "visible", timeout: timeoutMs });
    return;
  }
  const locator = page.locator?.(selector);
  if (locator?.waitFor) {
    await locator.waitFor({ state: "visible", timeout: timeoutMs });
  }
}

async function waitForTimeout(page: ComponentVrtPageLike, timeout: number): Promise<void> {
  if (page.waitForTimeout) {
    await page.waitForTimeout(timeout);
    return;
  }
  await new Promise((resolve) => setTimeout(resolve, timeout));
}

function validateScenario(scenario: ComponentVrtScenario): void {
  if (!scenario.id) {
    throw new Error("scenario.id is required");
  }
  if (!scenario.selector) {
    throw new Error(`scenario.selector is required: ${scenario.id}`);
  }
  if (scenario.html === undefined && !scenario.url) {
    throw new Error(`scenario.url or scenario.html is required: ${scenario.id}`);
  }
  if (scenario.html !== undefined && scenario.url) {
    throw new Error(`scenario.url and scenario.html are mutually exclusive: ${scenario.id}`);
  }
}

function validateConfig(config: ComponentVrtConfig): void {
  if (!Array.isArray(config.scenarios) || config.scenarios.length === 0) {
    throw new Error("config.scenarios must contain at least one scenario");
  }
  for (const scenario of config.scenarios) {
    validateScenario(scenario);
  }
}

function readFlagValue(args: string[], index: number, flag: string): string {
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`Missing value for ${flag}`);
  }
  return value;
}

function readPositiveInteger(value: string, flag: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${flag} must be a positive integer`);
  }
  return parsed;
}

async function launchBackend(
  backend: ComponentVrtBackend,
  options: { serverTimeoutMs: number; timeoutMs: number },
): Promise<{
  close(): Promise<void>;
  newContext(): Promise<{ newPage(): Promise<unknown> }>;
}> {
  if (backend === "chromium") {
    const { chromium } = await import("@playwright/test");
    return await chromium.launch({ headless: true });
  }
  const { chromium } = await import("../webdriver/playwright/adapter.ts");
  return await chromium.launch({
    autoStartBidi: true,
    serverTimeoutMs: options.serverTimeoutMs,
    timeout: options.timeoutMs,
  });
}

function printUsage(): void {
  console.log(`Usage: pnpm vrt:component -- --config <file> [options]

Options:
  --backend <crater|chromium>    Screenshot backend. Default: crater.
  --asset-cache-dir <dir>        Override text asset disk cache directory.
  --config <file>                JSON scenario config.
  --output-dir <dir>             Directory for component screenshots.
  --timeout-ms <ms>              Page operation timeout. Default: 5000.
  --server-timeout-ms <ms>       Crater BiDi startup timeout. Default: 20000.
`);
}

async function main(): Promise<void> {
  const cli = parseComponentVrtArgs(process.argv.slice(2));
  if (!cli.config) {
    throw new Error("--config is required");
  }
  const config = await readComponentVrtConfig(cli.config);
  const outputDir = cli.outputDir ?? config.outputDir ?? DEFAULT_OUTPUT_DIR;
  const result = await runComponentVrtCliConfig(cli, config);
  await mkdir(outputDir, { recursive: true });
  const manifestPath = path.join(outputDir, "manifest.json");
  await writeFile(manifestPath, JSON.stringify(result, null, 2));
  console.log(JSON.stringify({
    captures: result.captures.length,
    manifest: manifestPath,
  }, null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.stack || error.message : error);
    process.exit(1);
  });
}
