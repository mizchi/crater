import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core contract boundaries", () => {
  it("keeps renderer public API wrappers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/render_api.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "pub fn render(",
      "pub fn render_with_external_css",
      "pub fn render_document_with_external_css",
      "pub fn render_document_with_prepared_external_css",
      "pub fn render_to_node(",
      "pub fn render_to_node_with_external_css",
      "pub fn render_to_node_and_layout(",
      "pub fn render_to_node_and_layout_full_document",
      "pub fn render_to_node_and_layout_with_external_css",
      "pub fn render_to_node_with_document",
      "pub fn render_to_node_with_prepared_external_css",
      "pub fn render_to_node_and_layout_with_document",
      "pub fn render_to_node_and_layout_with_prepared_external_css",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("guards split core files from size regression", () => {
    const guardedFiles = [
      { file: "webdriver/webdriver/bidi_protocol.mbt", maxLines: 8000 },
      { file: "webdriver/webdriver/bidi_server.mbt", maxLines: 400 },
      { file: "renderer/renderer/renderer.mbt", maxLines: 30 },
      { file: "painter/svg/types.mbt", maxLines: 30 },
      { file: "renderer/renderer/render_test.mbt", maxLines: 20 },
      { file: "renderer/renderer/renderer_test.mbt", maxLines: 20 },
      { file: "renderer/renderer/table_render_test.mbt", maxLines: 20 },
    ] as const;

    const offenders = guardedFiles
      .map(({ file, maxLines }) => ({ file, maxLines, lines: countLines(file) }))
      .filter(({ lines, maxLines }) => lines > maxLines);

    expect(offenders).toEqual([]);
  });
});
