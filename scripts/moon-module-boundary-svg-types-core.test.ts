import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT } from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade core boundaries", () => {
  it("delegates SVG viewBox transform math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/viewbox.mbt"), "utf8");

    expect(source.includes("pub(all) struct ViewBox")).toBe(true);
    expect(source.includes("pub(all) struct PreserveAspectRatio")).toBe(true);
    expect(source.includes("pub fn ViewBox::get_transform(")).toBe(true);
    expect(source.includes("@msvg.ViewBox::")).toBe(true);
    expect(source.includes("fn get_alignment_factors(")).toBe(false);
    expect(typesSource.includes("pub(all) struct ViewBox")).toBe(false);
    expect(typesSource.includes("pub(all) struct PreserveAspectRatio")).toBe(false);
  });

  it("delegates SVG gradient color interpolation to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/gradient.mbt"), "utf8");

    expect(source.includes("pub(all) struct GradientStop")).toBe(true);
    expect(source.includes("pub(all) struct LinearGradient")).toBe(true);
    expect(source.includes("pub(all) struct RadialGradient")).toBe(true);
    expect(source.includes("pub(all) enum SpreadMethod")).toBe(true);
    expect(source.includes("@msvg.LinearGradient::new(")).toBe(true);
    expect(source.includes("@msvg.LinearGradient::horizontal(")).toBe(true);
    expect(source.includes("@msvg.LinearGradient::vertical(")).toBe(true);
    expect(source.includes("linear_gradient_from_msvg(")).toBe(true);
    expect(source.includes("pub fn LinearGradient::color_at(")).toBe(true);
    expect(source.includes("@msvg.RadialGradient::new(")).toBe(true);
    expect(source.includes("radial_gradient_from_msvg(")).toBe(true);
    expect(source.includes("pub fn RadialGradient::color_at(")).toBe(true);
    expect(source.includes("linear_gradient_to_msvg(self).color_at(")).toBe(true);
    expect(source.includes("radial_gradient_to_msvg(self).color_at(")).toBe(true);
    expect(source.includes("fn apply_spread(")).toBe(false);
    expect(source.includes("fn interpolate_gradient_color(")).toBe(false);
    expect(typesSource.includes("pub(all) struct LinearGradient")).toBe(false);
    expect(typesSource.includes("pub(all) struct RadialGradient")).toBe(false);
  });

  it("delegates SVG color and stroke defaults to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const colorSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/color.mbt"), "utf8");
    const paintSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/paint.mbt"), "utf8");

    expect(colorSource.includes("pub(all) struct Color")).toBe(true);
    expect(colorSource.includes("@msvg.Color::rgb(")).toBe(true);
    expect(colorSource.includes("@msvg.Color::rgba(")).toBe(true);
    expect(colorSource.includes("@msvg.Color::transparent()")).toBe(true);
    expect(colorSource.includes("@msvg.Color::black()")).toBe(true);
    expect(colorSource.includes("@msvg.Color::white()")).toBe(true);
    expect(colorSource.includes("color_to_msvg(self).is_transparent()")).toBe(true);
    expect(paintSource.includes("pub(all) enum Paint")).toBe(true);
    expect(paintSource.includes("pub(all) struct StrokeStyle")).toBe(true);
    expect(paintSource.includes("@msvg.StrokeStyle::default()")).toBe(true);
    expect(typesSource.includes("pub(all) struct Color")).toBe(false);
    expect(typesSource.includes("pub(all) struct StrokeStyle")).toBe(false);
  });

  it("delegates SVG transform operations to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/transform.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");

    expect(source.includes("pub(all) struct Transform")).toBe(true);
    expect(source.includes("@msvg.Transform::")).toBe(true);
    expect(source.includes("@msvg.Transform::matrix(")).toBe(true);
    expect(source.includes("@math.cos")).toBe(false);
    expect(source.includes("@math.tan")).toBe(false);
    expect(source.includes("@math.atan2")).toBe(false);
    expect(source.includes("Matrix multiplication:")).toBe(false);
    expect(source.includes("  { a, b, c, d, e, f }")).toBe(false);
    expect(interopSource.includes("Transform::matrix(")).toBe(false);
    expect(typesSource.includes("pub(all) struct Transform")).toBe(false);
  });

  it("delegates SVG bounding boxes and clip rects to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/geometry.mbt"), "utf8");

    expect(source.includes("pub(all) struct BoundingBox")).toBe(true);
    expect(source.includes("pub(all) struct ClipRect")).toBe(true);
    expect(source.includes("@msvg.BoundingBox::empty()")).toBe(true);
    expect(source.includes("@msvg.BoundingBox::from_rect(")).toBe(true);
    expect(source.includes("bounding_box_to_msvg(self).width()")).toBe(true);
    expect(source.includes("@msvg.ClipRect::")).toBe(true);
    expect(source.includes("fn min(")).toBe(false);
    expect(source.includes("fn max(")).toBe(false);
    expect(typesSource.includes("pub(all) struct BoundingBox")).toBe(false);
    expect(typesSource.includes("pub fn ClipRect::new(")).toBe(false);
  });

  it("delegates SVG node cloning to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/node.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct SVGNode")).toBe(true);
    expect(source.includes("svg_node_from_msvg(svg_node_to_msvg(self).clone())")).toBe(true);
    expect(interopSource.includes("fn svg_node_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn svg_node_from_msvg(")).toBe(true);
    expect(source.includes("let children : Array[SVGNode] = []")).toBe(false);
    expect(source.includes("let filters : Array[Filter] = []")).toBe(false);
    expect(typesSource.includes("pub(all) struct SVGNode")).toBe(false);
    expect(typesSource.includes("pub fn SVGNode::clone(")).toBe(false);
  });
});
