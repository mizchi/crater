#!/usr/bin/env node --experimental-strip-types
/**
 * Test case generator for crater
 *
 * Usage:
 *   npm run gentest <html-file> [output-json]
 *   npm run gentest --batch <fixture-dir> <output-dir>
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
  unit: 'px' | 'percent' | 'auto' | 'fr' | 'min-content' | 'max-content';
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

interface GridPlacement {
  type: 'auto' | 'line' | 'span';
  value?: number;
}

interface GridLine {
  start: GridPlacement;
  end: GridPlacement;
}

interface TrackSizing {
  type: 'length' | 'percent' | 'fr' | 'auto' | 'min-content' | 'max-content' | 'minmax' | 'repeat' | 'fit-content-length' | 'fit-content-percent';
  value?: number;
  min?: TrackSizing;
  max?: TrackSizing;
  repeatCount?: number | 'auto-fill' | 'auto-fit';
  tracks?: TrackSizing[];
}

interface NodeStyle {
  display?: string;
  position?: string;
  overflow?: string;
  overflowX?: string;
  overflowY?: string;
  width?: Dimension;
  height?: Dimension;
  minWidth?: Dimension;
  minHeight?: Dimension;
  maxWidth?: Dimension;
  maxHeight?: Dimension;
  margin?: Edges;
  padding?: Edges;
  border?: Edges;
  // Flexbox
  flexDirection?: string;
  flexWrap?: string;
  justifyContent?: string;
  alignItems?: string;
  alignContent?: string;
  alignSelf?: string;
  flexGrow?: number;
  flexShrink?: number;
  flexBasis?: Dimension;
  // Grid container
  gridTemplateColumns?: TrackSizing[];
  gridTemplateRows?: TrackSizing[];
  gridAutoColumns?: TrackSizing[];
  gridAutoRows?: TrackSizing[];
  gridAutoFlow?: string;
  gridTemplateAreas?: string[];
  justifyItems?: string;
  justifySelf?: string;
  // Grid item
  gridColumn?: GridLine;
  gridRow?: GridLine;
  gridArea?: string;
  // Gap
  rowGap?: Dimension;
  columnGap?: Dimension;
  // Inset
  inset?: Edges;
  // Aspect ratio
  aspectRatio?: number;
}

interface MeasureData {
  minWidth: number;
  maxWidth: number;
  minHeight: number;
  maxHeight: number;
}

interface NodeTestData {
  id: string;
  style: NodeStyle;
  layout: LayoutRect;
  children: NodeTestData[];
  measure?: MeasureData;
}

interface TestCase {
  name: string;
  viewport: { width: number; height: number };
  root: NodeTestData;
}

// Helper script to inject into the page
const extractorScript = `
function parseDimension(value) {
  // Distinguish between "not specified" (undefined) and "explicitly auto"
  if (!value || value === '' || value === 'none') return undefined;
  if (value === 'auto') return { unit: 'auto' };
  if (value.endsWith('px')) return { unit: 'px', value: parseFloat(value) };
  if (value.endsWith('%')) return { unit: 'percent', value: parseFloat(value) / 100 };
  if (value.endsWith('fr')) return { unit: 'fr', value: parseFloat(value) };
  if (value === 'min-content') return { unit: 'min-content' };
  if (value === 'max-content') return { unit: 'max-content' };
  return undefined;
}

function parseEdges(style, prop) {
  const left = parseDimension(style[prop + 'Left'] || style.getPropertyValue(prop + '-left'));
  const right = parseDimension(style[prop + 'Right'] || style.getPropertyValue(prop + '-right'));
  const top = parseDimension(style[prop + 'Top'] || style.getPropertyValue(prop + '-top'));
  const bottom = parseDimension(style[prop + 'Bottom'] || style.getPropertyValue(prop + '-bottom'));
  // Return undefined only if nothing is defined
  if (!left && !right && !top && !bottom) {
    return undefined;
  }
  return { left, right, top, bottom };
}

function parseBorderWidth(style) {
  // Border uses borderLeftWidth, not borderWidthLeft
  const left = parseDimension(style.borderLeftWidth || style.getPropertyValue('border-left-width'));
  const right = parseDimension(style.borderRightWidth || style.getPropertyValue('border-right-width'));
  const top = parseDimension(style.borderTopWidth || style.getPropertyValue('border-top-width'));
  const bottom = parseDimension(style.borderBottomWidth || style.getPropertyValue('border-bottom-width'));
  // Return undefined only if nothing is defined
  if (!left && !right && !top && !bottom) {
    return undefined;
  }
  return { left, right, top, bottom };
}

function parseTrackSizing(value) {
  if (!value || value === 'none' || value === '') return [];

  const tracks = [];
  // Simple tokenization - handle repeat(), minmax(), and simple values
  let remaining = value.trim();

  while (remaining.length > 0) {
    remaining = remaining.trim();
    if (remaining.length === 0) break;

    // Handle repeat(...)
    if (remaining.startsWith('repeat(')) {
      const parenStart = 7;
      let depth = 1;
      let i = parenStart;
      while (i < remaining.length && depth > 0) {
        if (remaining[i] === '(') depth++;
        else if (remaining[i] === ')') depth--;
        i++;
      }
      const repeatContent = remaining.slice(parenStart, i - 1);
      remaining = remaining.slice(i).trim();

      // Parse repeat content: count, tracks
      const commaIdx = repeatContent.indexOf(',');
      if (commaIdx > 0) {
        const countStr = repeatContent.slice(0, commaIdx).trim();
        const tracksStr = repeatContent.slice(commaIdx + 1).trim();

        let repeatCount;
        if (countStr === 'auto-fill') repeatCount = 'auto-fill';
        else if (countStr === 'auto-fit') repeatCount = 'auto-fit';
        else repeatCount = parseInt(countStr, 10);

        const innerTracks = parseTrackSizing(tracksStr);
        tracks.push({
          type: 'repeat',
          repeatCount: repeatCount,
          tracks: innerTracks
        });
      }
      continue;
    }

    // Handle minmax(...)
    if (remaining.startsWith('minmax(')) {
      const parenStart = 7;
      let depth = 1;
      let i = parenStart;
      while (i < remaining.length && depth > 0) {
        if (remaining[i] === '(') depth++;
        else if (remaining[i] === ')') depth--;
        i++;
      }
      const minmaxContent = remaining.slice(parenStart, i - 1);
      remaining = remaining.slice(i).trim();

      const commaIdx = minmaxContent.indexOf(',');
      if (commaIdx > 0) {
        const minStr = minmaxContent.slice(0, commaIdx).trim();
        const maxStr = minmaxContent.slice(commaIdx + 1).trim();
        const minTracks = parseTrackSizing(minStr);
        const maxTracks = parseTrackSizing(maxStr);
        tracks.push({
          type: 'minmax',
          min: minTracks[0] || { type: 'auto' },
          max: maxTracks[0] || { type: 'auto' }
        });
      }
      continue;
    }

    // Handle fit-content(...)
    if (remaining.startsWith('fit-content(')) {
      const parenStart = 12;
      let depth = 1;
      let i = parenStart;
      while (i < remaining.length && depth > 0) {
        if (remaining[i] === '(') depth++;
        else if (remaining[i] === ')') depth--;
        i++;
      }
      const fitContentArg = remaining.slice(parenStart, i - 1).trim();
      remaining = remaining.slice(i).trim();

      if (fitContentArg.endsWith('px')) {
        tracks.push({ type: 'fit-content-length', value: parseFloat(fitContentArg) });
      } else if (fitContentArg.endsWith('%')) {
        tracks.push({ type: 'fit-content-percent', value: parseFloat(fitContentArg) / 100 });
      }
      continue;
    }

    // Handle simple values (space-separated)
    const spaceIdx = remaining.indexOf(' ');
    const token = spaceIdx > 0 ? remaining.slice(0, spaceIdx) : remaining;
    remaining = spaceIdx > 0 ? remaining.slice(spaceIdx + 1) : '';

    if (token.endsWith('px')) {
      tracks.push({ type: 'length', value: parseFloat(token) });
    } else if (token.endsWith('%')) {
      tracks.push({ type: 'percent', value: parseFloat(token) / 100 });
    } else if (token.endsWith('fr')) {
      tracks.push({ type: 'fr', value: parseFloat(token) });
    } else if (token === 'auto') {
      tracks.push({ type: 'auto' });
    } else if (token === 'min-content') {
      tracks.push({ type: 'min-content' });
    } else if (token === 'max-content') {
      tracks.push({ type: 'max-content' });
    }
  }

  return tracks;
}

function parseGridPlacement(value) {
  if (!value || value === 'auto') return { type: 'auto' };
  if (value.startsWith('span ')) {
    return { type: 'span', value: parseInt(value.slice(5), 10) };
  }
  const num = parseInt(value, 10);
  if (!isNaN(num)) {
    return { type: 'line', value: num };
  }
  return { type: 'auto' };
}

function parseGridLine(startValue, endValue) {
  return {
    start: parseGridPlacement(startValue),
    end: parseGridPlacement(endValue)
  };
}

function parseGridTemplateAreas(value) {
  if (!value || value === 'none') return undefined;
  // Parse quoted strings: "header header" "sidebar main" "footer footer"
  const areas = [];
  const regex = /"([^"]+)"/g;
  let match;
  while ((match = regex.exec(value)) !== null) {
    areas.push(match[1]);
  }
  return areas.length > 0 ? areas : undefined;
}

function measureTextContent(el) {
  // Check if element has direct text content (not just whitespace)
  const hasTextContent = Array.from(el.childNodes).some(node =>
    node.nodeType === Node.TEXT_NODE && node.textContent.trim().length > 0
  );

  if (!hasTextContent || el.children.length > 0) {
    return null;
  }

  // Get computed font style from original element
  const computed = getComputedStyle(el);

  // Create a clone to measure without affecting layout
  const clone = el.cloneNode(true);
  clone.style.position = 'absolute';
  clone.style.visibility = 'hidden';
  clone.style.width = 'auto';
  clone.style.height = 'auto';
  clone.style.minWidth = '0';
  clone.style.maxWidth = 'none';
  clone.style.minHeight = '0';
  clone.style.maxHeight = 'none';
  clone.style.padding = '0';
  clone.style.border = 'none';
  clone.style.margin = '0';
  // Inherit font styles from original element (important for Ahem font)
  clone.style.fontFamily = computed.fontFamily;
  clone.style.fontSize = computed.fontSize;
  clone.style.lineHeight = computed.lineHeight;
  clone.style.fontWeight = computed.fontWeight;
  clone.style.fontStyle = computed.fontStyle;

  document.body.appendChild(clone);

  // Measure max-content (no wrapping) - this gives natural width and height
  clone.style.whiteSpace = 'nowrap';
  const maxWidth = clone.offsetWidth;
  const maxHeight = clone.offsetHeight;

  // Measure min-content width using CSS min-content
  // This respects word boundaries and zero-width space break opportunities
  clone.style.whiteSpace = 'normal';
  clone.style.wordBreak = 'normal';
  clone.style.width = 'min-content';
  const minWidth = clone.offsetWidth;
  // For min_height, we use the height at max-content width (natural line height)
  // because grid intrinsic sizing typically uses this for content-based sizing
  const minHeight = maxHeight;

  document.body.removeChild(clone);

  return {
    minWidth: Math.round(minWidth * 100) / 100,
    maxWidth: Math.round(maxWidth * 100) / 100,
    minHeight: Math.round(minHeight * 100) / 100,
    maxHeight: Math.round(maxHeight * 100) / 100,
  };
}

function describeElement(el, parentRect) {
  const rect = el.getBoundingClientRect();
  const inlineStyle = el.style;
  const computed = getComputedStyle(el);

  const id = el.id || el.getAttribute('data-id') || 'node';

  // Measure text content if present
  const measure = measureTextContent(el);

  // Get inline styles with fallback to computed
  const getStyle = (prop) => inlineStyle[prop] || inlineStyle.getPropertyValue(prop);
  const getComputed = (prop) => computed[prop] || computed.getPropertyValue(prop);

  const style = {
    display: getStyle('display') || undefined,
    position: getStyle('position') || undefined,
    overflow: getStyle('overflow') || undefined,
    overflowX: getStyle('overflowX') || getStyle('overflow-x') || undefined,
    overflowY: getStyle('overflowY') || getStyle('overflow-y') || undefined,
    width: parseDimension(getStyle('width')),
    height: parseDimension(getStyle('height')),
    minWidth: parseDimension(getStyle('minWidth') || getStyle('min-width')),
    minHeight: parseDimension(getStyle('minHeight') || getStyle('min-height')),
    maxWidth: parseDimension(getStyle('maxWidth') || getStyle('max-width')),
    maxHeight: parseDimension(getStyle('maxHeight') || getStyle('max-height')),
    margin: parseEdges(inlineStyle, 'margin'),
    padding: parseEdges(inlineStyle, 'padding'),
    border: parseBorderWidth(inlineStyle),
    // Flexbox
    flexDirection: getStyle('flexDirection') || getStyle('flex-direction') || undefined,
    flexWrap: getStyle('flexWrap') || getStyle('flex-wrap') || undefined,
    justifyContent: getStyle('justifyContent') || getStyle('justify-content') || undefined,
    alignItems: getStyle('alignItems') || getStyle('align-items') || undefined,
    alignContent: getStyle('alignContent') || getStyle('align-content') || undefined,
    alignSelf: getStyle('alignSelf') || getStyle('align-self') || undefined,
    justifyItems: getStyle('justifyItems') || getStyle('justify-items') || undefined,
    justifySelf: getStyle('justifySelf') || getStyle('justify-self') || undefined,
    flexGrow: getStyle('flexGrow') || getStyle('flex-grow') ? parseFloat(getStyle('flexGrow') || getStyle('flex-grow')) : undefined,
    flexShrink: getStyle('flexShrink') || getStyle('flex-shrink') ? parseFloat(getStyle('flexShrink') || getStyle('flex-shrink')) : undefined,
    flexBasis: parseDimension(getStyle('flexBasis') || getStyle('flex-basis')),
    // Grid container
    gridTemplateColumns: parseTrackSizing(getStyle('gridTemplateColumns') || getStyle('grid-template-columns')),
    gridTemplateRows: parseTrackSizing(getStyle('gridTemplateRows') || getStyle('grid-template-rows')),
    gridAutoColumns: parseTrackSizing(getStyle('gridAutoColumns') || getStyle('grid-auto-columns')),
    gridAutoRows: parseTrackSizing(getStyle('gridAutoRows') || getStyle('grid-auto-rows')),
    gridAutoFlow: getStyle('gridAutoFlow') || getStyle('grid-auto-flow') || undefined,
    gridTemplateAreas: parseGridTemplateAreas(getStyle('gridTemplateAreas') || getStyle('grid-template-areas')),
    // Grid item
    gridColumn: parseGridLine(
      getStyle('gridColumnStart') || getStyle('grid-column-start'),
      getStyle('gridColumnEnd') || getStyle('grid-column-end')
    ),
    gridRow: parseGridLine(
      getStyle('gridRowStart') || getStyle('grid-row-start'),
      getStyle('gridRowEnd') || getStyle('grid-row-end')
    ),
    gridArea: getStyle('gridArea') || getStyle('grid-area') || undefined,
    // Gap
    rowGap: parseDimension(getStyle('rowGap') || getStyle('row-gap')),
    columnGap: parseDimension(getStyle('columnGap') || getStyle('column-gap')),
    // Inset
    inset: parseEdges(inlineStyle, 'inset') || {
      left: parseDimension(getStyle('left')),
      right: parseDimension(getStyle('right')),
      top: parseDimension(getStyle('top')),
      bottom: parseDimension(getStyle('bottom'))
    },
    // Aspect ratio
    aspectRatio: (() => {
      const ar = getStyle('aspectRatio') || getStyle('aspect-ratio');
      if (!ar || ar === 'auto') return undefined;
      // Handle "3 / 1" or "3/1" or just "3"
      if (ar.includes('/')) {
        const parts = ar.split('/').map(s => parseFloat(s.trim()));
        if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
          return parts[0] / parts[1];
        }
      }
      const num = parseFloat(ar);
      return isNaN(num) ? undefined : num;
    })(),
  };

  // Clean up undefined values
  if (!style.width) delete style.width;
  if (!style.height) delete style.height;
  if (!style.minWidth) delete style.minWidth;
  if (!style.minHeight) delete style.minHeight;
  if (!style.maxWidth) delete style.maxWidth;
  if (!style.maxHeight) delete style.maxHeight;
  if (!style.flexBasis) delete style.flexBasis;
  if (!style.rowGap) delete style.rowGap;
  if (!style.columnGap) delete style.columnGap;
  if (!style.gridTemplateColumns?.length) delete style.gridTemplateColumns;
  if (!style.gridTemplateRows?.length) delete style.gridTemplateRows;
  if (!style.gridAutoColumns?.length) delete style.gridAutoColumns;
  if (!style.gridAutoRows?.length) delete style.gridAutoRows;
  if (style.gridColumn?.start?.type === 'auto' && style.gridColumn?.end?.type === 'auto') delete style.gridColumn;
  if (style.gridRow?.start?.type === 'auto' && style.gridRow?.end?.type === 'auto') delete style.gridRow;
  // Clean up empty edge objects (inset, margin, padding, border)
  if (style.inset && !style.inset.left && !style.inset.right && !style.inset.top && !style.inset.bottom) delete style.inset;
  if (style.margin && !style.margin.left && !style.margin.right && !style.margin.top && !style.margin.bottom) delete style.margin;
  if (style.padding && !style.padding.left && !style.padding.right && !style.padding.top && !style.padding.bottom) delete style.padding;
  if (style.border && !style.border.left && !style.border.right && !style.border.top && !style.border.bottom) delete style.border;

  const result = {
    id: id,
    style: style,
    layout: {
      x: parentRect ? Math.round((rect.x - parentRect.x) * 100) / 100 : Math.round(rect.x * 100) / 100,
      y: parentRect ? Math.round((rect.y - parentRect.y) * 100) / 100 : Math.round(rect.y * 100) / 100,
      width: Math.round(rect.width * 100) / 100,
      height: Math.round(rect.height * 100) / 100,
    },
    children: Array.from(el.children).map(child => describeElement(child, rect)),
  };

  // Add measure data if present
  if (measure) {
    result.measure = measure;
  }

  return result;
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

async function batchConvert(fixtureDir: string, outputDir: string, pattern?: string) {
  // Ensure output directory exists
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Find all HTML files
  const files = fs.readdirSync(fixtureDir)
    .filter(f => f.endsWith('.html'))
    .filter(f => !f.startsWith('x')) // Skip disabled tests (xgrid_*)
    .filter(f => !pattern || f.includes(pattern));

  console.log(`Found ${files.length} HTML fixtures in ${fixtureDir}`);

  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport({ width: 800, height: 600 });

  let success = 0;
  let failed = 0;

  for (const file of files) {
    const htmlPath = path.join(fixtureDir, file);
    const jsonPath = path.join(outputDir, file.replace('.html', '.json'));

    try {
      const absolutePath = path.resolve(htmlPath);
      await page.goto(`file://${absolutePath}`);
      await page.evaluate(extractorScript);
      const rootData = await page.evaluate('getTestData()') as NodeTestData;

      const testCase: TestCase = {
        name: path.basename(file, '.html'),
        viewport: { width: 800, height: 600 },
        root: rootData,
      };

      fs.writeFileSync(jsonPath, JSON.stringify(testCase, null, 2));
      success++;
      process.stdout.write('.');
    } catch (err) {
      failed++;
      console.error(`\nFailed: ${file}: ${err}`);
    }
  }

  await browser.close();

  console.log(`\n\nConverted ${success} fixtures, ${failed} failed`);
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log('Usage:');
    console.log('  npm run gentest -- <html-file> [output-json]');
    console.log('  npm run gentest -- --batch <fixture-dir> <output-dir> [pattern]');
    console.log('');
    console.log('Examples:');
    console.log('  npm run gentest -- taffy/test_fixtures/grid/grid_basic.html');
    console.log('  npm run gentest -- --batch taffy/test_fixtures/grid fixtures/grid');
    console.log('  npm run gentest -- --batch taffy/test_fixtures/grid fixtures/grid auto_fill');
    process.exit(1);
  }

  if (args[0] === '--batch') {
    const fixtureDir = args[1];
    const outputDir = args[2];
    const pattern = args[3];

    if (!fixtureDir || !outputDir) {
      console.error('Error: --batch requires <fixture-dir> and <output-dir>');
      process.exit(1);
    }

    if (!fs.existsSync(fixtureDir)) {
      console.error(`Error: Directory not found: ${fixtureDir}`);
      process.exit(1);
    }

    await batchConvert(fixtureDir, outputDir, pattern);
  } else {
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
    }
  }
}

main().catch(console.error);
