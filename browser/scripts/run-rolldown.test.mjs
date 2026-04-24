import assert from "node:assert/strict"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import { resolveRolldownCli } from "./run-rolldown.mjs"

function write_file(file_path, content = "") {
  fs.mkdirSync(path.dirname(file_path), { recursive: true })
  fs.writeFileSync(file_path, content)
}

function canonical_path(file_path) {
  return fs.realpathSync.native?.(file_path) ?? fs.realpathSync(file_path)
}

test("resolveRolldownCli prefers npm-style node_modules", (t) => {
  const temp_root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-rolldown-"))
  t.after(() => fs.rmSync(temp_root, { recursive: true, force: true }))

  const browser_root = path.join(temp_root, "browser")
  const cli_path = path.join(browser_root, "node_modules", "rolldown", "bin", "cli.mjs")
  write_file(cli_path, "export {};\n")

  assert.equal(canonical_path(resolveRolldownCli(browser_root)), canonical_path(cli_path))
})

test("resolveRolldownCli falls back to ancestor node_modules", (t) => {
  const temp_root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-rolldown-"))
  t.after(() => fs.rmSync(temp_root, { recursive: true, force: true }))

  const browser_root = path.join(temp_root, "browser")
  const cli_path = path.join(temp_root, "node_modules", "rolldown", "bin", "cli.mjs")
  write_file(cli_path, "export {};\n")

  assert.equal(canonical_path(resolveRolldownCli(browser_root)), canonical_path(cli_path))
})

test("resolveRolldownCli falls back to pnpm store layout without symlink", (t) => {
  const temp_root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-rolldown-"))
  t.after(() => fs.rmSync(temp_root, { recursive: true, force: true }))

  const browser_root = path.join(temp_root, "browser")
  const cli_path = path.join(
    temp_root,
    "node_modules",
    ".pnpm",
    "rolldown@1.0.0-beta.59",
    "node_modules",
    "rolldown",
    "bin",
    "cli.mjs",
  )
  write_file(cli_path, "export {};\n")

  assert.equal(canonical_path(resolveRolldownCli(browser_root)), canonical_path(cli_path))
})
