import fs from "node:fs"
import path from "node:path"
import process from "node:process"
import { fileURLToPath } from "node:url"

export function resolveBuildArtifactPath(cwd, candidates) {
  const checked = []
  for (const candidate of candidates) {
    const resolved = path.resolve(cwd, candidate)
    checked.push(resolved)
    if (fs.existsSync(resolved)) {
      return resolved
    }
  }
  throw new Error(`build artifact not found; searched ${checked.join(", ")}`)
}

export function copyDist(cwd = process.cwd()) {
  const distDir = path.join(cwd, "dist")
  fs.mkdirSync(distDir, { recursive: true })

  fs.copyFileSync(
    resolveBuildArtifactPath(cwd, [
      "_build/js/release/build/crater-js.js",
      "../_build/js/release/build/mizchi/crater-js/crater-js.js",
    ]),
    path.join(distDir, "crater.js"),
  )
  fs.copyFileSync(
    resolveBuildArtifactPath(cwd, [
      "_build/wasm-gc/release/build/crater-js.wasm",
      "../_build/wasm-gc/release/build/mizchi/crater-js/crater-js.wasm",
    ]),
    path.join(distDir, "crater.wasm"),
  )

  for (const filename of ["index.js", "index.d.ts", "wasm.js", "wasm.d.ts"]) {
    fs.copyFileSync(path.join(cwd, filename), path.join(distDir, filename))
  }
}

if (
  process.argv[1]
  && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  copyDist()
}
