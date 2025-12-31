#!/usr/bin/env node --experimental-strip-types
/**
 * Generate MoonBit test code from JSON fixtures
 *
 * Usage:
 *   npm run gen-moonbit-tests -- <fixture-dir> <output-file> [pattern]
 *
 * Example:
 *   npm run gen-moonbit-tests -- fixtures/grid grid/gen_test.mbt
 */

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
  flexDirection?: string;
  flexWrap?: string;
  justifyContent?: string;
  alignItems?: string;
  alignContent?: string;
  alignSelf?: string;
  justifyItems?: string;
  justifySelf?: string;
  flexGrow?: number;
  flexShrink?: number;
  flexBasis?: Dimension;
  aspectRatio?: number;
  gridTemplateColumns?: TrackSizing[];
  gridTemplateRows?: TrackSizing[];
  gridAutoColumns?: TrackSizing[];
  gridAutoRows?: TrackSizing[];
  gridAutoFlow?: string;
  gridTemplateAreas?: string[];
  gridColumn?: GridLine;
  gridRow?: GridLine;
  gridArea?: string;
  rowGap?: Dimension;
  columnGap?: Dimension;
  inset?: Edges;
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

function dimensionToMoonBit(dim: Dimension | undefined): string {
  if (!dim) return '@types.Length(0.0)';  // undefined = not specified = 0 (for margin/padding/border)
  switch (dim.unit) {
    case 'px': return `@types.Length(${dim.value!.toFixed(1)})`;
    case 'percent': return `@types.Percent(${dim.value!.toFixed(4)})`;
    case 'auto': return '@types.Auto';  // explicit auto
    default: return '@types.Length(0.0)';
  }
}

// For inset: undefined means Auto (not specified = default position)
function insetDimensionToMoonBit(dim: Dimension | undefined): string {
  if (!dim) return '@types.Auto';  // undefined = not specified = Auto for inset
  switch (dim.unit) {
    case 'px': return `@types.Length(${dim.value!.toFixed(1)})`;
    case 'percent': return `@types.Percent(${dim.value!.toFixed(4)})`;
    case 'auto': return '@types.Auto';
    default: return '@types.Auto';
  }
}

function edgesToMoonBit(edges: Edges | undefined): string {
  if (!edges) return '{ left: @types.Length(0.0), right: @types.Length(0.0), top: @types.Length(0.0), bottom: @types.Length(0.0) }';
  return `{ left: ${dimensionToMoonBit(edges.left)}, right: ${dimensionToMoonBit(edges.right)}, top: ${dimensionToMoonBit(edges.top)}, bottom: ${dimensionToMoonBit(edges.bottom)} }`;
}

function insetEdgesToMoonBit(edges: Edges | undefined): string {
  if (!edges) return '{ left: @types.Auto, right: @types.Auto, top: @types.Auto, bottom: @types.Auto }';
  return `{ left: ${insetDimensionToMoonBit(edges.left)}, right: ${insetDimensionToMoonBit(edges.right)}, top: ${insetDimensionToMoonBit(edges.top)}, bottom: ${insetDimensionToMoonBit(edges.bottom)} }`;
}

function trackSizingToMoonBit(track: TrackSizing): string {
  switch (track.type) {
    case 'length': return `@style.Length(${track.value!.toFixed(1)})`;
    case 'percent': return `@style.Percent(${track.value!.toFixed(4)})`;
    case 'fr': return `@style.Fr(${track.value!.toFixed(1)})`;
    case 'auto': return '@style.Auto';
    case 'min-content': return '@style.MinContent';
    case 'max-content': return '@style.MaxContent';
    case 'fit-content-length': return `@style.FitContentLength(${track.value!.toFixed(1)})`;
    case 'fit-content-percent': return `@style.FitContentPercent(${track.value!.toFixed(4)})`;
    case 'minmax':
      const min = minTrackToMoonBit(track.min!);
      const max = maxTrackToMoonBit(track.max!);
      return `@style.MinMax(${min}, ${max})`;
    case 'repeat':
      const count = track.repeatCount === 'auto-fill' ? '@style.AutoFill' :
                    track.repeatCount === 'auto-fit' ? '@style.AutoFit' :
                    `@style.Count(${track.repeatCount})`;
      const innerTracks = track.tracks!.map(t => singleTrackToMoonBit(t)).join(', ');
      return `@style.Repeat(${count}, [${innerTracks}])`;
    default:
      return '@style.Auto';
  }
}

