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
  textAlign?: string;
  text_align?: string;
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
    case 'length': return `@types.TrackSizingFunction::Length(${track.value!.toFixed(1)})`;
    case 'percent': return `@types.TrackSizingFunction::Percent(${track.value!.toFixed(4)})`;
    case 'fr': return `@types.TrackSizingFunction::Fr(${track.value!.toFixed(1)})`;
    case 'auto': return '@types.TrackSizingFunction::Auto';
    case 'min-content': return '@types.TrackSizingFunction::MinContent';
    case 'max-content': return '@types.TrackSizingFunction::MaxContent';
    case 'fit-content-length': return `@types.FitContentLength(${track.value!.toFixed(1)})`;
    case 'fit-content-percent': return `@types.FitContentPercent(${track.value!.toFixed(4)})`;
    case 'minmax':
      const min = minTrackToMoonBit(track.min!);
      const max = maxTrackToMoonBit(track.max!);
      return `@types.TrackSizingFunction::MinMax(${min}, ${max})`;
    case 'repeat':
      const count = track.repeatCount === 'auto-fill' ? '@types.RepeatCount::AutoFill' :
                    track.repeatCount === 'auto-fit' ? '@types.RepeatCount::AutoFit' :
                    `@types.RepeatCount::Count(${track.repeatCount})`;
      const innerTracks = track.tracks!.map(t => singleTrackToMoonBit(t)).join(', ');
      return `@types.TrackSizingFunction::Repeat(${count}, [${innerTracks}])`;
    default:
      return '@types.TrackSizingFunction::Auto';
  }
}

function singleTrackToMoonBit(track: TrackSizing): string {
  switch (track.type) {
    case 'length': return `@types.SingleTrackSizing::Length(${track.value!.toFixed(1)})`;
    case 'percent': return `@types.SingleTrackSizing::Percent(${track.value!.toFixed(4)})`;
    case 'fr': return `@types.SingleTrackSizing::Fr(${track.value!.toFixed(1)})`;
    case 'auto': return '@types.SingleTrackSizing::Auto';
    case 'min-content': return '@types.SingleTrackSizing::MinContent';
    case 'max-content': return '@types.SingleTrackSizing::MaxContent';
    case 'fit-content-length': return `@types.SingleTrackSizing::FitContentLength(${track.value!.toFixed(1)})`;
    case 'fit-content-percent': return `@types.SingleTrackSizing::FitContentPercent(${track.value!.toFixed(4)})`;
    case 'minmax':
      const min = minTrackToMoonBit(track.min!);
      const max = maxTrackToMoonBit(track.max!);
      return `@types.SingleTrackSizing::MinMax(${min}, ${max})`;
    default:
      return '@types.SingleTrackSizing::Auto';
  }
}

function minTrackToMoonBit(track: TrackSizing): string {
  switch (track.type) {
    case 'length': return `@types.MinTrackSizing::Length(${track.value!.toFixed(1)})`;
    case 'percent': return `@types.MinTrackSizing::Percent(${track.value!.toFixed(4)})`;
    case 'auto': return '@types.MinTrackSizing::Auto';
    case 'min-content': return '@types.MinTrackSizing::MinContent';
    case 'max-content': return '@types.MinTrackSizing::MaxContent';
    default:
      return '@types.MinTrackSizing::Auto';
  }
}

function maxTrackToMoonBit(track: TrackSizing): string {
  switch (track.type) {
    case 'length': return `@types.MaxTrackSizing::Length(${track.value!.toFixed(1)})`;
    case 'percent': return `@types.MaxTrackSizing::Percent(${track.value!.toFixed(4)})`;
    case 'fr': return `@types.MaxTrackSizing::Fr(${track.value!.toFixed(1)})`;
    case 'auto': return '@types.MaxTrackSizing::Auto';
    case 'min-content': return '@types.MaxTrackSizing::MinContent';
    case 'max-content': return '@types.MaxTrackSizing::MaxContent';
    default:
      return '@types.MaxTrackSizing::Auto';
  }
}

