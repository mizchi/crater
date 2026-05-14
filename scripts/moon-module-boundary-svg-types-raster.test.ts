import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, readSvgInteropSources } from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade raster boundaries", () => {
  it("delegates SVG path rasterization to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/path.mbt"), "utf8");
    const interopSource = readSvgInteropSources();

    expect(source.includes("@msvg.parse_path(data)")).toBe(true);
    expect(source.includes("@msvg.path_to_polylines(")).toBe(true);
    expect(source.includes("@msvg.raster_path(")).toBe(true);
    expect(source.includes("@msvg.path_bbox(")).toBe(true);
    expect(interopSource.includes("fn path_commands_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn pixel_setter_to_msvg(")).toBe(true);
    expect(source.includes("let polylines = path_to_polylines(commands, flatness)")).toBe(false);
    expect(source.includes("raster_polygon_fill(int_points, color, setter)")).toBe(false);
  });

  it("delegates SVG pixel setter clipping to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/raster.mbt"), "utf8");
    const interopSource = readSvgInteropSources();

    expect(source.includes("pixel_setter_from_msvg(")).toBe(true);
    expect(source.includes("pixel_setter_to_msvg(self).with_clip(")).toBe(true);
    expect(source.includes("pixel_setter_to_msvg(self).with_clip_and_offset(")).toBe(true);
    expect(interopSource.includes("fn pixel_setter_from_msvg(")).toBe(true);
    expect(source.includes("if clip.contains(")).toBe(false);
  });

  it("delegates SVG shape hit testing to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const shapeSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/shape.mbt"), "utf8");
    const hitTestSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/hit_testing.mbt"), "utf8");
    const interopSource = readSvgInteropSources();
    const nodeHitStart = hitTestSource.indexOf("pub fn SVGNode::hit_test(");
    const nodeHitEnd = hitTestSource.indexOf("///|\n/// Find all nodes", nodeHitStart);
    const nodeHitSource = hitTestSource.slice(nodeHitStart, nodeHitEnd);

    expect(shapeSource.includes("pub(all) enum PathCommand")).toBe(true);
    expect(shapeSource.includes("pub(all) enum Shape")).toBe(true);
    expect(shapeSource.includes("pub impl Show for Shape")).toBe(true);
    expect(hitTestSource.includes("pub fn hit_test_shape(")).toBe(true);
    expect(hitTestSource.includes("@msvg.hit_test_shape(px, py, shape_to_msvg(shape))")).toBe(true);
    expect(nodeHitSource.includes("svg_node_to_msvg(self).hit_test(px, py)")).toBe(true);
    expect(nodeHitSource.includes("let inv = self.transform.inverse()")).toBe(false);
    expect(nodeHitSource.includes("hit_test_shape(local_x, local_y, self.shape)")).toBe(false);
    expect(interopSource.includes("fn shape_to_msvg(")).toBe(true);
    expect(hitTestSource.includes("fn hit_test_rect(")).toBe(false);
    expect(hitTestSource.includes("fn hit_test_circle(")).toBe(false);
    expect(hitTestSource.includes("fn hit_test_ellipse(")).toBe(false);
    expect(hitTestSource.includes("fn hit_test_polygon(")).toBe(false);
    expect(hitTestSource.includes("fn hit_test_line(")).toBe(false);
    expect(typesSource.includes("pub(all) enum PathCommand")).toBe(false);
    expect(typesSource.includes("pub(all) enum Shape")).toBe(false);
    expect(typesSource.includes("pub fn hit_test_shape(")).toBe(false);
    expect(typesSource.includes("fn hit_test_recursive(")).toBe(false);
  });

  it("delegates SVG clip paths to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/clip_path.mbt"), "utf8");
    const interopSource = readSvgInteropSources();
    const containsStart = source.indexOf("pub fn ClipPath::contains(");
    const containsEnd = source.indexOf("///|\n/// Clip path registry", containsStart);
    const containsSource = source.slice(containsStart, containsEnd);

    expect(source.includes("pub(all) struct ClipPath")).toBe(true);
    expect(source.includes("pub(all) struct ClipPathRegistry")).toBe(true);
    expect(source.includes("@msvg.ClipPath::new(")).toBe(true);
    expect(source.includes("clip_path_from_msvg(")).toBe(true);
    expect(source.includes("clip_path_to_msvg(self).contains(x, y)")).toBe(true);
    expect(interopSource.includes("fn clip_path_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn clip_path_to_msvg(")).toBe(true);
    expect(containsSource.includes("let inv = self.transform.inverse()")).toBe(false);
    expect(containsSource.includes("hit_test_shape(cx, cy, self.shape)")).toBe(false);
    expect(typesSource.includes("pub(all) struct ClipPath")).toBe(false);
    expect(typesSource.includes("pub fn ClipPath::new(")).toBe(false);
  });

  it("delegates SVG camera math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/camera.mbt"), "utf8");
    const interopSource = readSvgInteropSources();

    expect(source.includes("pub(all) struct Camera")).toBe(true);
    expect(source.includes("@msvg.Camera::new(")).toBe(true);
    expect(source.includes("camera_to_msvg(self).get_visible_bounds()")).toBe(true);
    expect(source.includes("camera_to_msvg(self).world_to_screen(")).toBe(true);
    expect(source.includes("camera_to_msvg(self).screen_to_world(")).toBe(true);
    expect(source.includes("camera_to_msvg(self).get_transform()")).toBe(true);
    expect(interopSource.includes("fn camera_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_camera_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn camera_to_msvg(")).toBe(true);
    expect(source.includes("self.x = self.x + dx")).toBe(false);
    expect(source.includes("self.viewport_width.to_double() / 2.0")).toBe(false);
    expect(typesSource.includes("pub(all) struct Camera")).toBe(false);
    expect(typesSource.includes("pub fn Camera::new(")).toBe(false);
  });

  it("delegates SVG collision operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/collision.mbt"), "utf8");

    expect(source.includes("@msvg.collide_circle_circle(")).toBe(true);
    expect(source.includes("@msvg.collide_rect_rect(")).toBe(true);
    expect(source.includes("@msvg.collide_circle_rect(")).toBe(true);
    expect(source.includes("@msvg.collide_shapes(shape_to_msvg(shape1), shape_to_msvg(shape2))")).toBe(true);
    expect(source.includes("svg_node_to_msvg(self).collides_with(svg_node_to_msvg(other))")).toBe(true);
    expect(source.includes("fn get_shape_bbox(")).toBe(false);
    expect(source.includes("Fall back to bounding box collision")).toBe(false);
    expect(typesSource.includes("pub fn collide_circle_circle(")).toBe(false);
    expect(typesSource.includes("pub fn SVGNode::collides_with(")).toBe(false);
  });
});
