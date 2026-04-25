import assert from "node:assert/strict"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import {
  binding_suffix_for,
  read_rusty_v8_release,
  replace_non_alphanumeric,
  resolve_prefetch_spec,
  source_binding_cache_path,
  source_binding_url,
} from "./prefetch-rusty-v8-source-binding.mjs"

function write_json(file_path, value) {
  fs.mkdirSync(path.dirname(file_path), { recursive: true })
  fs.writeFileSync(file_path, `${JSON.stringify(value, null, 2)}\n`)
}

test("binding_suffix_for maps current CI hosts", () => {
  assert.equal(binding_suffix_for("linux", "x64"), "x86_64-unknown-linux-gnu")
  assert.equal(binding_suffix_for("linux", "arm64"), "aarch64-unknown-linux-gnu")
  assert.equal(binding_suffix_for("darwin", "arm64"), "aarch64-apple-darwin")
  assert.equal(binding_suffix_for("darwin", "x64"), "x86_64-apple-darwin")
})

test("replace_non_alphanumeric matches rusty_v8 cache naming", () => {
  const url =
    "https://github.com/denoland/rusty_v8/releases/download/v146.8.0/src_binding_release_x86_64-unknown-linux-gnu.rs"
  assert.equal(
    replace_non_alphanumeric(url),
    "https___github_com_denoland_rusty_v8_releases_download_v146_8_0_src_binding_release_x86_64_unknown_linux_gnu_rs",
  )
})

test("source_binding_cache_path stores entries under ~/.cargo/.rusty_v8", () => {
  const url =
    "https://github.com/denoland/rusty_v8/releases/download/v146.8.0/src_binding_release_x86_64-unknown-linux-gnu.rs"
  assert.equal(
    source_binding_cache_path(url, "/tmp/cargo-home"),
    "/tmp/cargo-home/.rusty_v8/https___github_com_denoland_rusty_v8_releases_download_v146_8_0_src_binding_release_x86_64_unknown_linux_gnu_rs",
  )
})

test("resolve_prefetch_spec reads release from mizchi/v8 module", (t) => {
  const temp_root = fs.mkdtempSync(path.join(os.tmpdir(), "rusty-v8-prefetch-"))
  t.after(() => fs.rmSync(temp_root, { recursive: true, force: true }))

  const webdriver_root = path.join(temp_root, "webdriver")
  const v8_root = path.join(temp_root, ".mooncakes", "mizchi", "v8")
  write_json(path.join(webdriver_root, "moon.mod.json"), {
    name: "mizchi/crater-webdriver-bidi",
    deps: {
      "mizchi/v8": "0.2.0",
    },
  })
  write_json(path.join(v8_root, "moon.mod.json"), {
    name: "mizchi/v8",
  })
  fs.mkdirSync(path.join(v8_root, "deps"), { recursive: true })
  fs.writeFileSync(path.join(v8_root, "deps", "rusty_v8.rev"), "v146.8.0\n")

  const spec = resolve_prefetch_spec(webdriver_root)
  assert.equal(spec.release, "v146.8.0")
  assert.equal(spec.url, source_binding_url("v146.8.0", binding_suffix_for(process.platform, process.arch)))
  assert.equal(read_rusty_v8_release(v8_root), "v146.8.0")
})

test("resolve_prefetch_spec accepts an explicit release without locating mizchi/v8", () => {
  const spec = resolve_prefetch_spec("/tmp/missing-module-root", undefined, "v146.8.0")
  assert.equal(spec.v8_root, null)
  assert.equal(spec.release, "v146.8.0")
  assert.equal(spec.url, source_binding_url("v146.8.0", binding_suffix_for(process.platform, process.arch)))
})
