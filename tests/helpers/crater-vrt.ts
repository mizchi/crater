import fs from "node:fs/promises";
import path from "node:path";
import type { Browser, Page } from "@playwright/test";
import pixelmatchFn from "pixelmatch";
import { CraterBidiPage } from "./crater-bidi-page";

export interface DecodedImage {
  width: number;
  height: number;
  data: Uint8Array;
}

export interface VisualDiffOptions {
  outputDir: string;
  threshold: number;
  maxDiffRatio: number;
  includeAA?: boolean;
  alpha?: number;
  diffMask?: boolean;
  cropToContent?: boolean;
  contentPadding?: number;
  backgroundTolerance?: number;
  maskToVisibleContent?: boolean;
  maskPadding?: number;
}

export interface VisualDiffResult {
  width: number;
  height: number;
  diffPixels: number;
  totalPixels: number;
  diffRatio: number;
  roi?: { x: number; y: number; width: number; height: number };
  maskPixels?: number;
  threshold: number;
  maxDiffRatio: number;
  chromiumPath: string;
  craterPath: string;
  diffPath: string;
  reportPath: string;
}

const VRT_BIDI_CONNECT_OPTIONS = {
  timeout: 60_000,
  retries: 0,
} as const;

interface PixelmatchResult {
  diffCount: number;
  output: Uint8Array;
}

function runPixelmatch(
  img1: Uint8Array,
  img2: Uint8Array,
  width: number,
  height: number,
  options: { threshold: number; includeAA: boolean; alpha: number; diffMask: boolean },
): PixelmatchResult {
  const output = new Uint8Array(width * height * 4);
  const diffCount = pixelmatchFn(img1, img2, output, width, height, {
    threshold: options.threshold,
    includeAA: options.includeAA,
    alpha: options.alpha,
    diffMask: options.diffMask,
  });
  return { diffCount, output };
}

type RoiRect = {
  x: number;
  y: number;
  width: number;
  height: number;
};

type FloatRect = {
  x: number;
  y: number;
  width: number;
  height: number;
};


export async function chromiumPageForVrt(
  browser: Browser,
  viewport: { width: number; height: number },
): Promise<Page> {
  const page = await browser.newPage({
    viewport,
    deviceScaleFactor: 1,
    colorScheme: "light",
  });
  await page.emulateMedia({ colorScheme: "light", reducedMotion: "reduce" });
  return page;
}

export async function connectCraterPageForVrt(): Promise<CraterBidiPage> {
  const page = new CraterBidiPage();
  // Large visual fixtures can keep the BiDi server busy long enough that the
  // default 15s connect budget is too short for the next context creation.
  await page.connect(VRT_BIDI_CONNECT_OPTIONS);
  return page;
}

export async function decodePng(page: Page, png: Buffer): Promise<DecodedImage> {
  const decoded = await page.evaluate(async (base64Png) => {
    const bytes = Uint8Array.from(atob(base64Png), (char) => char.charCodeAt(0));
    const blob = new Blob([bytes], { type: "image/png" });
    const bitmap = await createImageBitmap(blob);
    const canvas = document.createElement("canvas");
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;
    const ctx = canvas.getContext("2d");
    if (!ctx) {
      throw new Error("2D context unavailable");
    }
    ctx.drawImage(bitmap, 0, 0);
    const imageData = ctx.getImageData(0, 0, bitmap.width, bitmap.height);
    return {
      width: bitmap.width,
      height: bitmap.height,
      data: Array.from(imageData.data),
    };
  }, png.toString("base64"));
  return {
    width: decoded.width,
    height: decoded.height,
    data: Uint8Array.from(decoded.data),
  };
}

export async function encodePng(
  page: Page,
  image: DecodedImage,
): Promise<Buffer> {
  const base64Png = await page.evaluate(async (payload) => {
    const canvas = document.createElement("canvas");
    canvas.width = payload.width;
    canvas.height = payload.height;
    const ctx = canvas.getContext("2d");
    if (!ctx) {
      throw new Error("2D context unavailable");
    }
    const imageData = new ImageData(
      Uint8ClampedArray.from(payload.data),
      payload.width,
      payload.height,
    );
    ctx.putImageData(imageData, 0, 0);
    return canvas.toDataURL("image/png").replace(/^data:image\/png;base64,/, "");
  }, {
    width: image.width,
    height: image.height,
    data: Array.from(image.data),
  });
  return Buffer.from(base64Png, "base64");
}

