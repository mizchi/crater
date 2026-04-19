import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

export const BIDI_MAIN_BUILD_CANDIDATES = [
  "browser/jsbidi/_build/js/release/build/bidi_main/bidi_main.js",
  "_build/js/release/build/mizchi/crater-browser-js/bidi_main/bidi_main.js",
  "browser/target/js/release/build/bidi_main/bidi_main.js",
  "browser/_build/js/release/build/bidi_main/bidi_main.js",
];

export function resolveBidiMainBuildPath(
  cwd,
  existsSync = fs.existsSync,
) {
  for (const candidate of BIDI_MAIN_BUILD_CANDIDATES) {
    const resolved = path.join(cwd, candidate);
    if (existsSync(resolved)) {
      return resolved;
    }
  }
  return null;
}

export function resolveBidiMainBuildUrl(
  cwd,
  existsSync = fs.existsSync,
) {
  const resolved = resolveBidiMainBuildPath(cwd, existsSync);
  if (!resolved) {
    throw new Error(
      `BiDi server not built. Expected one of: ${BIDI_MAIN_BUILD_CANDIDATES.join(", ")}`,
    );
  }
  return pathToFileURL(resolved).href;
}
