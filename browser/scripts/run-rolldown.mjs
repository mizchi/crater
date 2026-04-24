#!/usr/bin/env node

import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const BROWSER_ROOT = path.resolve(SCRIPT_DIR, "..");
const require = createRequire(import.meta.url);
const SCRIPT_PATH = fileURLToPath(import.meta.url);

function findPnpmRolldownCli(pnpmDir) {
  if (!fs.existsSync(pnpmDir)) return null;
  const candidates = [];
  for (const entry of fs.readdirSync(pnpmDir, { withFileTypes: true })) {
    if (!entry.isDirectory() || !entry.name.startsWith("rolldown@")) continue;
    const cliPath = path.join(pnpmDir, entry.name, "node_modules", "rolldown", "bin", "cli.mjs");
    if (fs.existsSync(cliPath)) {
      candidates.push(cliPath);
    }
  }
  candidates.sort();
  return candidates.at(-1) ?? null;
}

export function resolveRolldownCli(searchRoot = BROWSER_ROOT) {
  try {
    return require.resolve("rolldown/bin/cli.mjs", { paths: [searchRoot] });
  } catch {}

  let current = path.resolve(searchRoot);
  while (true) {
    const pnpmCli = findPnpmRolldownCli(path.join(current, "node_modules", ".pnpm"));
    if (pnpmCli) {
      return pnpmCli;
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }

  throw new Error(`rolldown CLI not found from ${searchRoot}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === SCRIPT_PATH) {
  const cliPath = resolveRolldownCli();
  const result = spawnSync(process.execPath, [cliPath, ...process.argv.slice(2)], {
    cwd: BROWSER_ROOT,
    stdio: "inherit",
  });

  if (result.error) {
    throw result.error;
  }

  process.exit(result.status ?? 1);
}
