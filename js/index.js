// Re-export from MoonBit compiled JS
export {
  renderHtml,
  renderHtmlToJson,
  renderHtmlToPaintTree,
  renderHtmlToSixel,
  renderHtmlToSixelWithStyles,
} from './crater.js';

// Type-safe JSON parsing helpers
export const Crater = {
  /**
   * Parse layout JSON to typed LayoutNode
   * @param {string} json
   * @returns {import('./index').LayoutNode}
   */
  parseLayout(json) {
    return JSON.parse(json);
  },

  /**
   * Parse paint tree JSON to typed PaintNode
   * @param {string} json
   * @returns {import('./index').PaintNode}
   */
  parsePaintTree(json) {
    return JSON.parse(json);
  },
};
