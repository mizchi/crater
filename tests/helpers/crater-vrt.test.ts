import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { createVrtArtifactReportContext } from "../../scripts/vrt-report-contract.ts";
import {
  buildVrtArtifactReportJson,
  renderCraterHtml,
  summarizeCssRuleUsageRules,
} from "./crater-vrt.ts";

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

  it("includes css rule usage summary in normalized VRT metadata", () => {
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
      cssRuleUsage: {
        totalRules: 6,
        matchedRules: 5,
        unusedRules: 1,
        overriddenRules: 1,
        noEffectRules: 2,
        deadRules: 4,
        sameAsInheritedRules: 1,
        sameAsInitialRules: 0,
        sameAsFallbackRules: 1,
      },
    })) as Record<string, unknown>;

    expect(report).toMatchObject({
      metadata: {
        cssRuleUsage: {
          totalRules: 6,
          matchedRules: 5,
          unusedRules: 1,
          overriddenRules: 1,
          noEffectRules: 2,
          deadRules: 4,
          sameAsInheritedRules: 1,
          sameAsInitialRules: 0,
          sameAsFallbackRules: 1,
        },
      },
    });
  });
});

describe("summarizeCssRuleUsageRules", () => {
  it("counts dead css categories and no-effect reasons", () => {
    expect(summarizeCssRuleUsageRules([
      { matched: false, overridden: false },
      { matched: true, overridden: true },
      { matched: true, overridden: false, noEffect: true, noEffectReason: "same_as_inherited" },
      { matched: true, overridden: false, noEffect: true, noEffectReason: "same_as_fallback" },
      { matched: true, overridden: false },
    ])).toEqual({
      totalRules: 5,
      matchedRules: 4,
      unusedRules: 1,
      overriddenRules: 1,
      noEffectRules: 2,
      deadRules: 4,
      sameAsInheritedRules: 1,
      sameAsInitialRules: 0,
      sameAsFallbackRules: 1,
    });
  });
});

describe("renderCraterHtml", () => {
  it("attaches css rule usage summary to captured crater image", async () => {
    delete process.env.CRATER_PAINT_BACKEND;

    const calls: string[] = [];
    const fakePage = {
      async setViewport(width: number, height: number) {
        calls.push(`viewport:${width}x${height}`);
      },
      async setContentWithScripts(html: string) {
        calls.push(`content:${html.length}`);
      },
      async capturePaintData() {
        calls.push("paint");
        return {
          width: 320,
          height: 240,
          data: new Uint8Array([255, 255, 255, 255]),
        };
      },
      async getCssRuleUsageDetails() {
        calls.push("css");
        return {
          rules: [
            { selector: ".unused", matched: false, elements: 0, overridden: false },
            { selector: ".card", matched: true, elements: 1, overridden: true },
            {
              selector: "div.card",
              matched: true,
              elements: 1,
              overridden: false,
              noEffect: true,
              noEffectReason: "same_as_fallback",
            },
          ],
          elements: {},
        };
      },
    };

    const image = await renderCraterHtml(
      fakePage as never,
      "<div class='card'>A</div>",
      { width: 320, height: 240 },
    );

    expect(calls).toEqual([
      "viewport:320x240",
      "content:25",
      "paint",
      "css",
    ]);
    expect(image.cssRuleUsage).toEqual({
      totalRules: 3,
      matchedRules: 2,
      unusedRules: 1,
      overriddenRules: 1,
      noEffectRules: 1,
      deadRules: 3,
      sameAsInheritedRules: 0,
      sameAsInitialRules: 0,
      sameAsFallbackRules: 1,
    });
  });
});
