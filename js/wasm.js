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

    /** Raw WASM instance */
    _instance: instance,
    /** Raw WASM memory */
    _memory: memory,
  };
}

export default loadCrater;
