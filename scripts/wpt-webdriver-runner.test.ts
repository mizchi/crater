import fs from "fs";
import os from "os";
import path from "path";
import { afterEach, describe, expect, it } from "vitest";
import { parsePytestSummary, resolveBidiServerPath } from "./wpt-webdriver-runner.ts";

const createdDirs: string[] = [];

function mkTempProject(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "crater-wpt-webdriver-"));
  createdDirs.push(dir);
  return dir;
}

function touch(filepath: string): void {
  fs.mkdirSync(path.dirname(filepath), { recursive: true });
  fs.writeFileSync(filepath, "// test", "utf-8");
}

afterEach(() => {
  for (const dir of createdDirs.splice(0)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

describe("resolveBidiServerPath", () => {
  it("detects server in browser/_build when browser/target is missing", () => {
    const cwd = mkTempProject();
    const serverPath = path.join(cwd, "browser/_build/js/release/build/bidi_main/bidi_main.js");
    touch(serverPath);

    expect(resolveBidiServerPath(cwd)).toBe(serverPath);
  });

  it("prefers browser/target when both browser/target and browser/_build exist", () => {
    const cwd = mkTempProject();
    const targetPath = path.join(cwd, "browser/target/js/release/build/bidi_main/bidi_main.js");
    const buildPath = path.join(cwd, "browser/_build/js/release/build/bidi_main/bidi_main.js");
    touch(buildPath);
    touch(targetPath);

    expect(resolveBidiServerPath(cwd)).toBe(targetPath);
  });

  it("returns null when no server file exists", () => {
    const cwd = mkTempProject();
    expect(resolveBidiServerPath(cwd)).toBe(null);
  });
});

describe("parsePytestSummary", () => {
  it("extracts passed/failed/errors from pytest summary line", () => {
    const output = [
      "============================= test session starts ==============================",
      "collected 8 items",
      "",
      "================== 2 failed, 5 passed, 1 error in 3.13s ==================",
    ].join("\n");

    expect(parsePytestSummary(output)).toEqual({
      passed: 5,
      failed: 2,
      errors: 1,
      total: 8,
    });
  });

  it("ignores skipped/xfailed counts for compatibility pass rate", () => {
    const output = "================== 7 passed, 3 skipped, 1 xfailed in 2.00s ==================";

    expect(parsePytestSummary(output)).toEqual({
      passed: 7,
      failed: 0,
      errors: 0,
      total: 7,
    });
  });
});
