/**
 * One-command URL → VRT comparison.
 *
 * Usage:
 *   npx tsx scripts/vrt-url.ts https://example.com
 *   npx tsx scripts/vrt-url.ts https://example.com --name example-com --width 800 --height 600
 *   npx tsx scripts/vrt-url.ts https://example.com --backend native
 *   npx tsx scripts/vrt-url.ts https://example.com --mask-text --mask-dynamic
 *
 * Captures a URL with Chromium, renders with Crater, compares with pixelmatch.
 * Outputs diff images to output/playwright/vrt/url/<name>/
 */

import { chromium, type Page } from "playwright";
import path from "node:path";
import fs from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import pixelmatchFn from "pixelmatch";
import {
  ensureCraterBidiServer,
  type CraterBidiServerHandle,
} from "./crater-bidi-server.ts";
import {
  createNormalizedVrtArtifactReport,
  type VrtCssRuleUsageMetrics,
} from "./vrt-report-contract.ts";
import { summarizeCssRuleUsageResult } from "./vrt-css-rule-usage.ts";

type VrtUrlBackend = "native" | "sixel";

export interface VrtUrlOptions {
  backend: VrtUrlBackend;
  height: number;
  maskDynamic: boolean;
  maskText: boolean;
  maxDiffRatio: number;
  name: string;
  outputDir: string;
  serverTimeoutMs: number;
  threshold: number;
  url: string;
  width: number;
}

export const VRT_URL_USAGE = [
  "Usage: npx tsx scripts/vrt-url.ts <url> [--name slug] [--width N] [--height N] [--backend native|sixel] [--mask-text] [--mask-dynamic] [--max-diff-ratio N]",
  "",
  "Options:",
  "  --mask-text             Hide text glyph pixels while preserving text layout.",
  "  --mask-dynamic          Hide iframes, canvas/video/embed/object, and shadow-root hosts.",
  "  --backend native|sixel  Crater renderer backend. Default: sixel.",
  "  --server-timeout-ms N   BiDi startup timeout for sixel backend. Default: 20000.",
].join("\n");

export class VrtUrlUsageError extends Error {}

export interface VrtDynamicMaskBox {
  display?: string;
  height: number;
  width: number;
}

function formatCssPixel(value: number): string {
  const finite = Number.isFinite(value) ? Math.max(0, value) : 0;
  return Number(finite.toFixed(3)).toString();
}

export function buildDynamicMaskInlineStyle(existingStyle: string | null, box: VrtDynamicMaskBox): string {
  const declarations = (existingStyle ?? "").trim().replace(/;+\s*$/, "");
  const width = formatCssPixel(box.width);
  const height = formatCssPixel(box.height);
  const shouldFreezeInlineBox = box.display === "inline" &&
    box.width > 0 &&
    box.height > 0;
  return [
    declarations,
    "visibility:hidden",
    shouldFreezeInlineBox ? "display:inline-block!important" : "",
    "box-sizing:border-box!important",
    `width:${width}px!important`,
    `height:${height}px!important`,
    `min-width:${width}px!important`,
    `min-height:${height}px!important`,
    `max-width:${width}px!important`,
    `max-height:${height}px!important`,
    "overflow:hidden!important",
  ].filter(Boolean).join(";");
}

function getArg(args: string[], flag: string, fallback: string): string {
  const idx = args.indexOf(flag);
  return idx >= 0 && idx + 1 < args.length ? args[idx + 1] : fallback;
}

function parseNumberArg(args: string[], flag: string, fallback: string): number {
  const value = Number(getArg(args, flag, fallback));
  if (!Number.isFinite(value)) {
    throw new VrtUrlUsageError(`Invalid numeric value for ${flag}`);
  }
  return value;
}

function parseIntegerArg(args: string[], flag: string, fallback: string): number {
  const value = parseNumberArg(args, flag, fallback);
  if (!Number.isInteger(value) || value <= 0) {
    throw new VrtUrlUsageError(`Invalid positive integer for ${flag}`);
  }
  return value;
}