function pixelOffset(width: number, x: number, y: number): number {
  return (y * width + x) * 4;
}

function detectContentRoi(
  image: DecodedImage,
  options: { padding?: number; tolerance?: number } = {},
): RoiRect {
  const padding = options.padding ?? 8;
  const tolerance = options.tolerance ?? 12;
  const bgR = image.data[0] ?? 255;
  const bgG = image.data[1] ?? 255;
  const bgB = image.data[2] ?? 255;
  const bgA = image.data[3] ?? 255;

  let minX = image.width;
  let minY = image.height;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      const offset = pixelOffset(image.width, x, y);
      const r = image.data[offset] ?? 0;
      const g = image.data[offset + 1] ?? 0;
      const b = image.data[offset + 2] ?? 0;
      const a = image.data[offset + 3] ?? 0;
      const delta =
        Math.abs(r - bgR) +
        Math.abs(g - bgG) +
        Math.abs(b - bgB) +
        Math.abs(a - bgA);
      if (delta <= tolerance) {
        continue;
      }
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX < minX || maxY < minY) {
    return { x: 0, y: 0, width: image.width, height: image.height };
  }

  const x = Math.max(0, minX - padding);
  const y = Math.max(0, minY - padding);
  const right = Math.min(image.width, maxX + padding + 1);
  const bottom = Math.min(image.height, maxY + padding + 1);
  return {
    x,
    y,
    width: Math.max(1, right - x),
    height: Math.max(1, bottom - y),
  };
}

function cropImage(image: DecodedImage, roi: RoiRect): DecodedImage {
  const data = new Uint8Array(roi.width * roi.height * 4);
  for (let y = 0; y < roi.height; y += 1) {
    const srcStart = pixelOffset(image.width, roi.x, roi.y + y);
    const srcEnd = srcStart + roi.width * 4;
    data.set(image.data.slice(srcStart, srcEnd), y * roi.width * 4);
  }
  return {
    width: roi.width,
    height: roi.height,
    data,
  };
}

async function collectVisibleContentRects(page: Page): Promise<FloatRect[]> {
  return await page.evaluate(() => {
    const rects: Array<{ x: number; y: number; width: number; height: number }> = [];
    const pushRect = (rect: DOMRect | DOMRectReadOnly) => {
      if (rect.width <= 0 || rect.height <= 0) {
        return;
      }
      rects.push({
        x: rect.x,
        y: rect.y,
        width: rect.width,
        height: rect.height,
      });
    };

    const elementWalker = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT);
    let currentElement = elementWalker.currentNode as Element | null;
    while (currentElement) {
      const style = window.getComputedStyle(currentElement);
      if (
        style.display !== "none" &&
        style.visibility !== "hidden" &&
        style.opacity !== "0"
      ) {
        const rect = currentElement.getBoundingClientRect();
        const tag = currentElement.tagName.toLowerCase();
        const text = currentElement.textContent?.trim() ?? "";
        const isInteresting =
          tag === "input" ||
          tag === "textarea" ||
          tag === "select" ||
          tag === "button" ||
          tag === "img" ||
          tag === "svg" ||
          tag === "canvas" ||
          tag === "video" ||
          tag === "summary" ||
          tag === "a" ||
          text.length > 0;
        if (isInteresting) {
          pushRect(rect);
        }
      }
      currentElement = elementWalker.nextNode() as Element | null;
    }

    const textWalker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    let currentText = textWalker.currentNode as Text | null;
    while (currentText) {
      if ((currentText.textContent ?? "").trim().length > 0) {
        const range = document.createRange();
        range.selectNodeContents(currentText);
        for (const rect of Array.from(range.getClientRects())) {
          pushRect(rect);
        }
        range.detach?.();
      }
      currentText = textWalker.nextNode() as Text | null;
    }

    return rects;
  });
}

