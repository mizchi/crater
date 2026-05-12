import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  BROWSER_TERMINAL_PROTOCOL_ANSI_FILES,
  DIRECT_TUI_TERMINAL_PROTOCOL_FILES,
  REPO_ROOT,
  collectMoonBitFiles,
  collectMoonPackageFiles,
  countLines,
} from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade boundaries", () => {
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

  it("delegates SVG path rasterization to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/path.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

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
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pixel_setter_from_msvg(")).toBe(true);
    expect(source.includes("pixel_setter_to_msvg(self).with_clip(")).toBe(true);
    expect(source.includes("pixel_setter_to_msvg(self).with_clip_and_offset(")).toBe(true);
    expect(interopSource.includes("fn pixel_setter_from_msvg(")).toBe(true);
    expect(source.includes("if clip.contains(")).toBe(false);
  });

  it("delegates SVG pointer event state to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/event.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("@msvg.PointerEvent::new(")).toBe(true);
    expect(source.includes("pointer_event_from_msvg(")).toBe(true);
    expect(source.includes("pointer_event_to_msvg(self)")).toBe(true);
    expect(source.includes("event.stop_propagation()")).toBe(true);
    expect(interopSource.includes("fn pointer_event_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn pointer_event_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_pointer_event_state_from_msvg(")).toBe(true);
    expect(source.includes("self.propagation_stopped = true")).toBe(false);
  });

  it("delegates SVG text whitespace helpers to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/text.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

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
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

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
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
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
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

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

  it("keeps SVG event system in a dedicated module", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const eventSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/event.mbt"), "utf8");

    expect(eventSource.includes("pub(all) struct PointerEvent")).toBe(true);
    expect(eventSource.includes("pub(all) struct EventManager")).toBe(true);
    expect(eventSource.includes("pub fn EventManager::dispatch_click(")).toBe(true);
    expect(eventSource.includes("fn EventManager::dispatch_to_node(")).toBe(true);
    expect(typesSource.includes("pub(all) struct EventManager")).toBe(false);
    expect(typesSource.includes("fn EventManager::dispatch_to_node(")).toBe(false);
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

  it("delegates SVG node effect setters to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/node.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
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

  it("delegates SVG shape hit testing to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const shapeSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/shape.mbt"), "utf8");
    const hitTestSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/hit_testing.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
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
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
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
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

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

  it("delegates SVG image and sprite operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/image.mbt"), "utf8");
    const filterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/filter.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct Image")).toBe(true);
    expect(source.includes("pub(all) struct Sprite")).toBe(true);
    expect(source.includes("pub(all) struct SpriteSheet")).toBe(true);
    expect(source.includes("@msvg.Image::new(")).toBe(true);
    expect(source.includes("@msvg.Image::filled(")).toBe(true);
    expect(source.includes("image_to_msvg(self).get_pixel(")).toBe(true);
    expect(source.includes("image_to_msvg(self).clone()")).toBe(true);
    expect(filterSource.includes("@msvg.apply_blur(")).toBe(true);
    expect(filterSource.includes("@msvg.apply_drop_shadow(")).toBe(true);
    expect(filterSource.includes("@msvg.apply_filter(")).toBe(true);
    expect(source.includes("@msvg.blit(")).toBe(true);
    expect(source.includes("@msvg.blit_sprite(")).toBe(true);
    expect(source.includes("@msvg.blit_scaled(")).toBe(true);
    expect(source.includes("image_to_msvg(self).flip_horizontal()")).toBe(true);
    expect(source.includes("image_to_msvg(self).rotate_90_cw()")).toBe(true);
    expect(interopSource.includes("fn copy_image_pixels_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn sprite_to_msvg(")).toBe(true);
    expect(source.includes("Box blur")).toBe(false);
    expect(source.includes("Alpha blend foreground over background")).toBe(false);
    expect(source.includes("Nearest-neighbor sampling")).toBe(false);
    expect(source.includes("fn blend_colors(")).toBe(false);
    expect(typesSource.includes("pub(all) struct Image")).toBe(false);
    expect(typesSource.includes("pub fn Image::new(")).toBe(false);
  });

  it("delegates SVG animated sprite operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/image.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct AnimatedSprite")).toBe(true);
    expect(source.includes("@msvg.AnimatedSprite::new(")).toBe(true);
    expect(source.includes("@msvg.AnimatedSprite::from_range(")).toBe(true);
    expect(source.includes("animated_sprite_to_msvg(self).get_current_sprite()")).toBe(true);
    expect(source.includes("let sprite = animated_sprite_to_msvg(self)")).toBe(true);
    expect(source.includes("sprite.update(dt)")).toBe(true);
    expect(interopSource.includes("fn animated_sprite_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_animated_sprite_state_from_msvg(")).toBe(true);
    expect(source.includes("while self.elapsed >= self.frame_duration")).toBe(false);
    expect(source.includes("self.current_frame = self.current_frame + 1")).toBe(false);
    expect(typesSource.includes("pub(all) struct AnimatedSprite")).toBe(false);
  });

  it("delegates SVG particle operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/particle.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct Particle")).toBe(true);
    expect(source.includes("pub(all) struct ParticleEmitter")).toBe(true);
    expect(source.includes("pub(all) struct SimpleRNG")).toBe(true);
    expect(source.includes("@msvg.Particle::new(")).toBe(true);
    expect(source.includes("@msvg.EmitterConfig::default(")).toBe(true);
    expect(source.includes("@msvg.ParticleEmitter::new(")).toBe(true);
    expect(source.includes("particle_emitter_to_msvg(self)")).toBe(true);
    expect(source.includes("emitter.update(dt)")).toBe(true);
    expect(source.includes("particle_emitter_to_msvg(self).active_count()")).toBe(true);
    expect(interopSource.includes("fn particle_emitter_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_particle_emitter_state_from_msvg(")).toBe(true);
    expect(source.includes("fn ParticleEmitter::emit_one(")).toBe(false);
    expect(source.includes("fn random_range(")).toBe(false);
    expect(typesSource.includes("pub(all) struct Particle")).toBe(false);
    expect(typesSource.includes("pub fn ParticleEmitter::new(")).toBe(false);
  });

  it("delegates SVG path follower operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/path_animation.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct PathFollower")).toBe(true);
    expect(source.includes("@msvg.PathFollower::new(")).toBe(true);
    expect(source.includes("path_follower_to_msvg(self).get_position()")).toBe(true);
    expect(source.includes("let follower = path_follower_to_msvg(self)")).toBe(true);
    expect(source.includes("follower.update(dt, speed)")).toBe(true);
    expect(interopSource.includes("fn path_follower_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_path_follower_state_from_msvg(")).toBe(true);
    expect(source.includes("fn flatten_path(")).toBe(false);
    expect(source.includes("fn compute_path_lengths(")).toBe(false);
    expect(typesSource.includes("pub(all) struct PathFollower")).toBe(false);
    expect(typesSource.includes("pub fn PathFollower::new(")).toBe(false);
  });

  it("delegates SVG tween operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/tween.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) enum Easing")).toBe(true);
    expect(source.includes("pub(all) enum AnimProperty")).toBe(true);
    expect(source.includes("pub(all) struct Tween")).toBe(true);
    expect(source.includes("@msvg.Tween::new(")).toBe(true);
    expect(source.includes("tween_to_msvg(self).is_complete()")).toBe(true);
    expect(source.includes("let tween = tween_to_msvg(self)")).toBe(true);
    expect(source.includes("tween.update(dt, msvg_node)")).toBe(true);
    expect(interopSource.includes("fn easing_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn tween_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_tween_state_from_msvg(")).toBe(true);
    expect(source.includes("fn capture_property(")).toBe(false);
    expect(source.includes("fn apply_interpolated_property(")).toBe(false);
    expect(source.includes("fn lerp_color(")).toBe(false);
    expect(typesSource.includes("pub(all) struct Tween")).toBe(false);
    expect(typesSource.includes("pub fn Tween::new(")).toBe(false);
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

  it("delegates SVG object pool operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/object_pool.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("@msvg.ObjectPool::new(")).toBe(true);
    expect(source.includes("object_pool_from_msvg(")).toBe(true);
    expect(source.includes("object_pool_to_msvg(self).acquire()")).toBe(true);
    expect(source.includes("object_pool_to_msvg(self).release(obj)")).toBe(true);
    expect(source.includes("object_pool_to_msvg(self).available_count()")).toBe(true);
    expect(interopSource.includes("fn[T] object_pool_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn[T] object_pool_to_msvg(")).toBe(true);
    expect(source.includes("self.available.pop().unwrap()")).toBe(false);
    expect(typesSource.includes("pub(all) struct ObjectPool")).toBe(false);
    expect(typesSource.includes("pub fn[T] ObjectPool::new(")).toBe(false);
  });

  it("delegates SVG blend mode math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/blend.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

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
