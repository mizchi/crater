/**
 * Crater WASM-GC Module
 * Requires browser with WASM-GC support (Chrome 119+, Firefox 120+)
 */

export interface CraterWasm {
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