function buildMask(width: number, height: number, rects: FloatRect[], padding = 2): Uint8Array {
  const mask = new Uint8Array(width * height);
  for (const rect of rects) {
    const startX = Math.max(0, Math.floor(rect.x) - padding);
    const startY = Math.max(0, Math.floor(rect.y) - padding);
    const endX = Math.min(width, Math.ceil(rect.x + rect.width) + padding);
    const endY = Math.min(height, Math.ceil(rect.y + rect.height) + padding);
    for (let y = startY; y < endY; y += 1) {
      const rowOffset = y * width;
      for (let x = startX; x < endX; x += 1) {
        mask[rowOffset + x] = 1;
      }
    }
  }
  return mask;
}

function cropMask(mask: Uint8Array, width: number, roi: RoiRect): Uint8Array {
  const data = new Uint8Array(roi.width * roi.height);
  for (let y = 0; y < roi.height; y += 1) {
    const srcStart = (roi.y + y) * width + roi.x;
    const srcEnd = srcStart + roi.width;
    data.set(mask.slice(srcStart, srcEnd), y * roi.width);
  }
  return data;
}

function maskPixelCount(mask: Uint8Array): number {
  let count = 0;
  for (const value of mask) {
    if (value !== 0) {
      count += 1;
    }
  }
  return count;
}

function applyMask(reference: DecodedImage, target: DecodedImage, mask: Uint8Array): DecodedImage {
  const masked = Uint8Array.from(target.data);
  for (let index = 0; index < mask.length; index += 1) {
    if (mask[index] !== 0) {
      continue;
    }
    const offset = index * 4;
    masked[offset] = reference.data[offset] ?? 0;
    masked[offset + 1] = reference.data[offset + 1] ?? 0;
    masked[offset + 2] = reference.data[offset + 2] ?? 0;
    masked[offset + 3] = reference.data[offset + 3] ?? 0;
  }
  return {
    width: target.width,
    height: target.height,
    data: masked,
  };
}

export async function comparePngs(
  page: Page,
  chromiumPng: Buffer,
  craterPng: Buffer,
  options: VisualDiffOptions,
): Promise<VisualDiffResult> {
  const chromiumImage = await decodePng(page, chromiumPng);
  const craterImage = await decodePng(page, craterPng);

  if (
    chromiumImage.width !== craterImage.width ||
    chromiumImage.height !== craterImage.height
  ) {
    throw new Error(
      `Image size mismatch: chromium=${chromiumImage.width}x${chromiumImage.height} crater=${craterImage.width}x${craterImage.height}`,
    );
  }

  const result = runPixelmatch(
    chromiumImage.data,
    craterImage.data,
    chromiumImage.width,
    chromiumImage.height,
    {
      threshold: options.threshold,
      includeAA: options.includeAA ?? false,
      alpha: options.alpha ?? 0.1,
      diffMask: options.diffMask ?? false,
    },
  );

  const diffPixels = result.diffCount;
  const totalPixels = chromiumImage.width * chromiumImage.height;
  const diffRatio = diffPixels / Math.max(totalPixels, 1);
  const diffImage: DecodedImage = {
    width: chromiumImage.width,
    height: chromiumImage.height,
    data: result.output,
  };

  await fs.mkdir(options.outputDir, { recursive: true });
  const chromiumPath = path.join(options.outputDir, "chromium.png");
  const craterPath = path.join(options.outputDir, "crater.png");
  const diffPath = path.join(options.outputDir, "diff.png");
  const reportPath = path.join(options.outputDir, "report.json");
  await fs.writeFile(chromiumPath, chromiumPng);
  await fs.writeFile(craterPath, craterPng);
  await fs.writeFile(diffPath, await encodePng(page, diffImage));
  await fs.writeFile(
    reportPath,
    JSON.stringify(
      {
        width: chromiumImage.width,
        height: chromiumImage.height,
        diffPixels,
        totalPixels,
        diffRatio,
        threshold: options.threshold,
        maxDiffRatio: options.maxDiffRatio,
      },
      null,
      2,
    ),
  );

  return {
    width: chromiumImage.width,
    height: chromiumImage.height,
    diffPixels,
    totalPixels,
    diffRatio,
    threshold: options.threshold,
    maxDiffRatio: options.maxDiffRatio,
    chromiumPath,
    craterPath,
    diffPath,
    reportPath,
  };
}

