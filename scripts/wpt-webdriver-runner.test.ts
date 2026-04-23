import fs from "fs";
import os from "os";
import path from "path";
import { afterEach, describe, expect, it } from "vitest";
import {
  extractPytestFailureDetails,
  parsePytestSummary,
  resolveBidiServerPath,
  resolveRequestedTargetPath,
  shouldSkipPath,
} from "./wpt-webdriver-runner.ts";

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
  it("detects server in browser/jsbidi/_build when available", () => {
    const cwd = mkTempProject();
    const serverPath = path.join(cwd, "browser/jsbidi/_build/js/release/build/bidi_main/bidi_main.js");
    touch(serverPath);

    expect(resolveBidiServerPath(cwd)).toBe(serverPath);
  });

  it("detects server in workspace root _build when local module output is absent", () => {
    const cwd = mkTempProject();
    const serverPath = path.join(
      cwd,
      "_build/js/release/build/mizchi/crater-jsbidi/bidi_main/bidi_main.js",
    );
    touch(serverPath);

    expect(resolveBidiServerPath(cwd)).toBe(serverPath);
  });

  it("detects server in browser/_build when newer submodule build is missing", () => {
    const cwd = mkTempProject();
    const serverPath = path.join(cwd, "browser/_build/js/release/build/bidi_main/bidi_main.js");
    touch(serverPath);

    expect(resolveBidiServerPath(cwd)).toBe(serverPath);
  });

  it("prefers browser/jsbidi/_build over legacy paths", () => {
    const cwd = mkTempProject();
    const submodulePath = path.join(cwd, "browser/jsbidi/_build/js/release/build/bidi_main/bidi_main.js");
    const workspacePath = path.join(cwd, "_build/js/release/build/mizchi/crater-jsbidi/bidi_main/bidi_main.js");
    const targetPath = path.join(cwd, "browser/target/js/release/build/bidi_main/bidi_main.js");
    const buildPath = path.join(cwd, "browser/_build/js/release/build/bidi_main/bidi_main.js");
    touch(submodulePath);
    touch(workspacePath);
    touch(buildPath);
    touch(targetPath);

    expect(resolveBidiServerPath(cwd)).toBe(submodulePath);
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

describe("extractPytestFailureDetails", () => {
  it("extracts concise lines from pytest short summary info", () => {
    const output = [
      "============================= test session starts ==============================",
      "collected 2 items",
      "",
      "=================================== FAILURES ===================================",
      "... traceback omitted ...",
      "",
      "=========================== short test summary info ============================",
      "FAILED .wpt-temp/tests/bidi/session/subscribe/events.py::test_subscribe_to_module - AssertionError: assert 1 == 2",
      "ERROR .wpt-temp/tests/bidi/script/get_realms/get_realms.py::test_iframes - TimeoutException: Timed out waiting",
      "========================= 1 failed, 1 error in 3.21s ==========================",
    ].join("\n");

    expect(extractPytestFailureDetails(output)).toBe(
      "FAILED .wpt-temp/tests/bidi/session/subscribe/events.py::test_subscribe_to_module - AssertionError: assert 1 == 2 | ERROR .wpt-temp/tests/bidi/script/get_realms/get_realms.py::test_iframes - TimeoutException: Timed out waiting",
    );
  });
});

describe("shouldSkipPath", () => {
  it("supports glob patterns for nested auth-related paths", () => {
    expect(shouldSkipPath("network/auth_required/auth_required.py", ["network/auth_required/**"])).toBe(true);
    expect(shouldSkipPath("network/continue_with_auth/action.py", ["network/continue_with_auth/**"])).toBe(true);
    expect(shouldSkipPath("network/add_intercept/invalid.py", ["network/auth_required/**"])).toBe(false);
  });
});

describe("resolveRequestedTargetPath", () => {
  it("accepts file targets without .py suffix", () => {
    const cwd = mkTempProject();
    const bidiRoot = path.join(cwd, "wpt/webdriver/tests/bidi");
    const targetPath = path.join(bidiRoot, "script/realm_created/window_open.py");
    touch(targetPath);

    expect(resolveRequestedTargetPath("script/realm_created/window_open", bidiRoot)).toBe("script/realm_created/window_open.py");
  });
});

describe("crater_bidi_adapter fixture builder path", () => {
  it("uses the renamed jsbidi workspace path", () => {
    const adapter = fs.readFileSync(path.join(process.cwd(), "scripts/crater_bidi_adapter.py"), "utf-8");

    expect(adapter).toContain('root / "_build" / "js" / "release" / "build" / "mizchi" / "crater-jsbidi" / "webdriver_fixture_builder" / "webdriver_fixture_builder.js"');
    expect(adapter).not.toContain("crater-browser-js");
  });
});