export function buildVrtUrlOutputName(name: string, maskText: boolean, maskDynamic = false): string {
  let outputName = name;
  if (maskText && !outputName.endsWith("-text-masked")) {
    outputName = `${outputName}-text-masked`;
  }
  if (maskDynamic && !outputName.endsWith("-dynamic-masked")) {
    outputName = `${outputName}-dynamic-masked`;
  }
  return outputName;
}

export function buildVrtUrlOutputDir(cwd: string, name: string, maskText: boolean, maskDynamic = false): string {
  return path.join(cwd, "output", "playwright", "vrt", "url", buildVrtUrlOutputName(name, maskText, maskDynamic));
}

export function parseVrtUrlArgs(args: string[], cwd = process.cwd()): VrtUrlOptions {
  const normalizedArgs = args[0] === "--" ? args.slice(1) : args;
  const url = normalizedArgs.find((a) => /^https?:\/\//.test(a));
  if (!url) {
    throw new VrtUrlUsageError(VRT_URL_USAGE);
  }

  const backendArg = getArg(normalizedArgs, "--backend", "sixel");
  if (backendArg !== "native" && backendArg !== "sixel") {
    throw new VrtUrlUsageError(`Invalid backend: ${backendArg}`);
  }

  const name = getArg(normalizedArgs, "--name", new URL(url).hostname.replace(/\./g, "-"));
  const maskDynamic = normalizedArgs.includes("--mask-dynamic");
  const maskText = normalizedArgs.includes("--mask-text");
  return {
    backend: backendArg,
    height: parseIntegerArg(normalizedArgs, "--height", "600"),
    maskDynamic,
    maskText,
    maxDiffRatio: parseNumberArg(normalizedArgs, "--max-diff-ratio", "0.15"),
    name,
    outputDir: buildVrtUrlOutputDir(cwd, name, maskText, maskDynamic),
    serverTimeoutMs: parseIntegerArg(normalizedArgs, "--server-timeout-ms", "20000"),
    threshold: parseNumberArg(normalizedArgs, "--threshold", "0.3"),
    url,
    width: parseIntegerArg(normalizedArgs, "--width", "800"),
  };
}

export async function applyChromiumMasks(
  page: Page,
  options: { maskDynamic?: boolean; maskText?: boolean },
): Promise<void> {
  await page.evaluate((maskOptions) => {
    const maskAttribute = "data-crater-vrt-text-mask";
    const dynamicMaskAttribute = "data-crater-vrt-dynamic-mask";
    const rawTextSelector = "script,style,textarea,title,option,svg,math";
    const root = document.body ?? document.documentElement;
    if (!root) {
      return;
    }

    if (!document.querySelector("style[data-crater-vrt-text-mask-style]")) {
      const style = document.createElement("style");
      style.setAttribute("data-crater-vrt-text-mask-style", "");
      const rules: string[] = [];
      if (maskOptions.maskText) {
        rules.push(
          `[${maskAttribute}]{visibility:hidden!important}`,
          `input,textarea{color:transparent!important;-webkit-text-fill-color:transparent!important;text-shadow:none!important;caret-color:transparent!important}`,
          `input::placeholder,textarea::placeholder{color:transparent!important;-webkit-text-fill-color:transparent!important;text-shadow:none!important}`,
          `*::before,*::after{color:transparent!important;-webkit-text-fill-color:transparent!important;text-shadow:none!important}`,
          `svg text{visibility:hidden!important}`,
        );
      }
      if (maskOptions.maskDynamic) {
        rules.push(`[${dynamicMaskAttribute}]{visibility:hidden!important}`);
      }
      style.textContent = rules.join("\n");
      document.head?.appendChild(style);
    }

    if (maskOptions.maskText) {
      document.querySelectorAll("img[alt]").forEach((img) => img.setAttribute("alt", ""));

      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
        acceptNode(node) {
          if (!node.nodeValue || !/\S/.test(node.nodeValue)) {
            return NodeFilter.FILTER_REJECT;
          }
          const parent = node.parentElement;
          if (!parent) {
            return NodeFilter.FILTER_REJECT;
          }
          if (parent.closest(`[${maskAttribute}]`) || parent.closest(rawTextSelector)) {
            return NodeFilter.FILTER_REJECT;
          }
          return NodeFilter.FILTER_ACCEPT;
        },
      });

      const textNodes: Text[] = [];
      for (let node = walker.nextNode(); node; node = walker.nextNode()) {
        textNodes.push(node as Text);
      }
      for (const text of textNodes) {
        if (!text.parentNode) {
          continue;
        }
        const span = document.createElement("span");
        span.setAttribute(maskAttribute, "");
        span.setAttribute("style", "visibility: hidden");
        text.parentNode.replaceChild(span, text);
        span.appendChild(text);
      }
    }

    if (maskOptions.maskDynamic) {
      const dynamicElements: Element[] = [];
      for (const element of document.querySelectorAll("iframe,object,embed,video,canvas")) {
        dynamicElements.push(element);
      }
      for (const element of document.querySelectorAll("*")) {
        if ((element as HTMLElement).shadowRoot) {
          dynamicElements.push(element);
        }
      }
      for (const element of dynamicElements) {
        const htmlElement = element as HTMLElement;
        const rect = htmlElement.getBoundingClientRect();
        const computed = window.getComputedStyle(htmlElement);
        const finiteWidth = Number.isFinite(rect.width) ? Math.max(0, rect.width) : 0;
        const finiteHeight = Number.isFinite(rect.height) ? Math.max(0, rect.height) : 0;
        const width = Number(finiteWidth.toFixed(3)).toString();
        const height = Number(finiteHeight.toFixed(3)).toString();
        const shouldFreezeInlineBox = computed.display === "inline" &&
          finiteWidth > 0 &&
          finiteHeight > 0;
        const existingStyle = (htmlElement.getAttribute("style") ?? "").trim().replace(/;+\s*$/, "");
        element.setAttribute(dynamicMaskAttribute, "");
        htmlElement.setAttribute("style", [
          existingStyle,
          "visibility:hidden",
          shouldFreezeInlineBox ? "display:inline-block!important" : "",
          "box-sizing:border-box!important",
          `width:${width}px!important`,
          `height:${height}px!important`,
          `min-width:${width}px!important`,
          `min-height:${height}px!important`,
          `max-width:${width}px!important`,
          `max-height:${height}px!important`,
          "overflow:hidden!important",
        ].filter(Boolean).join(";"));
      }
    }
  }, options);
}

