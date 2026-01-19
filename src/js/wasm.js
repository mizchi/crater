// WASM-GC loader for Crater
// Requires browser with WASM-GC support (Chrome 119+, Firefox 120+)

/**
 * Load and instantiate the Crater WASM module
 * @param {string | URL | Request} [wasmPath] - Path to crater.wasm file
 * @returns {Promise<CraterWasm>}
 */
export async function loadCrater(wasmPath) {
  const path = wasmPath || new URL('./crater.wasm', import.meta.url);

  const { instance } = await WebAssembly.instantiateStreaming(
    fetch(path),
    {}
  );

  const exports = instance.exports;
  const memory = exports.memory;
  const decoder = new TextDecoder();
  const encoder = new TextEncoder();

  /**
   * Allocate string in WASM memory and return pointer
   * @param {string} str
   * @returns {number}
   */
  function allocString(str) {
    const bytes = encoder.encode(str);
    const ptr = exports.moonbit_string_alloc(bytes.length);
    const view = new Uint8Array(memory.buffer, ptr, bytes.length);
    view.set(bytes);
    return ptr;
  }

  /**
   * Read string from WASM memory
   * @param {number} ptr
   * @returns {string}
   */
  function readString(ptr) {
    const view = new DataView(memory.buffer);
    const len = view.getInt32(ptr - 4, true);
    const bytes = new Uint8Array(memory.buffer, ptr, len);
    return decoder.decode(bytes);
  }

  return {
    // ==========================================================================
    // Render API
    // ==========================================================================

    /**
     * Render HTML to text layout tree representation
     * @param {string} html
     * @param {number} width
     * @param {number} height
     * @returns {string}
     */
    renderHtml(html, width, height) {
      const htmlPtr = allocString(html);
      const resultPtr = exports.renderHtml(htmlPtr, width, height);
      return readString(resultPtr);
    },

    /**
     * Render HTML to JSON layout tree
     * @param {string} html
     * @param {number} width
     * @param {number} height
     * @returns {string}
     */
    renderHtmlToJson(html, width, height) {
      const htmlPtr = allocString(html);
      const resultPtr = exports.renderHtmlToJson(htmlPtr, width, height);
      return readString(resultPtr);
    },

    /**
     * Render HTML to paint tree JSON with colors
     * @param {string} html
     * @param {number} width
     * @param {number} height
     * @returns {string}
     */
    renderHtmlToPaintTree(html, width, height) {
      const htmlPtr = allocString(html);
      const resultPtr = exports.renderHtmlToPaintTree(htmlPtr, width, height);
      return readString(resultPtr);
    },

    /**
     * Render HTML to Sixel graphics
     * @param {string} html
     * @param {number} width
     * @param {number} height
     * @returns {string}
     */
    renderHtmlToSixel(html, width, height) {
      const htmlPtr = allocString(html);
      const resultPtr = exports.renderHtmlToSixel(htmlPtr, width, height);
      return readString(resultPtr);
    },

    /**
     * Render HTML to Sixel graphics with CSS colors
     * @param {string} html
     * @param {number} width
     * @param {number} height
     * @returns {string}
     */
    renderHtmlToSixelWithStyles(html, width, height) {
      const htmlPtr = allocString(html);
      const resultPtr = exports.renderHtmlToSixelWithStyles(htmlPtr, width, height);
      return readString(resultPtr);
    },

    // ==========================================================================
    // Incremental Layout API
    // ==========================================================================

    /**
     * Create a new layout tree from HTML
     * @param {string} html
     * @param {number} width
     * @param {number} height
     * @returns {number} Tree ID
     */
    createTree(html, width, height) {
      const htmlPtr = allocString(html);
      return exports.createTree(htmlPtr, width, height);
    },

    /**
     * Compute layout incrementally (uses cache when possible)
     * @returns {string} JSON layout tree
     */
    computeIncremental() {
      const resultPtr = exports.computeIncremental();
      return readString(resultPtr);
    },

    /**
     * Compute full layout (ignores cache)
     * @returns {string} JSON layout tree
     */
    computeFull() {
      const resultPtr = exports.computeFull();
      return readString(resultPtr);
    },

    /**
     * Mark a node as dirty by ID
     * @param {string} nodeId
     * @returns {boolean}
     */
    markDirty(nodeId) {
      const idPtr = allocString(nodeId);
      return !!exports.markDirty(idPtr);
    },

    /**
     * Update node style with CSS string
     * @param {string} nodeId
     * @param {string} css
     * @returns {boolean}
     */
    updateStyle(nodeId, css) {
      const idPtr = allocString(nodeId);
      const cssPtr = allocString(css);
      return !!exports.updateStyle(idPtr, cssPtr);
    },

    /**
     * Resize viewport
     * @param {number} width
     * @param {number} height
     */
    resizeViewport(width, height) {
      exports.resizeViewport(width, height);
    },

    /**
     * Get cache statistics as JSON
     * @returns {string}
     */
    getCacheStats() {
      const resultPtr = exports.getCacheStats();
      return readString(resultPtr);
    },

    /**
     * Reset cache statistics
     */
    resetCacheStats() {
      exports.resetCacheStats();
    },

    /**
     * Check if tree needs layout recomputation
     * @returns {boolean}
     */
    needsLayout() {
      return !!exports.needsLayout();
    },

    /**
     * Destroy the current tree
     */
    destroyTree() {
      exports.destroyTree();
    },

    // ==========================================================================
    // Yoga-compatible Node API
    // ==========================================================================

    /**
     * Create a new node with ID
     * @param {string} id
     * @returns {number} Node UID
     */
    createNode(id) {
      const idPtr = allocString(id);
      return exports.createNode(idPtr);
    },

    /**
     * Add a child node to parent
     * @param {string} parentId
     * @param {string} childId
     * @returns {boolean}
     */
    addChild(parentId, childId) {
      const parentPtr = allocString(parentId);
      const childPtr = allocString(childId);
      return !!exports.addChild(parentPtr, childPtr);
    },

    /**
     * Insert child at specific index
     * @param {string} parentId
     * @param {string} childId
     * @param {number} index
     * @returns {boolean}
     */
    insertChild(parentId, childId, index) {
      const parentPtr = allocString(parentId);
      const childPtr = allocString(childId);
      return !!exports.insertChild(parentPtr, childPtr, index);
    },

    /**
     * Remove child at index
     * @param {string} parentId
     * @param {number} index
     * @returns {boolean}
     */
    removeChild(parentId, index) {
      const parentPtr = allocString(parentId);
      return !!exports.removeChild(parentPtr, index);
    },

    /**
     * Get child count
     * @param {string} nodeId
     * @returns {number}
     */
    getChildCount(nodeId) {
      const idPtr = allocString(nodeId);
      return exports.getChildCount(idPtr);
    },

    // ==========================================================================
    // Yoga-compatible Style Setters
    // ==========================================================================

    /**
     * Set width in pixels
     * @param {string} nodeId
     * @param {number} value
     * @returns {boolean}
     */
    setWidth(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setWidth(idPtr, value);
    },

    /**
     * Set width as percentage (0-100)
     * @param {string} nodeId
     * @param {number} value
     * @returns {boolean}
     */
    setWidthPercent(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setWidthPercent(idPtr, value);
    },

    /**
     * Set width to auto
     * @param {string} nodeId
     * @returns {boolean}
     */
    setWidthAuto(nodeId) {
      const idPtr = allocString(nodeId);
      return !!exports.setWidthAuto(idPtr);
    },

    /**
     * Set height in pixels
     * @param {string} nodeId
     * @param {number} value
     * @returns {boolean}
     */
    setHeight(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setHeight(idPtr, value);
    },

    /**
     * Set height as percentage (0-100)
     * @param {string} nodeId
     * @param {number} value
     * @returns {boolean}
     */
    setHeightPercent(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setHeightPercent(idPtr, value);
    },

    /**
     * Set height to auto
     * @param {string} nodeId
     * @returns {boolean}
     */
    setHeightAuto(nodeId) {
      const idPtr = allocString(nodeId);
      return !!exports.setHeightAuto(idPtr);
    },

    /**
     * Set flex grow
     * @param {string} nodeId
     * @param {number} value
     * @returns {boolean}
     */
    setFlexGrow(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setFlexGrow(idPtr, value);
    },

    /**
     * Set flex shrink
     * @param {string} nodeId
     * @param {number} value
     * @returns {boolean}
     */
    setFlexShrink(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setFlexShrink(idPtr, value);
    },

    /**
     * Set flex basis in pixels
     * @param {string} nodeId
     * @param {number} value
     * @returns {boolean}
     */
    setFlexBasis(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setFlexBasis(idPtr, value);
    },

    /**
     * Set flex direction
     * @param {string} nodeId
     * @param {number} value - 0=row, 1=row-reverse, 2=column, 3=column-reverse
     * @returns {boolean}
     */
    setFlexDirection(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setFlexDirection(idPtr, value);
    },

    /**
     * Set flex wrap
     * @param {string} nodeId
     * @param {number} value - 0=no-wrap, 1=wrap, 2=wrap-reverse
     * @returns {boolean}
     */
    setFlexWrap(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setFlexWrap(idPtr, value);
    },

    /**
     * Set justify content
     * @param {string} nodeId
     * @param {number} value - 0=start, 1=end, 2=center, 3=space-between, 4=space-around, 5=space-evenly
     * @returns {boolean}
     */
    setJustifyContent(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setJustifyContent(idPtr, value);
    },

    /**
     * Set align items
     * @param {string} nodeId
     * @param {number} value - 0=start, 1=end, 2=center, 3=stretch, 4=baseline
     * @returns {boolean}
     */
    setAlignItems(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setAlignItems(idPtr, value);
    },

    /**
     * Set display
     * @param {string} nodeId
     * @param {number} value - 0=flex, 1=none, 2=block, 3=grid
     * @returns {boolean}
     */
    setDisplay(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setDisplay(idPtr, value);
    },

    /**
     * Set margin on all sides
     * @param {string} nodeId
     * @param {number} value
     * @returns {boolean}
     */
    setMargin(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setMargin(idPtr, value);
    },

    /**
     * Set padding on all sides
     * @param {string} nodeId
     * @param {number} value
     * @returns {boolean}
     */
    setPadding(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setPadding(idPtr, value);
    },

    /**
     * Set gap (row and column)
     * @param {string} nodeId
     * @param {number} value
     * @returns {boolean}
     */
    setGap(nodeId, value) {
      const idPtr = allocString(nodeId);
      return !!exports.setGap(idPtr, value);
    },

    // ==========================================================================
    // Yoga-compatible Layout Getters
    // ==========================================================================

    /**
     * Get computed X position (left)
     * @param {string} nodeId
     * @returns {number}
     */
    getComputedLeft(nodeId) {
      const idPtr = allocString(nodeId);
      return exports.getComputedLeft(idPtr);
    },

    /**
     * Get computed Y position (top)
     * @param {string} nodeId
     * @returns {number}
     */
    getComputedTop(nodeId) {
      const idPtr = allocString(nodeId);
      return exports.getComputedTop(idPtr);
    },

    /**
     * Get computed width
     * @param {string} nodeId
     * @returns {number}
     */
    getComputedWidth(nodeId) {
      const idPtr = allocString(nodeId);
      return exports.getComputedWidth(idPtr);
    },

    /**
     * Get computed height
     * @param {string} nodeId
     * @returns {number}
     */
    getComputedHeight(nodeId) {
      const idPtr = allocString(nodeId);
      return exports.getComputedHeight(idPtr);
    },

    /**
     * Check if node has new layout
     * @param {string} nodeId
     * @returns {boolean}
     */
    hasNewLayout(nodeId) {
      const idPtr = allocString(nodeId);
      return !!exports.hasNewLayout(idPtr);
    },

    /**
     * Mark layout as seen
     * @param {string} nodeId
     * @returns {boolean}
     */
    markLayoutSeen(nodeId) {
      const idPtr = allocString(nodeId);
      return !!exports.markLayoutSeen(idPtr);
    },

    /**
     * Calculate layout
     * @param {number} width
     * @param {number} height
     * @returns {string} JSON layout tree
     */
    calculateLayout(width, height) {
      const resultPtr = exports.calculateLayout(width, height);
      return readString(resultPtr);
    },

    /** Raw WASM instance */
    _instance: instance,
    /** Raw WASM memory */
    _memory: memory,
  };
}

export default loadCrater;