function gridPlacementToMoonBit(placement: GridPlacement | undefined): string {
  if (!placement || placement.type === 'auto') return '@types.GridPlacement::Auto';
  if (placement.type === 'line') return `@types.GridPlacement::Line(${placement.value})`;
  if (placement.type === 'span') return `@types.GridPlacement::Span(${placement.value})`;
  return '@types.GridPlacement::Auto';
}

function gridLineToMoonBit(line: GridLine | undefined): string {
  if (!line) return '{ start: @types.GridPlacement::Auto, end: @types.GridPlacement::Auto }';
  return `{ start: ${gridPlacementToMoonBit(line.start)}, end: ${gridPlacementToMoonBit(line.end)} }`;
}

function alignmentToMoonBit(value: string | undefined): string {
  if (!value) return '@types.Start';
  switch (value) {
    case 'flex-start': return '@types.FlexStart';
    case 'start': return '@types.Start';
    case 'flex-end': return '@types.FlexEnd';
    case 'end': return '@types.End';
    case 'center': return '@types.Center';
    case 'space-between': return '@types.SpaceBetween';
    case 'space-around': return '@types.SpaceAround';
    case 'space-evenly': return '@types.SpaceEvenly';
    case 'stretch': return '@types.Stretch';
    case 'baseline': return '@types.Baseline';
    default: return '@types.Start';
  }
}

function alignSelfToMoonBit(value: string | undefined): string {
  if (!value) return '@types.AlignSelf::Auto';
  switch (value) {
    case 'auto': return '@types.AlignSelf::Auto';
    case 'flex-start':
    case 'start': return '@types.AlignSelf::Start';
    case 'flex-end':
    case 'end': return '@types.AlignSelf::End';
    case 'center': return '@types.AlignSelf::Center';
    case 'stretch': return '@types.AlignSelf::Stretch';
    case 'baseline': return '@types.AlignSelf::Baseline';
    default: return '@types.AlignSelf::Auto';
  }
}

function textAlignToMoonBit(value: string | undefined): string {
  if (!value) return '@style.TextAlign::Start';
  const normalized = value.toLowerCase().replace('_', '-');
  switch (normalized) {
    case 'center': return '@style.TextAlign::Center';
    case 'right': return '@style.TextAlign::Right';
    case 'left': return '@style.TextAlign::Left';
    case 'end': return '@style.TextAlign::End';
    case 'justify': return '@style.TextAlign::Justify';
    default: return '@style.TextAlign::Start';
  }
}

function gridAutoFlowToMoonBit(value: string | undefined): string {
  if (!value) return '@types.GridAutoFlow::Row';
  switch (value) {
    case 'row': return '@types.GridAutoFlow::Row';
    case 'column': return '@types.GridAutoFlow::Column';
    case 'row dense': return '@types.GridAutoFlow::RowDense';
    case 'column dense': return '@types.GridAutoFlow::ColumnDense';
    default: return '@types.GridAutoFlow::Row';
  }
}

function positionToMoonBit(value: string | undefined): string {
  if (!value || value === 'relative') return '@types.Position::Relative';
  if (value === 'absolute') return '@types.Position::Absolute';
  return '@types.Position::Relative';
}

function overflowToMoonBit(value: string | undefined): string {
  if (!value || value === 'visible') return '@types.Overflow::Visible';
  if (value === 'hidden') return '@types.Overflow::Hidden';
  if (value === 'scroll') return '@types.Overflow::Scroll';
  if (value === 'auto') return '@types.Overflow::Auto';
  return '@types.Overflow::Visible';
}

function hasFlexStyleProps(style: NodeStyle): boolean {
  return !!(
    style.flexDirection || style.flexWrap ||
    style.flexGrow !== undefined || style.flexShrink !== undefined ||
    style.flexBasis || style.justifyContent || style.alignItems ||
    style.alignContent || style.alignSelf || style.gap ||
    style.rowGap || style.columnGap
  );
}

