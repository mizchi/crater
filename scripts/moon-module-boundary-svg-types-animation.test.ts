import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT } from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade animation boundaries", () => {
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
});
