/**
 * Fetch and prepare CSS tests from WPT (Web Platform Tests)
 *
 * This script fetches WPT tests and inlines external CSS files,
 * making them self-contained for testing with Crater.
 *
 * Usage:
 *   npx tsx tools/fetch-wpt.ts css-flexbox
 *   npx tsx tools/fetch-wpt.ts css-flexbox --limit 50
 *   npx tsx tools/fetch-wpt.ts --list
 *   npx tsx tools/fetch-wpt.ts --all
 */

import * as fs from "fs";
import * as path from "path";

const WPT_BASE =
  "https://raw.githubusercontent.com/web-platform-tests/wpt/master";
const WPT_API = "https://api.github.com/repos/web-platform-tests/wpt/contents";
const OUTPUT_DIR = "wpt-tests";

// CSS modules to fetch (subset relevant to layout)
const CSS_MODULES = [
  "css-flexbox",
  "css-grid",
  "css-display",
  "css-box",
  "css-sizing",
  "css-align",
  "css-position",
  "css-overflow",
  "css-contain",
];

// Test file prefixes to include (layout-relevant tests)
const INCLUDE_PREFIXES = [
  // Flexbox
  "align-content",
  "align-items",
  "align-self",
  "flex-",
  "justify-",
  "order-",
  "gap-",
  // Grid
  "grid-",
  "subgrid-",
  "grid-template",
  "grid-auto",
  "grid-area",
  "grid-row",
  "grid-column",
  "grid-gap",
  "grid-placement",
  // Sizing
  "aspect-ratio",
  "block-size",
  "inline-size",
  "min-content",
  "max-content",
  "fit-content",
  "intrinsic",
  "contain-intrinsic",
  // Box model
  "margin-",
  "padding-",
  "border-",
  "box-sizing",
  // Display
  "display-",
  "visibility-",
  // Position
  "position-",
  "relative-",
  "sticky-",
  "fixed-",
  // Overflow
  "clip-",
  "overflow-",
  // Containment
  "contain-",
];

interface GitHubFile {
  name: string;
  path: string;
  type: "file" | "dir";
  download_url: string | null;
}

// Cache for fetched CSS files
const cssCache: Map<string, string> = new Map();

