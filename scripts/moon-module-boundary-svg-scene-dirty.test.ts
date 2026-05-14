import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines, readSvgInteropSources } from "./moon-module-boundary-helpers";

describe("MoonBit SVG scene dirty and z-order boundaries", () => {
  it("delegates SVG scene queries to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_dirty.mbt"), "utf8");

    expect(sceneSource.includes("svg_scene_from_msvg(@msvg.Scene::empty())")).toBe(true);
    expect(source.includes("bounding_box_from_msvg(scene_to_msvg(self).get_bounds())")).toBe(true);
    expect(source.includes("bounding_box_from_msvg(scene_to_msvg(self).get_dirty_region())")).toBe(true);
    expect(source.includes("compute_bounds(self.root, Transform::identity())")).toBe(false);
    expect(source.includes("compute_dirty_region(self.root, Transform::identity())")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::get_bounds(")).toBe(false);
  });

  it("delegates SVG dirty rendering to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_dirty.mbt"), "utf8");
    const interopSource = readSvgInteropSources();
    const renderDirtyStart = source.indexOf("pub fn Scene::render_dirty(");
    const renderDirtyEnd = source.indexOf("///|\n/// Mark a node", renderDirtyStart);
    const renderDirtySource = source.slice(renderDirtyStart, renderDirtyEnd);

    expect(renderDirtySource.includes("let scene = scene_to_msvg(self)")).toBe(true);
    expect(renderDirtySource.includes("scene.render_dirty(render_context_to_msvg(ctx))")).toBe(true);
    expect(renderDirtySource.includes("copy_svg_scene_dirty_state_from_msvg(self, scene)")).toBe(true);
    expect(renderDirtySource.includes("RenderContext::with_clip(")).toBe(false);
    expect(source.includes("fn render_and_update_dirty(")).toBe(false);
    expect(source.includes("fn render_node(")).toBe(false);
    expect(source.includes("fn render_rect(")).toBe(false);
    expect(source.includes("fn apply_opacity(")).toBe(false);
    expect(interopSource.includes("fn copy_svg_scene_dirty_state_from_msvg(")).toBe(true);
    expect(sceneSource.includes("pub fn Scene::render_dirty(")).toBe(false);
  });

  it("delegates SVG scene dirty flag operations to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_dirty.mbt"), "utf8");
    const markStart = source.indexOf("pub fn Scene::mark_node_dirty(");
    const markEnd = source.indexOf("///|\n/// Clear all dirty flags", markStart);
    const markSource = source.slice(markStart, markEnd);
    const clearStart = source.indexOf("pub fn Scene::clear_all_dirty(");
    const clearEnd = source.indexOf("///|\n/// Set z_index", clearStart);
    const clearSource = source.slice(clearStart, clearEnd);

    expect(markSource.includes("let scene = scene_to_msvg(self)")).toBe(true);
    expect(markSource.includes("scene.mark_node_dirty(id)")).toBe(true);
    expect(markSource.includes("copy_svg_scene_dirty_state_from_msvg(self, scene)")).toBe(true);
    expect(clearSource.includes("let scene = scene_to_msvg(self)")).toBe(true);
    expect(clearSource.includes("scene.clear_all_dirty()")).toBe(true);
    expect(clearSource.includes("copy_svg_scene_dirty_state_from_msvg(self, scene)")).toBe(true);
    expect(source.includes("fn clear_dirty_recursive(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::mark_node_dirty(")).toBe(false);
  });

  it("delegates SVG scene z-index operations to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_z_order.mbt"), "utf8");
    const interopSource = readSvgInteropSources();

    expect(source.includes("scene.set_z_index(id, z_index)")).toBe(true);
    expect(source.includes("scene.bring_to_front(id)")).toBe(true);
    expect(source.includes("scene.send_to_back(id)")).toBe(true);
    expect(source.includes("copy_svg_scene_z_order_state_from_msvg(self, scene)")).toBe(true);
    expect(interopSource.includes("fn copy_svg_scene_z_order_state_from_msvg(")).toBe(true);
    expect(source.includes("fn find_parent_and_node(")).toBe(false);
    expect(source.includes("fn get_max_z_index(")).toBe(false);
    expect(source.includes("fn get_min_z_index(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::set_z_index(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::bring_to_front(")).toBe(false);
  });
});
