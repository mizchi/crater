import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { createVrtArtifactReportContext } from "../../scripts/vrt-report-contract.ts";
import { buildVrtArtifactReportJson } from "./crater-vrt.ts";

const originalPaintBackend = process.env.CRATER_PAINT_BACKEND;

afterEach(() => {
  if (originalPaintBackend === undefined) {
    delete process.env.CRATER_PAINT_BACKEND;
    return;
  }
  process.env.CRATER_PAINT_BACKEND = originalPaintBackend;
});

describe("buildVrtArtifactReportJson", () => {
  it("builds a normalized VRT artifact report with inferred snapshot kind", () => {
    delete process.env.CRATER_PAINT_BACKEND;

    const report = JSON.parse(buildVrtArtifactReportJson({
      outputDir: path.join("output", "playwright", "vrt", "responsive", "R1-fluid-boxes", "mobile"),
      threshold: 0.3,
      maxDiffRatio: 0.15,
      report: {
        title: "R1-fluid-boxes",
        taskId: "paint-vrt",
        spec: "tests/paint-vrt-responsive.test.ts",
        filter: "R1-fluid-boxes",
        variant: {
          viewportName: "mobile",
        },
        durationMs: 123,
      },
    }, {
      width: 375,
      height: 812,
      diffPixels: 900,
      totalPixels: 304500,
      diffRatio: 0.02,
      roi: {
        x: 4,
        y: 8,
        width: 360,
        height: 700,
      },
      maskPixels: 125000,
    })) as Record<string, unknown>;

    expect(report).toMatchObject({
      schemaVersion: 1,
      suite: "vrt-artifact",
      status: "pass",
      title: "R1-fluid-boxes",
      identity: {
        taskId: "paint-vrt",
        spec: "tests/paint-vrt-responsive.test.ts",
        filter: "R1-fluid-boxes",
        title: "R1-fluid-boxes",
        variant: {
          backend: "sixel",
          snapshotKind: "responsive",
          viewportName: "mobile",
        },
      },
      artifacts: {
        chromium: "chromium.png",
        crater: "crater.png",
        diff: "diff.png",
        report: "report.json",
      },
      metadata: {
        width: 375,
        height: 812,
        diffPixels: 900,
        totalPixels: 304500,
        diffRatio: 0.02,
        threshold: 0.3,
        maxDiffRatio: 0.15,
        backend: "sixel",
        snapshotKind: "responsive",
        viewport: {
          width: 375,
          height: 812,
        },
        roi: {
          x: 4,
          y: 8,
          width: 360,
          height: 700,
        },
        maskPixels: 125000,
      },
      durationMs: 123,
    });
    expect(String((report.identity as Record<string, unknown>).key)).toContain("\"snapshotKind\":\"responsive\"");
  });

  it("prefers explicit backend and artifact overrides over env and fallback label", () => {
    process.env.CRATER_PAINT_BACKEND = "native";

    const report = JSON.parse(buildVrtArtifactReportJson({
      outputDir: path.join("/repo", "output", "playwright", "vrt", "url", "example-com"),
      threshold: 0.2,
      maxDiffRatio: 0.1,
      report: {
        backend: "kagura",
        artifacts: {
          html: "input.html",
        },
      },
    }, {
      width: 1280,
      height: 720,
      diffPixels: 184320,
      totalPixels: 921600,
      diffRatio: 0.2,
    })) as Record<string, unknown>;

    expect(report).toMatchObject({
      schemaVersion: 1,
      suite: "vrt-artifact",
      status: "fail",
      title: "example-com",
      identity: {
        title: "example-com",
        variant: {
          backend: "kagura",
          snapshotKind: "url",
        },
      },
      artifacts: {
        chromium: "chromium.png",
        crater: "crater.png",
        diff: "diff.png",
        report: "report.json",
        html: "input.html",
      },
      metadata: {
        diffRatio: 0.2,
        maxDiffRatio: 0.1,
        threshold: 0.2,
        backend: "kagura",
        snapshotKind: "url",
      },
    });
    expect(String((report.identity as Record<string, unknown>).key)).not.toContain("\"native\"");
  });

  it("derives a stable filter from the output directory when the title is descriptive", () => {
    const report = JSON.parse(buildVrtArtifactReportJson({
      outputDir: path.join("/repo", "output", "playwright", "vrt", "fixture-cards-controls"),
      threshold: 0.3,
      maxDiffRatio: 0.12,
      report: {
        title: "fixture: cards and controls stay within relaxed visual diff budget",
        taskId: "paint-vrt",
        spec: "tests/paint-vrt.test.ts",
      },
    }, {
      width: 960,
      height: 720,
      diffPixels: 1200,
      totalPixels: 691200,
      diffRatio: 0.03,
    })) as Record<string, unknown>;

    expect(report).toMatchObject({
      identity: {
        taskId: "paint-vrt",
        spec: "tests/paint-vrt.test.ts",
        filter: "fixture-cards-controls",
        title: "fixture: cards and controls stay within relaxed visual diff budget",
      },
    });
    expect(String((report.identity as Record<string, unknown>).key)).toContain("\"filter\":\"fixture-cards-controls\"");
    expect(String((report.identity as Record<string, unknown>).key)).not.toContain(
      "fixture: cards and controls stay within relaxed visual diff budget",
    );
  });

  it("keeps output-dir-based stable filter inference when using createVrtArtifactReportContext", () => {
    const report = JSON.parse(buildVrtArtifactReportJson({
      outputDir: path.join("/repo", "output", "playwright", "vrt", "fixture-cards-controls"),
      threshold: 0.3,
      maxDiffRatio: 0.12,
      report: createVrtArtifactReportContext({
        cwd: "/repo",
        file: "/repo/tests/paint-vrt.test.ts",
        taskId: "paint-vrt",
        title: "fixture: cards and controls stay within relaxed visual diff budget",
      }),
    }, {
      width: 960,
      height: 720,
      diffPixels: 1200,
      totalPixels: 691200,
      diffRatio: 0.03,
    })) as Record<string, unknown>;

    expect(report).toMatchObject({
      identity: {
        filter: "fixture-cards-controls",
      },
    });
    expect(String((report.identity as Record<string, unknown>).key)).toContain("\"filter\":\"fixture-cards-controls\"");
    expect(String((report.identity as Record<string, unknown>).key)).not.toContain(
      "fixture: cards and controls stay within relaxed visual diff budget",
    );
  });

  it("infers real-world snapshot kind and stable filter from the output directory", () => {
    const report = JSON.parse(buildVrtArtifactReportJson({
      outputDir: path.join("/repo", "output", "playwright", "vrt", "real-world", "github-mizchi"),
      threshold: 0.3,
      maxDiffRatio: 0.12,
      report: {
        title: "github profile visual parity",
        taskId: "paint-vrt",
        spec: "tests/paint-vrt.test.ts",
      },
    }, {
      width: 1440,
      height: 960,
      diffPixels: 1200,
      totalPixels: 1382400,
      diffRatio: 0.0009,
    })) as Record<string, unknown>;

    expect(report).toMatchObject({
      status: "pass",
      identity: {
        taskId: "paint-vrt",
        spec: "tests/paint-vrt.test.ts",
        filter: "github-mizchi",
        title: "github profile visual parity",
        variant: {
          backend: "sixel",
          snapshotKind: "real-world",
        },
      },
      metadata: {
        diffRatio: 0.0009,
        maxDiffRatio: 0.12,
        backend: "sixel",
        snapshotKind: "real-world",
      },
    });
    expect(String((report.identity as Record<string, unknown>).key)).toContain("\"filter\":\"github-mizchi\"");
    expect(String((report.identity as Record<string, unknown>).key)).not.toContain(
      "github profile visual parity",
    );
  });
});
