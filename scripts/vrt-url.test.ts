import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildDynamicMaskInlineStyle,
  buildVrtUrlOutputDir,
  buildVrtUrlOutputName,
  parseVrtUrlArgs,
  VrtUrlUsageError,
} from "./vrt-url";

describe("parseVrtUrlArgs", () => {
  it("parses URL VRT flags including text masking", () => {
    expect(parseVrtUrlArgs([
      "--",
      "https://example.com/path",
      "--width",
      "1024",
      "--height",
      "768",
      "--backend",
      "sixel",
      "--threshold",
      "0.2",
      "--max-diff-ratio",
      "0.1",
      "--server-timeout-ms",
      "5000",
      "--mask-text",
      "--mask-dynamic",
      "--mask-assets",
    ], "/repo")).toEqual({
      backend: "sixel",
      height: 768,
      maskAssets: true,
      maskDynamic: true,
      maskText: true,
      maxDiffRatio: 0.1,
      name: "example-com",
      outputDir: path.join("/repo", "output", "playwright", "vrt", "url", "example-com-text-masked-dynamic-masked-asset-masked"),
      serverTimeoutMs: 5000,
      threshold: 0.2,
      url: "https://example.com/path",
      width: 1024,
    });
  });

  it("rejects unsupported backends", () => {
    expect(() =>
      parseVrtUrlArgs(["https://example.com", "--backend", "cli"], "/repo")
    ).toThrow(VrtUrlUsageError);
  });
});

describe("buildVrtUrlOutputName", () => {
  it("suffixes masked URL snapshots without duplicating the suffix", () => {
    expect(buildVrtUrlOutputName("example-com", true)).toBe("example-com-text-masked");
    expect(buildVrtUrlOutputName("example-com-text-masked", true)).toBe("example-com-text-masked");
    expect(buildVrtUrlOutputName("example-com", true, true)).toBe("example-com-text-masked-dynamic-masked");
    expect(buildVrtUrlOutputName("example-com", true, true, true)).toBe("example-com-text-masked-dynamic-masked-asset-masked");
    expect(buildVrtUrlOutputName("example-com", false)).toBe("example-com");
  });
});

describe("buildVrtUrlOutputDir", () => {
  it("uses the normalized snapshot name in the standard VRT output root", () => {
    expect(buildVrtUrlOutputDir("/repo", "example-com", true, true, true)).toBe(
      path.join("/repo", "output", "playwright", "vrt", "url", "example-com-text-masked-dynamic-masked-asset-masked"),
    );
  });
});

describe("buildDynamicMaskInlineStyle", () => {
  it("preserves the used geometry of dynamic content hosts", () => {
    expect(buildDynamicMaskInlineStyle("color:red;", {
      height: 94.375,
      width: 486.421875,
    })).toContain("width:486.422px!important");
    expect(buildDynamicMaskInlineStyle(null, {
      display: "inline",
      height: 20,
      width: 30,
    })).toContain("display:inline-block!important");
    expect(buildDynamicMaskInlineStyle(null, {
      display: "inline",
      height: 0,
      width: 0,
    })).not.toContain("display:");
  });
});
