import { execFileSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, expect, test } from "vitest";

const directories: string[] = [];
afterEach(() => {
  for (const directory of directories.splice(0)) rmSync(directory, { recursive: true, force: true });
});

function fixture() {
  const root = mkdtempSync(path.join(tmpdir(), "crater chromium cache "));
  directories.push(root);
  const cache = path.join(root, "browsers");
  const bin = path.join(root, "bin");
  mkdirSync(bin);
  writeFileSync(path.join(bin, "pnpm"), `#!/usr/bin/env bash
if [ "$2" = "node" ]; then
  printf '%s\\n' "$CRATER_TEST_CHROME"
else
  printf '%s\\n' "$CRATER_TEST_DRY_RUN"
fi
`, { mode: 0o755 });
  const chrome = path.join(cache, "chromium-1254/chrome-linux64/chrome");
  const shell = path.join(cache, "chromium_headless_shell-1254");
  const executable = (name: string) => {
    mkdirSync(path.dirname(name), { recursive: true });
    writeFileSync(name, "#!/bin/sh\nexit 0\n", { mode: 0o755 });
  };
  return {
    cache, chrome, shell, executable,
    present: () => execFileSync("bash", ["scripts/ci/chromium-cache-present.sh"], {
      encoding: "utf8",
      env: {
        ...process.env, PATH: `${bin}:${process.env.PATH}`, PLAYWRIGHT_BROWSERS_PATH: cache,
        CRATER_TEST_CHROME: chrome,
        CRATER_TEST_DRY_RUN: `Chrome\n  Install location: ${path.dirname(path.dirname(chrome))}\nChrome Headless Shell\n  Install location: ${shell}\n`,
      },
    }).trim(),
  };
}

test("rejects a restored Chromium from an older Playwright revision", () => {
  const f = fixture();
  f.executable(path.join(f.cache, "chromium-1234/chrome-linux/chrome"));
  expect(f.present()).toBe("false");
});

test("rejects the current Chromium when its headless shell is missing", () => {
  const f = fixture();
  f.executable(f.chrome);
  expect(f.present()).toBe("false");
});

test.each(["chrome-headless-shell-linux64/chrome-headless-shell", "chrome-linux/headless_shell"])(
  "accepts the current Chromium and executable headless shell at %s", (layout) => {
    const f = fixture();
    f.executable(f.chrome);
    f.executable(path.join(f.shell, layout));
    expect(f.present()).toBe("true");
  },
);

test("rejects an incomplete cache with a non-executable headless shell", () => {
  const f = fixture();
  f.executable(f.chrome);
  const shell = path.join(f.shell, "chrome-headless-shell-linux64/chrome-headless-shell");
  f.executable(shell);
  chmodSync(shell, 0o644);
  expect(f.present()).toBe("false");
});
