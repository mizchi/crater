import { writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { chromium } from "../webdriver/playwright/adapter.ts";

export type CraterPlaywrightSmokeOptions = {
  url?: string;
  width: number;
  height: number;
  output?: string;
  autoStartBidi: boolean;
  timeoutMs: number;
  serverTimeoutMs: number;
};

const DEFAULT_OPTIONS: CraterPlaywrightSmokeOptions = {
  autoStartBidi: true,
  height: 600,
  output: undefined,
  serverTimeoutMs: 20_000,
  timeoutMs: 5_000,
  url: undefined,
  width: 800,
};

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

export function parseCraterPlaywrightSmokeArgs(
  args: string[],
): CraterPlaywrightSmokeOptions {
  const options = { ...DEFAULT_OPTIONS };
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    switch (arg) {
      case "--url":
        options.url = readFlagValue(args, index, arg);
        index += 1;
        break;
      case "--width":
        options.width = readPositiveInteger(readFlagValue(args, index, arg), arg);
        index += 1;
        break;
      case "--height":
        options.height = readPositiveInteger(readFlagValue(args, index, arg), arg);
        index += 1;
        break;
      case "--output":
        options.output = readFlagValue(args, index, arg);
        index += 1;
        break;
      case "--timeout-ms":
        options.timeoutMs = readPositiveInteger(readFlagValue(args, index, arg), arg);
        index += 1;
        break;
      case "--server-timeout-ms":
        options.serverTimeoutMs = readPositiveInteger(readFlagValue(args, index, arg), arg);
        index += 1;
        break;
      case "--connect-only":
        options.autoStartBidi = false;
        break;
      case "--":
        break;
      case "--help":
        printUsage();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return options;
}

export async function runCraterPlaywrightSmoke(
  options: CraterPlaywrightSmokeOptions,
): Promise<{ url: string; screenshotBytes: number; output?: string }> {
  const browser = await chromium.launch({
    autoStartBidi: options.autoStartBidi,
    serverTimeoutMs: options.serverTimeoutMs,
    timeout: options.timeoutMs,
  });
  try {
    const context = await browser.newContext({
      viewport: { width: options.width, height: options.height },
      timeout: options.timeoutMs,
    });
    const page = await context.newPage();
    if (options.url) {
      await page.goto(options.url, { waitUntil: "commit", timeout: options.timeoutMs });
    } else {
      await page.setContentWithScripts(`
        <html>
          <head>
            <title>Crater Playwright Smoke</title>
            <style>
              body { margin: 0; font: 16px sans-serif; }
              main { min-height: 900px; padding: 24px; }
              .ready { width: 160px; height: 80px; background: #1f7a5c; color: white; }
            </style>
          </head>
          <body>
            <main>
              <div class="ready" data-ready="true">Crater smoke ready</div>
            </main>
          </body>
        </html>
      `);
      await page.waitForFunction(
        () => document.querySelector("[data-ready='true']") !== null,
        undefined,
        { timeout: options.timeoutMs },
      );
    }

    const screenshot = await page.screenshot({
      fullPage: true,
      timeout: options.timeoutMs,
    });
    if (options.output) {
      await writeFile(options.output, screenshot);
    }
    return {
      url: page.url(),
      screenshotBytes: screenshot.byteLength,
      output: options.output,
    };
  } finally {
    await browser.close();
  }
}

function printUsage(): void {
  console.log(`Usage: pnpm exec tsx scripts/crater-playwright-smoke.ts [options]

Options:
  --url <url>                Open a URL instead of the built-in static fixture.
  --width <px>               Viewport width. Default: 800.
  --height <px>              Viewport height. Default: 600.
  --output <path>            Write the full-page PNG screenshot.
  --connect-only             Do not auto-start the Crater BiDi server.
  --timeout-ms <ms>          Page operation timeout. Default: 5000.
  --server-timeout-ms <ms>   BiDi server startup timeout. Default: 20000.
`);
}

async function main(): Promise<void> {
  const result = await runCraterPlaywrightSmoke(
    parseCraterPlaywrightSmokeArgs(process.argv.slice(2)),
  );
  console.log(JSON.stringify(result, null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.stack || error.message : error);
    process.exit(1);
  });
}