function singleTrackToMoonBit(track: TrackSizing): string {
  switch (track.type) {
    case 'length': return `@style.SingleTrackSizing::Length(${track.value!.toFixed(1)})`;
    case 'percent': return `@style.SingleTrackSizing::Percent(${track.value!.toFixed(4)})`;
    case 'fr': return `@style.SingleTrackSizing::Fr(${track.value!.toFixed(1)})`;
    case 'auto': return '@style.SingleTrackSizing::Auto';
    case 'min-content': return '@style.SingleTrackSizing::MinContent';
    case 'max-content': return '@style.SingleTrackSizing::MaxContent';
    case 'fit-content-length': return `@style.SingleTrackSizing::FitContentLength(${track.value!.toFixed(1)})`;
    case 'fit-content-percent': return `@style.SingleTrackSizing::FitContentPercent(${track.value!.toFixed(4)})`;
    case 'minmax':
      const min = minTrackToMoonBit(track.min!);
      const max = maxTrackToMoonBit(track.max!);
      return `@style.SingleTrackSizing::MinMax(${min}, ${max})`;
    default:
      return '@style.SingleTrackSizing::Auto';
  }
}

function minTrackToMoonBit(track: TrackSizing): string {
  switch (track.type) {
    case 'length': return `@style.MinTrackSizing::Length(${track.value!.toFixed(1)})`;
    case 'percent': return `@style.MinTrackSizing::Percent(${track.value!.toFixed(4)})`;
    case 'auto': return '@style.MinTrackSizing::Auto';
    case 'min-content': return '@style.MinTrackSizing::MinContent';
    case 'max-content': return '@style.MinTrackSizing::MaxContent';
    default:
      return '@style.MinTrackSizing::Auto';
  }
}

function maxTrackToMoonBit(track: TrackSizing): string {
  switch (track.type) {
    case 'length': return `@style.MaxTrackSizing::Length(${track.value!.toFixed(1)})`;
    case 'percent': return `@style.MaxTrackSizing::Percent(${track.value!.toFixed(4)})`;
    case 'fr': return `@style.MaxTrackSizing::Fr(${track.value!.toFixed(1)})`;
    case 'auto': return '@style.MaxTrackSizing::Auto';
    case 'min-content': return '@style.MaxTrackSizing::MinContent';
    case 'max-content': return '@style.MaxTrackSizing::MaxContent';
    default:
      return '@style.MaxTrackSizing::Auto';
  }
}

function gridPlacementToMoonBit(placement: GridPlacement | undefined): string {
  if (!placement || placement.type === 'auto') return '@style.Auto';
  if (placement.type === 'line') return `@style.Line(${placement.value})`;
  if (placement.type === 'span') return `@style.Span(${placement.value})`;
  return '@style.Auto';
}

function gridLineToMoonBit(line: GridLine | undefined): string {
  if (!line) return '{ start: @style.Auto, end: @style.Auto }';
  return `{ start: ${gridPlacementToMoonBit(line.start)}, end: ${gridPlacementToMoonBit(line.end)} }`;
}

function alignmentToMoonBit(value: string | undefined): string {
  if (!value) return '@style.Start';
  switch (value) {
    case 'flex-start':
    case 'start': return '@style.Start';
    case 'flex-end':
    case 'end': return '@style.End';
    case 'center': return '@style.Center';
    case 'space-between': return '@style.SpaceBetween';
    case 'space-around': return '@style.SpaceAround';
    case 'space-evenly': return '@style.SpaceEvenly';
    case 'stretch': return '@style.Stretch';
    case 'baseline': return '@style.Baseline';
    default: return '@style.Start';
  }
}

