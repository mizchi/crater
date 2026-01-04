/**
 * Crater WASM-GC Module
 * Requires browser with WASM-GC support (Chrome 119+, Firefox 120+)
 */

export interface CraterWasm {
  // ==========================================================================
  // Render API
  // ==========================================================================

  /**
   * Render HTML to text layout tree representation
   */
  renderHtml(html: string, width: number, height: number): string;

  /**
   * Render HTML to JSON layout tree
   */
  renderHtmlToJson(html: string, width: number, height: number): string;

  /**
   * Render HTML to paint tree JSON with colors
   */
  renderHtmlToPaintTree(html: string, width: number, height: number): string;

  /**
   * Render HTML to Sixel graphics
   */
  renderHtmlToSixel(html: string, width: number, height: number): string;

  /**
   * Render HTML to Sixel graphics with CSS colors
   */
  renderHtmlToSixelWithStyles(html: string, width: number, height: number): string;

  // ==========================================================================
  // Incremental Layout API
  // ==========================================================================

  /**
   * Create a new layout tree from HTML
   * @returns Tree ID
   */
  createTree(html: string, width: number, height: number): number;

  /**
   * Compute layout incrementally (uses cache when possible)
   * @returns JSON layout tree
   */
  computeIncremental(): string;

  /**
   * Compute full layout (ignores cache)
   * @returns JSON layout tree
   */
  computeFull(): string;

  /**
   * Mark a node as dirty by ID
   */
  markDirty(nodeId: string): boolean;

  /**
   * Update node style with CSS string
   */
  updateStyle(nodeId: string, css: string): boolean;

  /**
   * Resize viewport
   */
  resizeViewport(width: number, height: number): void;

  /**
   * Get cache statistics as JSON
   */
  getCacheStats(): string;

  /**
   * Reset cache statistics
   */
  resetCacheStats(): void;

  /**
   * Check if tree needs layout recomputation
   */
  needsLayout(): boolean;

  /**
   * Destroy the current tree
   */
  destroyTree(): void;

  // ==========================================================================
  // Yoga-compatible Node API
  // ==========================================================================

  /**
   * Create a new node with ID
   * @returns Node UID
   */
  createNode(id: string): number;

  /**
   * Add a child node to parent
   */
  addChild(parentId: string, childId: string): boolean;

  /**
   * Insert child at specific index
   */
  insertChild(parentId: string, childId: string, index: number): boolean;

  /**
   * Remove child at index
   */
  removeChild(parentId: string, index: number): boolean;

  /**
   * Get child count
   */
  getChildCount(nodeId: string): number;

  // ==========================================================================
  // Yoga-compatible Style Setters
  // ==========================================================================

  /**
   * Set width in pixels
   */
  setWidth(nodeId: string, value: number): boolean;

  /**
   * Set width as percentage (0-100)
   */
  setWidthPercent(nodeId: string, value: number): boolean;

  /**
   * Set width to auto
   */
  setWidthAuto(nodeId: string): boolean;

  /**
   * Set height in pixels
   */
  setHeight(nodeId: string, value: number): boolean;

  /**
   * Set height as percentage (0-100)
   */
  setHeightPercent(nodeId: string, value: number): boolean;

  /**
   * Set height to auto
   */
  setHeightAuto(nodeId: string): boolean;

  /**
   * Set flex grow
   */
  setFlexGrow(nodeId: string, value: number): boolean;

  /**
   * Set flex shrink
   */
  setFlexShrink(nodeId: string, value: number): boolean;

  /**
   * Set flex basis in pixels
   */
  setFlexBasis(nodeId: string, value: number): boolean;

  /**
   * Set flex direction
   * @param value - 0=row, 1=row-reverse, 2=column, 3=column-reverse
   */
  setFlexDirection(nodeId: string, value: number): boolean;

  /**
   * Set flex wrap
   * @param value - 0=no-wrap, 1=wrap, 2=wrap-reverse
   */
  setFlexWrap(nodeId: string, value: number): boolean;

  /**
   * Set justify content
   * @param value - 0=start, 1=end, 2=center, 3=space-between, 4=space-around, 5=space-evenly
   */
  setJustifyContent(nodeId: string, value: number): boolean;

  /**
   * Set align items
   * @param value - 0=start, 1=end, 2=center, 3=stretch, 4=baseline
   */
  setAlignItems(nodeId: string, value: number): boolean;

  /**
   * Set display
   * @param value - 0=flex, 1=none, 2=block, 3=grid
   */
  setDisplay(nodeId: string, value: number): boolean;

  /**
   * Set margin on all sides
   */
  setMargin(nodeId: string, value: number): boolean;

  /**
   * Set padding on all sides
   */
  setPadding(nodeId: string, value: number): boolean;

  /**
   * Set gap (row and column)
   */
  setGap(nodeId: string, value: number): boolean;

  // ==========================================================================
  // Yoga-compatible Layout Getters
  // ==========================================================================

  /**
   * Get computed X position (left)
   */
  getComputedLeft(nodeId: string): number;

  /**
   * Get computed Y position (top)
   */
  getComputedTop(nodeId: string): number;

  /**
   * Get computed width
   */
  getComputedWidth(nodeId: string): number;

  /**
   * Get computed height
   */
  getComputedHeight(nodeId: string): number;

  /**
   * Check if node has new layout
   */
  hasNewLayout(nodeId: string): boolean;

  /**
   * Mark layout as seen
   */
  markLayoutSeen(nodeId: string): boolean;

  /**
   * Calculate layout
   * @returns JSON layout tree
   */
  calculateLayout(width: number, height: number): string;

  /** Raw WASM instance */
  _instance: WebAssembly.Instance;

  /** Raw WASM memory */
  _memory: WebAssembly.Memory;
}

/**
 * Load and instantiate the Crater WASM module
 * @param wasmPath - Path to crater.wasm file (optional, defaults to ./crater.wasm)
 */
export function loadCrater(wasmPath?: string | URL | Request): Promise<CraterWasm>;

export default loadCrater;
