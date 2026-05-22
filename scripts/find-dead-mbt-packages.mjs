#!/usr/bin/env node

import {
  existsSync,
  readFileSync,
  readdirSync,
} from "node:fs";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const PACKAGE_FILENAMES = new Set(["moon.pkg", "moon.pkg.json"]);
const SEARCH_FILENAMES = new Set([
  "moon.pkg",
  "moon.pkg.json",
  "moon.mod.json",
  "moon.work",
]);
const SEARCH_EXTENSIONS = new Set([".mbt", ".mbti"]);
const SKIP_DIR_NAMES = new Set([
  ".git",
  ".mooncakes",
  ".repos",
  "_build",
  "dist",
  "node_modules",
  "output",
  "playwright-report",
  "test-results",
]);
const SKIP_PACKAGE_ROOTS = ["benchmarks", "testing"];

export const DEFAULT_ALLOWLIST = {
  exact: [
    // JS build artifacts consumed by scripts/tools rather than MoonBit imports.
    "mizchi/crater-browser/cdp_js",
    "mizchi/crater-conformance/taffy",
    "mizchi/crater-conformance/wpt",
    "mizchi/crater-webdriver-bidi/font_runtime",
    // Documented compatibility facades kept for external consumers.
    "mizchi/crater-browser/js",
    "mizchi/crater-browser/runtime",
    "mizchi/crater-browser/tui/paint",
    "mizchi/crater-dom/layout/dom_bridge",
    "mizchi/crater-dom/layout/html_bridge",
    "mizchi/crater-painter/paint/layout_bridge",
    // WIT/WASM build-tooling packages are entry points for generated bindings.
    "mizchi/crater-wasm",
    "mizchi/crater-wasm/ffi",
    "mizchi/crater-wasm/gen",
    "mizchi/crater-wasm/gen/world/crater",
    "mizchi/crater-wasm/world/crater",
  ],
  prefixes: [
    "mizchi/crater-wasm/gen/interface/",
    "mizchi/crater-wasm/interface/",
  ],
};

function toPosix(path) {
  return path.split(sep).join("/");
}

function hasSkippedSegment(path) {
  return toPosix(path)
    .split("/")
    .some((segment) => SKIP_DIR_NAMES.has(segment));
}

function isPackageRootSkipped(root, pkgDir) {
  const rel = toPosix(relative(root, pkgDir));
  return SKIP_PACKAGE_ROOTS.some(
    (prefix) => rel === prefix || rel.startsWith(`${prefix}/`),
  );
}

function extensionOf(filename) {
  const dot = filename.lastIndexOf(".");
  return dot >= 0 ? filename.slice(dot) : "";
}

function walkFiles(root, predicate) {
  const files = [];
  function visit(dir) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        if (!SKIP_DIR_NAMES.has(entry.name)) {
          visit(join(dir, entry.name));
        }
        continue;
      }
      if (!entry.isFile()) {
        continue;
      }
      const file = join(dir, entry.name);
      if (predicate(file, entry.name)) {
        files.push(file);
      }
    }
  }
  visit(root);
  return files.sort();
}

function nearestMoonModuleRoot(root, startDir) {
  let cursor = startDir;
  while (cursor.startsWith(root)) {
    const moduleFile = join(cursor, "moon.mod.json");
    if (existsSync(moduleFile)) {
      return cursor;
    }
    const parent = dirname(cursor);
    if (parent === cursor) {
      break;
    }
    cursor = parent;
  }
  return null;
}

function readModuleName(moduleRoot) {
  const moduleJson = JSON.parse(
    readFileSync(join(moduleRoot, "moon.mod.json"), "utf8"),
  );
  if (typeof moduleJson.name !== "string" || moduleJson.name.length === 0) {
    throw new Error(`moon.mod.json missing name: ${moduleRoot}`);
  }
  return moduleJson.name;
}

function packageImportPath(moduleName, moduleRoot, pkgDir) {
  const rel = toPosix(relative(moduleRoot, pkgDir));
  return rel === "" ? moduleName : `${moduleName}/${rel}`;
}

function isMainPackage(pkgFile) {
  const source = readFileSync(pkgFile, "utf8");
  return /["']?is-main["']?\s*[:=]\s*true\b/.test(source);
}

function isInsideDir(file, dir) {
  const rel = relative(dir, file);
  return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel));
}

function mergeAllowlists(base, extra) {
  return {
    exact: [...base.exact, ...extra.exact],
    prefixes: [...base.prefixes, ...extra.prefixes],
  };
}

