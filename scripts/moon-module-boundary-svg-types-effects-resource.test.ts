import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade resource effect boundaries", () => {
  it("delegates SVG mask math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/mask.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) enum MaskUnits")).toBe(true);
    expect(source.includes("pub(all) enum MaskType")).toBe(true);
    expect(source.includes("pub(all) struct Mask")).toBe(true);
    expect(source.includes("pub(all) struct MaskRegistry")).toBe(true);
    expect(source.includes("@msvg.Mask::new(")).toBe(true);
    expect(source.includes("@msvg.Mask::with_bounds(")).toBe(true);
    expect(source.includes("@msvg.compute_luminance(")).toBe(true);
    expect(source.includes("@msvg.compute_alpha_mask(")).toBe(true);
    expect(source.includes("mask_to_msvg(self).get_mask_bounds(")).toBe(true);
    expect(source.includes("@msvg.apply_mask_to_image(")).toBe(true);
    expect(interopSource.includes("fn mask_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn mask_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn mask_type_to_msvg(")).toBe(true);
    expect(source.includes("fn resolve_mask_coord(")).toBe(false);
    expect(source.includes("fn resolve_mask_size(")).toBe(false);
    expect(source.includes("Standard luminance formula")).toBe(false);
    expect(typesSource.includes("pub(all) struct Mask")).toBe(false);
    expect(typesSource.includes("pub fn Mask::new(")).toBe(false);
  });

  it("delegates SVG pattern sampling to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/pattern.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct Pattern")).toBe(true);
    expect(source.includes("pub(all) enum PatternUnits")).toBe(true);
    expect(source.includes("pub(all) struct PatternRegistry")).toBe(true);
    expect(source.includes("@msvg.Pattern::new(")).toBe(true);
    expect(source.includes("pattern_to_msvg(self).get_color_at(")).toBe(true);
    expect(interopSource.includes("fn pattern_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn pattern_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn svg_node_to_msvg(")).toBe(true);
    expect(source.includes("Calculate pattern space coordinates")).toBe(false);
    expect(source.includes("Get position within pattern tile")).toBe(false);
    expect(typesSource.includes("pub(all) struct Pattern")).toBe(false);
    expect(typesSource.includes("pub fn Pattern::new(")).toBe(false);
  });

  it("delegates SVG marker transforms to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/marker.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct Marker")).toBe(true);
    expect(source.includes("pub(all) enum MarkerOrient")).toBe(true);
    expect(source.includes("pub(all) enum MarkerUnits")).toBe(true);
    expect(source.includes("pub(all) struct MarkerRegistry")).toBe(true);
    expect(source.includes("@msvg.Marker::new(")).toBe(true);
    expect(source.includes("@msvg.Marker::arrow(")).toBe(true);
    expect(source.includes("@msvg.Marker::dot(")).toBe(true);
    expect(source.includes("marker_to_msvg(self).get_transform(")).toBe(true);
    expect(interopSource.includes("fn marker_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn marker_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn marker_orient_to_msvg(")).toBe(true);
    expect(source.includes("let orient_angle = match self.orient")).toBe(false);
    expect(source.includes("Translate to position, rotate, scale")).toBe(false);
    expect(typesSource.includes("pub(all) struct Marker")).toBe(false);
    expect(typesSource.includes("pub fn Marker::new(")).toBe(false);
  });

  it("delegates SVG marked line angle math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/marker.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct MarkedLine")).toBe(true);
    expect(source.includes("@msvg.MarkedLine::new(")).toBe(true);
    expect(source.includes("@msvg.MarkedLine::with_markers(")).toBe(true);
    expect(source.includes("marked_line_to_msvg(self).get_angle_at(index)")).toBe(true);
    expect(interopSource.includes("fn marked_line_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn marked_line_to_msvg(")).toBe(true);
    expect(source.includes("let a1 = @math.atan2(dy1, dx1)")).toBe(false);
    expect(typesSource.includes("pub(all) struct MarkedLine")).toBe(false);
    expect(typesSource.includes("pub fn MarkedLine::new(")).toBe(false);
  });
});
