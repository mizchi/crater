import fs from "fs";
import os from "os";
import path from "path";
import { afterEach, describe, expect, it } from "vitest";
import { resolveBidiServerPath } from "./wpt-webdriver-runner.ts";

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
