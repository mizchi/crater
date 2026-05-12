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

describe("MoonBit SVG scene module boundaries", () => {
  it("delegates SVG scene node factories to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_factory.mbt"), "utf8");
    const factoryStart = source.indexOf("/// Helper: Create a rectangle node");
    const factoryEnd = source.length;
    const factorySource = source.slice(factoryStart, factoryEnd);
    const groupStart = source.indexOf("pub fn group(", factoryStart);
    const groupEnd = source.indexOf("///|", groupStart + 1);
    const groupSource = source.slice(groupStart, groupEnd);

    expect(factorySource.includes("svg_node_from_msvg(@msvg.rect(")).toBe(true);
    expect(factorySource.includes("svg_node_from_msvg(@msvg.circle(")).toBe(true);
    expect(factorySource.includes("svg_node_from_msvg(@msvg.line(")).toBe(true);
    expect(factorySource.includes("svg_node_from_msvg(@msvg.path(")).toBe(true);
    expect(factorySource.includes("svg_node_from_msvg(@msvg.text(")).toBe(true);
    expect(factorySource.includes("svg_node_from_msvg(@msvg.group(")).toBe(false);
    expect(groupSource.includes("node.children.push(child)")).toBe(true);
    expect(sceneSource.includes("pub fn rect(")).toBe(false);
    expect(sceneSource.includes("pub fn group(")).toBe(false);
  });

  it("delegates SVG scene render entrypoints to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_render.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("let scene = scene_to_msvg(self)")).toBe(true);
    expect(source.includes("scene.render(render_context_to_msvg(ctx))")).toBe(true);
    expect(source.includes("scene.render_with_camera(")).toBe(true);
    expect(source.includes("scene.render_with_viewbox(")).toBe(true);
    expect(source.includes("scene.render_with_viewbox_and_camera(")).toBe(true);
    expect(interopSource.includes("fn render_context_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn scene_to_msvg(")).toBe(true);
    expect(source.includes("render_node(self.root, Transform::identity(), ctx)")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::render(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::render_with_camera(")).toBe(false);
  });

  it("delegates SVG render context constructors to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/render_context.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct RenderContext")).toBe(true);
    expect(source.includes("render_context_from_msvg(")).toBe(true);
    expect(source.includes("@msvg.RenderContext::new(")).toBe(true);
    expect(source.includes("@msvg.RenderContext::with_clip(")).toBe(true);
    expect(source.includes("@msvg.RenderContext::for_camera(")).toBe(true);
    expect(interopSource.includes("fn render_context_from_msvg(")).toBe(true);
    expect(source.includes("{ setter, width, height, flatness: 0.5, clip: None }")).toBe(false);
    expect(source.includes("{ setter, width, height, flatness: 0.5, clip: Some(clip) }")).toBe(false);
    expect(source.includes("let clip = ClipRect::from_size(camera.viewport_width, camera.viewport_height)")).toBe(false);
    expect(sceneSource.includes("pub(all) struct RenderContext")).toBe(false);
    expect(sceneSource.includes("pub fn RenderContext::new(")).toBe(false);
  });

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
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
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
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

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

  it("isolates SVG scene graph mutation helpers from scene type", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_graph.mbt"), "utf8");

    expect(source.includes("pub fn Scene::update_node(")).toBe(true);
    expect(source.includes("fn update_node_recursive(")).toBe(true);
    expect(source.includes("pub fn Scene::find_node(")).toBe(true);
    expect(source.includes("fn find_node_recursive(")).toBe(true);
    expect(source.includes("pub fn Scene::add_child(")).toBe(true);
    expect(source.includes("fn add_child_recursive(")).toBe(true);
    expect(source.includes("pub fn Scene::remove_node(")).toBe(true);
    expect(source.includes("fn remove_node_recursive(")).toBe(true);
    expect(sceneSource.includes("pub fn Scene::update_node(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::find_node(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::add_child(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::remove_node(")).toBe(false);
  });

  it("delegates SVG animation manager operations to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/animation_manager.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct AnimationManager")).toBe(true);
    expect(source.includes("animation_manager_from_msvg(@msvg.AnimationManager::new())")).toBe(true);
    expect(source.includes("let manager = animation_manager_to_msvg(self)")).toBe(true);
    expect(source.includes("manager.animate_translate(")).toBe(true);
    expect(source.includes("manager.animate_opacity(")).toBe(true);
    expect(source.includes("manager.animate_scale(")).toBe(true);
    expect(source.includes("manager.update(dt, msvg_scene)")).toBe(true);
    expect(source.includes("manager.cleanup()")).toBe(true);
    expect(source.includes("animation_manager_to_msvg(self).is_animating()")).toBe(true);
    expect(source.includes("manager.clear()")).toBe(true);
    expect(interopSource.includes("fn animation_manager_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn animation_manager_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_animation_manager_state_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_svg_scene_animation_state_from_msvg(")).toBe(true);
    expect(source.includes("for tween in self.tweens")).toBe(false);
    expect(source.includes("Remove completed tweens")).toBe(false);
    expect(source.includes("self.tweens.clear()")).toBe(false);
    expect(sceneSource.includes("pub(all) struct AnimationManager")).toBe(false);
    expect(sceneSource.includes("pub fn AnimationManager::new(")).toBe(false);
  });
});
