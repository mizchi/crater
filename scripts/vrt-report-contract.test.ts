import { describe, expect, it } from "vitest";
import {
  asNormalizedVrtArtifactReport,
  buildStableVrtIdentity,
  createVrtArtifactReportContext,
  createNormalizedVrtArtifactReport,
  inferVrtStableFilter,
  inferVrtSnapshotKind,
  readVrtArtifactStatus,
} from "./vrt-report-contract.ts";

describe("buildStableVrtIdentity", () => {
  it("normalizes variant keys into a stable identity key", () => {
    const identity = buildStableVrtIdentity({
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      title: "fixture-nav-native",
      variant: {
        snapshotKind: "fixture",
        backend: "native",
        empty: "",
      },
    });

    expect(identity.variant).toEqual({
      backend: "native",
      snapshotKind: "fixture",
    });
    expect(identity.key).toBe(
      "{\"title\":\"fixture-nav-native\",\"taskId\":\"paint-vrt\",\"spec\":\"tests/paint-vrt.test.ts\",\"variant\":{\"backend\":\"native\",\"snapshotKind\":\"fixture\"}}",
    );
  });

  it("treats title as display metadata when a stable filter is available", () => {
    const beforeRename = buildStableVrtIdentity({
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      filter: "https://example.com/",
      title: "example-com",
      variant: {
        backend: "native",
        snapshotKind: "url",
      },
      shard: "1/2",
    });
    const afterRename = buildStableVrtIdentity({
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      filter: "https://example.com/",
      title: "example-com-homepage",
      variant: {
        snapshotKind: "url",
        backend: "native",
      },
      shard: "1/2",
    });

    expect(beforeRename.title).toBe("example-com");
    expect(afterRename.title).toBe("example-com-homepage");
    expect(beforeRename.key).toBe(afterRename.key);
    expect(beforeRename.key).toBe(
      "{\"taskId\":\"paint-vrt\",\"spec\":\"tests/paint-vrt.test.ts\",\"filter\":\"https://example.com/\",\"variant\":{\"backend\":\"native\",\"snapshotKind\":\"url\"},\"shard\":\"1/2\"}",
    );
  });
});