export async function applyChromiumTextMask(page: Page): Promise<void> {
  await applyChromiumMasks(page, { maskText: true });
}

async function captureChromiumReference(options: VrtUrlOptions): Promise<{ html: string; png: Buffer }> {
  const browser = await chromium.launch({ args: ["--no-sandbox"] });
  try {
    const context = await browser.newContext({
      viewport: { width: options.width, height: options.height },
      deviceScaleFactor: 1,
      colorScheme: "light",
    });
    const page = await context.newPage();
    await page.emulateMedia({ colorScheme: "light", reducedMotion: "reduce" });

    await page.goto(options.url, { waitUntil: "load", timeout: 30000 });
    await page.waitForTimeout(1000);
    if (options.maskText || options.maskDynamic) {
      await applyChromiumMasks(page, {
        maskDynamic: options.maskDynamic,
        maskText: options.maskText,
      });
    }

    const html = await page.evaluate(() => {
      const styles: string[] = [];
      for (const sheet of document.styleSheets) {
        try {
          const rules = Array.from(sheet.cssRules).map((r) => r.cssText).join("\n");
          styles.push(rules);
        } catch {
          // Cross-origin stylesheet, skip.
        }
      }
      const clone = document.documentElement.cloneNode(true) as HTMLElement;
      clone.querySelectorAll("script").forEach((s) => s.remove());
      clone.querySelectorAll('link[rel="stylesheet"]').forEach((l) => l.remove());
      clone.querySelectorAll('link[rel="preload"], link[rel="prefetch"], link[rel="dns-prefetch"], link[rel="preconnect"]').forEach((l) => l.remove());
      const base = document.createElement("base");
      base.href = document.location.href;
      const head = clone.querySelector("head");
      if (head) {
        head.insertBefore(base, head.firstChild);
        for (const css of styles) {
          const style = document.createElement("style");
          style.textContent = css;
          head.appendChild(style);
        }
      }
      return "<!DOCTYPE html>" + clone.outerHTML;
    });

    return {
      html,
      png: await page.screenshot({ type: "png" }),
    };
  } finally {
    await browser.close();
  }
}

