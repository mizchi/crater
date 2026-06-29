import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import process from "node:process"
import { spawnSync } from "node:child_process"
import { fileURLToPath } from "node:url"

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

function collect_search_roots(module_root, search_roots) {
  const roots = []
  const seen = new Set()
  for (const root of [module_root, ...search_roots]) {
    if (typeof root !== "string" || root === "") {
      continue
    }
    const absolute_root = path.resolve(root)
    if (seen.has(absolute_root)) {
      continue
    }
    seen.add(absolute_root)
    roots.push(absolute_root)
  }
  return roots
}

function ancestor_roots(root) {
  const roots = []
  let current = path.resolve(root)
  while (true) {
    roots.push(current)
    const parent = path.dirname(current)
    if (parent === current) {
      return roots
    }
    current = parent
  }
}

function candidate_mooncakes_roots(root) {
  const candidates = []
  for (const ancestor of ancestor_roots(root)) {
    candidates.push(path.join(ancestor, ".mooncakes", "mizchi", "v8"))
  }
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name.startsWith(".")) {
      continue
    }
    candidates.push(path.join(root, entry.name, ".mooncakes", "mizchi", "v8"))
  }
  return candidates
}

export function resolve_v8_module_root(module_root, search_roots = []) {
  const roots = collect_search_roots(module_root, search_roots)
  for (const root of roots) {
    const moon_mod_path = path.join(root, "moon.mod.json")
    if (!fs.existsSync(moon_mod_path)) {
      continue
    }
    const moon_mod = read_json(moon_mod_path)
    const dep_path = moon_mod.deps?.["mizchi/v8"]?.path
    if (typeof dep_path === "string" && dep_path !== "") {
      return path.resolve(root, dep_path)
    }
  }

  for (const root of roots) {
    for (const mooncakes_root of candidate_mooncakes_roots(root)) {
      if (fs.existsSync(path.join(mooncakes_root, "moon.mod.json"))) {
        return mooncakes_root
      }
    }
  }

  throw new Error(
    `failed to locate mizchi/v8; searched ${roots.join(", ")}`,
  )
}

function bridge_archive_path(module_root) {
  return path.join(
    module_root,
    "target",
    "rusty_v8_bridge",
    "release",
    "librusty_v8_bridge.a",
  )
}

// MoonBit's runtime statically links its OWN simdutf (`$HOME/.moon/lib/simdutf.o`)
// and V8 statically links a DIFFERENT simdutf inside librusty_v8_bridge.a. Linking
// both leaves duplicate global `simdutf::*` symbols. `-Wl,-z,muldefs` makes the
// link *succeed* by keeping the first definition — but then MoonBit code and V8
// code share ONE simdutf at runtime; the version/ABI mismatch corrupts simdutf's
// first-use CPU dispatch and SIGSEGVs the moment MoonBit converts a JS source
// string (UTF-16->UTF-8) for `Runtime::eval_string` (see
// docs/v8-snapshot-pre-injection.md / the V8 sandbox investigation).
//
// The real fix: rename V8's simdutf symbols (defs AND intra-archive refs, so V8
// stays self-consistent) with a private suffix, so they no longer collide with
// MoonBit's copy — each side binds to its own simdutf. Idempotent; a no-op if
// already renamed or if binutils (nm/objcopy) aren't available (then we fall back
// to the -z,muldefs behavior, preserving prior behavior on such hosts).
export function isolate_v8_simdutf_symbols(archive_path) {
  if (process.platform !== "linux" || !fs.existsSync(archive_path)) {
    return false
  }
  const nm = spawnSync("nm", [archive_path], {
    encoding: "utf8",
    maxBuffer: 1 << 30,
  })
  if (nm.status !== 0 || typeof nm.stdout !== "string") {
    return false // nm unavailable -> leave archive as-is (fall back to muldefs)
  }
  const SUFFIX = "__v8priv"
  const syms = new Set()
  for (const line of nm.stdout.split("\n")) {
    const name = line.trim().split(/\s+/).pop()
    if (name && name.includes("simdutf") && !name.endsWith(SUFFIX)) {
      syms.add(name)
    }
  }
  if (syms.size === 0) {
    return false // already isolated, or this archive has no simdutf symbols
  }
  const map = [...syms].map((s) => `${s} ${s}${SUFFIX}`).join("\n") + "\n"
  const mapfile = path.join(os.tmpdir(), `v8-simdutf-rename-${process.pid}.txt`)
  fs.writeFileSync(mapfile, map)
  const oc = spawnSync("objcopy", [`--redefine-syms=${mapfile}`, archive_path], {
    stdio: "inherit",
  })
  fs.rmSync(mapfile, { force: true })
  if (oc.status === 0) {
    process.stderr.write(
      `[mizchi/v8] isolated ${syms.size} V8 simdutf symbols ` +
        `(avoids the MoonBit-runtime simdutf collision / SIGSEGV)\n`,
    )
    return true
  }
  return false
}

