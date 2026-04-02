import { describe, expect, it } from "vitest";
import {
  assertRequiredOptions,
  createBooleanFlagHandler,
  createReportOutputHandlers,
  parseCliFlags,
  renderUsage,
  type CliFlagHandlerMap,
} from "./script-cli.ts";

describe("parseCliFlags", () => {
  it("parses value and boolean flags", () => {
    const handlers: CliFlagHandlerMap<{
      inputDir: string;
      jsonOutput?: string;
      githubMatrix: boolean;
    }> = {
      "--input": {
        set: (target, value) => {
          target.inputDir = value ?? "";
        },
      },
      ...createReportOutputHandlers(),
      "--github-matrix": createBooleanFlagHandler((target) => {
        target.githubMatrix = true;
      }),
    };

    const parsed = parseCliFlags(
      ["--input", "nightly", "--github-matrix", "--json", "out.json"],
      {
        inputDir: "",
        githubMatrix: false,
      },
      {
        usage: () => "usage",
        handlers,
      },
    );

    expect(parsed).toEqual({
      inputDir: "nightly",
      githubMatrix: true,
      jsonOutput: "out.json",
    });
  });

  it("parses markdown output through shared report handlers", () => {
    const parsed = parseCliFlags(
      ["--markdown", "out.md"],
      {},
      {
        usage: () => "usage",
        handlers: createReportOutputHandlers(),
      },
    );

    expect(parsed).toEqual({
      markdownOutput: "out.md",
    });
  });

  it("prints usage and exits through injected hooks", () => {
    const messages: string[] = [];
    const exitCodes: number[] = [];

    expect(() =>
      parseCliFlags([], { value: "" }, {
        usage: () => "usage text",
        handlers: {},
        printUsage: (message) => {
          messages.push(message);
        },
        exit: (code) => {
          exitCodes.push(code);
          throw new Error("exit");
        },
      }),
    ).not.toThrow();

    expect(messages).toEqual([]);
    expect(exitCodes).toEqual([]);

    expect(() =>
      parseCliFlags(["--help"], { value: "" }, {
        usage: () => "usage text",
        handlers: {},
        printUsage: (message) => {
          messages.push(message);
        },
        exit: (code) => {
          exitCodes.push(code);
          throw new Error("exit");
        },
      }),
    ).toThrow("exit");

    expect(messages).toEqual(["usage text"]);
    expect(exitCodes).toEqual([0]);
  });
});

describe("renderUsage", () => {
  it("renders summary, command, options, and help", () => {
    const usage = renderUsage({
      summary: "Aggregate results",
      command: "node scripts/tool.ts --input <dir> [options]",
      optionLines: [
        "  --input <dir>    Input root",
        "  --json <file>    Write JSON summary",
      ],
    });

    expect(usage).toContain("Aggregate results");
    expect(usage).toContain("Usage:");
    expect(usage).toContain("  node scripts/tool.ts --input <dir> [options]");
    expect(usage).toContain("  --input <dir>    Input root");
    expect(usage).toContain("  --json <file>    Write JSON summary");
    expect(usage).toContain("  --help           Show this help");
  });
});

describe("assertRequiredOptions", () => {
  it("accepts populated values", () => {
    expect(() =>
      assertRequiredOptions(
        {
          taskId: "paint-vrt",
          configPath: "flaker.star",
        },
        [
          {
            select: (options) => options.taskId,
            errorMessage: "--task is required",
          },
          {
            select: (options) => options.configPath,
            errorMessage: "--config requires a file path",
          },
        ],
      ),
    ).not.toThrow();
  });

  it("throws the matching message for the first missing value", () => {
    expect(() =>
      assertRequiredOptions(
        {
          taskId: "",
          configPath: "",
        },
        [
          {
            select: (options) => options.taskId,
            errorMessage: "--task is required",
          },
          {
            select: (options) => options.configPath,
            errorMessage: "--config requires a file path",
          },
        ],
      ),
    ).toThrow("--task is required");
  });
});