async function renderCraterNative(
  html: string,
  options: VrtUrlOptions,
): Promise<{ rgba: Uint8Array; width: number; height: number; cssRuleUsage?: VrtCssRuleUsageMetrics }> {
  fs.writeFileSync("/tmp/crater_paint_input.html", html);
  fs.writeFileSync("/tmp/crater_paint_config.txt", `${options.width} ${options.height}`);

  const binCandidates = [
    process.env.CRATER_PAINT_BIN,
    `${process.env.HOME}/ghq/github.com/mizchi/kagura/examples/crater_paint/_build/native/debug/build/crater_paint.exe`,
  ].filter(Boolean) as string[];

  let bin: string | null = null;
  for (const candidate of binCandidates) {
    if (fs.existsSync(candidate)) { bin = candidate; break; }
  }
  if (!bin) {
    throw new Error("crater_paint binary not found");
  }

  const cwd = `${process.env.HOME}/ghq/github.com/mizchi/kagura/examples/crater_paint`;
  const result = execFileSync(bin, [], { cwd, timeout: 120000, maxBuffer: 10 * 1024 * 1024 });
  if (!result.toString().includes("OK")) {
    throw new Error(`crater_paint failed: ${result.toString()}`);
  }

  const bmpData = fs.readFileSync("/tmp/crater_paint_output.bmp");
  const bmpOffset = bmpData.readUInt32LE(10);
  const bmpW = bmpData.readInt32LE(18);
  const bmpH = Math.abs(bmpData.readInt32LE(22));
  const bpp = bmpData.readUInt16LE(28) / 8;
  const rowStride = Math.ceil(bmpW * bpp / 4) * 4;
  const rgba = new Uint8Array(bmpW * bmpH * 4);
  for (let y = 0; y < bmpH; y++) {
    const srcRow = bmpH - 1 - y;
    const srcOffset = bmpOffset + srcRow * rowStride;
    for (let x = 0; x < bmpW; x++) {
      const si = srcOffset + x * bpp;
      const di = (y * bmpW + x) * 4;
      rgba[di] = bmpData[si + 2];     // R
      rgba[di + 1] = bmpData[si + 1]; // G
      rgba[di + 2] = bmpData[si];     // B
      rgba[di + 3] = 255;
    }
  }
  return { height: bmpH, rgba, width: bmpW };
}

