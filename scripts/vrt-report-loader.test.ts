import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { loadVrtArtifactReports } from "./vrt-report-loader.ts";

describe("loadVrtArtifactReports", () => {
  it("ignores normalized reports that do not satisfy the VRT metrics contract", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-vrt-report-loader-"));
    const inputDir = path.join(root, "output", "playwright", "vrt");
    fs.mkdirSync(path.join(inputDir, "valid"), { recursive: true });
    fs.mkdirSync(path.join(inputDir, "invalid"), { recursive: true });

    fs.writeFileSync(
      path.join(inputDir, "valid", "report.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact",
        status: "pass",
        title: "fixture-card",
        identity: {
          key: "valid-key",
          title: "fixture-card",
          variant: {
            backend: "sixel",
          },
        },
        metadata: {
          diffRatio: 0.03,
          maxDiffRatio: 0.15,
          backend: "sixel",
        },
        artifacts: {},
      }),
      "utf8",
    );
    fs.writeFileSync(
      path.join(inputDir, "invalid", "report.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact",
        status: "pass",
        title: "fixture-nav",
        identity: {
          key: "invalid-key",
          title: "fixture-nav",
          variant: {
            backend: "native",
          },
        },
        metadata: {
          maxDiffRatio: 0.15,
          backend: "native",
        },
        artifacts: {},
      }),
      "utf8",
    );

    expect(loadVrtArtifactReports(inputDir)).toEqual([
      {
        label: "fixture-card",
        reportPath: path.join(inputDir, "valid", "report.json"),
        report: expect.objectContaining({
          title: "fixture-card",
        }),
      },
    ]);
  });
});