export async function compareChromiumPngToImage(
  page: Page,
  chromiumPng: Buffer,
  craterImage: DecodedImage,
  options: VisualDiffOptions,
): Promise<VisualDiffResult> {
  const chromiumImage = await decodePng(page, chromiumPng);

  if (
    chromiumImage.width !== craterImage.width ||
    chromiumImage.height !== craterImage.height
  ) {
    throw new Error(
      `Image size mismatch: chromium=${chromiumImage.width}x${chromiumImage.height} crater=${craterImage.width}x${craterImage.height}`,
    );
  }

  const roi = options.cropToContent
    ? detectContentRoi(chromiumImage, {
        padding: options.contentPadding,
        tolerance: options.backgroundTolerance,
      })
    : undefined;
  const chromiumCompareImage = roi ? cropImage(chromiumImage, roi) : chromiumImage;
  const craterCompareImage = roi ? cropImage(craterImage, roi) : craterImage;
  const mask = options.maskToVisibleContent
    ? buildMask(
        chromiumImage.width,
        chromiumImage.height,
        await collectVisibleContentRects(page),
        options.maskPadding ?? 2,
      )
    : undefined;
  const compareMask = mask
    ? (roi ? cropMask(mask, chromiumImage.width, roi) : mask)
    : undefined;
  const maskedCraterImage = compareMask
    ? applyMask(chromiumCompareImage, craterCompareImage, compareMask)
    : craterCompareImage;

  const result = runPixelmatch(
    chromiumCompareImage.data,
    maskedCraterImage.data,
    chromiumCompareImage.width,
    chromiumCompareImage.height,
    {
      threshold: options.threshold,
      includeAA: options.includeAA ?? false,
      alpha: options.alpha ?? 0.1,
      diffMask: options.diffMask ?? false,
    },
  );

  const diffPixels = result.diffCount;
  const totalPixels = compareMask
    ? Math.max(maskPixelCount(compareMask), 1)
    : chromiumCompareImage.width * chromiumCompareImage.height;
  const diffRatio = diffPixels / Math.max(totalPixels, 1);
  const diffImage: DecodedImage = {
    width: chromiumCompareImage.width,
    height: chromiumCompareImage.height,
    data: result.output,
  };

  await fs.mkdir(options.outputDir, { recursive: true });
  const chromiumPath = path.join(options.outputDir, "chromium.png");
  const craterPath = path.join(options.outputDir, "crater.png");
  const diffPath = path.join(options.outputDir, "diff.png");
  const reportPath = path.join(options.outputDir, "report.json");
  await fs.writeFile(chromiumPath, chromiumPng);
  await fs.writeFile(craterPath, await encodePng(page, craterImage));
  await fs.writeFile(diffPath, await encodePng(page, diffImage));
  await fs.writeFile(
    reportPath,
    JSON.stringify(
      {
        width: chromiumImage.width,
        height: chromiumImage.height,
        diffPixels,
        totalPixels,
        diffRatio,
        roi,
        maskPixels: compareMask ? maskPixelCount(compareMask) : undefined,
        threshold: options.threshold,
        maxDiffRatio: options.maxDiffRatio,
      },
      null,
      2,
    ),
  );

  return {
    width: chromiumImage.width,
    height: chromiumImage.height,
    diffPixels,
    totalPixels,
    diffRatio,
    roi,
    maskPixels: compareMask ? maskPixelCount(compareMask) : undefined,
    threshold: options.threshold,
    maxDiffRatio: options.maxDiffRatio,
    chromiumPath,
    craterPath,
    diffPath,
    reportPath,
  };
}