function alignSelfToMoonBit(value: string | undefined): string {
  if (!value) return '@style.AlignSelf::Auto';
  switch (value) {
    case 'auto': return '@style.AlignSelf::Auto';
    case 'flex-start':
    case 'start': return '@style.AlignSelf::Start';
    case 'flex-end':
    case 'end': return '@style.AlignSelf::End';
    case 'center': return '@style.AlignSelf::Center';
    case 'stretch': return '@style.AlignSelf::Stretch';
    default: return '@style.AlignSelf::Auto';
  }
}

function gridAutoFlowToMoonBit(value: string | undefined): string {
  if (!value) return '@style.GridAutoFlow::Row';
  switch (value) {
    case 'row': return '@style.GridAutoFlow::Row';
    case 'column': return '@style.GridAutoFlow::Column';
    case 'row dense': return '@style.GridAutoFlow::RowDense';
    case 'column dense': return '@style.GridAutoFlow::ColumnDense';
    default: return '@style.GridAutoFlow::Row';
  }
}

function positionToMoonBit(value: string | undefined): string {
  if (!value || value === 'relative') return '@style.Position::Relative';
  if (value === 'absolute') return '@style.Position::Absolute';
  return '@style.Position::Relative';
}

function overflowToMoonBit(value: string | undefined): string {
  if (!value || value === 'visible') return '@style.Overflow::Visible';
  if (value === 'hidden') return '@style.Overflow::Hidden';
  if (value === 'scroll') return '@style.Overflow::Scroll';
  if (value === 'auto') return '@style.Overflow::Auto';
  return '@style.Overflow::Visible';
}

