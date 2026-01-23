/**
 * Simple JS DOM test runner for Crater
 *
 * Usage: npx tsx browser/tests/run-js-test.ts
 */

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Import the built browser module
const browserModule = await import('../dist/shell.js');

async function runTest() {
  console.log('=== Crater JS DOM Test ===\n');

  // Read the test HTML
  const htmlPath = join(__dirname, 'js-dom-test.html');
  const html = readFileSync(htmlPath, 'utf-8');

  // Create browser instance
  const browser = browserModule.Browser.new(800, 600);

  // Set HTML content directly (simulating local file load)
  browser.html_content = html;
  browser.current_url = 'file://' + htmlPath;

  // Execute scripts
  console.log('Executing scripts...\n');
  const executed = browser.execute_scripts();

  console.log(`\nScripts executed: ${executed}`);

  // Check the DOM tree for results
  const domTree = browser.get_dom_tree();
  if (domTree) {
    const doc = domTree.get_document();

    // Look for result elements
    const resultsQuery = domTree.query_selector(doc, '#results');
    if (resultsQuery.tag === 'Ok' && resultsQuery.val) {
      console.log('\nTest results found in DOM');

      // Count pass/fail elements
      const passElements = domTree.query_selector_all(doc, '.pass');
      const failElements = domTree.query_selector_all(doc, '.fail');

      if (passElements.tag === 'Ok') {
        console.log(`Passed: ${passElements.val.length}`);
      }
      if (failElements.tag === 'Ok') {
        console.log(`Failed: ${failElements.val.length}`);
      }
    }
  }

  console.log('\n=== Test Complete ===');
}

runTest().catch(console.error);
