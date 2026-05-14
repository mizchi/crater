import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, readSvgInteropSources } from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade text and symbol boundaries", () => {
  it("delegates SVG text whitespace helpers to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/text.mbt"), "utf8");
    const interopSource = readSvgInteropSources();

    expect(source.includes("pub(all) enum WhiteSpace")).toBe(true);
    expect(source.includes("pub(all) enum TextOverflow")).toBe(true);
    expect(source.includes("@msvg.process_white_space(")).toBe(true);
    expect(source.includes("@msvg.apply_text_overflow(")).toBe(true);
    expect(source.includes("white_space_to_msvg(mode)")).toBe(true);
    expect(source.includes("text_overflow_to_msvg(overflow)")).toBe(true);
    expect(interopSource.includes("fn white_space_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn text_overflow_to_msvg(")).toBe(true);
    expect(source.includes("fn take_chars(")).toBe(false);
    expect(typesSource.includes("pub(all) enum WhiteSpace")).toBe(false);
    expect(typesSource.includes("pub fn process_white_space(")).toBe(false);
  });

  it("delegates SVG text blocks to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/text.mbt"), "utf8");
    const interopSource = readSvgInteropSources();

    expect(source.includes("pub(all) struct TextStyle")).toBe(true);
    expect(source.includes("pub(all) struct TextSpan")).toBe(true);
    expect(source.includes("pub(all) struct TextBlock")).toBe(true);
    expect(source.includes("@msvg.TextDecorationFull::default()")).toBe(true);
    expect(source.includes("text_style_from_msvg(@msvg.TextStyle::default())")).toBe(true);
    expect(source.includes("text_span_from_msvg(@msvg.TextSpan::new(text))")).toBe(true);
    expect(source.includes("text_block_from_msvg(@msvg.TextBlock::new(")).toBe(true);
    expect(source.includes("text_block_to_msvg(self).get_width()")).toBe(true);
    expect(source.includes("text_block_to_msvg(self).wrap_text()")).toBe(true);
    expect(interopSource.includes("fn text_style_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn text_block_to_msvg(")).toBe(true);
    expect(source.includes("fn split_words(")).toBe(false);
    expect(typesSource.includes("pub(all) struct TextBlock")).toBe(false);
    expect(typesSource.includes("pub fn TextBlock::new(")).toBe(false);
  });

  it("delegates SVG use element helpers to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/use_symbol.mbt"), "utf8");
    const interopSource = readSvgInteropSources();
    const instantiateStart = source.indexOf("pub fn UseElement::instantiate(");
    const instantiateEnd = source.length;
    const instantiateSource = source.slice(instantiateStart, instantiateEnd);

    expect(source.includes("pub(all) struct UseElement")).toBe(true);
    expect(source.includes("@msvg.UseElement::new(")).toBe(true);
    expect(source.includes("@msvg.UseElement::with_size(")).toBe(true);
    expect(source.includes("use_element_from_msvg(")).toBe(true);
    expect(source.includes("use_element_to_msvg(self).get_id()")).toBe(true);
    expect(instantiateSource.includes("use_element_to_msvg(self).instantiate(symbol_registry_to_msvg(registry))")).toBe(true);
    expect(interopSource.includes("fn use_element_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn use_element_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn symbol_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn symbol_registry_to_msvg(")).toBe(true);
    expect(source.includes("fn hex_value(")).toBe(false);
    expect(source.includes("fn decode_percent(")).toBe(false);
    expect(instantiateSource.includes("registry.get(id)")).toBe(false);
    expect(instantiateSource.includes("symbol.content.clone()")).toBe(false);
    expect(typesSource.includes("pub(all) struct UseElement")).toBe(false);
    expect(typesSource.includes("pub fn UseElement::new(")).toBe(false);
  });

  it("delegates SVG symbol constructors to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/use_symbol.mbt"), "utf8");
    const interopSource = readSvgInteropSources();

    expect(source.includes("pub(all) struct Symbol")).toBe(true);
    expect(source.includes("pub(all) struct SymbolRegistry")).toBe(true);
    expect(source.includes("@msvg.Symbol::new(")).toBe(true);
    expect(source.includes("@msvg.Symbol::with_viewbox(")).toBe(true);
    expect(source.includes("symbol_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn symbol_from_msvg(")).toBe(true);
    expect(source.includes("view_box: None,\n    preserve_aspect_ratio: PreserveAspectRatio::default(),")).toBe(false);
    expect(typesSource.includes("pub(all) struct Symbol")).toBe(false);
    expect(typesSource.includes("pub fn Symbol::new(")).toBe(false);
  });
});
