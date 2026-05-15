#!/usr/bin/env node
// Render the repo's MoonBit module dependency graph (mermaid + DOT).
// Writes docs/module-graph.md (mermaid + textual summary) and docs/module-graph.dot.

import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SKIP_DIRS = new Set(["_build", ".repos", ".mooncakes", "node_modules"]);

function walk(dir, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;
      walk(path.join(dir, entry.name), out);
    } else if (entry.name === "moon.mod.json") {
      out.push(path.join(dir, entry.name));
    }
  }
  return out;
}

// Layer assignment by module name. Keep this small and obvious.
const LAYERS = [
  ["Core", new Set([
    "mizchi/crater-core",
  ])],
  ["Foundation", new Set([
    "mizchi/crater-css",
    "mizchi/crater-dom",
    "mizchi/crater-layout",
    "mizchi/crater-network",
    "mizchi/crater-html-assets",
  ])],
  ["Render", new Set([
    "mizchi/crater-painter",
    "mizchi/crater-renderer",
    "mizchi/crater-renderer-terminal",
    "mizchi/crater-renderer-inline-style-cache",
    "mizchi/crater-webvitals",
  ])],
  ["Terminal", new Set([
    "mizchi/crater-terminal-protocol",
    "mizchi/crater-terminal-image-cache",
    "mizchi/crater-painter-terminal",
  ])],
  ["Browser", new Set([
    "mizchi/crater-browser",
    "mizchi/crater-browser-runtime",
    "mizchi/crater-browser-helpers",
    "mizchi/crater-browser-http",
    "mizchi/crater-browser-http-sqlite",
    "mizchi/crater-browser-native",
  ])],
  ["Driver", new Set([
    "mizchi/crater-webdriver-bidi",
  ])],
  ["Distribution", new Set([
    "mizchi/crater",
    "mizchi/crater-js",
    "mizchi/crater-wasm",
  ])],
  ["Test / Dev", new Set([
    "mizchi/crater-testing",
    "mizchi/crater-benchmarks",
    "mizchi/crater-tools",
    "mizchi/crater-aomx",
  ])],
];

function layerOf(name) {
  for (const [label, set] of LAYERS) {
    if (set.has(name)) return label;
  }
  return "Other";
}

function shortName(name) {
  if (name === "mizchi/crater") return "crater (umbrella)";
  return name.replace(/^mizchi\//, "");
}

function nodeId(name) {
  return name.replaceAll("/", "_").replaceAll("-", "_");
}

function loadModules() {
  const found = walk(REPO_ROOT);
  const modules = new Map();
  for (const file of found) {
    const data = JSON.parse(readFileSync(file, "utf8"));
    const name = data.name;
    const deps = Object.keys(data.deps ?? {});
    modules.set(name, {
      name,
      dir: path.relative(REPO_ROOT, path.dirname(file)) || ".",
      internalDeps: deps.filter((d) => d.startsWith("mizchi/crater")),
      externalDeps: deps.filter((d) => !d.startsWith("mizchi/crater")),
      description: data.description ?? "",
      version: data.version ?? "",
    });
  }
  return modules;
}

function inDegree(modules) {
  const indeg = new Map();
  for (const name of modules.keys()) indeg.set(name, 0);
  for (const { internalDeps } of modules.values()) {
    for (const dep of internalDeps) {
      if (indeg.has(dep)) indeg.set(dep, indeg.get(dep) + 1);
    }
  }
  return indeg;
}

function renderMermaid(modules) {
  const lines = ["```mermaid", "graph LR"];
  for (const [label] of LAYERS) {
    lines.push(`  subgraph ${nodeId(label)}["${label}"]`);
    for (const m of modules.values()) {
      if (layerOf(m.name) !== label) continue;
      lines.push(`    ${nodeId(m.name)}["${shortName(m.name)}"]`);
    }
    lines.push("  end");
  }
  // "Other" bucket if anything missed.
  const others = [...modules.values()].filter((m) => layerOf(m.name) === "Other");
  if (others.length > 0) {
    lines.push(`  subgraph Other`);
    for (const m of others) lines.push(`    ${nodeId(m.name)}["${shortName(m.name)}"]`);
    lines.push("  end");
  }
  lines.push("");
  for (const m of modules.values()) {
    for (const dep of m.internalDeps) {
      if (!modules.has(dep)) continue;
      lines.push(`  ${nodeId(m.name)} --> ${nodeId(dep)}`);
    }
  }
  lines.push("```");
  return lines.join("\n");
}

function renderDot(modules) {
  const lines = [
    "digraph crater_modules {",
    "  rankdir=LR;",
    '  node [shape=box, style=rounded, fontname="Helvetica"];',
  ];
  for (const [label, set] of LAYERS) {
    lines.push(`  subgraph cluster_${nodeId(label)} {`);
    lines.push(`    label="${label}";`);
    for (const m of modules.values()) {
      if (layerOf(m.name) !== label) continue;
      lines.push(`    ${nodeId(m.name)} [label="${shortName(m.name)}"];`);
    }
    lines.push("  }");
  }
  for (const m of modules.values()) {
    for (const dep of m.internalDeps) {
      if (!modules.has(dep)) continue;
      lines.push(`  ${nodeId(m.name)} -> ${nodeId(dep)};`);
    }
  }
  lines.push("}");
  return lines.join("\n");
}

function renderTable(modules, indeg) {
  const rows = [...modules.values()].sort((a, b) => {
    const layerOrder = LAYERS.map(([l]) => l).concat(["Other"]);
    const la = layerOrder.indexOf(layerOf(a.name));
    const lb = layerOrder.indexOf(layerOf(b.name));
    if (la !== lb) return la - lb;
    return a.name.localeCompare(b.name);
  });
  const lines = [
    "| Layer | Module | Dir | In-deg | Internal deps |",
    "| --- | --- | --- | --- | --- |",
  ];
  for (const m of rows) {
    const layer = layerOf(m.name);
    const dep = m.internalDeps.map(shortName).sort().join(", ") || "—";
    lines.push(`| ${layer} | \`${shortName(m.name)}\` | \`${m.dir}\` | ${indeg.get(m.name)} | ${dep} |`);
  }
  return lines.join("\n");
}

function main() {
  const modules = loadModules();
  const indeg = inDegree(modules);

  const md = [
    "# Module Dependency Graph",
    "",
    "Auto-generated by `scripts/render-module-graph.mjs`. Do not edit by hand.",
    "",
    `Snapshot of the MoonBit module graph across the workspace (${modules.size} modules).`,
    "",
    "## Visualization",
    "",
    renderMermaid(modules),
    "",
    "## Modules and incoming-edge counts",
    "",
    renderTable(modules, indeg),
    "",
    "## Notes",
    "",
    "- Internal edges follow `moon.mod.json` `deps` entries that start with `mizchi/crater`.",
    "- Layers are assigned by name in `scripts/render-module-graph.mjs` (`LAYERS`).",
    "- `crater (umbrella)` has no MoonBit packages of its own — it is a registry meta-module aggregating the foundation/render layer.",
  ].join("\n");

  writeFileSync(path.join(REPO_ROOT, "docs/module-graph.md"), md + "\n");
  writeFileSync(path.join(REPO_ROOT, "docs/module-graph.dot"), renderDot(modules) + "\n");
  console.log(`Wrote docs/module-graph.md and docs/module-graph.dot for ${modules.size} modules.`);
}

main();
