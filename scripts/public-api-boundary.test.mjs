import test from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")

function read(rel) {
  return readFileSync(path.join(rootDir, rel), "utf8")
}

test("published docs point to the external mizchi/css module, not the retired crater-css module", () => {
  const docs = [
    "README.mbt.md",
    "docs/api.md",
    "docs/browser-api.md",
    "docs/compatibility-bridges.md",
    "docs/monorepo-workspace.md",
    "docs/module-graph.md",
    "docs/tui-api.md",
  ]

  for (const rel of docs) {
    assert.doesNotMatch(
      read(rel),
      /mizchi\/crater-css|crater-css/,
      `${rel} should not mention the retired crater-css module`,
    )
  }
})

test("local tasks and CI do not use deprecated Moon manifest selectors", () => {
  const files = [
    "package.json",
    "justfile",
    "scripts/moon-publish-workspace.mjs",
    "scripts/vrt-bench.ts",
    "benchmarks/scripts/component-vrt-bench-baseline.mjs",
    "benchmarks/scripts/crater-cli-bench-baseline.mjs",
    ".github/workflows/ci.yml",
    ".github/workflows/browser.yml",
    ".github/workflows/copilot-setup-steps.yml",
    ".github/workflows/flaker-daily.yml",
  ]

  for (const rel of files) {
    assert.doesNotMatch(read(rel), /--manifest-path/, rel)
  }
})

test("public API docs use current split module paths", () => {
  const files = [
    "docs/api.md",
    "docs/tui-api.md",
    "docs/browser-api.md",
  ]

  for (const rel of files) {
    assert.doesNotMatch(
      read(rel),
      /mizchi\/crater\/(?:paint|types|style|layout)(?:\b|\/)/,
      rel,
    )
  }
})

test("module graph treats aomx as a public canonical module", () => {
  const graphScript = read("scripts/render-module-graph.mjs")
  const graphDoc = read("docs/module-graph.md")

  assert.match(graphScript, /"mizchi\/crater-aomx"/)
  assert.doesNotMatch(
    graphScript,
    /\["Test \/ Dev", new Set\(\[[\s\S]*"mizchi\/crater-aomx"/,
  )
  assert.match(graphDoc, /\| Foundation \| `crater-aomx` \| `aomx` \|/)
})

test("webdriver root facade does not expose CDP handler internals", () => {
  const mbti = read("webdriver/pkg.generated.mbti")

  assert.doesNotMatch(mbti, /@cdp\.CdpSession/)
  assert.doesNotMatch(mbti, /pub fn handle_/)
  assert.doesNotMatch(mbti, /CdpHandlerError/)
  assert.doesNotMatch(mbti, /CdpSessionManager/)
})

test("webvitals layout shift result exposes its numeric fields", () => {
  const mbti = read("webvitals/pkg.generated.mbti")

  assert.match(mbti, /pub\(all\) struct LayoutShift/)
  assert.match(mbti, /impact_fraction : Double/)
  assert.match(mbti, /distance_fraction : Double/)
  assert.match(mbti, /score : Double/)
})
