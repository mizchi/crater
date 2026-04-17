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
      rows: Array<{ label: string; status: string }>;
    };
    expect(parsed.total).toBe(2);
    expect(parsed.failed).toBe(1);
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
});