function nodeToMoonBit(node: NodeTestData, varName: string, indent: string): string[] {
  const lines: string[] = [];
  const style = node.style;

  // Build style
  lines.push(`${indent}let ${varName}_style = {`);
  lines.push(`${indent}  ..@style.Style::default(),`);

  if (style.display === 'grid') {
    lines.push(`${indent}  display: @style.Grid,`);
  } else if (style.display === 'flex') {
    lines.push(`${indent}  display: @style.Flex,`);
  } else if (style.display === 'none') {
    lines.push(`${indent}  display: @style.None,`);
  }

  if (style.position) {
    lines.push(`${indent}  position: ${positionToMoonBit(style.position)},`);
  }

  // Overflow - handle shorthand 'overflow' and individual overflowX/overflowY
  const overflowX = style.overflowX || style.overflow;
  const overflowY = style.overflowY || style.overflow;
  if (overflowX && overflowX !== 'visible') {
    lines.push(`${indent}  overflow_x: ${overflowToMoonBit(overflowX)},`);
  }
  if (overflowY && overflowY !== 'visible') {
    lines.push(`${indent}  overflow_y: ${overflowToMoonBit(overflowY)},`);
  }

  if (style.width) {
    lines.push(`${indent}  width: ${dimensionToMoonBit(style.width)},`);
  }
  if (style.height) {
    lines.push(`${indent}  height: ${dimensionToMoonBit(style.height)},`);
  }
  if (style.minWidth) {
    lines.push(`${indent}  min_width: ${dimensionToMoonBit(style.minWidth)},`);
  }
  if (style.minHeight) {
    lines.push(`${indent}  min_height: ${dimensionToMoonBit(style.minHeight)},`);
  }
  if (style.maxWidth) {
    lines.push(`${indent}  max_width: ${dimensionToMoonBit(style.maxWidth)},`);
  }
  if (style.maxHeight) {
    lines.push(`${indent}  max_height: ${dimensionToMoonBit(style.maxHeight)},`);
  }

  if (style.margin) {
    lines.push(`${indent}  margin: ${edgesToMoonBit(style.margin)},`);
  }
  if (style.padding) {
    lines.push(`${indent}  padding: ${edgesToMoonBit(style.padding)},`);
  }
  if (style.border) {
    lines.push(`${indent}  border: ${edgesToMoonBit(style.border)},`);
  }

  // Grid container properties
  if (style.gridTemplateColumns && style.gridTemplateColumns.length > 0) {
    const tracks = style.gridTemplateColumns.map(t => trackSizingToMoonBit(t)).join(', ');
    lines.push(`${indent}  grid_template_columns: [${tracks}],`);
  }
  if (style.gridTemplateRows && style.gridTemplateRows.length > 0) {
    const tracks = style.gridTemplateRows.map(t => trackSizingToMoonBit(t)).join(', ');
    lines.push(`${indent}  grid_template_rows: [${tracks}],`);
  }
  if (style.gridAutoColumns && style.gridAutoColumns.length > 0) {
    const tracks = style.gridAutoColumns.map(t => trackSizingToMoonBit(t)).join(', ');
    lines.push(`${indent}  grid_auto_columns: [${tracks}],`);
  }
  if (style.gridAutoRows && style.gridAutoRows.length > 0) {
    const tracks = style.gridAutoRows.map(t => trackSizingToMoonBit(t)).join(', ');
    lines.push(`${indent}  grid_auto_rows: [${tracks}],`);
  }
  if (style.gridAutoFlow) {
    lines.push(`${indent}  grid_auto_flow: ${gridAutoFlowToMoonBit(style.gridAutoFlow)},`);
  }
  if (style.gridTemplateAreas && style.gridTemplateAreas.length > 0) {
    const areas = style.gridTemplateAreas.map(a => `"${a}"`).join(', ');
    lines.push(`${indent}  grid_template_areas: [${areas}],`);
  }

  // Grid item properties
  if (style.gridColumn && (style.gridColumn.start?.type !== 'auto' || style.gridColumn.end?.type !== 'auto')) {
    lines.push(`${indent}  grid_column: ${gridLineToMoonBit(style.gridColumn)},`);
  }
  if (style.gridRow && (style.gridRow.start?.type !== 'auto' || style.gridRow.end?.type !== 'auto')) {
    lines.push(`${indent}  grid_row: ${gridLineToMoonBit(style.gridRow)},`);
  }
  if (style.gridArea) {
    lines.push(`${indent}  grid_area: Some("${style.gridArea}"),`);
  }

  // Gap
  if (style.rowGap) {
    lines.push(`${indent}  row_gap: ${dimensionToMoonBit(style.rowGap)},`);
  }
  if (style.columnGap) {
    lines.push(`${indent}  column_gap: ${dimensionToMoonBit(style.columnGap)},`);
  }

  // Alignment
  if (style.justifyContent) {
    lines.push(`${indent}  justify_content: ${alignmentToMoonBit(style.justifyContent)},`);
  }
  if (style.alignItems) {
    lines.push(`${indent}  align_items: ${alignmentToMoonBit(style.alignItems)},`);
  }
  if (style.alignContent) {
    lines.push(`${indent}  align_content: ${alignmentToMoonBit(style.alignContent)},`);
  }
  if (style.alignSelf) {
    lines.push(`${indent}  align_self: ${alignSelfToMoonBit(style.alignSelf)},`);
  }
  if (style.justifyItems) {
    lines.push(`${indent}  justify_items: ${alignmentToMoonBit(style.justifyItems)},`);
  }
  if (style.justifySelf) {
    lines.push(`${indent}  justify_self: ${alignSelfToMoonBit(style.justifySelf)},`);
  }

  // Inset
  if (style.inset) {
    lines.push(`${indent}  inset: ${insetEdgesToMoonBit(style.inset)},`);
  }

  // Flex container properties
  if (style.flexDirection) {
    const dir = style.flexDirection;
    if (dir === 'row') lines.push(`${indent}  flex_direction: @style.Row,`);
    else if (dir === 'row-reverse') lines.push(`${indent}  flex_direction: @style.RowReverse,`);
    else if (dir === 'column') lines.push(`${indent}  flex_direction: @style.Column,`);
    else if (dir === 'column-reverse') lines.push(`${indent}  flex_direction: @style.ColumnReverse,`);
  }
  if (style.flexWrap) {
    const wrap = style.flexWrap;
    if (wrap === 'wrap') lines.push(`${indent}  flex_wrap: @style.Wrap,`);
    else if (wrap === 'wrap-reverse') lines.push(`${indent}  flex_wrap: @style.WrapReverse,`);
    else if (wrap === 'nowrap') lines.push(`${indent}  flex_wrap: @style.NoWrap,`);
  }

  // Flex item properties
  if (style.flexGrow !== undefined && style.flexGrow !== 0) {
    lines.push(`${indent}  flex_grow: ${style.flexGrow.toFixed(1)},`);
  }
  if (style.flexShrink !== undefined && style.flexShrink !== 1) {
    lines.push(`${indent}  flex_shrink: ${style.flexShrink.toFixed(1)},`);
  }
  if (style.flexBasis) {
    lines.push(`${indent}  flex_basis: ${dimensionToMoonBit(style.flexBasis)},`);
  }

  // Aspect ratio
  if (style.aspectRatio !== undefined) {
    lines.push(`${indent}  aspect_ratio: Some(${style.aspectRatio.toFixed(4)}),`);
  }

  lines.push(`${indent}}`);

  // Build children
  if (node.children.length > 0) {
    lines.push(`${indent}let ${varName}_children : Array[@node.Node] = []`);
    for (let i = 0; i < node.children.length; i++) {
      const child = node.children[i];
      const childVar = `${varName}_child${i}`;
      lines.push(...nodeToMoonBit(child, childVar, indent));
      lines.push(`${indent}${varName}_children.push(${childVar})`);
    }
    lines.push(`${indent}let ${varName} = @node.Node::new("${node.id}", ${varName}_style, ${varName}_children)`);
  } else if (node.measure) {
    // Leaf node with measure function
    const m = node.measure;
    lines.push(`${indent}let ${varName}_measure = @node.MeasureFunc::{`);
    lines.push(`${indent}  func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {`);
    lines.push(`${indent}    { min_width: ${m.minWidth.toFixed(1)}, max_width: ${m.maxWidth.toFixed(1)}, min_height: ${m.minHeight.toFixed(1)}, max_height: ${m.maxHeight.toFixed(1)} }`);
    lines.push(`${indent}  }`);
    lines.push(`${indent}}`);
    lines.push(`${indent}let ${varName} = @node.Node::with_measure("${node.id}", ${varName}_style, ${varName}_measure)`);
  } else {
    lines.push(`${indent}let ${varName} = @node.Node::leaf("${node.id}", ${varName}_style)`);
  }

  return lines;
}

