/**
 * Crater - CSS Layout Engine
 * TypeScript type definitions
 */

/** Box model edges (margin, padding, border) */
export interface BoxEdges {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

/** Layout node in the layout tree */
export interface LayoutNode {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  margin: BoxEdges;
  padding: BoxEdges;
  border: BoxEdges;
  children: LayoutNode[];
}

/** Paint node with visual properties */
export interface PaintNode {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  backgroundColor: string;
  color: string;
  opacity: number;
  text?: string;
  children: PaintNode[];
}

/**
 * Render HTML to layout tree (text representation)
 * @param html - HTML string with inline styles
 * @param width - Viewport width in pixels
 * @param height - Viewport height in pixels
 * @returns Text representation of layout tree
 */
export function renderHtml(html: string, width: number, height: number): string;

/**
 * Render HTML to JSON layout tree
 * @param html - HTML string with inline styles
 * @param width - Viewport width in pixels
 * @param height - Viewport height in pixels
 * @returns JSON string of LayoutNode tree
 */
export function renderHtmlToJson(html: string, width: number, height: number): string;

/**
 * Render HTML to paint tree with visual properties
 * @param html - HTML string with inline styles
 * @param width - Viewport width in pixels
 * @param height - Viewport height in pixels
 * @returns JSON string of PaintNode tree
 */
export function renderHtmlToPaintTree(html: string, width: number, height: number): string;

/**
 * Render HTML to Sixel graphics string
 * @param html - HTML string with inline styles
 * @param width - Viewport width in pixels
 * @param height - Viewport height in pixels
 * @returns Sixel graphics string for terminal display
 */
export function renderHtmlToSixel(html: string, width: number, height: number): string;

/**
 * Render HTML to Sixel graphics with actual CSS colors
 * @param html - HTML string with inline styles
 * @param width - Viewport width in pixels
 * @param height - Viewport height in pixels
 * @returns Sixel graphics string with CSS colors
 */
export function renderHtmlToSixelWithStyles(html: string, width: number, height: number): string;

// =============================================================================
// Incremental Layout API
// =============================================================================

/** Cache statistics for performance tracking */
export interface CacheStats {
  hits: number;
  misses: number;
  nodesComputed: number;
  hitRate: number;
}

/**
 * Create a new layout tree from HTML
 * @param html - HTML string with inline styles
 * @param width - Viewport width in pixels
 * @param height - Viewport height in pixels
 * @returns Tree ID (always 0 for single tree)
 */
export function createTree(html: string, width: number, height: number): number;

/**
 * Compute layout incrementally (uses cache when possible)
 * @returns JSON string of layout tree
 */
export function computeIncremental(): string;

/**
 * Compute full layout (ignores cache)
 * @returns JSON string of layout tree
 */
export function computeFull(): string;

/**
 * Mark a node as dirty by ID
 * @param nodeId - Node ID to mark dirty
 * @returns true if node was found and marked
 */
export function markDirty(nodeId: string): boolean;

/**
 * Update node style with CSS string
 * @param nodeId - Node ID to update
 * @param css - CSS string (e.g., "width: 100px; display: flex")
 * @returns true if successful
 */
export function updateStyle(nodeId: string, css: string): boolean;

/**
 * Resize viewport
 * @param width - New viewport width
 * @param height - New viewport height
 */
export function resizeViewport(width: number, height: number): void;

/**
 * Get cache statistics as JSON
 * @returns JSON string of CacheStats
 */
export function getCacheStats(): string;

/**
 * Reset cache statistics
 */
export function resetCacheStats(): void;

/**
 * Check if tree needs layout recomputation
 * @returns true if any node is dirty
 */
export function needsLayout(): boolean;

/**
 * Destroy the current tree and free resources
 */
export function destroyTree(): void;

// =============================================================================
// Yoga-compatible Node API
// =============================================================================

/** Flex direction values */
export const enum FlexDirection {
  Row = 0,
  RowReverse = 1,
  Column = 2,
  ColumnReverse = 3,
}

/** Flex wrap values */
export const enum FlexWrap {
  NoWrap = 0,
  Wrap = 1,
  WrapReverse = 2,
}

/** Justify content values */
export const enum JustifyContent {
  FlexStart = 0,
  FlexEnd = 1,
  Center = 2,
  SpaceBetween = 3,
  SpaceAround = 4,
  SpaceEvenly = 5,
}

/** Align items values */
export const enum AlignItems {
  FlexStart = 0,
  FlexEnd = 1,
  Center = 2,
  Stretch = 3,
  Baseline = 4,
}

/** Display values */
export const enum Display {
  Flex = 0,
  None = 1,
  Block = 2,
  Grid = 3,
}

/**
 * Create a new node with ID
 * @param id - Node identifier
 * @returns Node UID
 */
export function createNode(id: string): number;

/**
 * Add a child node to parent (appends to end)
 * @param parentId - Parent node ID
 * @param childId - Child node ID
 * @returns true if successful
 */
export function addChild(parentId: string, childId: string): boolean;

/**
 * Insert child at specific index
 * @param parentId - Parent node ID
 * @param childId - Child node ID
 * @param index - Index to insert at
 * @returns true if successful
 */
export function insertChild(parentId: string, childId: string, index: number): boolean;

/**
 * Remove child at index
 * @param parentId - Parent node ID
 * @param index - Index of child to remove
 * @returns true if successful
 */
export function removeChild(parentId: string, index: number): boolean;

/**
 * Get child count
 * @param nodeId - Node ID
 * @returns Number of children
 */
export function getChildCount(nodeId: string): number;

// =============================================================================
// Yoga-compatible Style Setters
// =============================================================================

/**
 * Set width in pixels
 */
export function setWidth(nodeId: string, value: number): boolean;

/**
 * Set width as percentage (0-100)
 */
export function setWidthPercent(nodeId: string, value: number): boolean;

/**
 * Set width to auto
 */
export function setWidthAuto(nodeId: string): boolean;

/**
 * Set height in pixels
 */
export function setHeight(nodeId: string, value: number): boolean;

/**
 * Set height as percentage (0-100)
 */
export function setHeightPercent(nodeId: string, value: number): boolean;

/**
 * Set height to auto
 */
export function setHeightAuto(nodeId: string): boolean;

/**
 * Set flex grow
 */
export function setFlexGrow(nodeId: string, value: number): boolean;

/**
 * Set flex shrink
 */
export function setFlexShrink(nodeId: string, value: number): boolean;

/**
 * Set flex basis in pixels
 */
export function setFlexBasis(nodeId: string, value: number): boolean;

/**
 * Set flex direction
 * @param value - 0=row, 1=row-reverse, 2=column, 3=column-reverse
 */
export function setFlexDirection(nodeId: string, value: FlexDirection | number): boolean;

/**
 * Set flex wrap
 * @param value - 0=no-wrap, 1=wrap, 2=wrap-reverse
 */
export function setFlexWrap(nodeId: string, value: FlexWrap | number): boolean;

/**
 * Set justify content
 * @param value - 0=start, 1=end, 2=center, 3=space-between, 4=space-around, 5=space-evenly
 */
export function setJustifyContent(nodeId: string, value: JustifyContent | number): boolean;

/**
 * Set align items
 * @param value - 0=start, 1=end, 2=center, 3=stretch, 4=baseline
 */
export function setAlignItems(nodeId: string, value: AlignItems | number): boolean;

/**
 * Set display
 * @param value - 0=flex, 1=none, 2=block, 3=grid
 */
export function setDisplay(nodeId: string, value: Display | number): boolean;

/**
 * Set margin on all sides
 */
export function setMargin(nodeId: string, value: number): boolean;

/**
 * Set padding on all sides
 */
export function setPadding(nodeId: string, value: number): boolean;

/**
 * Set gap (row and column)
 */
export function setGap(nodeId: string, value: number): boolean;

// =============================================================================
// Yoga-compatible Layout Getters
// =============================================================================

/**
 * Get computed X position (left)
 */
export function getComputedLeft(nodeId: string): number;

/**
 * Get computed Y position (top)
 */
export function getComputedTop(nodeId: string): number;

/**
 * Get computed width
 */
export function getComputedWidth(nodeId: string): number;

/**
 * Get computed height
 */
export function getComputedHeight(nodeId: string): number;

/**
 * Check if node has new layout
 */
export function hasNewLayout(nodeId: string): boolean;

/**
 * Mark layout as seen
 */
export function markLayoutSeen(nodeId: string): boolean;

/**
 * Calculate layout (Yoga-compatible name)
 * @param width - Available width
 * @param height - Available height
 * @returns JSON string of layout tree
 */
export function calculateLayout(width: number, height: number): string;

// =============================================================================
// Accessibility API
// =============================================================================

/** Accessibility node in the tree */
export interface AccessibilityNode {
  id: string;
  role: string;
  name?: string;
  level?: number;
  states?: string[];
  children?: AccessibilityNode[];
}

/**
 * Get ARIA snapshot in YAML format (Playwright-compatible)
 * @param html - HTML string
 * @returns YAML-formatted ARIA snapshot
 */
export function getAriaSnapshot(html: string): string;

/**
 * Get ARIA snapshot in JSON format
 * @param html - HTML string
 * @returns JSON-formatted ARIA snapshot
 */
export function getAriaSnapshotJson(html: string): string;

/**
 * Get full accessibility tree as JSON
 * @param html - HTML string
 * @returns JSON string of AccessibilityNode tree
 */
export function getAccessibilityTree(html: string): string;

// Type-safe JSON parsing helpers
export namespace Crater {
  /**
   * Parse layout JSON to typed LayoutNode
   */
  export function parseLayout(json: string): LayoutNode;

  /**
   * Parse paint tree JSON to typed PaintNode
   */
  export function parsePaintTree(json: string): PaintNode;

  /**
   * Parse cache stats JSON to typed CacheStats
   */
  export function parseCacheStats(json: string): CacheStats;
}
