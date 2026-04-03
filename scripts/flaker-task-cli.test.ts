import { describe, expect, it } from "vitest";
import { createFlakerTaskRuntimeDefaults } from "./flaker-task-runtime.ts";
import {
  parseFlakerTaskCliFlags,
  renderFlakerTaskUsage,
  splitCliArgsOnSeparator,
} from "./flaker-task-cli.ts";

describe("splitCliArgsOnSeparator", () => {
  it("splits arguments around -- for downstream command forwarding", () => {
    expect(
      splitCliArgsOnSeparator([
        "--task",
        "paint-vrt",
        "--owner",
        "mizchi",
        "--",
        "sample",
        "--count",
        "5",
      ]),
    ).toEqual({
      head: ["--task", "paint-vrt", "--owner", "mizchi"],
      tail: ["sample", "--count", "5"],
    });
  });
});

describe("parseFlakerTaskCliFlags", () => {
  it("parses shared runtime flags and task-specific extensions", () => {
    const options = {
      ...createFlakerTaskRuntimeDefaults("/tmp/repo"),
      branch: "",
    };

    const parsed = parseFlakerTaskCliFlags(
      [
        "--task",
        "paint-vrt",
        "--repo",
        "sandbox",
        "--workspace-root",
        ".cache/flaker",
        "--branch",
        "main",
      ],
      options,
      {
        usage: () => "usage",
        extraHandlers: {
          "--branch": {
            set: (target, value) => {
              target.branch = value;
            },
          },
        },
      },
    );

    expect(parsed).toMatchObject({
      taskId: "paint-vrt",
      repo: "sandbox",
      workspaceRoot: ".cache/flaker",
      branch: "main",
    });
  });

  it("prints usage and exits through injected hooks", () => {
    const messages: string[] = [];
    const exitCodes: number[] = [];

    expect(() =>
      parseFlakerTaskCliFlags(
        ["--help"],
        createFlakerTaskRuntimeDefaults("/tmp/repo"),
        {
          usage: () => "usage text",
          printUsage: (message) => {
            messages.push(message);
          },
          exit: (code) => {
            exitCodes.push(code);
            throw new Error("exit");
          },
        },
      ),
    ).toThrow("exit");

    expect(messages).toEqual(["usage text"]);
    expect(exitCodes).toEqual([0]);
  });
});

describe("renderFlakerTaskUsage", () => {
  it("renders shared runtime options with extra task-specific lines", () => {
    const usage = renderFlakerTaskUsage({
      summary: "Run flaker task",
      command: "node scripts/flaker-task-run.ts --task <task-id> -- <flaker args...>",
      defaultFlakerCliPath: "/tmp/flaker-cli.js",
      extraOptions: [
        "  --json <file>       Write JSON summary",
      ],
    });

    expect(usage).toContain("Run flaker task");
    expect(usage).toContain("Usage:");
    expect(usage).toContain("  --task <id>           Task id from flaker.star");
    expect(usage).toContain("  --config <file>       flaker.star path (default: flaker.star)");
    expect(usage).toContain("  --manifest <file>     quarantine manifest path (default: flaker-quarantine.json)");
    expect(usage).toContain("  --flaker-cli <file>   Metric CI / flaker CLI entry (default: /tmp/flaker-cli.js)");
    expect(usage).toContain("  --json <file>       Write JSON summary");
    expect(usage).toContain("  --help                Show this help");
  });
});
