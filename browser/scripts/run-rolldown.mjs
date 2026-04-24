#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const BROWSER_ROOT = path.resolve(SCRIPT_DIR, "..");
const PNPM_DIR = path.join(BROWSER_ROOT, "node_modules", ".pnpm");

function resolveRolldownCli() {
  const candidates = [];
  for (const entry of fs.readdirSync(PNPM_DIR, { withFileTypes: true })) {
    if (!entry.isDirectory() || !entry.name.startsWith("rolldown@")) continue;
    const cliPath = path.join(PNPM_DIR, entry.name, "node_modules", "rolldown", "bin", "cli.mjs");
    if (fs.existsSync(cliPath)) {
      candidates.push(cliPath);
    }
  }
  candidates.sort();
  if (candidates.length === 0) {
    throw new Error("rolldown CLI not found under browser/node_modules/.pnpm");
  }
  return candidates[candidates.length - 1];
}

const cliPath = resolveRolldownCli();
const result = spawnSync(process.execPath, [cliPath, ...process.argv.slice(2)], {
  cwd: BROWSER_ROOT,
  stdio: "inherit",
});

if (result.error) {
  throw result.error;
}

process.exit(result.status ?? 1);