function assertionsToMoonBit(node: NodeTestData, varPath: string, indent: string): string[] {
  const lines: string[] = [];
  const layout = node.layout;

  lines.push(`${indent}assert_approx(${varPath}.x, ${layout.x.toFixed(1)})`);
  lines.push(`${indent}assert_approx(${varPath}.y, ${layout.y.toFixed(1)})`);
  lines.push(`${indent}assert_approx(${varPath}.width, ${layout.width.toFixed(1)})`);
  lines.push(`${indent}assert_approx(${varPath}.height, ${layout.height.toFixed(1)})`);

  for (let i = 0; i < node.children.length; i++) {
    lines.push(...assertionsToMoonBit(node.children[i], `${varPath}.children[${i}]`, indent));
  }

  return lines;
}

function testCaseToMoonBit(tc: TestCase, layoutType: 'grid' | 'flex' | 'block' = 'grid'): string {
  const lines: string[] = [];

  lines.push('///|');
  lines.push(`test "taffy/${tc.name}" {`);

  // Build node tree
  lines.push(...nodeToMoonBit(tc.root, 'root', '  '));

  // Compute layout
  lines.push('');
  if (layoutType === 'flex') {
    lines.push(`  let ctx : @node.LayoutContext = { available_width: ${tc.viewport.width.toFixed(1)}, available_height: Some(${tc.viewport.height.toFixed(1)}), sizing_mode: @node.MaxContent }`);
    lines.push(`  let layout = compute(root, ctx)`);
  } else if (layoutType === 'block') {
    lines.push(`  let ctx : @node.LayoutContext = { available_width: ${tc.viewport.width.toFixed(1)}, available_height: Some(${tc.viewport.height.toFixed(1)}), sizing_mode: @node.MaxContent }`);
    lines.push(`  let layout = compute(root, ctx)`);
  } else {
    lines.push(`  let layout = compute_grid_layout(root, ${tc.viewport.width.toFixed(1)}, ${tc.viewport.height.toFixed(1)})`);
  }
  lines.push('');

  // Assertions
  lines.push(...assertionsToMoonBit(tc.root, 'layout', '  '));

  lines.push('}');

  return lines.join('\n');
}

