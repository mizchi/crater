import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, test } from "vitest";
import { extractWorkflowJob, extractWorkflowStep } from "./ci-workflow-test-helpers";

function readRepoFile(relativePath: string): string {
  return readFileSync(new URL(`../${relativePath}`, import.meta.url), "utf8");
}

describe("CI compatible font setup", () => {
  test("installs compatible fonts in VRT jobs", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");
    const matches = workflow.match(/bash scripts\/ci\/install-compatible-fonts\.sh/g) ?? [];
    expect(matches).toHaveLength(2);
  });

  test("restores Playwright browser cache for browser-backed workflows", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");
    const browserJobs = [
      ["js-package", "js_chromium_present", "Install Chromium (Playwright) for the browser gates"],
      ["wpt-css-tests", "wpt_css_chromium_present", "Install Chromium (Playwright) for the WPT runner"],
      ["playwright-bidi-tests", "playwright_bidi_chromium_present", "Install Playwright Chromium browser"],
      ["playwright-paint-vrt", "paint_vrt_chromium_present", "Install Playwright browsers for VRT"],
      ["playwright-wpt-vrt", "wpt_vrt_chromium_present", "Install Playwright browsers for VRT"],
    ];
    for (const [jobName, detectorId, installName] of browserJobs) {
      const job = extractWorkflowJob(workflow, jobName);
      const restore = extractWorkflowStep(job, "Restore Playwright Chromium browser cache");
      const detect = extractWorkflowStep(job, "Detect cached Chromium browser");
      const install = extractWorkflowStep(job, installName);

      expect(restore, jobName).toContain("uses: actions/cache@");
      expect(restore, jobName).toContain("path: ~/.cache/ms-playwright");
      expect(restore, jobName).toContain("restore-keys:");
      expect(detect, jobName).toContain(`id: ${detectorId}`);
      expect(detect, jobName).toContain("bash scripts/ci/chromium-cache-present.sh");
      // Partial cache restores can contain Chromium even without an exact key hit.
      expect(install, jobName).toContain(`steps.${detectorId}.outputs.present != 'true'`);
      expect(install, jobName).not.toContain(".outputs.cache-hit");
      expect(install, jobName).toContain("run: bash scripts/ci/install-playwright-chromium.sh");
      expect(job.indexOf(restore), jobName).toBeLessThan(job.indexOf(detect));
      expect(job.indexOf(detect), jobName).toBeLessThan(job.indexOf(install));
    }
  });

  test("restores rusty_v8 source binding cache in all native or BiDi jobs", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");
    const action = readRepoFile(".github/actions/rusty-v8-prefetch/action.yml");

    // The composite action owns the cache restore + prefetch
    expect(action).toContain("Restore rusty_v8 source binding cache");
    expect(action).toContain("path: ~/.cargo/.rusty_v8");
    expect(action).toContain("prefetch-rusty-v8-source-binding.mjs --release ${{ inputs.release }}");
    expect(action).toContain("default: v146.8.0");

    // The workflow opts into rusty_v8 prefetch in every native / BiDi-backed job
    for (const jobName of [
      "test",
      "wpt-webdriver-tests",
      "playwright-bidi-tests",
      "playwright-paint-vrt",
      "playwright-wpt-vrt",
    ]) {
      const job = extractWorkflowJob(workflow, jobName);
      expect(job, jobName).toContain("uses: ./.github/actions/rusty-v8-prefetch");
    }
  });

  test("uses Deno 2 in BiDi and VRT workflows for lockfile v5 compatibility", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");
    const action = readRepoFile(".github/actions/setup-crater/action.yml");

    // Deno is pinned to v2.x inside the setup composite action
    expect(action).toContain("deno-version: v2.x");
    expect(action).not.toContain("deno-version: v1.46.3");

    // BiDi + VRT jobs opt in via the `deno: "true"` input
    const usages = workflow.match(/deno: "true"/g) ?? [];
    expect(usages).toHaveLength(4);
  });

  test("font install script retries flaky msttcorefonts extraction", () => {
    const script = readRepoFile("scripts/ci/install-compatible-fonts.sh");

    expect(script).toContain("for attempt in 1 2 3; do");
    expect(script).toContain("sudo dpkg-reconfigure ttf-mscorefonts-installer || true");
    expect(script).toContain("sudo rm -f /var/lib/update-notifier/package-data-downloads/partial/* || true");
    expect(script).toContain("sudo apt-get install -y --reinstall --no-install-recommends ttf-mscorefonts-installer || true");
  });

  test("font install script pulls in medium-weight faces for paint.font-weight-numeric Layer C", () => {
    const script = readRepoFile("scripts/ci/install-compatible-fonts.sh");

    expect(script).toContain("fonts-roboto");
    expect(script).toContain("fonts-noto-core");
    expect(script).toContain("medium_weight_files=(");
    expect(script).toContain("Roboto-Medium.ttf");
    expect(script).toContain("NotoSans-Medium.ttf");
    expect(script).toContain("No medium-weight font found");
  });

  test("font resolvers include msttcorefonts file variants", () => {
    const bidiSource = readRepoFile("webdriver/bidi_main/start-with-font.ts");
    const resolverSource = readRepoFile("scripts/system-font-resolver.ts");

    for (const source of [bidiSource, resolverSource]) {
      expect(source).toContain("Times_New_Roman.ttf");
      expect(source).toContain("Times_New_Roman_Bold.ttf");
      expect(source).toContain("Courier_New.ttf");
      expect(source).toContain("Georgia_Bold.ttf");
      expect(source).toContain("verdanab.ttf");
    }
  });

  test("BiDi font resolver keeps Chrome-like macOS fallback order", () => {
    const bidiSource = readRepoFile("webdriver/bidi_main/start-with-font.ts");

    expect(bidiSource).toContain("\"system-ui\": {");
    expect(bidiSource).toContain("SFNS.ttf");
    expect(bidiSource).toContain("\"-apple-system\": \"system-ui\"");
    expect(bidiSource).toContain("blinkmacsystemfont: \"system-ui\"");
    expect(bidiSource).toContain("helvetica: {");
    expect(bidiSource).toContain("\"helvetica neue\": \"helvetica\"");
    expect(bidiSource).not.toContain("helvetica: \"arial\"");
    expect(bidiSource).not.toContain("regular: [\"Roboto-Regular.ttf\", \"Arial.ttf\"");

    const stHeitiIndex = bidiSource.indexOf("STHeiti Light.ttc");
    const hiraginoIndex = bidiSource.indexOf("W3.ttc");
    const arialUnicodeIndex = bidiSource.indexOf("Arial Unicode.ttf");
    expect(stHeitiIndex).toBeGreaterThanOrEqual(0);
    expect(hiraginoIndex).toBeGreaterThanOrEqual(0);
    expect(arialUnicodeIndex).toBeGreaterThanOrEqual(0);
    expect(stHeitiIndex).toBeLessThan(hiraginoIndex);
    expect(hiraginoIndex).toBeLessThan(arialUnicodeIndex);
  });

  test("start-with-font resolves helper scripts from the repo root after webdriver split", () => {
    const bidiPath = new URL("../webdriver/bidi_main/start-with-font.ts", import.meta.url);
    const textIntrinsicPath = new URL("../../scripts/text-intrinsic.ts", bidiPath);
    const fontDefaultsPath = new URL("../../scripts/font-family-defaults.ts", bidiPath);

    expect(path.basename(textIntrinsicPath.pathname)).toBe("text-intrinsic.ts");
    expect(path.basename(fontDefaultsPath.pathname)).toBe("font-family-defaults.ts");
    expect(textIntrinsicPath.pathname).toContain("/crater/scripts/");
    expect(fontDefaultsPath.pathname).toContain("/crater/scripts/");
  });
});
