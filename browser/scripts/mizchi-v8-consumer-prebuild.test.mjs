import assert from "node:assert/strict"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import { resolve_v8_module_root } from "./mizchi-v8-consumer-prebuild.mjs"

function write_json(file_path, value) {
  fs.mkdirSync(path.dirname(file_path), { recursive: true })
  fs.writeFileSync(file_path, `${JSON.stringify(value, null, 2)}\n`)
}

test("resolve_v8_module_root prefers a local path dependency", (t) => {
  const temp_root = fs.mkdtempSync(path.join(os.tmpdir(), "mizchi-v8-prebuild-"))
  t.after(() => fs.rmSync(temp_root, { recursive: true, force: true }))

  const module_root = path.join(temp_root, "browser")
  const vendor_v8_root = path.join(temp_root, "vendor", "v8")
  write_json(path.join(module_root, "moon.mod.json"), {
    name: "mizchi/crater-browser",
    deps: {
      "mizchi/v8": {
        path: "../vendor/v8",
      },
    },
  })
  write_json(path.join(vendor_v8_root, "moon.mod.json"), {
    name: "mizchi/v8",
  })

  assert.equal(resolve_v8_module_root(module_root), vendor_v8_root)
})

test("resolve_v8_module_root falls back to nested consumer mooncakes", (t) => {
  const temp_root = fs.mkdtempSync(path.join(os.tmpdir(), "mizchi-v8-prebuild-"))
  t.after(() => fs.rmSync(temp_root, { recursive: true, force: true }))

  const browser_root = path.join(temp_root, "browser")
  const jsbidi_root = path.join(browser_root, "jsbidi")
  const v8_root = path.join(jsbidi_root, ".mooncakes", "mizchi", "v8")
  write_json(path.join(browser_root, "moon.mod.json"), {
    name: "mizchi/crater-browser",
    deps: {
      "mizchi/crater": {
        path: "..",
      },
    },
  })
  write_json(path.join(v8_root, "moon.mod.json"), {
    name: "mizchi/v8",
  })

  assert.equal(resolve_v8_module_root(browser_root), v8_root)
})

test("resolve_v8_module_root falls back to ancestor workspace mooncakes", (t) => {
  const temp_root = fs.mkdtempSync(path.join(os.tmpdir(), "mizchi-v8-prebuild-"))
  t.after(() => fs.rmSync(temp_root, { recursive: true, force: true }))

  const native_root = path.join(temp_root, "browser", "native")
  const v8_root = path.join(temp_root, ".mooncakes", "mizchi", "v8")
  write_json(path.join(native_root, "moon.mod.json"), {
    name: "mizchi/crater-browser-native",
    deps: {
      "mizchi/v8": "0.2.0",
    },
  })
  write_json(path.join(v8_root, "moon.mod.json"), {
    name: "mizchi/v8",
  })

  assert.equal(resolve_v8_module_root(native_root), v8_root)
})
