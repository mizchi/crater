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
  webServer: {
    command: "just build-bidi && just start-bidi",
    url: "http://127.0.0.1:9222/",
    reuseExistingServer: true,
    timeout: 120000,
  },
});
