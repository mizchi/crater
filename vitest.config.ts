import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: [
      "scripts/**/*.test.ts",
    ],
    exclude: [
      "**/node_modules/**",
      "**/.mooncakes/**",
      "**/dist/**",
      "**/target/**",
      "**/output/**",
      "**/test-results/**",
      "**/*.test.mjs",
    ],
  },
});
