/**
 * Tailwind CSS Coverage Analyzer
 *
 * Compares Crater's safe subset against Tailwind CSS core utilities
 * to identify gaps and prioritize implementation work.
 *
 * Usage:
 *   npx tsx scripts/tailwind-coverage.ts
 */

import fs from 'fs';

// Tailwind CSS Core Utilities - CSS properties used by each category
// Based on https://tailwindcss.com/docs
const TAILWIND_CORE_PROPERTIES: Record<string, string[]> = {
  // Layout
  'Layout': [
    'display',           // flex, grid, block, inline-block, none, etc.
    'position',          // relative, absolute, fixed, sticky
    'top', 'right', 'bottom', 'left',
    'z-index',
    'float', 'clear',
    'overflow', 'overflow-x', 'overflow-y',
    'visibility',
  ],

  // Flexbox
  'Flexbox': [
    'flex-direction',
    'flex-wrap',
    'flex-grow',
    'flex-shrink',
    'flex-basis',
    'justify-content',
    'align-items',
    'align-content',
    'align-self',
    'order',
    'gap', 'row-gap', 'column-gap',
  ],

  // Grid
  'Grid': [
    'grid-template-columns',
    'grid-template-rows',
    'grid-column',
    'grid-column-start',
    'grid-column-end',
    'grid-row',
    'grid-row-start',
    'grid-row-end',
    'grid-auto-flow',
    'grid-auto-columns',
    'grid-auto-rows',
    'justify-items',
    'justify-self',
    'place-content',
    'place-items',
    'place-self',
  ],

  // Sizing
  'Sizing': [
    'width',
    'min-width',
    'max-width',
    'height',
    'min-height',
    'max-height',
    'aspect-ratio',
  ],

  // Spacing
  'Spacing': [
    'padding',
    'padding-top',
    'padding-right',
    'padding-bottom',
    'padding-left',
    'margin',
    'margin-top',
    'margin-right',
    'margin-bottom',
    'margin-left',
  ],

  // Typography
  'Typography': [
    'font-family',
    'font-size',
    'font-weight',
    'font-style',
    'line-height',
    'letter-spacing',
    'text-align',
    'text-decoration',
    'text-transform',
    'text-overflow',
    'white-space',
    'word-break',
    'overflow-wrap',
    'color',
  ],

  // Backgrounds
  'Backgrounds': [
    'background-color',
    'background-image',
    'background-size',
    'background-position',
    'background-repeat',
    'background-attachment',
  ],

  // Borders
  'Borders': [
    'border-width',
    'border-style',
    'border-color',
    'border-radius',
    'border-top-width',
    'border-right-width',
    'border-bottom-width',
    'border-left-width',
  ],

  // Effects
  'Effects': [
    'box-shadow',
    'opacity',
  ],

  // Box Model (additional)
  'Box Model': [
    'box-sizing',
  ],
};

// Values that Tailwind commonly uses for each property
const TAILWIND_COMMON_VALUES: Record<string, string[]> = {
  'display': ['block', 'inline-block', 'inline', 'flex', 'inline-flex', 'grid', 'inline-grid', 'none', 'table', 'table-row', 'table-cell'],
  'position': ['static', 'relative', 'absolute', 'fixed', 'sticky'],
  'flex-direction': ['row', 'row-reverse', 'column', 'column-reverse'],
  'flex-wrap': ['wrap', 'nowrap', 'wrap-reverse'],
  'justify-content': ['flex-start', 'flex-end', 'center', 'space-between', 'space-around', 'space-evenly', 'start', 'end'],
  'align-items': ['flex-start', 'flex-end', 'center', 'baseline', 'stretch', 'start', 'end'],
  'align-content': ['flex-start', 'flex-end', 'center', 'space-between', 'space-around', 'stretch', 'start', 'end'],
  'align-self': ['auto', 'flex-start', 'flex-end', 'center', 'baseline', 'stretch', 'start', 'end'],
  'text-align': ['left', 'center', 'right', 'justify', 'start', 'end'],
  'overflow': ['auto', 'hidden', 'visible', 'scroll', 'clip'],
  'white-space': ['normal', 'nowrap', 'pre', 'pre-wrap', 'pre-line', 'break-spaces'],
  'word-break': ['normal', 'break-all', 'keep-all', 'break-word'],
  'box-sizing': ['border-box', 'content-box'],
};

interface SafeSubset {
  version: string;
  generated: string;
  threshold: number;
  properties: Record<string, { values: string[]; passRate: number }>;
}

function loadSafeSubset(): SafeSubset {
  const content = fs.readFileSync('safe-subset.json', 'utf-8');
  return JSON.parse(content);
}

