/**
 * Fetch and prepare Accessibility tests from WPT (Web Platform Tests)
 *
 * This script fetches WPT accessibility tests (accname, html-aam, wai-aria)
 * and prepares them for testing with Crater's AOM module.
 *
 * Usage:
 *   npx tsx tools/fetch-wpt-a11y.ts accname
 *   npx tsx tools/fetch-wpt-a11y.ts html-aam
 *   npx tsx tools/fetch-wpt-a11y.ts --list
 *   npx tsx tools/fetch-wpt-a11y.ts --all
 */

import * as fs from "fs";
import * as path from "path";

const WPT_BASE =
  "https://raw.githubusercontent.com/web-platform-tests/wpt/master";
const WPT_API = "https://api.github.com/repos/web-platform-tests/wpt/contents";
const OUTPUT_DIR = "wpt-tests";

// Accessibility modules to fetch
const A11Y_MODULES = ["accname", "html-aam", "wai-aria"];

interface GitHubFile {
  name: string;
  path: string;
  type: "file" | "dir";
  download_url: string | null;
}

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

function listModules(): void {
  console.log("Available accessibility modules:");
  console.log("");
  for (const mod of A11Y_MODULES) {
    console.log(`  ${mod}`);
  }
  console.log("");
  console.log("Usage:");
  console.log("  npx tsx tools/fetch-wpt-a11y.ts <module-name>");
  console.log("  npx tsx tools/fetch-wpt-a11y.ts --all");
}

/**
 * Check if a file is a test HTML
 */
function isTestFile(filename: string): boolean {
  if (!filename.endsWith(".html")) return false;
  if (filename.endsWith("-ref.html")) return false;
  if (filename.includes("support")) return false;
  if (filename.startsWith("reference")) return false;
  return true;
}

/**
 * Remove WPT-specific script tags
 */
