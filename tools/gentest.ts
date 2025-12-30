#!/usr/bin/env bun
/**
 * Test case generator for crater
 *
 * Usage:
 *   bun run tools/gentest.ts <html-file> [output-json]
 *
 * This script:
 * 1. Opens an HTML file in a headless browser
 * 2. Extracts style and layout information from the DOM
 * 3. Outputs a JSON test case that crater can use
 */

import puppeteer from 'puppeteer';
import * as fs from 'fs';
import * as path from 'path';

interface Dimension {
  unit: 'px' | 'percent' | 'auto';
  value?: number;
}

interface Edges {
  left?: Dimension;
  right?: Dimension;
  top?: Dimension;
  bottom?: Dimension;
}

interface LayoutRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

interface NodeTestData {
  id: string;
  style: {
    display?: string;
    position?: string;
    width?: Dimension;
    height?: Dimension;
    margin?: Edges;
    padding?: Edges;
    border?: Edges;
    flexDirection?: string;
    justifyContent?: string;
    alignItems?: string;
  };
  layout: LayoutRect;
  children: NodeTestData[];
}

interface TestCase {
  name: string;
  viewport: { width: number; height: number };
  root: NodeTestData;
}

// Helper script to inject into the page
const extractorScript = `
function parseDimension(value) {
  if (!value || value === 'auto' || value === '') return { unit: 'auto' };
  if (value.endsWith('px')) return { unit: 'px', value: parseFloat(value) };
  if (value.endsWith('%')) return { unit: 'percent', value: parseFloat(value) / 100 };
  return { unit: 'auto' };
}

function parseEdges(style, prop) {
  const left = parseDimension(style[prop + 'Left']);
  const right = parseDimension(style[prop + 'Right']);
  const top = parseDimension(style[prop + 'Top']);
  const bottom = parseDimension(style[prop + 'Bottom']);
  if (left.unit === 'auto' && right.unit === 'auto' && top.unit === 'auto' && bottom.unit === 'auto') {
    return undefined;
  }
  return { left, right, top, bottom };
}

function describeElement(el, parentRect) {
  const rect = el.getBoundingClientRect();
  const style = el.style;
  const computed = getComputedStyle(el);

  const id = el.id || el.getAttribute('data-id') || 'node';

  return {
    id: id,
    style: {
      display: style.display || undefined,
      position: style.position || undefined,
      width: parseDimension(style.width),
      height: parseDimension(style.height),
      margin: parseEdges(style, 'margin'),
      padding: parseEdges(style, 'padding'),
      border: parseEdges(style, 'borderWidth') || parseEdges(style, 'border'),
      flexDirection: style.flexDirection || undefined,
      justifyContent: style.justifyContent || undefined,
      alignItems: style.alignItems || undefined,
    },
    layout: {
      x: parentRect ? rect.x - parentRect.x : rect.x,
      y: parentRect ? rect.y - parentRect.y : rect.y,
      width: rect.width,
      height: rect.height,
    },
    children: Array.from(el.children).map(child => describeElement(child, rect)),
  };
}

function getTestData() {
  const root = document.getElementById('test-root');
  if (!root) throw new Error('No element with id="test-root" found');
  return describeElement(root, null);
}
`;

async function generateTestCase(htmlPath: string): Promise<TestCase> {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();

  // Set viewport
  await page.setViewport({ width: 800, height: 600 });

  // Load the HTML file
  const absolutePath = path.resolve(htmlPath);
  await page.goto(`file://${absolutePath}`);

  // Inject our extractor script
  await page.evaluate(extractorScript);

  // Extract test data
  const rootData = await page.evaluate('getTestData()') as NodeTestData;

  await browser.close();

  const name = path.basename(htmlPath, '.html');

  return {
    name,
    viewport: { width: 800, height: 600 },
    root: rootData,
  };
}

// Convert test case to MoonBit test code
function toMoonBitTest(tc: TestCase): string {
  function nodeToStyle(node: NodeTestData, indent: string): string {
    const lines: string[] = [];
    lines.push(`${indent}let style = @crater.Style::default()`);
    // TODO: Add style overrides based on node.style
    return lines.join('\n');
  }

  function nodeToAssertion(node: NodeTestData, varName: string, indent: string): string {
    const lines: string[] = [];
    lines.push(`${indent}// Expected layout for ${node.id}`);
    lines.push(`${indent}inspect(${varName}.x, content="${node.layout.x}")`);
    lines.push(`${indent}inspect(${varName}.y, content="${node.layout.y}")`);
    lines.push(`${indent}inspect(${varName}.width, content="${node.layout.width}")`);
    lines.push(`${indent}inspect(${varName}.height, content="${node.layout.height}")`);
    return lines.join('\n');
  }

  return `///|
test "${tc.name}" {
  // Viewport: ${tc.viewport.width}x${tc.viewport.height}
  // TODO: Build node tree and compute layout
  // Expected root layout:
  //   x: ${tc.root.layout.x}
  //   y: ${tc.root.layout.y}
  //   width: ${tc.root.layout.width}
  //   height: ${tc.root.layout.height}
  inspect(true, content="true") // placeholder
}
`;
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log('Usage: bun run tools/gentest.ts <html-file> [output-json]');
    console.log('');
    console.log('Example:');
    console.log('  bun run tools/gentest.ts taffy/test_fixtures/block/block_basic.html');
    process.exit(1);
  }

  const htmlPath = args[0];
  const outputPath = args[1];

  if (!fs.existsSync(htmlPath)) {
    console.error(`Error: File not found: ${htmlPath}`);
    process.exit(1);
  }

  console.log(`Generating test case from: ${htmlPath}`);

  const testCase = await generateTestCase(htmlPath);

  if (outputPath) {
    fs.writeFileSync(outputPath, JSON.stringify(testCase, null, 2));
    console.log(`Wrote JSON to: ${outputPath}`);
  } else {
    console.log('\n--- JSON Test Case ---');
    console.log(JSON.stringify(testCase, null, 2));
    console.log('\n--- MoonBit Test (template) ---');
    console.log(toMoonBitTest(testCase));
  }
}

main().catch(console.error);
