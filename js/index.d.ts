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
}