async function fetchJson(url: string): Promise<any> {
  const res = await fetch(url, {
    headers: {
      "User-Agent": "crater-wpt-fetcher",
      Accept: "application/vnd.github.v3+json",
    },
  });
  if (!res.ok) {
    throw new Error(`Failed to fetch ${url}: ${res.status}`);
  }
  return res.json();
}

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Failed to fetch ${url}: ${res.status}`);
  }
  return res.text();
}

/**
 * List available CSS modules
 */
function listModules(): void {
  console.log("Available CSS modules for layout testing:");
  console.log("");
  for (const mod of CSS_MODULES) {
    console.log(`  ${mod}`);
  }
  console.log("");
  console.log("Usage:");
  console.log("  npx tsx tools/fetch-wpt.ts <module-name>");
  console.log("  npx tsx tools/fetch-wpt.ts --all");
}

/**
 * Check if a file is a layout test HTML
 */
function isLayoutTest(filename: string): boolean {
  if (!filename.endsWith(".html")) return false;
  if (filename.endsWith("-ref.html")) return false;
  if (filename.includes("support")) return false;
  if (filename.startsWith("reference")) return false;

  // Only include tests with relevant prefixes
  return INCLUDE_PREFIXES.some((prefix) => filename.startsWith(prefix));
}

/**
 * Inline external CSS from <link> tags into <style> tags
 */
async function inlineExternalCSS(
  html: string,
  moduleName: string
): Promise<string> {
  // Match <link rel="stylesheet" href="...">
  const linkRegex =
    /<link\s+[^>]*rel\s*=\s*["']stylesheet["'][^>]*href\s*=\s*["']([^"']+)["'][^>]*>/gi;
  const linkRegex2 =
    /<link\s+[^>]*href\s*=\s*["']([^"']+)["'][^>]*rel\s*=\s*["']stylesheet["'][^>]*>/gi;

  let result = html;

  // Process both orderings of rel and href
  for (const regex of [linkRegex, linkRegex2]) {
    const matches = [...result.matchAll(regex)];
    for (const match of matches) {
      const fullMatch = match[0];
      const href = match[1];

      // Skip external URLs
      if (
        href.startsWith("http://") ||
        href.startsWith("https://") ||
        href.startsWith("//")
      ) {
        continue;
      }

      // Skip already processed
      if (!result.includes(fullMatch)) continue;

      try {
        let cssContent: string;

        // Check cache first
        const cacheKey = `${moduleName}/${href}`;
        if (cssCache.has(cacheKey)) {
          cssContent = cssCache.get(cacheKey)!;
        } else {
          // Fetch from WPT
          const cssUrl = `${WPT_BASE}/css/${moduleName}/${href}`;
          cssContent = await fetchText(cssUrl);
          cssCache.set(cacheKey, cssContent);
        }

        // Replace link with inline style
        result = result.replace(
          fullMatch,
          `<style>/* Inlined from ${href} */\n${cssContent}</style>`
        );
      } catch (error) {
        // If CSS can't be fetched, add a comment
        console.warn(`  Warning: Could not inline ${href}`);
        result = result.replace(fullMatch, `<!-- CSS not found: ${href} -->`);
      }
    }
  }

  return result;
}

/**
 * Extract image references from HTML
 */
function extractImageRefs(html: string): string[] {
  const imgRegex = /<img[^>]+src\s*=\s*["']([^"']+)["'][^>]*>/gi;
  const refs: string[] = [];
  let match;
  while ((match = imgRegex.exec(html)) !== null) {
    const src = match[1];
    // Only include relative paths (not data URIs or external URLs)
    if (!src.startsWith('data:') && !src.startsWith('http://') &&
        !src.startsWith('https://') && !src.startsWith('//')) {
      refs.push(src);
    }
  }
  return [...new Set(refs)]; // Remove duplicates
}

/**
 * Download support files (images) for a module
 */
async function fetchSupportFiles(
  moduleName: string,
  imageRefs: string[]
): Promise<void> {
  if (imageRefs.length === 0) return;

  const supportDir = path.join(OUTPUT_DIR, moduleName, 'support');
  fs.mkdirSync(supportDir, { recursive: true });

  const uniqueFiles = [...new Set(imageRefs.map(ref => {
    // Extract filename from path like "support/100x100-green.png"
    return ref.split('/').pop()!;
  }))];

  console.log(`  Downloading ${uniqueFiles.length} support files...`);

  for (const filename of uniqueFiles) {
    const outPath = path.join(supportDir, filename);
    if (fs.existsSync(outPath)) continue; // Skip if already downloaded

    try {
      const url = `${WPT_BASE}/css/${moduleName}/support/${filename}`;
      const res = await fetch(url);
      if (res.ok) {
        const buffer = await res.arrayBuffer();
        fs.writeFileSync(outPath, Buffer.from(buffer));
      }
    } catch (error) {
      // Silently skip failed downloads
    }
  }
}

/**
 * Remove WPT-specific script tags
 */
function removeTestScripts(html: string): string {
  // Remove testharness scripts
  const scriptPatterns = [
    /<script\s+src\s*=\s*["'][^"']*testharness[^"']*["'][^>]*><\/script>/gi,
    /<script\s+src\s*=\s*["'][^"']*testharnessreport[^"']*["'][^>]*><\/script>/gi,
    /<script\s+src\s*=\s*["'][^"']*check-layout[^"']*["'][^>]*><\/script>/gi,
    /<script\s+src\s*=\s*["']\/resources\/[^"']*["'][^>]*><\/script>/gi,
  ];

  let result = html;
  for (const pattern of scriptPatterns) {
    result = result.replace(pattern, "");
  }

  // Remove onload handlers that call test functions
  // Handle nested quotes: onload="checkLayout('.foo')" or onload='checkLayout(".foo")'
  result = result.replace(/\s+onload\s*=\s*"[^"]*"/gi, "");
  result = result.replace(/\s+onload\s*=\s*'[^']*'/gi, "");

  return result;
}

/**
 * Fetch and process tests for a specific CSS module
 */
async function fetchModule(
  moduleName: string,
  options: { limit?: number } = {}
): Promise<void> {
  const outDir = path.join(OUTPUT_DIR, moduleName);
  fs.mkdirSync(outDir, { recursive: true });

  console.log(`Fetching tests for ${moduleName}...`);

  // Get file list from GitHub API
  const apiUrl = `${WPT_API}/css/${moduleName}`;
  let files: GitHubFile[];

  try {
    files = await fetchJson(apiUrl);
  } catch (error) {
    console.error(`Failed to fetch file list: ${error}`);
    return;
  }

  // Filter HTML test files
  const testFiles = files.filter(
    (f) => f.type === "file" && isLayoutTest(f.name)
  );
  const limit = options.limit || testFiles.length;
  const filesToFetch = testFiles.slice(0, limit);

  console.log(
    `Found ${testFiles.length} layout tests, fetching ${filesToFetch.length}...`
  );

  let fetched = 0;
  let failed = 0;
  const allImageRefs: string[] = [];

  for (const file of filesToFetch) {
    const outPath = path.join(outDir, file.name);

    try {
      let content = await fetchText(file.download_url!);

      // Process content: inline CSS, remove test scripts
      content = await inlineExternalCSS(content, moduleName);
      content = removeTestScripts(content);

      // Collect image references before saving
      const imageRefs = extractImageRefs(content);
      allImageRefs.push(...imageRefs);

      fs.writeFileSync(outPath, content);
      fetched++;
      process.stdout.write(`\r  Fetched: ${fetched}/${filesToFetch.length}`);
    } catch (error) {
      failed++;
      console.error(`\n  Failed to fetch ${file.name}: ${error}`);
    }
  }

  console.log("");

  // Download support files (images)
  await fetchSupportFiles(moduleName, allImageRefs);

  console.log(`Done: ${fetched} fetched, ${failed} failed`);
  console.log(`Tests saved to: ${outDir}/`);
}

/**
 * Fetch all recommended modules
 */
async function fetchAll(options: { limit?: number } = {}): Promise<void> {
  console.log("Fetching all recommended CSS modules...\n");

  for (const moduleName of CSS_MODULES) {
    await fetchModule(moduleName, options);
    console.log("");
  }
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === "--help") {
    listModules();
    return;
  }

  if (args[0] === "--list") {
    listModules();
    return;
  }

  let limit: number | undefined;
  const limitIdx = args.indexOf("--limit");
  if (limitIdx !== -1 && args[limitIdx + 1]) {
    limit = parseInt(args[limitIdx + 1], 10);
  }

  if (args[0] === "--all") {
    await fetchAll({ limit });
    return;
  }

  const moduleName = args[0];

  if (!CSS_MODULES.includes(moduleName)) {
    console.warn(`Warning: ${moduleName} is not in the recommended list`);
  }

  await fetchModule(moduleName, { limit });
}

main().catch(console.error);
