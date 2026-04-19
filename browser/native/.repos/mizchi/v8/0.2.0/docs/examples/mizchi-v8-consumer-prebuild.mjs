import fs from "node:fs"
import path from "node:path"
import process from "node:process"
import { spawnSync } from "node:child_process"

function read_stdin() {
  return new Promise((resolve, reject) => {
    let text = ""
    process.stdin.setEncoding("utf8")
    process.stdin.on("data", (chunk) => {
      text += chunk
    })
    process.stdin.on("end", () => resolve(text))
    process.stdin.on("error", reject)
  })
}

function read_json(file_path) {
  return JSON.parse(fs.readFileSync(file_path, "utf8"))
}

function resolve_v8_module_root(module_root) {
  const moon_mod_path = path.join(module_root, "moon.mod.json")
  if (fs.existsSync(moon_mod_path)) {
    const moon_mod = read_json(moon_mod_path)
    const dep_path = moon_mod.deps?.["mizchi/v8"]?.path
    if (typeof dep_path === "string" && dep_path !== "") {
      return path.resolve(module_root, dep_path)
    }
  }

  const mooncakes_root = path.join(module_root, ".mooncakes", "mizchi", "v8")
  if (fs.existsSync(path.join(mooncakes_root, "moon.mod.json"))) {
    return mooncakes_root
  }

  throw new Error(
    "failed to locate mizchi/v8; expected a local path dependency or .mooncakes/mizchi/v8",
  )
}

function platform_link_flags(platform, module_root) {
  const archive_path = path.join(
    module_root,
    "target",
    "rusty_v8_bridge",
    "release",
    "librusty_v8_bridge.a",
  )
  switch (platform) {
    case "darwin":
      return `${archive_path} -lc++ -pthread -framework CoreFoundation`
    case "linux":
      return `${archive_path} -lstdc++ -ldl -pthread`
    default:
      throw new Error(
        `mizchi/v8 consumer setup does not support host platform ${platform}`,
      )
  }
}

const raw_input = await read_stdin()
const input = raw_input.trim() === "" ? {} : JSON.parse(raw_input)
const module_root = input.paths?.module_root ?? process.cwd()
const v8_root = resolve_v8_module_root(module_root)
const build_script = path.join(v8_root, "src", "scripts", "build-rusty-v8.sh")
const stamp_path = path.join(v8_root, "src", "build-stamps", "rusty_v8_build.stamp")

const result = spawnSync("bash", [build_script, stamp_path], {
  cwd: v8_root,
  env: process.env,
  stdio: "inherit",
})

if (result.status !== 0) {
  process.exit(result.status ?? 1)
}

process.stdout.write(
  JSON.stringify({
    vars: {
      MIZCHI_V8_CC_LINK_FLAGS: platform_link_flags(process.platform, v8_root),
    },
  }),
)