async function renderCraterSixel(
  html: string,
  options: VrtUrlOptions,
): Promise<{ rgba: Uint8Array; width: number; height: number; cssRuleUsage?: VrtCssRuleUsageMetrics }> {
  const WebSocket = (await import("ws")).default;
  let server: CraterBidiServerHandle | null = null;
  let ws: InstanceType<typeof WebSocket> | null = null;
  server = await ensureCraterBidiServer({
    stdio: "ignore",
    timeoutMs: options.serverTimeoutMs,
  });
  ws = new WebSocket(server.url);
  let cmdId = 0;
  const pending = new Map<number, { resolve: (v: any) => void }>();

  try {
    await new Promise<void>((resolve, reject) => {
      ws!.on("open", resolve);
      ws!.on("error", reject);
    });
    ws.on("message", (data) => {
      const msg = JSON.parse(data.toString());
      const p = pending.get(msg.id);
      if (p) { pending.delete(msg.id); p.resolve(msg); }
    });

    const send = (method: string, params: any) => new Promise<any>((resolve) => {
      const id = ++cmdId;
      pending.set(id, { resolve });
      ws!.send(JSON.stringify({ id, method, params }));
    });

    const createResp = await send("browsingContext.create", { type: "tab" });
    const contextId = createResp.result.context;
    await send("browsingContext.setViewport", {
      context: contextId,
      viewport: { width: options.width, height: options.height },
    });

    const dataUrl = `data:text/html;base64,${Buffer.from(html).toString("base64")}`;
    await send("browsingContext.navigate", { context: contextId, url: dataUrl, wait: "complete" });
    await send("script.evaluate", {
      expression: `__loadHTML(${JSON.stringify(html)})`,
      target: { context: contextId },
      awaitPromise: false,
    });

    const paintResp = await send("browsingContext.capturePaintData", { context: contextId, origin: "viewport" });
    const paintResult = paintResp.result;
    const cssRuleUsageResp = await send("browsingContext.getCssRuleUsage", { context: contextId });
    await send("browsingContext.close", { context: contextId });
    return {
      cssRuleUsage: summarizeCssRuleUsageResult(cssRuleUsageResp.result),
      height: paintResult.height,
      rgba: Uint8Array.from(Buffer.from(paintResult.data, "base64")),
      width: paintResult.width,
    };
  } finally {
    ws.close();
    await server.close();
  }
}

async function decodePngToRgba(png: Buffer): Promise<{ data: Uint8Array; width: number; height: number }> {
  const chromiumBrowser = await chromium.launch({ args: ["--no-sandbox"] });
  try {
    const decodePage = await chromiumBrowser.newPage();
    const decoded = await decodePage.evaluate(async (base64Png: string) => {
      const bytes = Uint8Array.from(atob(base64Png), (c) => c.charCodeAt(0));
      const blob = new Blob([bytes], { type: "image/png" });
      const bitmap = await createImageBitmap(blob);
      const canvas = document.createElement("canvas");
      canvas.width = bitmap.width;
      canvas.height = bitmap.height;
      const ctx = canvas.getContext("2d")!;
      ctx.drawImage(bitmap, 0, 0);
      const imageData = ctx.getImageData(0, 0, bitmap.width, bitmap.height);
      return { width: bitmap.width, height: bitmap.height, data: Array.from(imageData.data) };
    }, png.toString("base64"));
    return {
      data: Uint8Array.from(decoded.data),
      height: decoded.height,
      width: decoded.width,
    };
  } finally {
    await chromiumBrowser.close();
  }
}

async function encodeRgbaPngs(images: Array<{ name: string; rgba: Uint8Array }>, width: number, height: number): Promise<Map<string, Buffer>> {
  const encodeBrowser = await chromium.launch({ args: ["--no-sandbox"] });
  try {
    const encodePage = await encodeBrowser.newPage();
    const outputs = new Map<string, Buffer>();
    for (const image of images) {
      const base64 = await encodePage.evaluate(async (payload: { data: number[]; width: number; height: number }) => {
        const canvas = document.createElement("canvas");
        canvas.width = payload.width;
        canvas.height = payload.height;
        const ctx = canvas.getContext("2d")!;
        const imageData = new ImageData(Uint8ClampedArray.from(payload.data), payload.width, payload.height);
        ctx.putImageData(imageData, 0, 0);
        return canvas.toDataURL("image/png").replace(/^data:image\/png;base64,/, "");
      }, { data: Array.from(image.rgba), width, height });
      outputs.set(image.name, Buffer.from(base64, "base64"));
    }
    return outputs;
  } finally {
    await encodeBrowser.close();
  }
}