export function platform_link_flags(platform, module_root) {
  const archive_path = bridge_archive_path(module_root)
  switch (platform) {
    case "darwin":
      return `${archive_path} -lc++ -pthread -framework CoreFoundation`
    case "linux":
      // `-z,muldefs` is kept as a belt-and-suspenders fallback for hosts where
      // the symbol-rename above couldn't run (no binutils); when the rename
      // succeeds there is no longer a duplicate to tolerate.
      return `${archive_path} -Wl,-z,muldefs -lstdc++ -ldl -pthread -lm`
    default:
      throw new Error(
        `mizchi/v8 consumer setup does not support host platform ${platform}`,
      )
  }
}

// When MIZCHI_V8_OPTIONAL=1 (or CRATER_SKIP_V8_BUILD=1), a failure to build the
// rusty_v8 bridge degrades to "no v8 link flags" instead of failing the whole
// build. This lets v8-independent packages (dom, layout, ...) resolve and run
// `moon test` in environments where rusty_v8 cannot be fetched/built (e.g. the
// web sandbox, where github egress to denoland/rusty_v8 is policy-blocked).
// Native targets that actually link v8 will then fail at link time, which is
// the expected outcome when v8 is unavailable.
function v8_optional() {
  return (
    process.env.MIZCHI_V8_OPTIONAL === "1" ||
    process.env.CRATER_SKIP_V8_BUILD === "1"
  )
}

function emit_no_v8(reason) {
  process.stderr.write(
    `[mizchi/v8] ${reason}; MIZCHI_V8_OPTIONAL set -> continuing without v8 ` +
      `link flags (native v8 runtime will be unavailable)\n`,
  )
  process.stdout.write(JSON.stringify({ vars: {} }))
}

async function main() {
  const raw_input = await read_stdin()
  const input = raw_input.trim() === "" ? {} : JSON.parse(raw_input)
  const module_root = input.paths?.module_root ?? process.cwd()
  const workspace_root = input.paths?.workspace_root
  let v8_root
  try {
    v8_root = resolve_v8_module_root(module_root, [
      process.cwd(),
      workspace_root,
    ])
  } catch (err) {
    if (v8_optional()) {
      emit_no_v8(`failed to locate mizchi/v8 (${err.message})`)
      return
    }
    throw err
  }
  const build_script = path.join(v8_root, "src", "scripts", "build-rusty-v8.sh")
  const stamp_path = path.join(
    v8_root,
    "src",
    "build-stamps",
    "rusty_v8_build.stamp",
  )

  const result = spawnSync("bash", [build_script, stamp_path], {
    cwd: v8_root,
    env: process.env,
    stdio: "inherit",
  })

  if (result.status !== 0) {
    if (v8_optional()) {
      emit_no_v8("rusty_v8 bridge build failed")
      return
    }
    process.exit(result.status ?? 1)
  }

  // Isolate V8's simdutf symbols from MoonBit's to avoid the link-time collision
  // that otherwise SIGSEGVs at first JS-string conversion. Best-effort.
  isolate_v8_simdutf_symbols(bridge_archive_path(v8_root))

  process.stdout.write(
    JSON.stringify({
      vars: {
        MIZCHI_V8_CC_LINK_FLAGS: platform_link_flags(process.platform, v8_root),
      },
    }),
  )
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  await main()
}
