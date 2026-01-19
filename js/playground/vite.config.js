import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  resolve: {
    alias: {
      // Map to MoonBit JS build output
      '@crater': resolve(__dirname, '../../target/js/release/build/js/js.js')
    }
  },
  build: {
    outDir: 'dist'
  }
});
