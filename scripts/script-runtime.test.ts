import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  appendReportWrites,
  emitScriptExecutionResult,
  isMainModule,
  writeOutput,
} from "./script-runtime.ts";

describe("writeOutput", () => {
  it("creates parent directories before writing", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-script-runtime-"));
    const targetPath = path.join(root, "nested", "summary.md");

    writeOutput(targetPath, "# summary\n");

    expect(fs.readFileSync(targetPath, "utf8")).toBe("# summary\n");
  });
});

describe("isMainModule", () => {
  it("matches file URLs against argv[1]", () => {
    expect(
      isMainModule("file:///tmp/tool.ts", "/tmp/tool.ts"),
    ).toBe(true);
    expect(
      isMainModule("file:///tmp/tool.ts", "/tmp/other.ts"),
    ).toBe(false);
  });
});

describe("emitScriptExecutionResult", () => {
  it("writes stdout, stderr, artifacts, and exit code through injected sinks", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-script-runtime-emit-"));
    const targetPath = path.join(root, "report.json");
    let stdout = "";
    let stderr = "";
    let exitCode = 0;

    emitScriptExecutionResult(
      {
        exitCode: 1,
        stdout: "hello\n",
        stderr: "boom\n",
        writes: [
          {
            path: targetPath,
            content: '{"ok":true}\n',
          },
        ],
      },
      {
        stdoutWrite: (content) => {
          stdout += content;
        },
        stderrWrite: (content) => {
          stderr += content;
        },
        exit: (code) => {
          exitCode = code;
        },
      },
    );

    expect(stdout).toBe("hello\n");
    expect(stderr).toBe("boom\n");
    expect(fs.readFileSync(targetPath, "utf8")).toBe('{"ok":true}\n');
    expect(exitCode).toBe(1);
  });
});

describe("appendReportWrites", () => {
  it("appends optional markdown and json writes with resolved paths", () => {
    const writes: { path: string; content: string }[] = [];

    appendReportWrites(writes, {
      cwd: "/repo",
      markdownPath: "out/report.md",
      markdownContent: "# report\n",
      jsonPath: "out/report.json",
      jsonValue: { ok: true },
    });

    expect(writes).toEqual([
      {
        path: path.resolve("/repo", "out/report.md"),
        content: "# report\n",
      },
      {
        path: path.resolve("/repo", "out/report.json"),
        content: '{\n  "ok": true\n}\n',
      },
    ]);
  });
});
