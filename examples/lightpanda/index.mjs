/**
 * Lightpanda + Crater integration example
 *
 * This demonstrates using Lightpanda as a headless browser to:
 * 1. Fetch and render JavaScript-heavy pages
 * 2. Extract the resulting HTML/CSS
 * 3. Pass to Crater for layout computation
 *
 * Usage:
 *   # Start Lightpanda first
 *   lightpanda --remote-debugging-port=9222
 *
 *   # Or use Lightpanda Cloud
 *   export LIGHTPANDA_ENDPOINT="wss://cloud.lightpanda.io/..."
 *
 *   # Run this script
 *   node index.mjs <url>
 *   node index.mjs https://example.com
 */

import puppeteer from 'puppeteer-core';
import { spawn } from 'child_process';
import { writeFileSync, unlinkSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

// Lightpanda WebSocket endpoint
const LIGHTPANDA_ENDPOINT = process.env.LIGHTPANDA_ENDPOINT || 'ws://localhost:9222';

/**
 * Extract full HTML including computed styles as inline styles
 */
async function extractStyledHTML(page) {
  return await page.evaluate(() => {
    function getInlineStyles(el) {
      const cs = window.getComputedStyle(el);
      const styles = [];

      // Layout-relevant properties
      const props = [
        'display', 'position',
        'width', 'height', 'min-width', 'max-width', 'min-height', 'max-height',
        'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
        'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
        'border-top-width', 'border-right-width', 'border-bottom-width', 'border-left-width',
        'flex-direction', 'flex-wrap', 'justify-content', 'align-items', 'align-content',
        'flex-grow', 'flex-shrink', 'flex-basis',
        'gap', 'row-gap', 'column-gap',
        'overflow', 'overflow-x', 'overflow-y',
        'box-sizing',
      ];

      for (const prop of props) {
        const value = cs.getPropertyValue(prop);
        if (value && value !== 'auto' && value !== 'normal' && value !== 'none' && value !== '0px') {
          styles.push(`${prop}: ${value}`);
        }
      }

      return styles.join('; ');
    }

    function cloneWithStyles(node) {
      if (node.nodeType === Node.TEXT_NODE) {
        return document.createTextNode(node.textContent);
      }

      if (node.nodeType !== Node.ELEMENT_NODE) {
        return null;
      }

      const el = node;
      const tagName = el.tagName.toLowerCase();

      // Skip non-renderable elements
      if (['script', 'style', 'link', 'meta', 'noscript', 'template'].includes(tagName)) {
        return null;
      }

      const clone = document.createElement(tagName);

      // Copy essential attributes
      for (const attr of ['id', 'class', 'src', 'href', 'alt']) {
        if (el.hasAttribute(attr)) {
          clone.setAttribute(attr, el.getAttribute(attr));
        }
      }

      // Add computed styles as inline style
      const inlineStyles = getInlineStyles(el);
      if (inlineStyles) {
        clone.setAttribute('style', inlineStyles);
      }

      // Clone children
      for (const child of el.childNodes) {
        const clonedChild = cloneWithStyles(child);
        if (clonedChild) {
          clone.appendChild(clonedChild);
        }
      }

      return clone;
    }

    const body = document.body;
    if (!body) return null;

    const styledBody = cloneWithStyles(body);
    if (!styledBody) return null;

    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Styled HTML from Lightpanda</title>
</head>
<body>${styledBody.innerHTML}</body>
</html>`;
  });
}

/**
 * Run Crater on HTML content
 */
async function runCrater(html, width, height, outputFormat) {
  return new Promise((resolve, reject) => {
    // Write HTML to temp file
    const tmpFile = join(tmpdir(), `crater-${Date.now()}.html`);
    writeFileSync(tmpFile, html);

    const args = [
      'run', 'cmd/main', '--',
      '--width', String(width),
      '--height', String(height),
    ];

    if (outputFormat === 'json') {
      args.push('--json');
    }

    args.push(tmpFile);

    const cratePath = new URL('../../', import.meta.url).pathname;
    const moon = spawn('moon', args, {
      cwd: cratePath,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    moon.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    moon.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    moon.on('close', (code) => {
      // Clean up temp file
      try {
        unlinkSync(tmpFile);
      } catch {}

      if (code === 0) {
        resolve(stdout);
      } else {
        reject(new Error(`Crater exited with code ${code}: ${stderr}`));
      }
    });

    moon.on('error', (err) => {
      try {
        unlinkSync(tmpFile);
      } catch {}
      reject(err);
    });
  });
}

async function main() {
  const url = process.argv[2] || 'https://example.com';
  const width = parseInt(process.argv[3]) || 1024;
  const height = parseInt(process.argv[4]) || 768;
  const outputFormat = process.argv[5] || 'sixel'; // 'sixel' or 'json'

  console.error(`[Lightpanda] Connecting to ${LIGHTPANDA_ENDPOINT}...`);

  try {
    const browser = await puppeteer.connect({
      browserWSEndpoint: LIGHTPANDA_ENDPOINT,
    });

    const page = await browser.newPage();
    await page.setViewport({ width, height });

    console.error(`[Lightpanda] Navigating to ${url}...`);
    await page.goto(url, { waitUntil: 'networkidle0' });

    console.error('[Lightpanda] Extracting styled HTML...');
    const styledHTML = await extractStyledHTML(page);

    await browser.close();

    if (!styledHTML) {
      console.error('Error: Could not extract HTML');
      process.exit(1);
    }

    console.error(`[Crater] Computing layout (${width}x${height})...`);
    const output = await runCrater(styledHTML, width, height, outputFormat);

    // Output result to stdout
    console.log(output);

  } catch (error) {
    if (error.message.includes('ECONNREFUSED')) {
      console.error(`
Error: Could not connect to Lightpanda at ${LIGHTPANDA_ENDPOINT}

To use this example:

1. Install Lightpanda:
   https://github.com/lightpanda-io/browser

2. Start Lightpanda server:
   lightpanda --remote-debugging-port=9222

3. Or use Lightpanda Cloud:
   export LIGHTPANDA_ENDPOINT="wss://cloud.lightpanda.io/..."

4. Run this script:
   node index.mjs https://example.com
   node index.mjs https://example.com 800 600        # with dimensions
   node index.mjs https://example.com 800 600 json   # JSON output
`);
    } else {
      console.error('Error:', error.message);
    }
    process.exit(1);
  }
}

main();
