import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import {
  DEFAULT_ALLOWLIST,
  discoverMoonPackages,
  findDeadMoonPackages,
} from "./find-dead-mbt-packages.mjs";

function write(path, content) {
  mkdirSync(path.slice(0, path.lastIndexOf("/")), { recursive: true });
  writeFileSync(path, content);
}

function fixtureRepo() {
  const root = mkdtempSync(join(tmpdir(), "crater-dead-mbt-"));
  write(
    join(root, "moon.mod.json"),
    JSON.stringify({ name: "owner/app", version: "0.0.0" }),
  );
  write(join(root, "live/moon.pkg"), "");
  write(join(root, "dead/moon.pkg"), "");
  write(join(root, "cmd/moon.pkg"), '{ "is-main": true }\n');
  write(join(root, "generated/moon.pkg"), "");
  write(join(root, "testing/e2e/moon.pkg"), "");
  write(
    join(root, "consumer/moon.pkg"),
    'import { "owner/app/live" @live }\n',
  );
  write(
    join(root, "consumer/use.mbt"),
    'let _x = "owner/app/live should not be required outside moon.pkg"\n',
  );
  write(
    join(root, ".mooncakes/vendor/moon.mod.json"),
    JSON.stringify({ name: "vendor/pkg", version: "0.0.0" }),
  );
  write(join(root, ".mooncakes/vendor/unused/moon.pkg"), "");
  return root;
}

test("discoverMoonPackages derives import paths and skips generated dependency trees", () => {
  const packages = discoverMoonPackages(fixtureRepo());
  const importPaths = packages.map((pkg) => pkg.importPath).sort();
  assert.deepEqual(importPaths, [
    "owner/app/cmd",
    "owner/app/consumer",
    "owner/app/dead",
    "owner/app/generated",
    "owner/app/live",
  ]);
});

test("findDeadMoonPackages reports only unreferenced non-main packages outside allowlist", () => {
  const dead = findDeadMoonPackages(fixtureRepo(), {
    allowlist: {
      exact: ["owner/app/generated"],
      prefixes: [],
    },
  });
  assert.deepEqual(
    dead.map((pkg) => pkg.importPath).sort(),
    ["owner/app/consumer", "owner/app/dead"],
  );
});

test("DEFAULT_ALLOWLIST carries crater's known build-tooling false positives", () => {
  assert.ok(DEFAULT_ALLOWLIST.exact.includes("mizchi/crater-wasm"));
  assert.ok(
    DEFAULT_ALLOWLIST.prefixes.includes("mizchi/crater-wasm/gen/interface/"),
  );
});