export async function renderCraterHtml(
  page: CraterBidiPage,
  html: string,
  viewport: { width: number; height: number },
): Promise<DecodedImage> {
  if (process.env.CRATER_PAINT_BACKEND === "native") {
    return renderCraterHtmlNative(html, viewport);
  }
  await page.setViewport(viewport.width, viewport.height);
  await page.setContentWithScripts(html);
  return page.capturePaintData();
}

function getCraterPaintBinCandidates(): string[] {
  const home = process.env.HOME ?? "";
  return [
    process.env.CRATER_PAINT_BIN ?? "",
    `${home}/ghq/github.com/mizchi/kagura/examples/crater_paint/_build/native/debug/build/crater_paint.exe`,
    `${home}/ghq/github.com/mizchi/kagura/examples/crater_paint/_build/native/release/build/crater_paint.exe`,
  ].filter(Boolean);
}

async function renderCraterHtmlNative(
  html: string,
  viewport: { width: number; height: number },
): Promise<DecodedImage> {
  const { writeFileSync, readFileSync } = await import("node:fs");
  const { execFileSync } = await import("node:child_process");

  // Write input files
  writeFileSync("/tmp/crater_paint_input.html", html);
  writeFileSync("/tmp/crater_paint_config.txt", `${viewport.width} ${viewport.height}`);

  // Find binary
  let bin: string | null = null;
  for (const candidate of getCraterPaintBinCandidates()) {
    try {
      const { accessSync } = await import("node:fs");
      accessSync(candidate);
      bin = candidate;
      break;
    } catch {
      continue;
    }
  }
  if (!bin) {
    throw new Error("crater_paint binary not found. Build it with: cd ~/ghq/github.com/mizchi/kagura/examples/crater_paint && moon build --target native");
  }

  // Run renderer
  const cwd = `${process.env.HOME}/ghq/github.com/mizchi/kagura/examples/crater_paint`;
  const result = execFileSync(bin, [], {
    cwd,
    timeout: 30_000,
    maxBuffer: 10 * 1024 * 1024,
  });
  const stdout = result.toString();
  if (!stdout.includes("OK")) {
    throw new Error(`crater_paint failed: ${stdout}`);
  }

  // Read BMP output
  const bmpData = readFileSync("/tmp/crater_paint_output.bmp");
  return decodeBmp(bmpData, viewport.width, viewport.height);
}

function decodeBmp(data: Buffer, expectedWidth: number, expectedHeight: number): DecodedImage {
  // BMP header: 14 bytes file header + DIB header
  // Pixel data offset at bytes 10-13 (little-endian uint32)
  const pixelOffset = data.readUInt32LE(10);
  const width = data.readInt32LE(18);
  const height = Math.abs(data.readInt32LE(22));
  const bitsPerPixel = data.readUInt16LE(28);
  const topDown = data.readInt32LE(22) < 0;

  if (width !== expectedWidth || height !== expectedHeight) {
    throw new Error(`BMP size mismatch: ${width}x${height} vs expected ${expectedWidth}x${expectedHeight}`);
  }

  const bytesPerPixel = bitsPerPixel / 8;
  const rowStride = Math.ceil((width * bytesPerPixel) / 4) * 4; // BMP rows are 4-byte aligned
  const rgba = new Uint8Array(width * height * 4);

  for (let y = 0; y < height; y++) {
    const srcRow = topDown ? y : (height - 1 - y);
    const srcOffset = pixelOffset + srcRow * rowStride;
    for (let x = 0; x < width; x++) {
      const srcIdx = srcOffset + x * bytesPerPixel;
      const dstIdx = (y * width + x) * 4;
      if (bytesPerPixel >= 3) {
        // BMP is BGR(A)
        rgba[dstIdx] = data[srcIdx + 2];     // R
        rgba[dstIdx + 1] = data[srcIdx + 1]; // G
        rgba[dstIdx + 2] = data[srcIdx];     // B
        rgba[dstIdx + 3] = bytesPerPixel >= 4 ? data[srcIdx + 3] : 255; // A
      }
    }
  }

  return { width, height, data: rgba };
}
