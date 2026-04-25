import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import process from "node:process"
import { spawnSync } from "node:child_process"

import { resolve_v8_module_root } from "../browser/scripts/mizchi-v8-consumer-prebuild.mjs"

export function binding_suffix_for(platform, arch) {
  switch (`${platform}:${arch}`) {
    case "darwin:arm64":
      return "aarch64-apple-darwin"
    case "darwin:x64":
      return "x86_64-apple-darwin"
    case "linux:x64":
      return "x86_64-unknown-linux-gnu"
    case "linux:arm64":
      return "aarch64-unknown-linux-gnu"
    default:
      throw new Error(`unsupported host platform for rusty_v8 source binding: ${platform}:${arch}`)
  }
}

export function replace_non_alphanumeric(text) {
  return [...text].map((char) => (/[A-Za-z0-9]/.test(char) ? char : "_")).join("")
}

export function source_binding_url(release, binding_suffix) {
  const base_url =
    process.env.RUSTY_V8_MIRROR || "https://github.com/denoland/rusty_v8/releases/download"
  return `${base_url}/${release}/src_binding_release_${binding_suffix}.rs`
}

export function source_binding_cache_path(url, cargo_home = process.env.CARGO_HOME || path.join(os.homedir(), ".cargo")) {
  return path.join(cargo_home, ".rusty_v8", replace_non_alphanumeric(url))
}

export function read_rusty_v8_release(v8_root) {
  const release_path = path.join(v8_root, "deps", "rusty_v8.rev")
  return fs.readFileSync(release_path, "utf8").trim()
}

export function resolve_prefetch_spec(module_root, workspace_root, release_override) {
  const v8_root = release_override
    ? null
    : resolve_v8_module_root(module_root, [process.cwd(), workspace_root])
  const release = release_override || read_rusty_v8_release(v8_root)
  const binding_suffix = binding_suffix_for(process.platform, process.arch)
  const url = source_binding_url(release, binding_suffix)
  const cache_path = source_binding_cache_path(url)
  return {
    v8_root,
    release,
    binding_suffix,
    url,
    cache_path,
  }
}

export function prefetch_source_binding(module_root, workspace_root, release_override) {
  const spec = resolve_prefetch_spec(module_root, workspace_root, release_override)
  if (fs.existsSync(spec.cache_path) && fs.statSync(spec.cache_path).size > 0) {
    return {
      ...spec,
      cache_hit: true,
    }
  }

  fs.mkdirSync(path.dirname(spec.cache_path), { recursive: true })
  const tmp_path = `${spec.cache_path}.tmp`
  fs.rmSync(tmp_path, { force: true })

  const result = spawnSync(
    "curl",
    [
      "-L",
      "--fail",
      "--retry",
      "5",
      "--retry-delay",
      "2",
      "--retry-all-errors",
      "--silent",
      "--show-error",
      "-o",
      tmp_path,
      spec.url,
    ],
    {
      stdio: "inherit",
    },
  )

  if (result.status !== 0) {
    fs.rmSync(tmp_path, { force: true })
    throw new Error(`failed to prefetch rusty_v8 source binding from ${spec.url}`)
  }

  fs.renameSync(tmp_path, spec.cache_path)
  return {
    ...spec,
    cache_hit: false,
  }
}

function parse_args(argv) {
  let module_root = "webdriver"
  let workspace_root
  let release
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    if (arg === "--module-root") {
      module_root = argv[index + 1]
      index += 1
      continue
    }
    if (arg === "--workspace-root") {
      workspace_root = argv[index + 1]
      index += 1
      continue
    }
    if (arg === "--release") {
      release = argv[index + 1]
      index += 1
      continue
    }
    module_root = arg
  }
  return { module_root, workspace_root, release }
}

function main() {
  const { module_root, workspace_root, release } = parse_args(process.argv.slice(2))
  const result = prefetch_source_binding(module_root, workspace_root, release)
  process.stdout.write(`${JSON.stringify(result)}\n`)
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main()
}
