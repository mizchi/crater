#!/usr/bin/env npx tsx

import fs from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright";
import { inlineHtmlSnapshot } from "./real-world-snapshot.ts";

interface CliOptions {
  url: string;
  name: string;
  width: number;
  height: number;
  waitMs: number;
  realWorldDir: string;
}

function usage(): string {
  return [
    "Capture real-world site snapshot",
    "",
    "Usage:",
    "  npx tsx scripts/capture-real-world-snapshot.ts <url> [--name slug] [--width 1440] [--height 960] [--wait-ms 1000]",
  ].join("\n");
}

function slugifyUrl(url: string): string {
  const normalized = new URL(url);
  const raw = `${normalized.hostname}${normalized.pathname}`.replace(/\/+$/, "") || normalized.hostname;
  return raw
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase();
}

function parseArgs(argv: string[]): CliOptions {
  if (argv.length === 0 || argv.includes("--help") || argv.includes("-h")) {
    console.log(usage());
    process.exit(0);
  }

  const positional: string[] = [];
  const options: Partial<CliOptions> = {
    width: 1440,
    height: 960,
    waitMs: 1000,
    realWorldDir: path.join(process.cwd(), "real-world"),
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      positional.push(arg);
      continue;
    }
    if (arg === "--name") {
      options.name = argv[++i];
      continue;
    }
    if (arg === "--width") {
      options.width = Number(argv[++i]);
      continue;
    }
    if (arg === "--height") {
      options.height = Number(argv[++i]);
      continue;
    }
    if (arg === "--wait-ms") {
      options.waitMs = Number(argv[++i]);
      continue;
    }
    if (arg === "--real-world-dir") {
      options.realWorldDir = argv[++i];
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  const url = positional[0];
  if (!url) throw new Error("URL is required");
  return {
    url,
    name: options.name ?? slugifyUrl(url),
    width: options.width ?? 1440,
    height: options.height ?? 960,
    waitMs: options.waitMs ?? 1000,
    realWorldDir: options.realWorldDir ?? path.join(process.cwd(), "real-world"),
  };
}

async function fetchStylesheets(stylesheetUrls: string[]): Promise<string[]> {
  const cssTexts: string[] = [];
  for (const href of stylesheetUrls) {
    const response = await fetch(href, {
      headers: {
        "user-agent": "crater-snapshot/0.1",
      },
    });
    if (!response.ok) {
      console.warn(`skip stylesheet ${href}: ${response.status}`);
      continue;
    }
    cssTexts.push(await response.text());
  }
  return cssTexts;
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const browser = await chromium.launch({ headless: true });

  try {
    const page = await browser.newPage({
      viewport: { width: options.width, height: options.height },
      deviceScaleFactor: 1,
    });

    await page.goto(options.url, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForLoadState("networkidle", { timeout: 5000 }).catch(() => {});
    await page.waitForTimeout(options.waitMs);

    const [title, html, stylesheetUrls] = await Promise.all([
      page.title(),
      page.content(),
      page.$$eval("link[rel~='stylesheet'][href]", (links) =>
        links.map((link) => (link as HTMLLinkElement).href).filter(Boolean),
      ),
    ]);

    const styles = await fetchStylesheets([...new Set(stylesheetUrls)]);
    const snapshotHtml = inlineHtmlSnapshot({
      html,
      styles,
      baseHref: options.url,
    });

    const dir = path.join(options.realWorldDir, options.name);
    await fs.mkdir(dir, { recursive: true });
    await Promise.all([
      fs.writeFile(path.join(dir, "index.html"), snapshotHtml, "utf8"),
      fs.writeFile(
        path.join(dir, "meta.json"),
        JSON.stringify(
          {
            title,
            sourceUrl: options.url,
            viewport: { width: options.width, height: options.height },
            stylesheetUrls,
            capturedAt: new Date().toISOString(),
          },
          null,
          2,
        ),
        "utf8",
      ),
      page.screenshot({ path: path.join(dir, "source.png"), fullPage: false }),
    ]);

    console.log(JSON.stringify({
      name: options.name,
      title,
      url: options.url,
      viewport: { width: options.width, height: options.height },
      stylesheets: styles.length,
      outputDir: dir,
    }, null, 2));
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack || error.message : error);
  process.exit(1);
});
