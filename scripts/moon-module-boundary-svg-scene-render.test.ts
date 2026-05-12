import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit SVG scene render boundaries", () => {
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
});