function analyzeGaps(safeSubset: SafeSubset): void {
  const safeProps = new Set(Object.keys(safeSubset.properties));
  const allTailwindProps = new Set<string>();

  // Collect all Tailwind properties
  for (const props of Object.values(TAILWIND_CORE_PROPERTIES)) {
    for (const prop of props) {
      allTailwindProps.add(prop);
    }
  }

  console.log('# Tailwind CSS Coverage Analysis\n');
  console.log(`Safe Subset has ${safeProps.size} properties`);
  console.log(`Tailwind Core uses ${allTailwindProps.size} properties\n`);

  // Analyze by category
  for (const [category, props] of Object.entries(TAILWIND_CORE_PROPERTIES)) {
    const supported = props.filter(p => safeProps.has(p));
    const missing = props.filter(p => !safeProps.has(p));
    const coverage = (supported.length / props.length * 100).toFixed(0);

    console.log(`## ${category} (${coverage}% coverage)`);
    console.log(`Supported: ${supported.length}/${props.length}`);

    if (supported.length > 0) {
      console.log('\n✓ Supported:');
      for (const prop of supported) {
        const info = safeSubset.properties[prop];
        console.log(`  - ${prop}: ${(info.passRate * 100).toFixed(0)}% pass rate`);
        if (info.values.length <= 5) {
          console.log(`    values: ${info.values.join(', ')}`);
        }
      }
    }

    if (missing.length > 0) {
      console.log('\n✗ Missing:');
      for (const prop of missing) {
        const expectedValues = TAILWIND_COMMON_VALUES[prop];
        if (expectedValues) {
          console.log(`  - ${prop} (needs: ${expectedValues.slice(0, 5).join(', ')}${expectedValues.length > 5 ? '...' : ''})`);
        } else {
          console.log(`  - ${prop}`);
        }
      }
    }
    console.log('');
  }

  // Priority list
  console.log('## Priority Implementation List\n');
  console.log('Based on Tailwind usage frequency and layout importance:\n');

  const priorities = [
    { prop: 'display', reason: 'Core layout - flex, grid, block modes' },
    { prop: 'flex-direction', reason: 'Flex layout direction' },
    { prop: 'flex-wrap', reason: 'Flex wrapping behavior' },
    { prop: 'width', reason: 'Element sizing' },
    { prop: 'height', reason: 'Element sizing' },
    { prop: 'padding', reason: 'Box model spacing' },
    { prop: 'margin', reason: 'Box model spacing' },
    { prop: 'gap', reason: 'Flex/Grid gap (modern spacing)' },
    { prop: 'position', reason: 'Positioning context' },
    { prop: 'background-color', reason: 'Visual styling' },
    { prop: 'color', reason: 'Text color' },
    { prop: 'font-size', reason: 'Typography' },
    { prop: 'font-weight', reason: 'Typography' },
    { prop: 'border-width', reason: 'Border styling' },
    { prop: 'grid-template-columns', reason: 'Grid layout definition' },
  ];

  let priority = 1;
  for (const { prop, reason } of priorities) {
    const status = safeProps.has(prop) ? '✓' : '✗';
    const passRate = safeSubset.properties[prop]?.passRate;
    const rateStr = passRate ? ` (${(passRate * 100).toFixed(0)}%)` : '';
    console.log(`${priority}. [${status}] ${prop}${rateStr}`);
    console.log(`   ${reason}`);
    priority++;
  }

  // Summary
  console.log('\n## Summary\n');
  const coveredCount = [...allTailwindProps].filter(p => safeProps.has(p)).length;
  const totalCoverage = (coveredCount / allTailwindProps.size * 100).toFixed(1);
  console.log(`Overall Tailwind coverage: ${coveredCount}/${allTailwindProps.size} (${totalCoverage}%)`);

  // Generate JSON for further analysis
  const gapReport = {
    coverage: {
      total: totalCoverage,
      covered: coveredCount,
      total_props: allTailwindProps.size,
    },
    byCategory: {} as Record<string, { covered: number; total: number; missing: string[] }>,
    priorities: priorities.map(p => ({
      property: p.prop,
      supported: safeProps.has(p.prop),
      reason: p.reason,
    })),
  };

  for (const [category, props] of Object.entries(TAILWIND_CORE_PROPERTIES)) {
    const supported = props.filter(p => safeProps.has(p));
    const missing = props.filter(p => !safeProps.has(p));
    gapReport.byCategory[category] = {
      covered: supported.length,
      total: props.length,
      missing,
    };
  }

  fs.writeFileSync('tailwind-coverage.json', JSON.stringify(gapReport, null, 2));
  console.log('\nWrote tailwind-coverage.json');
}

const safeSubset = loadSafeSubset();
analyzeGaps(safeSubset);