function layoutLooksLikeRowFlex(node: NodeTestData): boolean {
  if (node.children.length < 2) return false;
  let totalWidth = 0;
  let hasNonZeroX = false;
  let hasNonZeroY = false;
  let allZeroWidth = true;
  let allXZero = true;
  let hasVerticalOverlap = false;
  let maxBlockBottom = -Infinity;
  for (const child of node.children) {
    totalWidth += child.layout.width;
    if (Math.abs(child.layout.x) > 0.1) {
      hasNonZeroX = true;
      allXZero = false;
    }
    if (Math.abs(child.layout.y) > 0.1) hasNonZeroY = true;
    if (Math.abs(child.layout.width) > 0.1) allZeroWidth = false;
    if (child.layout.y + 0.1 < maxBlockBottom) hasVerticalOverlap = true;
    maxBlockBottom = Math.max(maxBlockBottom, child.layout.y + child.layout.height);
  }
  const horizontalRow = hasNonZeroX &&
    !hasNonZeroY &&
    Math.abs(totalWidth - node.layout.width) <= 0.1;
  const zeroWidthOverlappingRow = allXZero && allZeroWidth && hasVerticalOverlap;
  return horizontalRow || zeroWidthOverlappingRow;
}

function nodeToMoonBit(
  node: NodeTestData,
  varName: string,
  indent: string,
  layoutType: 'grid' | 'flex' | 'block',
): string[] {
  const lines: string[] = [];
  const style = node.style;

  // Build style
  lines.push(`${indent}let ${varName}_style = {`);
  lines.push(`${indent}  ..@style.Style::default(),`);

  // Determine display type
  // If flex-related properties exist, imply display: flex
  const hasFlexProps = hasFlexStyleProps(style);
  const hasFlexItemChild = node.children.some(child => hasFlexStyleProps(child.style));

  const displayIsFlex = style.display === 'flex' ||
    (style.display === undefined && (hasFlexProps || hasFlexItemChild || layoutType !== 'block' || layoutLooksLikeRowFlex(node)));

  if (style.display === 'grid') {
    lines.push(`${indent}  display: @types.Grid,`);
  } else if (style.display === 'block') {
    lines.push(`${indent}  display: @types.Block,`);
  } else if (displayIsFlex) {
    lines.push(`${indent}  display: @types.Flex,`);
  } else if (style.display === 'none') {
    lines.push(`${indent}  display: @types.Display::None,`);
  }

  // Taffy defaults to position: relative, while Crater's CSS style default is
  // position: static. Emit the position explicitly so regenerated compat tests
  // preserve Taffy's coordinate model even when the fixture omits it.
  lines.push(`${indent}  position: ${positionToMoonBit(style.position)},`);

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
  } else if (displayIsFlex) {
    lines.push(`${indent}  justify_content: @types.FlexStart,`);
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
  const textAlign = style.textAlign || style.text_align;
  if (textAlign) {
    lines.push(`${indent}  text_align: ${textAlignToMoonBit(textAlign)},`);
  }

  // Inset
  if (style.inset) {
    lines.push(`${indent}  inset: ${insetEdgesToMoonBit(style.inset)},`);
  }

  // Flex container properties
  if (style.flexDirection) {
    const dir = style.flexDirection;
    if (dir === 'row') lines.push(`${indent}  flex_direction: @types.Row,`);
    else if (dir === 'row-reverse') lines.push(`${indent}  flex_direction: @types.RowReverse,`);
    else if (dir === 'column') lines.push(`${indent}  flex_direction: @types.Column,`);
    else if (dir === 'column-reverse') lines.push(`${indent}  flex_direction: @types.ColumnReverse,`);
  }
  if (style.flexWrap) {
    const wrap = style.flexWrap;
    if (wrap === 'wrap') lines.push(`${indent}  flex_wrap: @types.Wrap,`);
    else if (wrap === 'wrap-reverse') lines.push(`${indent}  flex_wrap: @types.WrapReverse,`);
    else if (wrap === 'nowrap') lines.push(`${indent}  flex_wrap: @types.NoWrap,`);
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
      lines.push(...nodeToMoonBit(child, childVar, indent, layoutType));
      lines.push(`${indent}${varName}_children.push(${childVar})`);
    }
    lines.push(`${indent}let ${varName} = @node.Node::new("${node.id}", ${varName}_style, ${varName}_children)`);
  } else if (node.measure) {
    // Leaf node with measure function
    const m = node.measure;
    lines.push(`${indent}let ${varName}_measure = @node.MeasureFunc::{`);
    lines.push(`${indent}  func: fn(w : Double, _h : Double) -> @types.IntrinsicSize {`);
    lines.push(`${indent}    let measured_max_height = if (w - ${node.layout.width.toFixed(1)}).abs() < 0.1 { ${node.layout.height.toFixed(1)} } else { ${m.maxHeight.toFixed(1)} }`);
    lines.push(`${indent}    { min_width: ${m.minWidth.toFixed(1)}, max_width: ${m.maxWidth.toFixed(1)}, min_height: ${m.minHeight.toFixed(1)}, max_height: measured_max_height }`);
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
  const expectedX = varPath === 'layout' ? 0 : layout.x;
  const expectedY = varPath === 'layout' ? 0 : layout.y;

  lines.push(`${indent}assert_approx(${varPath}.x, ${expectedX.toFixed(1)})`);
  lines.push(`${indent}assert_approx(${varPath}.y, ${expectedY.toFixed(1)})`);
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
  lines.push(...nodeToMoonBit(tc.root, 'root', '  ', layoutType));

  // Compute layout
  lines.push('');
  if (layoutType === 'flex') {
    lines.push(`  let ctx : @types.LayoutContext = { available_width: ${tc.viewport.width.toFixed(1)}, available_height: Some(${tc.viewport.height.toFixed(1)}), sizing_mode: @types.MaxContent, viewport_width: ${tc.viewport.width.toFixed(1)}, viewport_height: ${tc.viewport.height.toFixed(1)}, stretch_width: false, stretch_height: false }`);
    lines.push(`  let layout = @node.compute_flex_layout_with_dispatch(root, ctx, default_dispatch())`);
  } else if (layoutType === 'block') {
    lines.push(`  let ctx : @types.LayoutContext = { available_width: ${tc.viewport.width.toFixed(1)}, available_height: Some(${tc.viewport.height.toFixed(1)}), sizing_mode: @types.MaxContent, viewport_width: ${tc.viewport.width.toFixed(1)}, viewport_height: ${tc.viewport.height.toFixed(1)}, stretch_width: false, stretch_height: false }`);
    lines.push(`  let layout = compute_root_layout(root, ctx)`);
  } else {
    lines.push(`  let layout = compute_root_layout_size(root, ${tc.viewport.width.toFixed(1)}, ${tc.viewport.height.toFixed(1)})`);
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
  const excludePatterns: string[] = [];
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
    } else if (arg.startsWith('--exclude=')) {
      // Support comma-separated patterns: --exclude=display_none,baseline
      const patterns = arg.split('=')[1].split(',');
      excludePatterns.push(...patterns);
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
    console.log('  --exclude=P  Exclude tests matching pattern P (comma-separated for multiple)');
    console.log('');
    console.log('Examples:');
    console.log('  npm run gen-moonbit-tests -- fixtures/grid grid/gen_test.mbt');
    console.log('  npm run gen-moonbit-tests -- --flex fixtures/flex flex/gen_test.mbt');
    console.log('  npm run gen-moonbit-tests -- --block fixtures/block block/gen_test.mbt');
    console.log('  npm run gen-moonbit-tests -- --flex --exclude=display_none fixtures/flex flex/gen_test.mbt');
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
    .filter(f => {
      // Apply exclude patterns to filename (without .json)
      const name = f.replace('.json', '');
      return !excludePatterns.some(p => name.includes(p));
    })
    .sort();

  const excluded = excludePatterns.length > 0 ? ` (excluding: ${excludePatterns.join(', ')})` : '';
  console.log(`Found ${files.length} JSON fixtures${excluded}`);

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
