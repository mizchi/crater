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
