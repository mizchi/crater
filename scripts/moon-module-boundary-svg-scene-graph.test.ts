import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit SVG scene graph boundaries", () => {
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
});
