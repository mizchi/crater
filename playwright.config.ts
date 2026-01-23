import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  testMatch: "**/*.test.ts",
  fullyParallel: false, // Run tests serially since they share the BiDi server
  retries: 0,
  workers: 1,
  reporter: "list",
  timeout: 10000,
  use: {
    trace: "on-first-retry",
  },
});
