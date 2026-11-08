import { defineConfig } from 'vite';
import { resolve } from 'node:path';

export default defineConfig({
  resolve: {
    alias: {
      // Map to MoonBit JS build output
      '@crater': resolve(import.meta.dirname, '../dist/crater.js')
    }
  },
  build: {
    outDir: 'dist'
  }
});
