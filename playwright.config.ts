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
    launchOptions: {
      // Disable LCD subpixel anti-aliasing so the Chromium reference
      // uses grayscale AA, matching Crater's grayscale-only glyph
      // rasterizer. Without this, L2/L6/L19/R3 text-heavy fixtures
      // record large colored-fringe pixel diffs that have nothing to
      // do with glyph metrics. See issue #47 / paint.text-glyph-metrics.
      args: ["--disable-lcd-text", "--font-render-hinting=none"],
    },
  },
  webServer: {
    command: "just build-bidi && just start-bidi-with-font",
    url: "http://127.0.0.1:9222/",
    reuseExistingServer: true,
    timeout: 120000,
  },
});