function isAllowed(importPath, allowlist) {
  return (
    allowlist.exact.includes(importPath) ||
    allowlist.prefixes.some((prefix) => importPath.startsWith(prefix))
  );
}

export function discoverMoonPackages(rootDir = process.cwd()) {
  const root = resolve(rootDir);
  const packageFiles = walkFiles(root, (_file, name) => PACKAGE_FILENAMES.has(name));
  const packages = [];
  const moduleNameByRoot = new Map();
  for (const pkgFile of packageFiles) {
    if (hasSkippedSegment(relative(root, pkgFile))) {
      continue;
    }
    const pkgDir = dirname(pkgFile);
    if (isPackageRootSkipped(root, pkgDir)) {
      continue;
    }
    const moduleRoot = nearestMoonModuleRoot(root, pkgDir);
    if (moduleRoot === null) {
      continue;
    }
    let moduleName = moduleNameByRoot.get(moduleRoot);
    if (moduleName === undefined) {
      moduleName = readModuleName(moduleRoot);
      moduleNameByRoot.set(moduleRoot, moduleName);
    }
    packages.push({
      importPath: packageImportPath(moduleName, moduleRoot, pkgDir),
      packageFile: toPosix(relative(root, pkgFile)),
      packageDir: toPosix(relative(root, pkgDir)),
      moduleRoot: toPosix(relative(root, moduleRoot)),
      isMain: isMainPackage(pkgFile),
    });
  }
  return packages.sort((a, b) => a.importPath.localeCompare(b.importPath));
}

export function findDeadMoonPackages(rootDir = process.cwd(), options = {}) {
  const root = resolve(rootDir);
  const allowlist = options.allowlist ?? DEFAULT_ALLOWLIST;
  const packages = discoverMoonPackages(root);
  const searchFiles = walkFiles(root, (_file, name) => {
    return SEARCH_FILENAMES.has(name) || SEARCH_EXTENSIONS.has(extensionOf(name));
  });
  const fileSources = searchFiles.map((file) => ({
    file,
    source: readFileSync(file, "utf8"),
  }));
  const dead = [];
  for (const pkg of packages) {
    if (pkg.isMain || isAllowed(pkg.importPath, allowlist)) {
      continue;
    }
    const quoted = `"${pkg.importPath}"`;
    const refs = fileSources.filter(({ file, source }) => {
      if (isInsideDir(file, join(root, pkg.packageDir))) {
        return false;
      }
      return source.includes(quoted);
    });
    if (refs.length === 0) {
      dead.push(pkg);
    }
  }
  return dead;
}

function parseArgs(argv) {
  const options = {
    root: process.cwd(),
    json: false,
    useDefaultAllowlist: true,
    allowlist: { exact: [], prefixes: [] },
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--root") {
      options.root = argv[i + 1];
      i += 1;
    } else if (arg === "--json") {
      options.json = true;
    } else if (arg === "--no-default-allowlist") {
      options.useDefaultAllowlist = false;
    } else if (arg === "--allow") {
      options.allowlist.exact.push(argv[i + 1]);
      i += 1;
    } else if (arg === "--allow-prefix") {
      options.allowlist.prefixes.push(argv[i + 1]);
      i += 1;
    } else if (arg === "--help" || arg === "-h") {
      options.help = true;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return options;
}

function printHelp() {
  console.log(`Usage: node scripts/find-dead-mbt-packages.mjs [options]

Options:
  --root <dir>              Repository root. Defaults to cwd.
  --json                    Print JSON.
  --no-default-allowlist    Disable Crater's known build-tooling allowlist.
  --allow <import>          Allow an exact package import path.
  --allow-prefix <prefix>   Allow package import paths with this prefix.
`);
}

function main(argv) {
  const options = parseArgs(argv);
  if (options.help) {
    printHelp();
    return 0;
  }
  const allowlist = options.useDefaultAllowlist
    ? mergeAllowlists(DEFAULT_ALLOWLIST, options.allowlist)
    : options.allowlist;
  const dead = findDeadMoonPackages(options.root, { allowlist });
  if (options.json) {
    console.log(JSON.stringify(dead, null, 2));
  } else if (dead.length === 0) {
    console.log("No unallowlisted dead MoonBit packages found.");
  } else {
    console.error("Unallowlisted dead MoonBit packages:");
    for (const pkg of dead) {
      console.error(`- ${pkg.importPath} (${pkg.packageFile})`);
    }
  }
  return dead.length === 0 ? 0 : 1;
}

const entry = process.argv[1] ? resolve(process.argv[1]) : "";
if (entry === fileURLToPath(import.meta.url)) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 2;
  }
}