function removeTestScripts(html: string): string {
  const scriptPatterns = [
    /<script\s+src\s*=\s*["'][^"']*testharness[^"']*["'][^>]*><\/script>/gi,
    /<script\s+src\s*=\s*["'][^"']*testharnessreport[^"']*["'][^>]*><\/script>/gi,
    /<script\s+src\s*=\s*["'][^"']*AriaUtils[^"']*["'][^>]*><\/script>/gi,
    /<script\s+src\s*=\s*["']\/resources\/[^"']*["'][^>]*><\/script>/gi,
  ];

  let result = html;
  for (const pattern of scriptPatterns) {
    result = result.replace(pattern, "");
  }

  // Remove inline scripts
  result = result.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "");

  return result;
}

/**
 * Extract test cases from HTML
 * Tests use class containing "ex" (ex, ex-label, etc) with data-expectedlabel or data-expectedrole
 */
function extractTestCases(html: string): TestCase[] {
  const testCases: TestCase[] = [];

  // Match elements with data-expected* attributes (the main test pattern)
  // This handles all element types with test expectations
  const testRegex = /<([a-z][a-z0-9]*)[^>]*data-expected(?:label|role)[^>]*>/gi;

  let match;
  while ((match = testRegex.exec(html)) !== null) {
    const fullTag = match[0];

    // Extract data-expectedlabel
    const labelMatch = fullTag.match(/data-expectedlabel\s*=\s*["']([^"']*)["']/i);
    // Extract data-expectedrole
    const roleMatch = fullTag.match(/data-expectedrole\s*=\s*["']([^"']*)["']/i);
    // Extract id
    const idMatch = fullTag.match(/id\s*=\s*["']([^"']*)["']/i);
    // Extract test name
    const testNameMatch = fullTag.match(/data-testname\s*=\s*["']([^"']*)["']/i);
    // Extract class (for selector)
    const classMatch = fullTag.match(/class\s*=\s*["']([^"']*)["']/i);

    if (labelMatch || roleMatch) {
      testCases.push({
        id: idMatch ? idMatch[1] : undefined,
        testName: testNameMatch ? testNameMatch[1] : undefined,
        className: classMatch ? classMatch[1] : undefined,
        expectedLabel: labelMatch ? labelMatch[1] : undefined,
        expectedRole: roleMatch ? roleMatch[1] : undefined,
      });
    }
  }

  return testCases;
}

interface TestCase {
  id?: string;
  testName?: string;
  className?: string;
  expectedLabel?: string;
  expectedRole?: string;
}

interface TestFile {
  name: string;
  html: string;
  testCases: TestCase[];
}

/**
 * Fetch test files from a directory recursively
 */
async function fetchTestFilesFromDir(
  apiUrl: string,
  basePath: string
): Promise<GitHubFile[]> {
  const allFiles: GitHubFile[] = [];

  try {
    const items: GitHubFile[] = await fetchJson(apiUrl);

    for (const item of items) {
      if (item.type === "file" && isTestFile(item.name)) {
        allFiles.push(item);
      } else if (item.type === "dir" && !item.name.includes("support")) {
        // Recurse into subdirectories
        const subFiles = await fetchTestFilesFromDir(
          `${WPT_API}/${item.path}`,
          `${basePath}/${item.name}`
        );
        allFiles.push(...subFiles);
      }
    }
  } catch (error) {
    console.warn(`Warning: Could not fetch ${apiUrl}: ${error}`);
  }

  return allFiles;
}

/**
 * Fetch and process tests for a specific module
 */
async function fetchModule(
  moduleName: string,
  options: { limit?: number } = {}
): Promise<void> {
  const outDir = path.join(OUTPUT_DIR, moduleName);
  fs.mkdirSync(outDir, { recursive: true });

  console.log(`Fetching accessibility tests for ${moduleName}...`);

  // Get file list from GitHub API
  const apiUrl = `${WPT_API}/${moduleName}`;
  let files: GitHubFile[];

  try {
    files = await fetchTestFilesFromDir(apiUrl, moduleName);
  } catch (error) {
    console.error(`Failed to fetch file list: ${error}`);
    return;
  }

  const limit = options.limit || files.length;
  const filesToFetch = files.slice(0, limit);

  console.log(`Found ${files.length} test files, fetching ${filesToFetch.length}...`);

  let fetched = 0;
  let failed = 0;
  const testSummary: { file: string; testCount: number }[] = [];

  for (const file of filesToFetch) {
    // Create subdirectory if needed
    const relativePath = file.path.replace(`${moduleName}/`, "");
    const outPath = path.join(outDir, relativePath);
    const outDirPath = path.dirname(outPath);
    fs.mkdirSync(outDirPath, { recursive: true });

    try {
      let content = await fetchText(file.download_url!);

      // Extract test cases before removing scripts
      const testCases = extractTestCases(content);

      // Remove test scripts
      content = removeTestScripts(content);

      // Save HTML
      fs.writeFileSync(outPath, content);

      // Save test metadata as JSON
      if (testCases.length > 0) {
        const metaPath = outPath.replace(".html", ".json");
        fs.writeFileSync(
          metaPath,
          JSON.stringify({ testCases }, null, 2)
        );
        testSummary.push({ file: relativePath, testCount: testCases.length });
      }

      fetched++;
      process.stdout.write(`\r  Fetched: ${fetched}/${filesToFetch.length}`);
    } catch (error) {
      failed++;
      console.error(`\n  Failed to fetch ${file.name}: ${error}`);
    }
  }

  console.log("");
  console.log(`Done: ${fetched} fetched, ${failed} failed`);
  console.log(`Tests saved to: ${outDir}/`);

  // Print summary of test cases found
  const totalTests = testSummary.reduce((sum, t) => sum + t.testCount, 0);
  console.log(`\nTest cases extracted: ${totalTests} in ${testSummary.length} files`);

  // Save summary
  const summaryPath = path.join(outDir, "_summary.json");
  fs.writeFileSync(summaryPath, JSON.stringify(testSummary, null, 2));
}

/**
 * Fetch all accessibility modules
 */
async function fetchAll(options: { limit?: number } = {}): Promise<void> {
  console.log("Fetching all accessibility modules...\n");

  for (const moduleName of A11Y_MODULES) {
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

  if (!A11Y_MODULES.includes(moduleName)) {
    console.warn(`Warning: ${moduleName} is not in the list of accessibility modules`);
  }

  await fetchModule(moduleName, { limit });
}

main().catch(console.error);
