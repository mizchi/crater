import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines, readSvgInteropSources } from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade filter and blend boundaries", () => {
  it("delegates SVG node effect setters to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/node.mbt"), "utf8");
    const interopSource = readSvgInteropSources();
    const effectStart = source.indexOf("/// Add a filter to the node");
    const effectEnd = source.indexOf("///|\n/// Clone an SVGNode", effectStart);
    const effectSource = source.slice(effectStart, effectEnd);

    expect(effectSource.includes("let node = svg_node_to_msvg(self)")).toBe(true);
    expect(effectSource.includes("node.add_filter(filter_to_msvg(filter))")).toBe(true);
    expect(effectSource.includes("node.clear_filters()")).toBe(true);
    expect(effectSource.includes("node.set_mask(mask_id)")).toBe(true);
    expect(effectSource.includes("node.clear_mask()")).toBe(true);
    expect(effectSource.includes("node.set_clip_path(clip_path_id)")).toBe(true);
    expect(effectSource.includes("node.clear_clip_path()")).toBe(true);
    expect(effectSource.includes("copy_svg_node_effect_state_from_msvg(self, node)")).toBe(true);
    expect(interopSource.includes("fn copy_svg_node_effect_state_from_msvg(")).toBe(true);
    expect(effectSource.includes("self.filters.push(")).toBe(false);
    expect(effectSource.includes("self.filters.clear()")).toBe(false);
    expect(effectSource.includes("self.mask_id =")).toBe(false);
    expect(effectSource.includes("self.clip_path_id =")).toBe(false);
    expect(effectSource.includes("self.node_dirty =")).toBe(false);
    expect(typesSource.includes("pub fn SVGNode::add_filter(")).toBe(false);
    expect(typesSource.includes("pub fn SVGNode::set_mask(")).toBe(false);
  });

  it("delegates SVG color filter math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/filter.mbt"), "utf8");

    expect(source.includes("pub(all) enum Filter")).toBe(true);
    expect(source.includes("@msvg.apply_brightness(")).toBe(true);
    expect(source.includes("@msvg.apply_grayscale(")).toBe(true);
    expect(source.includes("@msvg.apply_contrast(")).toBe(true);
    expect(source.includes("@msvg.apply_sepia(")).toBe(true);
    expect(source.includes("@msvg.apply_hue_rotate(")).toBe(true);
    expect(source.includes("@msvg.apply_invert(")).toBe(true);
    expect(source.includes("@msvg.apply_saturate(")).toBe(true);
    expect(source.includes("@msvg.apply_color_matrix(")).toBe(true);
    expect(source.includes("@msvg.identity_matrix()")).toBe(true);
    expect(source.includes("@msvg.saturate_matrix(")).toBe(true);
    expect(source.includes("@msvg.hue_rotate_matrix(")).toBe(true);
    expect(source.includes("@msvg.luminance_to_alpha_matrix()")).toBe(true);
    expect(source.includes("fn cos_approx(")).toBe(false);
    expect(source.includes("fn sin_approx(")).toBe(false);
    expect(source.includes("Hue rotation matrix")).toBe(false);
    expect(source.includes("Sepia matrix coefficients")).toBe(false);
    expect(typesSource.includes("pub(all) enum Filter")).toBe(false);
    expect(typesSource.includes("pub fn apply_filter(image : Image")).toBe(false);
  });

  it("delegates SVG blend mode math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/blend.mbt"), "utf8");
    const interopSource = readSvgInteropSources();

    expect(source.includes("pub(all) enum BlendMode")).toBe(true);
    expect(source.includes("pub(all) enum Isolation")).toBe(true);
    expect(source.includes("@msvg.blend_with_mode(")).toBe(true);
    expect(source.includes("@msvg.blend_images(")).toBe(true);
    expect(interopSource.includes("fn blend_mode_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn image_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn image_from_msvg(")).toBe(true);
    expect(source.includes("fn blend_overlay_channel(")).toBe(false);
    expect(source.includes("fn blend_color_dodge_channel(")).toBe(false);
    expect(source.includes("fn blend_color_burn_channel(")).toBe(false);
    expect(source.includes("fn blend_soft_light_channel(")).toBe(false);
    expect(source.includes("fn rgb_to_hsl(")).toBe(false);
    expect(source.includes("fn hsl_to_rgb(")).toBe(false);
    expect(source.includes("fn sqrt_approx(")).toBe(false);
    expect(typesSource.includes("pub(all) enum BlendMode")).toBe(false);
    expect(typesSource.includes("pub fn blend_images(")).toBe(false);
  });
});
