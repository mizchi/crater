import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  appendFlakerCollectedSummaryWrites,
  resolveFlakerCollectedSummaryPaths,
} from "./flaker-collected-summary-paths.ts";

describe("resolveFlakerCollectedSummaryPaths", () => {
  it("builds collect-compatible summary paths per task and kind", () => {
    expect(resolveFlakerCollectedSummaryPaths("/tmp/out", "paint-vrt", "vrt-summary")).toEqual({
      jsonPath: "/tmp/out/paint-vrt/vrt-summary/paint-vrt.json",
      markdownPath: "/tmp/out/paint-vrt/vrt-summary/paint-vrt.md",
    });
    expect(resolveFlakerCollectedSummaryPaths("/tmp/out", "flaker-daily", "batch-summary")).toEqual({
      jsonPath: "/tmp/out/flaker-daily/batch-summary/flaker-daily.json",
      markdownPath: "/tmp/out/flaker-daily/batch-summary/flaker-daily.md",
    });
  });
});

describe("appendFlakerCollectedSummaryWrites", () => {
  it("deduplicates base dirs resolved from json and markdown outputs", () => {
    const writes: Array<{ path: string; content: string }> = [];

    appendFlakerCollectedSummaryWrites(writes, {
      cwd: "/repo",
      taskId: "paint-vrt",
      kind: "playwright-summary",
      jsonOutput: "out/summary.json",
      markdownOutput: "out/summary.md",
      jsonContent: "{\n}\n",
      markdownContent: "# Summary\n",
    });

    expect(writes).toEqual([
      {
        path: path.resolve("/repo", "out/paint-vrt/playwright-summary/paint-vrt.md"),
        content: "# Summary\n",
      },
      {
        path: path.resolve("/repo", "out/paint-vrt/playwright-summary/paint-vrt.json"),
        content: "{\n}\n",
      },
    ]);
  });

  it("reuses already collect-compatible task artifact directories", () => {
    const writes: Array<{ path: string; content: string }> = [];

    appendFlakerCollectedSummaryWrites(writes, {
      cwd: "/repo",
      taskId: "paint-vrt",
      kind: "flaker-summary",
      jsonOutput: "flaker-daily/paint-vrt/flaker-summary/paint-vrt.json",
      markdownOutput: "flaker-daily/paint-vrt/flaker-summary/paint-vrt.md",
      jsonContent: "{\n}\n",
      markdownContent: "# Summary\n",
    });

    expect(writes).toEqual([
      {
        path: path.resolve("/repo", "flaker-daily/paint-vrt/flaker-summary/paint-vrt.md"),
        content: "# Summary\n",
      },
      {
        path: path.resolve("/repo", "flaker-daily/paint-vrt/flaker-summary/paint-vrt.json"),
        content: "{\n}\n",
      },
    ]);
  });

  it("skips collect copies when the target files are already queued", () => {
    const writes = [
      {
        path: path.resolve("/repo", "flaker-daily/paint-vrt/flaker-summary/paint-vrt.md"),
        content: "# Summary\n",
      },
      {
        path: path.resolve("/repo", "flaker-daily/paint-vrt/flaker-summary/paint-vrt.json"),
        content: "{\n}\n",
      },
    ];

    appendFlakerCollectedSummaryWrites(writes, {
      cwd: "/repo",
      taskId: "paint-vrt",
      kind: "flaker-summary",
      jsonOutput: "flaker-daily/paint-vrt/flaker-summary/paint-vrt.json",
      markdownOutput: "flaker-daily/paint-vrt/flaker-summary/paint-vrt.md",
      jsonContent: "{\n}\n",
      markdownContent: "# Summary\n",
    });

    expect(writes).toEqual([
      {
        path: path.resolve("/repo", "flaker-daily/paint-vrt/flaker-summary/paint-vrt.md"),
        content: "# Summary\n",
      },
      {
        path: path.resolve("/repo", "flaker-daily/paint-vrt/flaker-summary/paint-vrt.json"),
        content: "{\n}\n",
      },
    ]);
  });

  it("writes one collect copy per distinct output directory", () => {
    const writes: Array<{ path: string; content: string }> = [];

    appendFlakerCollectedSummaryWrites(writes, {
      cwd: "/repo",
      taskId: "paint-vrt",
      kind: "flaker-summary",
      jsonOutput: "out/json/summary.json",
      markdownOutput: "out/markdown/summary.md",
      jsonContent: "{\n}\n",
      markdownContent: "# Summary\n",
    });

    expect(writes).toEqual([
      {
        path: path.resolve("/repo", "out/json/paint-vrt/flaker-summary/paint-vrt.md"),
        content: "# Summary\n",
      },
      {
        path: path.resolve("/repo", "out/json/paint-vrt/flaker-summary/paint-vrt.json"),
        content: "{\n}\n",
      },
      {
        path: path.resolve("/repo", "out/markdown/paint-vrt/flaker-summary/paint-vrt.md"),
        content: "# Summary\n",
      },
      {
        path: path.resolve("/repo", "out/markdown/paint-vrt/flaker-summary/paint-vrt.json"),
        content: "{\n}\n",
      },
    ]);
  });
});
