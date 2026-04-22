import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

export const FONT_RUNTIME_BUILD_CANDIDATES = [
  "browser/jsbidi/_build/js/release/build/font_runtime/font_runtime.js",
  "_build/js/release/build/mizchi/crater-jsbidi/font_runtime/font_runtime.js",
  "browser/jsbidi/target/js/release/build/font_runtime/font_runtime.js",
];

export function resolveFontRuntimeBuildPath(
  cwd,
  existsSync = fs.existsSync,
) {
  const envOverride = process.env.CRATER_FONT_RUNTIME_PATH;
  if (envOverride) {
    const resolved = path.isAbsolute(envOverride)
      ? envOverride
      : path.join(cwd, envOverride);
    if (existsSync(resolved)) {
      return resolved;
    }
  }

  for (const candidate of FONT_RUNTIME_BUILD_CANDIDATES) {
    const resolved = path.join(cwd, candidate);
    if (existsSync(resolved)) {
      return resolved;
    }
  }
  return null;
}

export function resolveFontRuntimeBuildUrl(
  cwd,
  existsSync = fs.existsSync,
) {
  const resolved = resolveFontRuntimeBuildPath(cwd, existsSync);
  if (!resolved) {
    throw new Error(
      `Font runtime not built. Expected one of: ${FONT_RUNTIME_BUILD_CANDIDATES.join(", ")}`,
    );
  }
  return pathToFileURL(resolved).href;
}
