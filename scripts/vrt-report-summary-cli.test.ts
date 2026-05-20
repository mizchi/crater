import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { runVrtReportSummaryCli } from "./vrt-report-summary.ts";

describe("runVrtReportSummaryCli", () => {
  it("loads nested report.json files and emits JSON/Markdown writes", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-vrt-report-summary-"));
    const inputDir = path.join(root, "output", "playwright", "vrt");
    fs.mkdirSync(path.join(inputDir, "fixture-card"), { recursive: true });
    fs.mkdirSync(path.join(inputDir, "fixture-nav"), { recursive: true });
    fs.mkdirSync(path.join(inputDir, "ignored"), { recursive: true });

    fs.writeFileSync(
      path.join(inputDir, "fixture-card", "report.json"),
      JSON.stringify({
        width: 960,
        height: 720,
        diffPixels: 1200,
        totalPixels: 691200,
        diffRatio: 0.03,
        threshold: 0.3,
        maxDiffRatio: 0.15,
        cssRuleUsage: {
          totalRules: 10,
          deadRules: 4,
          unusedRules: 1,
          overriddenRules: 1,
          noEffectRules: 2,
        },
      }),
      "utf8",
    );
    fs.writeFileSync(
      path.join(inputDir, "fixture-nav", "report.json"),
      JSON.stringify({
        width: 1024,
        height: 200,
        diffPixels: 40960,
        totalPixels: 204800,
        diffRatio: 0.2,
        threshold: 0.3,
        maxDiffRatio: 0.15,
      }),
      "utf8",
    );
    fs.writeFileSync(path.join(inputDir, "ignored", "report.json"), "{not-json", "utf8");

    const result = runVrtReportSummaryCli([
      "--input",
      "output/playwright/vrt",
      "--label",
      "paint-vrt",
      "--json",
      "out/vrt-summary.json",
      "--markdown",
      "out/vrt-summary.md",
    ], {
      cwd: root,
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# VRT Artifact Summary");
    expect(result.stdout).toContain("fixture-nav");
    expect(result.stdout).toContain("| CSS Rules (total/dead) | 10 / 4 |");
    expect(result.stdout).toContain("| CSS Unused / Overridden / No-Effect | 1 / 1 / 2 |");
    expect(result.writes?.map((write) => path.relative(root, write.path))).toEqual([
      "out/vrt-summary.md",
      "out/vrt-summary.json",
      "out/paint-vrt/vrt-summary/paint-vrt.md",
      "out/paint-vrt/vrt-summary/paint-vrt.json",
    ]);

    const jsonWrite = result.writes?.find((write) => write.path.endsWith("vrt-summary.json"));
    expect(jsonWrite).toBeDefined();
    const parsed = JSON.parse(jsonWrite!.content) as {
      total: number;
      failed: number;
      cssRuleUsage?: {
        totalRules?: number;
        deadRules?: number;
        unusedRules?: number;
        overriddenRules?: number;
        noEffectRules?: number;
      };
      rows: Array<{ label: string; status: string }>;
    };
    expect(parsed.total).toBe(2);
    expect(parsed.failed).toBe(1);
    expect(parsed.cssRuleUsage).toEqual({
      reports: 1,
      totalRules: 10,
      deadRules: 4,
      unusedRules: 1,
      overriddenRules: 1,
      noEffectRules: 2,
    });
    expect(parsed.rows.map((row) => `${row.label}:${row.status}`)).toEqual([
      "fixture-nav:fail",
      "fixture-card:pass",
    ]);
  });

  it("accepts normalized vrt-artifact reports and preserves contract fields", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-vrt-report-contract-"));
    const inputDir = path.join(root, "output", "playwright", "vrt");
    fs.mkdirSync(path.join(inputDir, "normalized-nav"), { recursive: true });

    fs.writeFileSync(
      path.join(inputDir, "normalized-nav", "report.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact",
        status: "fail",
        title: "fixture-nav-native",
        identity: {
          key: "{\"taskId\":\"paint-vrt\",\"spec\":\"tests/paint-vrt.test.ts\",\"title\":\"fixture-nav-native\",\"variant\":{\"backend\":\"native\"}}",
          taskId: "paint-vrt",
          spec: "tests/paint-vrt.test.ts",
          title: "fixture-nav-native",
          variant: {
            backend: "native",
          },
        },
        durationMs: 987,
        artifacts: {
          chromium: "chromium.png",
          crater: "crater.png",
          diff: "diff.png",
          report: "report.json",
        },
        metadata: {
          width: 1024,
          height: 200,
          diffPixels: 40960,
          totalPixels: 204800,
          diffRatio: 0.2,
          threshold: 0.3,
          maxDiffRatio: 0.15,
          backend: "native",
          snapshotKind: "fixture",
          viewport: {
            width: 1024,
            height: 200,
          },
        },
      }),
      "utf8",
    );

    const result = runVrtReportSummaryCli([
      "--input",
      "output/playwright/vrt",
      "--label",
      "paint-vrt-artifacts",
      "--collect-task-id",
      "paint-vrt",
      "--json",
      "out/vrt-summary.json",
    ], {
      cwd: root,
    });

    expect(result.exitCode).toBe(0);
    const jsonWrite = result.writes?.find((write) => write.path.endsWith("vrt-summary.json"));
    expect(jsonWrite).toBeDefined();
    const parsed = JSON.parse(jsonWrite!.content) as {
      total: number;
      failed: number;
      rows: Array<{
        label: string;
        status: string;
        backend?: string;
        snapshotKind?: string;
        durationMs?: number;
        identityKey?: string;
      }>;
    };
    expect(parsed.total).toBe(1);
    expect(parsed.failed).toBe(1);
    expect(parsed.rows[0]).toMatchObject({
      label: "fixture-nav-native",
      status: "fail",
      backend: "native",
      snapshotKind: "fixture",
      durationMs: 987,
    });
    expect(parsed.rows[0]?.identityKey).toContain("\"taskId\":\"paint-vrt\"");
    expect(result.writes?.map((write) => path.relative(root, write.path))).toEqual([
      "out/vrt-summary.json",
      "out/paint-vrt/vrt-summary/paint-vrt.md",
      "out/paint-vrt/vrt-summary/paint-vrt.json",
    ]);
  });

  it("disambiguates duplicate titles with stable identity metadata", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-vrt-report-variant-labels-"));
    const inputDir = path.join(root, "output", "playwright", "vrt", "responsive");
    fs.mkdirSync(path.join(inputDir, "R1-fluid-boxes", "mobile"), { recursive: true });
    fs.mkdirSync(path.join(inputDir, "R1-fluid-boxes", "desktop"), { recursive: true });

    fs.writeFileSync(
      path.join(inputDir, "R1-fluid-boxes", "mobile", "report.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact",
        status: "pass",
        title: "R1-fluid-boxes",
        identity: {
          key: "{\"taskId\":\"paint-vrt\",\"spec\":\"tests/paint-vrt-responsive.test.ts\",\"filter\":\"R1-fluid-boxes\",\"title\":\"R1-fluid-boxes\",\"variant\":{\"backend\":\"sixel\",\"snapshotKind\":\"responsive\",\"viewport\":\"mobile\"}}",
          taskId: "paint-vrt",
          spec: "tests/paint-vrt-responsive.test.ts",
          filter: "R1-fluid-boxes",
          title: "R1-fluid-boxes",
          variant: {
            backend: "sixel",
            snapshotKind: "responsive",
            viewport: "mobile",
          },
        },
        metadata: {
          diffRatio: 0.02,
          maxDiffRatio: 0.1,
          backend: "sixel",
          snapshotKind: "responsive",
        },
      }),
      "utf8",
    );

    fs.writeFileSync(
      path.join(inputDir, "R1-fluid-boxes", "desktop", "report.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact",
        status: "fail",
        title: "R1-fluid-boxes",
        identity: {
          key: "{\"taskId\":\"paint-vrt\",\"spec\":\"tests/paint-vrt-responsive.test.ts\",\"filter\":\"R1-fluid-boxes\",\"title\":\"R1-fluid-boxes\",\"variant\":{\"backend\":\"sixel\",\"snapshotKind\":\"responsive\",\"viewport\":\"desktop\"}}",
          taskId: "paint-vrt",
          spec: "tests/paint-vrt-responsive.test.ts",
          filter: "R1-fluid-boxes",
          title: "R1-fluid-boxes",
          variant: {
            backend: "sixel",
            snapshotKind: "responsive",
            viewport: "desktop",
          },
        },
        metadata: {
          diffRatio: 0.2,
          maxDiffRatio: 0.1,
          backend: "sixel",
          snapshotKind: "responsive",
        },
      }),
      "utf8",
    );

    const result = runVrtReportSummaryCli([
      "--input",
      "output/playwright/vrt/responsive",
      "--label",
      "paint-vrt-responsive",
      "--json",
      "out/vrt-summary.json",
    ], {
      cwd: root,
    });

    expect(result.exitCode).toBe(0);
    const jsonWrite = result.writes?.find((write) => write.path.endsWith("vrt-summary.json"));
    expect(jsonWrite).toBeDefined();
    const parsed = JSON.parse(jsonWrite!.content) as {
      rows: Array<{
        label: string;
        status: string;
        identity?: {
          filter?: string;
          variant?: Record<string, string>;
        };
      }>;
    };
    expect(parsed.rows.map((row) => row.label)).toEqual([
      "R1-fluid-boxes [viewport=desktop]",
      "R1-fluid-boxes [viewport=mobile]",
    ]);
    expect(parsed.rows[0]).toMatchObject({
      status: "fail",
      identity: {
        filter: "R1-fluid-boxes",
        variant: {
          viewport: "desktop",
        },
      },
    });
  });

  it("filters current paint VRT summaries by task id and excluded filter", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-vrt-report-current-filter-"));
    const inputDir = path.join(root, "output", "playwright", "vrt");
    fs.mkdirSync(path.join(inputDir, "mdn-wasm-text"), { recursive: true });
    fs.mkdirSync(path.join(inputDir, "wikipedia"), { recursive: true });
    fs.mkdirSync(path.join(inputDir, "wpt", "css-display", "display-contents"), { recursive: true });
    fs.mkdirSync(path.join(inputDir, "font-fallback-ja-system"), { recursive: true });

    fs.writeFileSync(
      path.join(inputDir, "mdn-wasm-text", "report.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact",
        status: "pass",
        title: "real-world snapshot: mdn-wasm-text stays within loose visual diff budget",
        identity: {
          key: "paint-mdn",
          taskId: "paint-vrt",
          spec: "tests/paint-vrt.test.ts",
          filter: "mdn-wasm-text",
          title: "real-world snapshot: mdn-wasm-text stays within loose visual diff budget",
          variant: { backend: "sixel", snapshotKind: "real-world" },
        },
        metadata: {
          width: 1440,
          height: 960,
          diffRatio: 0.03,
          maxDiffRatio: 0.04,
        },
      }),
      "utf8",
    );
    fs.writeFileSync(
      path.join(inputDir, "font-fallback-ja-system", "report.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact",
        status: "pass",
        title: "Japanese text uses system fallback glyphs",
        identity: {
          key: "paint-font",
          taskId: "paint-vrt-font-fallback",
          spec: "tests/paint-vrt-font-fallback.test.ts",
          filter: "font-fallback-ja-system",
          title: "Japanese text uses system fallback glyphs",
          variant: { backend: "sixel" },
        },
        metadata: {
          diffRatio: 0.08,
          maxDiffRatio: 0.095,
        },
      }),
      "utf8",
    );
    fs.writeFileSync(
      path.join(inputDir, "wikipedia", "report.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact",
        status: "pass",
        title: "url snapshot: wikipedia visual diff within budget",
        identity: {
          key: "paint-wikipedia",
          taskId: "paint-vrt",
          spec: "tests/paint-vrt.test.ts",
          filter: "wikipedia",
          title: "url snapshot: wikipedia visual diff within budget",
          variant: { backend: "sixel" },
        },
        metadata: {
          diffRatio: 0.2,
          maxDiffRatio: 0.25,
        },
      }),
      "utf8",
    );
    fs.writeFileSync(
      path.join(inputDir, "wpt", "css-display", "display-contents", "report.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact",
        status: "fail",
        title: "display contents WPT",
        identity: {
          key: "wpt-display",
          taskId: "wpt-vrt",
          spec: "tests/wpt-vrt.test.ts",
          filter: "css-display/display-contents.html",
          title: "display contents WPT",
          variant: { backend: "sixel", snapshotKind: "wpt" },
        },
        metadata: {
          diffRatio: 0.9,
          maxDiffRatio: 0.15,
        },
      }),
      "utf8",
    );

    const result = runVrtReportSummaryCli([
      "--input",
      "output/playwright/vrt",
      "--label",
      "paint-vrt-current",
      "--include-task-id",
      "paint-vrt",
      "--include-task-id",
      "paint-vrt-font-fallback",
      "--exclude-filter",
      "wikipedia",
      "--json",
      "out/vrt-current.json",
    ], {
      cwd: root,
    });

    expect(result.exitCode).toBe(0);
    const jsonWrite = result.writes?.find((write) => write.path.endsWith("vrt-current.json"));
    expect(jsonWrite).toBeDefined();
    const parsed = JSON.parse(jsonWrite!.content) as {
      total: number;
      rows: Array<{ label: string; status: string; diffRatio: number }>;
    };
    expect(parsed.total).toBe(2);
    expect(parsed.rows.map((row) => row.label).sort()).toEqual([
      "Japanese text uses system fallback glyphs",
      "real-world snapshot: mdn-wasm-text stays within loose visual diff budget",
    ]);
  });

  it("fails freshness check when an existing summary is older than selected reports", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-vrt-report-fresh-check-"));
    const inputDir = path.join(root, "output", "playwright", "vrt", "google");
    const outDir = path.join(root, "output", "playwright");
    fs.mkdirSync(inputDir, { recursive: true });
    fs.mkdirSync(outDir, { recursive: true });

    const reportPath = path.join(inputDir, "report.json");
    const summaryPath = path.join(outDir, "vrt-current-summary.json");
    fs.writeFileSync(
      reportPath,
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact",
        status: "pass",
        title: "url snapshot: google visual diff within budget",
        identity: {
          key: "paint-google",
          taskId: "paint-vrt",
          spec: "tests/paint-vrt.test.ts",
          filter: "google",
          title: "url snapshot: google visual diff within budget",
          variant: { backend: "sixel" },
        },
        metadata: {
          diffRatio: 0.006,
          maxDiffRatio: 0.02,
        },
      }),
      "utf8",
    );
    fs.writeFileSync(summaryPath, "{}\n", "utf8");
    fs.utimesSync(summaryPath, new Date("2026-01-01T00:00:00Z"), new Date("2026-01-01T00:00:00Z"));
    fs.utimesSync(reportPath, new Date("2026-01-02T00:00:00Z"), new Date("2026-01-02T00:00:00Z"));

    const result = runVrtReportSummaryCli([
      "--input",
      "output/playwright/vrt",
      "--label",
      "paint-vrt-current",
      "--include-task-id",
      "paint-vrt",
      "--json",
      "output/playwright/vrt-current-summary.json",
      "--check-fresh",
    ], {
      cwd: root,
    });

    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain("VRT summary is stale");
    expect(result.stderr).toContain("google/report.json");
    expect(result.writes).toEqual([]);
  });
});
