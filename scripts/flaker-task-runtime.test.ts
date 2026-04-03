import { describe, expect, it } from "vitest";
import {
  assertValidFlakerTaskRuntimeOptions,
  createFlakerTaskRuntimeDefaults,
  runJsonTextCommand,
} from "./flaker-task-runtime.ts";

describe("assertValidFlakerTaskRuntimeOptions", () => {
  it("accepts populated task runtime options", () => {
    const options = createFlakerTaskRuntimeDefaults("/tmp/repo");
    options.taskId = "paint-vrt";

    expect(() => assertValidFlakerTaskRuntimeOptions(options)).not.toThrow();
  });

  it("rejects missing task ids", () => {
    expect(() =>
      assertValidFlakerTaskRuntimeOptions(createFlakerTaskRuntimeDefaults("/tmp/repo")),
    ).toThrow("--task is required");
  });

  it("rejects missing flaker cli paths", () => {
    const options = createFlakerTaskRuntimeDefaults("/tmp/repo");
    options.taskId = "paint-vrt";
    options.flakerCliPath = "";

    expect(() => assertValidFlakerTaskRuntimeOptions(options)).toThrow(
      "--flaker-cli requires a file path",
    );
  });
});

describe("runJsonTextCommand", () => {
  it("parses JSON stdout via injected spawnText", () => {
    const result = runJsonTextCommand("node", ["tool.js", "eval", "--json"], {
      cwd: "/tmp/repo",
      maxBuffer: 1024,
      commandLabel: "flaker eval",
      spawnText: () => ({
        status: 0,
        stdout: JSON.stringify({ healthScore: 72 }),
      }),
    });

    expect(result).toEqual({ healthScore: 72 });
  });

  it("throws with stderr when the command fails", () => {
    expect(() =>
      runJsonTextCommand("node", ["tool.js", "reason", "--json"], {
        cwd: "/tmp/repo",
        maxBuffer: 1024,
        commandLabel: "flaker reason",
        spawnText: () => ({
          status: 1,
          stderr: "boom",
        }),
      }),
    ).toThrow("flaker reason failed: boom");
  });
});