async function main() {
  const args = process.argv.slice(2);

  // Parse options
  let layoutType: 'grid' | 'flex' | 'block' = 'grid';
  let noHeader = false;
  const positionalArgs: string[] = [];

  for (const arg of args) {
    if (arg === '--flex') {
      layoutType = 'flex';
    } else if (arg === '--grid') {
      layoutType = 'grid';
    } else if (arg === '--block') {
      layoutType = 'block';
    } else if (arg === '--no-header') {
      noHeader = true;
    } else {
      positionalArgs.push(arg);
    }
  }

  if (positionalArgs.length < 2) {
    console.log('Usage: npm run gen-moonbit-tests -- [options] <fixture-dir> <output-file> [pattern]');
    console.log('');
    console.log('Options:');
    console.log('  --flex       Generate tests using flex compute function');
    console.log('  --block      Generate tests using block compute function');
    console.log('  --grid       Generate tests using grid compute function (default)');
    console.log('  --no-header  Skip generating assert_approx helper (for additional test files)');
    console.log('');
    console.log('Examples:');
    console.log('  npm run gen-moonbit-tests -- fixtures/grid grid/gen_test.mbt');
    console.log('  npm run gen-moonbit-tests -- --flex fixtures/flex flex/gen_test.mbt');
    console.log('  npm run gen-moonbit-tests -- --block fixtures/block block/gen_test.mbt');
    console.log('  npm run gen-moonbit-tests -- --no-header fixtures/blockgrid grid/gen_blockgrid_test.mbt');
    process.exit(1);
  }

  const fixtureDir = positionalArgs[0];
  const outputFile = positionalArgs[1];
  const pattern = positionalArgs[2];

  if (!fs.existsSync(fixtureDir)) {
    console.error(`Error: Directory not found: ${fixtureDir}`);
    process.exit(1);
  }

  // Find all JSON files
  const files = fs.readdirSync(fixtureDir)
    .filter(f => f.endsWith('.json'))
    .filter(f => !pattern || f.includes(pattern))
    .sort();

  console.log(`Found ${files.length} JSON fixtures`);

  const tests: string[] = [];
  let skipped = 0;

  for (const file of files) {
    const jsonPath = path.join(fixtureDir, file);
    try {
      const content = fs.readFileSync(jsonPath, 'utf-8');
      const tc: TestCase = JSON.parse(content);

      // Skip tests that use unsupported features
      // Note: absolute positioning is now supported in grid
      const hasUnsupportedFeatures = (node: NodeTestData): boolean => {
        // Currently no features are skipped
        // Recursively check children
        return node.children.some(hasUnsupportedFeatures);
      };

      if (hasUnsupportedFeatures(tc.root)) {
        skipped++;
        continue;
      }

      tests.push(testCaseToMoonBit(tc, layoutType));
    } catch (err) {
      console.error(`Failed to process ${file}: ${err}`);
    }
  }

  // Write output
  const headerWithHelper = `// Auto-generated from taffy test fixtures
// DO NOT EDIT - regenerate with: npm run gen-moonbit-tests

///|
/// Helper for approximate floating point comparison (tolerance: 0.1)
fn assert_approx(actual : Double, expected : Double) -> Unit raise {
  let tolerance = 0.1
  let diff = if actual > expected { actual - expected } else { expected - actual }
  if diff > tolerance {
    raise Failure("assert_approx failed: actual=\\{actual}, expected=\\{expected}, diff=\\{diff}")
  }
}

`;
  const headerWithoutHelper = `// Auto-generated from taffy test fixtures
// DO NOT EDIT - regenerate with: npm run gen-moonbit-tests
// Uses assert_approx from main gen_test.mbt

`;
  const header = noHeader ? headerWithoutHelper : headerWithHelper;
  fs.writeFileSync(outputFile, header + tests.join('\n\n') + '\n');

  console.log(`Generated ${tests.length} tests, skipped ${skipped} (unsupported features)`);
  console.log(`Output written to: ${outputFile}`);
}

main().catch(console.error);
