import path from "node:path";

export function normalizeRepoPath(root: string, target: string): string {
  const normalizedTarget = target.replaceAll("\\", "/");
  return path.relative(root, path.resolve(root, normalizedTarget)).split(path.sep).join("/");
}
