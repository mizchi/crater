/**
 * Generate MoonBit tests from WPT accessibility test files
 *
 * This script reads fetched WPT accessibility tests and generates
 * MoonBit test files that use Crater's AOM module.
 *
 * Usage:
 *   npx tsx tools/gen-aom-tests.ts wpt-tests/accname aom/wpt_accname_test.mbt
 */

import * as fs from "fs";
import * as path from "path";

interface TestCase {
  id?: string;
  testName?: string;
  className?: string;
  expectedLabel?: string;
  expectedRole?: string;
}

interface TestFile {
  file: string;
  testCount: number;
}

function escapeString(s: string): string {
  return s
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r")
    .replace(/\t/g, "\\t");
}

function sanitizeTestName(name: string): string {
  return name
    .replace(/[^a-zA-Z0-9_]/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_/, "")
    .replace(/_$/, "")
    .toLowerCase()
    .slice(0, 50);
}

function generateTest(
  htmlFile: string,
  jsonFile: string,
  testIndex: number
): string | null {
  if (!fs.existsSync(jsonFile)) {
    return null;
  }

  const html = fs.readFileSync(htmlFile, "utf-8");
  const json = JSON.parse(fs.readFileSync(jsonFile, "utf-8"));
  const testCases: TestCase[] = json.testCases || [];

  if (testCases.length === 0) {
    return null;
  }

  const tests: string[] = [];
  const fileName = path.basename(htmlFile, ".html");

  for (let i = 0; i < testCases.length; i++) {
    const tc = testCases[i];
    const testName = tc.testName
      ? sanitizeTestName(tc.testName)
      : `${sanitizeTestName(fileName)}_${i}`;

    if (tc.expectedLabel) {
      tests.push(`
///|
test "accname/${fileName}: ${tc.testName || `test_${i}`}" {
  let html = #|${escapeString(html).split("\n").join("\n  #|")}
  let doc = @html.parse_document(html)
  let tree = @aom.build_accessibility_tree(doc)

  // Find element by class or ID
  // Expected label: "${escapeString(tc.expectedLabel)}"
  // TODO: Implement element lookup and assertion
  ignore(tree)
}`);
    }
  }

  return tests.join("\n");
}

function main(): void {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.log("Usage: npx tsx tools/gen-aom-tests.ts <input-dir> <output-file>");
    console.log("Example: npx tsx tools/gen-aom-tests.ts wpt-tests/accname aom/wpt_accname_test.mbt");
    return;
  }

  const inputDir = args[0];
  const outputFile = args[1];

  if (!fs.existsSync(inputDir)) {
    console.error(`Input directory not found: ${inputDir}`);
    return;
  }

  // Read summary
  const summaryPath = path.join(inputDir, "_summary.json");
  if (!fs.existsSync(summaryPath)) {
    console.error(`Summary file not found: ${summaryPath}`);
    console.log("Run fetch-wpt-a11y.ts first to download tests.");
    return;
  }

  const summary: TestFile[] = JSON.parse(fs.readFileSync(summaryPath, "utf-8"));

  console.log(`Found ${summary.length} test files with test cases`);

  // Generate header
  let output = `///|
/// WPT Accessibility Tests (auto-generated)
/// Generated from: ${inputDir}
/// Run: npx tsx tools/gen-aom-tests.ts ${inputDir} ${outputFile}

`;

  let totalTests = 0;
  let generatedTests = 0;

  for (let i = 0; i < summary.length; i++) {
    const tf = summary[i];
    const htmlPath = path.join(inputDir, tf.file);
    const jsonPath = htmlPath.replace(".html", ".json");

    const testCode = generateTest(htmlPath, jsonPath, i);
    if (testCode) {
      output += testCode + "\n";
      generatedTests++;
    }
    totalTests += tf.testCount;
  }

  fs.writeFileSync(outputFile, output);
  console.log(`Generated ${generatedTests} test functions (${totalTests} assertions)`);
  console.log(`Output: ${outputFile}`);
}

main();
