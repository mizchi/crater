import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  resolve: {
    alias: {
      // Map to MoonBit JS build output
      '@crater': resolve(__dirname, '../dist/crater.js')
    }
  },
  build: {
    outDir: 'dist'
  }
});