describe("vrt report contract", () => {
  it("infers snapshot kind from report title and spec context", () => {
    expect(inferVrtSnapshotKind({
      title: "real-world snapshot: github-mizchi stays within loose visual diff budget",
      spec: "tests/paint-vrt.test.ts",
    })).toBe("real-world");
    expect(inferVrtSnapshotKind({
      outputDir: "/repo/output/playwright/vrt/real-world/github-mizchi",
    })).toBe("real-world");
    expect(inferVrtSnapshotKind({
      title: "R1-fluid-boxes",
      spec: "tests/paint-vrt-responsive.test.ts",
    })).toBe("responsive");
    expect(inferVrtSnapshotKind({
      title: "wpt/css/css-flexbox/align-items-006.html",
      spec: "tests/wpt-vrt.test.ts",
    })).toBe("wpt");
    expect(inferVrtSnapshotKind({
      outputDir: "/repo/output/playwright/vrt/url/example-com",
    })).toBe("url");
  });

  it("infers stable filters from VRT output directories", () => {
    expect(inferVrtStableFilter({
      title: "github profile visual parity",
      outputDir: "/repo/output/playwright/vrt/real-world/github-mizchi",
    })).toBe("github-mizchi");
    expect(inferVrtStableFilter({
      title: "fixture: cards and controls stay within relaxed visual diff budget",
      outputDir: "/repo/output/playwright/vrt/fixture-cards-controls",
    })).toBe("fixture-cards-controls");
    expect(inferVrtStableFilter({
      title: "R1: fluid width boxes",
      outputDir: "/repo/output/playwright/vrt/responsive/R1-fluid-boxes/mobile",
    })).toBe("R1-fluid-boxes");
    expect(inferVrtStableFilter({
      title: "wpt/css/css-flexbox/align-items-006.html",
      outputDir: "/repo/output/playwright/vrt/wpt/css-flexbox/align-items-006",
    })).toBeUndefined();
  });

  it("infers snapshot kind and stable filter from Windows-style output directories", () => {
    expect(inferVrtSnapshotKind({
      outputDir: "C:\\repo\\output\\playwright\\vrt\\responsive\\R1-fluid-boxes\\mobile",
    })).toBe("responsive");
    expect(inferVrtStableFilter({
      title: "R1: fluid width boxes",
      outputDir: "C:\\repo\\output\\playwright\\vrt\\responsive\\R1-fluid-boxes\\mobile",
    })).toBe("R1-fluid-boxes");
  });

  it("creates report context from task/spec/title metadata", () => {
    const context = createVrtArtifactReportContext({
      cwd: "/repo",
      file: "/repo/tests/paint-vrt.test.ts",
      taskId: "paint-vrt",
      title: "fixture: cards and controls stay within relaxed visual diff budget",
      variant: {
        backend: "native",
        empty: "",
      },
    });

    expect(context).toEqual({
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      title: "fixture: cards and controls stay within relaxed visual diff budget",
      filter: "fixture: cards and controls stay within relaxed visual diff budget",
      snapshotKind: "fixture",
      variant: {
        backend: "native",
      },
    });
  });

  it("infers stable filter and snapshot kind from output directories when creating report context", () => {
    const context = createVrtArtifactReportContext({
      cwd: "/repo",
      file: "/repo/tests/paint-vrt.test.ts",
      outputDir: "/repo/output/playwright/vrt/fixture-cards-controls",
      taskId: "paint-vrt",
      title: "fixture: cards and controls stay within relaxed visual diff budget",
    });

    expect(context).toEqual({
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      title: "fixture: cards and controls stay within relaxed visual diff budget",
      filter: "fixture-cards-controls",
      snapshotKind: "fixture",
    });
  });

  it("normalizes Windows absolute paths into repo-relative spec paths", () => {
    const context = createVrtArtifactReportContext({
      cwd: "C:\\repo",
      file: "C:\\repo\\tests\\paint-vrt.test.ts",
      taskId: "paint-vrt",
      title: "fixture: cards and controls stay within relaxed visual diff budget",
      variant: {
        backend: "native",
      },
    });

    expect(context).toEqual({
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      title: "fixture: cards and controls stay within relaxed visual diff budget",
      filter: "fixture: cards and controls stay within relaxed visual diff budget",
      snapshotKind: "fixture",
      variant: {
        backend: "native",
      },
    });
  });

  it("derives snapshot kind for responsive and real-world paint vrt contexts", () => {
    const responsive = createVrtArtifactReportContext({
      cwd: "/repo",
      file: "/repo/tests/paint-vrt-responsive.test.ts",
      taskId: "paint-vrt",
      title: "R3-max-width-center",
      variant: {
        viewport: "tablet",
      },
    });
    const realWorld = createVrtArtifactReportContext({
      cwd: "/repo",
      file: "/repo/tests/paint-vrt.test.ts",
      taskId: "paint-vrt",
      title: "real-world snapshot: example-com visual parity",
    });

    expect(responsive.snapshotKind).toBe("responsive");
    expect(realWorld.snapshotKind).toBe("real-world");
  });

  it("builds normalized vrt-artifact reports with derived identity and status", () => {
    const report = createNormalizedVrtArtifactReport({
      title: "fixture-nav-native",
      taskId: "paint-vrt",
      spec: "tests/paint-vrt.test.ts",
      filter: "fixture-nav",
      artifacts: {
        diff: "diff.png",
        chromium: "chromium.png",
        crater: "crater.png",
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
    });

    expect(report).toMatchObject({
      schemaVersion: 1,
      suite: "vrt-artifact",
      status: "fail",
      title: "fixture-nav-native",
      identity: {
        taskId: "paint-vrt",
        spec: "tests/paint-vrt.test.ts",
        filter: "fixture-nav",
        title: "fixture-nav-native",
        variant: {
          backend: "native",
          snapshotKind: "fixture",
        },
      },
      artifacts: {
        chromium: "chromium.png",
        crater: "crater.png",
        diff: "diff.png",
        report: "report.json",
      },
      metadata: {
        diffRatio: 0.2,
        maxDiffRatio: 0.15,
        backend: "native",
        snapshotKind: "fixture",
      },
    });
    expect(report.identity.key).toContain("\"backend\":\"native\"");
  });

  it("accepts normalized vrt-artifact payloads", () => {
    const report = asNormalizedVrtArtifactReport({
      schemaVersion: 1,
      suite: "vrt-artifact",
      status: "pass",
      title: "fixture-card",
      identity: {
        key: "identity-key",
        title: "fixture-card",
        variant: {
          backend: "sixel",
        },
      },
      artifacts: {
        chromium: "chromium.png",
      },
      metadata: {
        diffRatio: 0.04,
        maxDiffRatio: 0.15,
        backend: "sixel",
      },
    });

    expect(report).toMatchObject({
      suite: "vrt-artifact",
      status: "pass",
      title: "fixture-card",
      identity: {
        key: "identity-key",
      },
      metadata: {
        diffRatio: 0.04,
        maxDiffRatio: 0.15,
        backend: "sixel",
      },
    });
  });

  it("rejects normalized vrt-artifact payloads when diffRatio is missing", () => {
    expect(asNormalizedVrtArtifactReport({
      schemaVersion: 1,
      suite: "vrt-artifact",
      status: "pass",
      title: "fixture-card",
      identity: {
        key: "identity-key",
        title: "fixture-card",
        variant: {
          backend: "sixel",
        },
      },
      artifacts: {
        chromium: "chromium.png",
      },
      metadata: {
        maxDiffRatio: 0.15,
        backend: "sixel",
      },
    })).toBeNull();
  });

  it("derives status from legacy diff budget when status is omitted", () => {
    expect(readVrtArtifactStatus({
      diffRatio: 0.04,
      maxDiffRatio: 0.15,
    })).toBe("pass");
    expect(readVrtArtifactStatus({
      diffRatio: 0.2,
      maxDiffRatio: 0.15,
    })).toBe("fail");
    expect(readVrtArtifactStatus({
      diffRatio: 0.2,
    })).toBe("unknown");
  });
});
