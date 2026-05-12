import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit SVG scene animation boundaries", () => {
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
