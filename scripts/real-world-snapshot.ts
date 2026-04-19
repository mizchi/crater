import fs from "node:fs";
import path from "node:path";

export interface RealWorldViewport {
  width: number;
  height: number;
}

export interface RealWorldSnapshot {
  name: string;
  title: string;
  html: string;
  viewport: RealWorldViewport;
  sourceType: "builtin" | "local";
  sourceUrl?: string;
  htmlPath?: string;
}

export interface RealWorldSnapshotOptions {
  realWorldDir?: string;
  repoRoot?: string;
}

interface LocalSnapshotMeta {
  title?: string;
  sourceUrl?: string;
  viewport?: Partial<RealWorldViewport>;
}

const DEFAULT_VIEWPORT: RealWorldViewport = { width: 1440, height: 960 };
const BUILTIN_GITHUB_NAME = "github-mizchi";

function repoRoot(options: RealWorldSnapshotOptions = {}): string {
  return options.repoRoot ?? process.cwd();
}

function realWorldDir(options: RealWorldSnapshotOptions = {}): string {
  return options.realWorldDir ?? path.join(repoRoot(options), "real-world");
}

function fixtureDir(options: RealWorldSnapshotOptions = {}): string {
  const root = repoRoot(options);
  const candidates = [
    path.join(root, "benchmarks", "fixtures"),
    path.join(root, "src", "benchmarks", "fixtures"),
  ];
  const resolved = candidates.find((candidate) => fs.existsSync(candidate));
  if (!resolved) {
    throw new Error(`benchmark fixture directory not found: ${candidates.join(", ")}`);
  }
  return resolved;
}

function removeScriptTags(html: string): string {
  return html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "")
    .replace(/<script\b[^>]*\/\s*>/gi, "");
}

function removeStylesheetLinks(html: string): string {
  return html.replace(/<link\b[^>]*rel=(['"])[^'"]*stylesheet[^'"]*\1[^>]*>/gi, "");
}

function removeNetworkHintLinks(html: string): string {
  return html.replace(
    /<link\b[^>]*rel=(['"])[^'"]*(dns-prefetch|preconnect|prefetch|preload)[^'"]*\1[^>]*>/gi,
    "",
  );
}

function ensureHead(html: string): string {
  if (/<head\b/i.test(html)) return html;
  if (/<html\b[^>]*>/i.test(html)) {
    return html.replace(/<html\b[^>]*>/i, (match) => `${match}<head></head>`);
  }
  return `<head></head>${html}`;
}

function injectIntoHead(html: string, chunks: string[]): string {
  const normalized = ensureHead(html);
  const insertion = chunks.filter(Boolean).join("\n");
  if (/<\/head>/i.test(normalized)) {
    return normalized.replace(/<\/head>/i, `${insertion}\n</head>`);
  }
  return `${insertion}\n${normalized}`;
}

function styleTag(css: string, index: number): string {
  return `<style data-real-world-style="${index + 1}">\n${css}\n</style>`;
}

function baseTag(baseHref?: string): string {
  return baseHref ? `<base href="${baseHref}">` : "";
}

function extractTitle(html: string): string {
  const match = html.match(/<title\b[^>]*>([\s\S]*?)<\/title>/i);
  return match?.[1]?.trim() || "Untitled";
}

export function inlineHtmlSnapshot(input: {
  html: string;
  styles: string[];
  baseHref?: string;
}): string {
  const stripped = removeNetworkHintLinks(removeStylesheetLinks(removeScriptTags(input.html)));
  const headChunks = [baseTag(input.baseHref), ...input.styles.map(styleTag)];
  return injectIntoHead(stripped, headChunks);
}

export function buildGithubMizchiSnapshot(
  options: RealWorldSnapshotOptions = {},
): RealWorldSnapshot {
  const dir = fixtureDir(options);
  const html = fs.readFileSync(path.join(dir, "github_mizchi.html"), "utf8");
  const cssFiles = [
    "github_primer.css",
    "github_global.css",
    "github_main.css",
    "github_profile.css",
  ];
  const styles = cssFiles.map((file) => fs.readFileSync(path.join(dir, file), "utf8"));
  return {
    name: BUILTIN_GITHUB_NAME,
    title: "GitHub profile snapshot",
    html: inlineHtmlSnapshot({
      html,
      styles,
      baseHref: "https://github.com/mizchi",
    }),
    viewport: DEFAULT_VIEWPORT,
    sourceType: "builtin",
    sourceUrl: "https://github.com/mizchi",
  };
}

function localSnapshotHtmlPath(baseDir: string, name: string): string {
  const dir = path.join(baseDir, name);
  const preferred = path.join(dir, "index.html");
  if (fs.existsSync(preferred)) return preferred;
  return path.join(dir, "snapshot.html");
}

function loadLocalSnapshotMeta(baseDir: string, name: string): LocalSnapshotMeta {
  const metaPath = path.join(baseDir, name, "meta.json");
  if (!fs.existsSync(metaPath)) return {};
  return JSON.parse(fs.readFileSync(metaPath, "utf8")) as LocalSnapshotMeta;
}

function loadLocalSnapshot(
  name: string,
  options: RealWorldSnapshotOptions = {},
): RealWorldSnapshot {
  const baseDir = realWorldDir(options);
  const htmlPath = localSnapshotHtmlPath(baseDir, name);
  if (!fs.existsSync(htmlPath)) {
    throw new Error(`Unknown real-world snapshot: ${name}`);
  }
  const meta = loadLocalSnapshotMeta(baseDir, name);
  const html = fs.readFileSync(htmlPath, "utf8");
  return {
    name,
    title: meta.title ?? extractTitle(html),
    html,
    viewport: {
      width: meta.viewport?.width ?? DEFAULT_VIEWPORT.width,
      height: meta.viewport?.height ?? DEFAULT_VIEWPORT.height,
    },
    sourceType: "local",
    sourceUrl: meta.sourceUrl,
    htmlPath,
  };
}

function listLocalSnapshots(options: RealWorldSnapshotOptions = {}): string[] {
  const baseDir = realWorldDir(options);
  if (!fs.existsSync(baseDir)) return [];
  return fs
    .readdirSync(baseDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .filter((name) => fs.existsSync(localSnapshotHtmlPath(baseDir, name)))
    .sort();
}

export function listRealWorldSnapshotNames(
  options: RealWorldSnapshotOptions = {},
): string[] {
  return [BUILTIN_GITHUB_NAME, ...listLocalSnapshots(options)];
}

export function loadRealWorldSnapshot(
  name: string,
  options: RealWorldSnapshotOptions = {},
): RealWorldSnapshot {
  if (name === BUILTIN_GITHUB_NAME) return buildGithubMizchiSnapshot(options);
  return loadLocalSnapshot(name, options);
}