export async function runVrtUrl(options: VrtUrlOptions): Promise<{ diffPixels: number; diffRatio: number; outputDir: string; status: string }> {
  console.log(`\nVRT: ${options.url}`);
  console.log(`  viewport: ${options.width}x${options.height}`);
  console.log(`  backend: ${options.backend}`);
  console.log(`  text mask: ${options.maskText ? "on" : "off"}`);
  console.log(`  dynamic mask: ${options.maskDynamic ? "on" : "off"}`);
  console.log(`  output: ${options.outputDir}\n`);

  console.log("1. Capturing with Chromium...");
  const reference = await captureChromiumReference(options);
  console.log(`   HTML: ${reference.html.length} chars`);
  console.log(`   Screenshot: ${reference.png.length} bytes`);

  console.log(`2. Rendering with Crater (${options.backend})...`);
  const crater = options.backend === "native"
    ? await renderCraterNative(reference.html, options)
    : await renderCraterSixel(reference.html, options);
  console.log(`   Crater: ${crater.width}x${crater.height}`);

  console.log("3. Comparing...");
  const decoded = await decodePngToRgba(reference.png);
  if (decoded.width !== crater.width || decoded.height !== crater.height) {
    throw new Error(`Size mismatch: Chromium ${decoded.width}x${decoded.height} vs Crater ${crater.width}x${crater.height}`);
  }

  const w = decoded.width;
  const h = decoded.height;
  const diffOutput = new Uint8Array(w * h * 4);
  const diffPixels = pixelmatchFn(decoded.data, crater.rgba, diffOutput, w, h, { threshold: options.threshold });
  const totalPixels = w * h;
  const diffRatio = diffPixels / totalPixels;

  fs.mkdirSync(options.outputDir, { recursive: true });
  fs.writeFileSync(path.join(options.outputDir, "chromium.png"), reference.png);

  const encoded = await encodeRgbaPngs([
    { name: "crater.png", rgba: crater.rgba },
    { name: "diff.png", rgba: diffOutput },
  ], w, h);
  for (const [name, png] of encoded) {
    fs.writeFileSync(path.join(options.outputDir, name), png);
  }

  const title = buildVrtUrlOutputName(options.name, options.maskText, options.maskDynamic);
  const report = createNormalizedVrtArtifactReport({
    title,
    filter: options.url,
    artifacts: {
      chromium: "chromium.png",
      crater: "crater.png",
      diff: "diff.png",
      report: "report.json",
    },
    metadata: {
      width: w,
      height: h,
      diffPixels,
      totalPixels,
      diffRatio,
      threshold: options.threshold,
      maxDiffRatio: options.maxDiffRatio,
      backend: options.backend,
      viewport: {
        width: w,
        height: h,
      },
      snapshotKind: [
        "url",
        ...(options.maskText ? ["text-masked"] : []),
        ...(options.maskDynamic ? ["dynamic-masked"] : []),
      ].join("-"),
      cssRuleUsage: crater.cssRuleUsage,
    },
  });
  fs.writeFileSync(path.join(options.outputDir, "report.json"), JSON.stringify(report, null, 2));

  const pct = (diffRatio * 100).toFixed(2);
  const status = diffRatio <= 0.05 ? "PASS" : diffRatio <= options.maxDiffRatio ? "WARN" : "FAIL";
  console.log(`\n${status}: ${pct}% diff (${diffPixels}/${totalPixels} pixels)`);
  console.log(`  Output: ${options.outputDir}/`);
  return { diffPixels, diffRatio, outputDir: options.outputDir, status };
}

export async function runVrtUrlCli(args = process.argv.slice(2)): Promise<void> {
  try {
    await runVrtUrl(parseVrtUrlArgs(args));
  } catch (error) {
    if (error instanceof VrtUrlUsageError) {
      console.error(error.message);
      process.exitCode = 1;
      return;
    }
    throw error;
  }
}

const isCli = process.argv[1] !== undefined &&
  fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (isCli) {
  await runVrtUrlCli();
}
