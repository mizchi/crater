import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    testTimeout: 60000,
    hookTimeout: 60000,
    // Run tests sequentially - CDP server has single active context
    sequence: {
      concurrent: false,
    },
    pool: 'forks',
  },
});
