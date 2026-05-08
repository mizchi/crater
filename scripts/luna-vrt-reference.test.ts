import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, expect, it, vi } from "vitest";
import {
  buildLunaReferenceCraterInvocation,
  discoverLunaReferenceFixtures,
  parseLunaReferenceVrtArgs,
  runLunaReferenceVrtCli,
  runLunaReferenceVrtSuite,
  type LunaReferenceVrtExecFile,
} from "./luna-vrt-reference";

function fakeArtifact(width = 120, height = 40): string {
  return JSON.stringify({
    artifact: "image",
    data: Buffer.from("png").toString("base64"),
    encoding: "png-base64",
    height,
    width,
  });
}

describe("discoverLunaReferenceFixtures", () => {
  it("discovers sorted HTML fixtures and filters by fixture id", async () => {
    const fixturesDir = await mkdtemp(path.join(tmpdir(), "crater-luna-fixtures-"));
    await writeFile(path.join(fixturesDir, "switch.html"), "<div id='target'>switch</div>");
    await writeFile(path.join(fixturesDir, "alert.html"), "<div id='target'>alert</div>");
    await writeFile(path.join(fixturesDir, "notes.txt"), "ignored");

    await expect(discoverLunaReferenceFixtures(fixturesDir)).resolves.toEqual([
      {
        htmlFile: path.join(fixturesDir, "alert.html"),
        id: "alert",
      },
      {
        htmlFile: path.join(fixturesDir, "switch.html"),
        id: "switch",
      },
    ]);
    await expect(discoverLunaReferenceFixtures(fixturesDir, {
      fixture: "switch",
    })).resolves.toEqual([
      {
        htmlFile: path.join(fixturesDir, "switch.html"),
        id: "switch",
      },
    ]);
  });
});

describe("buildLunaReferenceCraterInvocation", () => {
  it("wraps crater JS entrypoints with node and emits image artifact args", () => {
    expect(buildLunaReferenceCraterInvocation({
      craterBin: "/repo/browser/dist/crater.js",
      fixturePath: "/tmp/switch.html",
      nodeBin: "node-bin",
      scenario: {
        htmlFile: "/tmp/switch.html",
        id: "switch",
        targetId: "target",
        viewport: { height: 240, width: 320 },
      },
    })).toEqual({
      args: [
        "/repo/browser/dist/crater.js",
        "--artifact",
        "image",
        "--target-id",
        "target",
        "--html-file",
        "/tmp/switch.html",
        "--viewport-width",
        "320",
        "--viewport-height",
        "240",
      ],
      command: "node-bin",
    });
  });

  it("uses target selectors without a default target id", () => {
    const invocation = buildLunaReferenceCraterInvocation({
      craterBin: "/repo/bin/crater",
      fixturePath: "/tmp/card.html",
      scenario: {
        htmlFile: "/tmp/card.html",
        id: "card",
      },
      suite: {
        targetSelector: "[data-vrt-root]",
      },
    });

    expect(invocation.command).toBe("/repo/bin/crater");
    expect(invocation.args).toContain("--target-selector");
    expect(invocation.args).toContain("[data-vrt-root]");
    expect(invocation.args).not.toContain("--target-id");
  });
});

describe("runLunaReferenceVrtSuite", () => {
  it("renders generated HTML fixtures through crater without Luna package hooks", async () => {
    const outputDir = await mkdtemp(path.join(tmpdir(), "crater-luna-output-"));
    const calls: Array<{ args: string[]; command: string }> = [];
    const execFile: LunaReferenceVrtExecFile = async (command, args) => {
      calls.push({ args, command });
      return {
        stderr: "",
        stdout: `debug line\n${fakeArtifact(300, 96)}\n`,
      };
    };

    const result = await runLunaReferenceVrtSuite({
      scenarios: [{
        html: "<div id='target'>switch</div>",
        id: "switch primary",
      }],
      targetId: "target",
      viewport: { height: 720, width: 432 },
    }, {
      craterBin: "browser/dist/crater.js",
      execFile,
      outputDir,
    });

    expect(calls).toHaveLength(1);
    expect(calls[0]?.args).toEqual(expect.arrayContaining([
      "--target-id",
      "target",
      "--viewport-width",
      "432",
      "--viewport-height",
      "720",
    ]));
    expect(await readFile(result.captures[0]!.fixturePath, "utf8")).toBe("<div id='target'>switch</div>");
    expect(await readFile(path.join(outputDir, "switch-primary.png"), "utf8")).toBe("png");
    expect(result.captures[0]).toMatchObject({
      bytes: 3,
      height: 96,
      id: "switch primary",
      outputPath: path.join(outputDir, "switch-primary.png"),
      targetId: "target",
      viewport: { height: 720, width: 432 },
      width: 300,
    });
  });
});

describe("parseLunaReferenceVrtArgs", () => {
  it("parses positional fixture and CLI flags", () => {
    expect(parseLunaReferenceVrtArgs([
      "--",
      "switch",
      "--fixtures-dir",
      "fixtures",
      "--output-dir",
      "out",
      "--crater-bin",
      "bin/crater",
      "--target-selector",
      "[data-vrt-root]",
      "--viewport-width",
      "320",
      "--viewport-height",
      "240",
      "--timeout-ms",
      "1000",
      "--json",
    ])).toEqual({
      craterBin: "bin/crater",
      fixture: "switch",
      fixturesDir: "fixtures",
      json: true,
      outputDir: "out",
      targetSelector: "[data-vrt-root]",
      timeoutMs: 1000,
      viewport: { height: 240, width: 320 },
    });
  });

  it("rejects target id and selector together", () => {
    expect(() =>
      parseLunaReferenceVrtArgs([
        "--target-id",
        "target",
        "--target-selector",
        "#target",
      ])
    ).toThrow("Specify either --target-id or --target-selector, not both");
  });
});

describe("runLunaReferenceVrtCli", () => {
  it("runs selector-based captures without adding the default target id", async () => {
    const fixturesDir = await mkdtemp(path.join(tmpdir(), "crater-luna-cli-fixtures-"));
    const outputDir = await mkdtemp(path.join(tmpdir(), "crater-luna-cli-output-"));
    await writeFile(path.join(fixturesDir, "switch.html"), "<div data-vrt-root>switch</div>");
    const calls: Array<{ args: string[] }> = [];
    const execFile: LunaReferenceVrtExecFile = async (_command, args) => {
      calls.push({ args });
      return {
        stderr: "",
        stdout: fakeArtifact(),
      };
    };
    const consoleLog = vi.spyOn(console, "log").mockImplementation(() => {});

    try {
      await runLunaReferenceVrtCli([
        "switch",
        "--fixtures-dir",
        fixturesDir,
        "--output-dir",
        outputDir,
        "--target-selector",
        "[data-vrt-root]",
      ], {
        execFile,
      });
    } finally {
      consoleLog.mockRestore();
    }

    expect(calls).toHaveLength(1);
    expect(calls[0]?.args).toContain("--target-selector");
    expect(calls[0]?.args).toContain("[data-vrt-root]");
    expect(calls[0]?.args).not.toContain("--target-id");
  });
});
