import assert from "node:assert/strict"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import { copyDist, resolveBuildArtifactPath } from "../scripts/copy-dist.mjs"

function touch(filePath, content = "// test\n") {
  fs.mkdirSync(path.dirname(filePath), { recursive: true })
  fs.writeFileSync(filePath, content)
}

test("copyDist uses the workspace build when stale module artifacts remain", (t) => {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "crater-copy-dist-"))
  t.after(() => fs.rmSync(workspace, { recursive: true, force: true }))
  const moduleDir = path.join(workspace, "js")
  for (const [target, filename, content] of [
    ["js", "crater-js.js", "fresh-js"],
    ["wasm-gc", "crater-js.wasm", "fresh-wasm"],
  ]) {
    touch(path.join(moduleDir, "_build", target, "release", "build", filename), "stale")
    touch(path.join(workspace, "_build", target, "release", "build", "mizchi", "crater-js", filename), content)
  }
  for (const filename of ["index.js", "index.d.ts", "wasm.js", "wasm.d.ts", "gfx-web-runtime.mjs"]) {
    touch(path.join(moduleDir, filename))
  }

  copyDist(moduleDir)

  assert.equal(fs.readFileSync(path.join(moduleDir, "dist", "crater.js"), "utf8"), "fresh-js")
  assert.equal(fs.readFileSync(path.join(moduleDir, "dist", "crater.wasm"), "utf8"), "fresh-wasm")
})

test("resolveBuildArtifactPath prefers local module build output", (t) => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-copy-dist-"))
  t.after(() => fs.rmSync(tempRoot, { recursive: true, force: true }))

  const localArtifact = path.join(tempRoot, "_build", "js", "release", "build", "crater-js.js")
  const workspaceArtifact = path.join(
    tempRoot,
    "..",
    "_build",
    "js",
    "release",
    "build",
    "mizchi",
    "crater-js",
    "crater-js.js",
  )
  touch(localArtifact, "local")
  touch(workspaceArtifact, "workspace")

  assert.equal(
    resolveBuildArtifactPath(tempRoot, [
      "_build/js/release/build/crater-js.js",
      "../_build/js/release/build/mizchi/crater-js/crater-js.js",
    ]),
    localArtifact,
  )
})

test("copyDist falls back to workspace root build output", (t) => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-copy-dist-"))
  t.after(() => fs.rmSync(tempRoot, { recursive: true, force: true }))

  touch(
    path.join(
      tempRoot,
      "..",
      "_build",
      "js",
      "release",
      "build",
      "mizchi",
      "crater-js",
      "crater-js.js",
    ),
    "workspace-js",
  )
  touch(
    path.join(
      tempRoot,
      "..",
      "_build",
      "wasm-gc",
      "release",
      "build",
      "mizchi",
      "crater-js",
      "crater-js.wasm",
    ),
    "workspace-wasm",
  )
  touch(path.join(tempRoot, "index.js"), "index")
  touch(path.join(tempRoot, "index.d.ts"), "index-types")
  touch(path.join(tempRoot, "wasm.js"), "wasm")
  touch(path.join(tempRoot, "wasm.d.ts"), "wasm-types")
  touch(path.join(tempRoot, "gfx-web-runtime.mjs"), "runtime")

  copyDist(tempRoot)

  assert.equal(
    fs.readFileSync(path.join(tempRoot, "dist", "crater.js"), "utf8"),
    "workspace-js",
  )
  assert.equal(
    fs.readFileSync(path.join(tempRoot, "dist", "crater.wasm"), "utf8"),
    "workspace-wasm",
  )
  assert.equal(
    fs.readFileSync(path.join(tempRoot, "dist", "index.js"), "utf8"),
    "index",
  )
})
