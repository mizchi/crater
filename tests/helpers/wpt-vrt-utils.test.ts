import { describe, expect, it } from "vitest";
import {
  collectWptVrtTests,
  createWptVrtBatches,
  type WptVrtConfig,
} from "./wpt-vrt-utils.ts";

const baseConfig: Omit<WptVrtConfig, "modules" | "limitPerModule"> = {
  viewport: { width: 800, height: 600 },
  pixelmatchThreshold: 0.3,
  defaultMaxDiffRatio: 0.15,
};

describe("collectWptVrtTests", () => {
  it("merges explicit tests after module slices without duplicates", () => {
    const config: WptVrtConfig = {
      ...baseConfig,
      modules: ["css-flexbox", "css-display"],
      limitPerModule: 1,
      explicitTests: [
        "wpt/css/css-flexbox/flexbox-whitespace-handling-001a.xhtml",
        "wpt/css/css-display/display-contents-inline-flex-001.html",
        "wpt/css/css-flexbox/flex-001.html",
      ],
    };

    const entries = collectWptVrtTests(config, (moduleName) => {
      if (moduleName === "css-flexbox") {
        return [
          "wpt/css/css-flexbox/flex-001.html",
          "wpt/css/css-flexbox/flex-002.html",
        ];
      }
      if (moduleName === "css-display") {
        return [
          "wpt/css/css-display/display-001.html",
          "wpt/css/css-display/display-002.html",
        ];
      }
      return [];
    });

    expect(entries.map((entry) => entry.relativePath)).toEqual([
      "css-flexbox/flex-001.html",
      "css-display/display-001.html",
      "css-flexbox/flexbox-whitespace-handling-001a.xhtml",
      "css-display/display-contents-inline-flex-001.html",
    ]);
  });

  it("infers module names for explicit tests outside the module list", () => {
    const config: WptVrtConfig = {
      ...baseConfig,
      modules: [],
      limitPerModule: 0,
      explicitTests: [
        "wpt/css/css-position/position-absolute-center-001.html",
      ],
    };

    const entries = collectWptVrtTests(config, () => []);

    expect(entries).toEqual([
      {
        testPath: "wpt/css/css-position/position-absolute-center-001.html",
        relativePath: "css-position/position-absolute-center-001.html",
        moduleName: "css-position",
      },
    ]);
  });
});

describe("createWptVrtBatches", () => {
  it("splits entries into fixed-size batches while preserving order", () => {
    const entries = [
      { testPath: "a", relativePath: "a", moduleName: "m" },
      { testPath: "b", relativePath: "b", moduleName: "m" },
      { testPath: "c", relativePath: "c", moduleName: "m" },
      { testPath: "d", relativePath: "d", moduleName: "m" },
      { testPath: "e", relativePath: "e", moduleName: "m" },
    ];

    expect(createWptVrtBatches(entries, 2)).toEqual([
      [entries[0], entries[1]],
      [entries[2], entries[3]],
      [entries[4]],
    ]);
  });

  it("returns a single batch when the batch size is larger than the input", () => {
    const entries = [
      { testPath: "a", relativePath: "a", moduleName: "m" },
      { testPath: "b", relativePath: "b", moduleName: "m" },
    ];

    expect(createWptVrtBatches(entries, 10)).toEqual([entries]);
  });
});
