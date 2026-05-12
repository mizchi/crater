import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser TUI render hit-region boundaries", () => {
  it("splits browser tui hit regions out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const hitSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_region.mbt"), "utf8");

    expect(hitSource).toContain("pub(all) struct HitRegion");
    expect(hitSource).toContain("pub(all) enum HitClipShape");
    expect(hitSource).toContain("pub fn find_hit_region_at(");
    expect(hitSource).toContain("fn collect_hit_region(");
    expect(hitSource).toContain("ctx.hit_regions.push(");
    expect(hitSource).not.toContain("pub(all) struct LinkRegion");
    expect(hitSource).not.toContain("fn point_in_polygon(");
    expect(renderSource).not.toContain("pub(all) struct LinkRegion");
    expect(renderSource).not.toContain("pub(all) struct HitRegion");
    expect(renderSource).not.toContain("pub(all) enum HitClipShape");
    expect(renderSource).not.toContain("fn point_in_polygon(");
    expect(renderSource).not.toContain("ctx.hit_regions.push(");
  });

  it("splits browser tui link regions out of hit regions", () => {
    const hitSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_region.mbt"), "utf8");
    const linkSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_link_region.mbt"), "utf8");

    expect(linkSource).toContain("pub(all) struct LinkRegion");
    expect(linkSource).toContain("pub fn find_link_at(");
    expect(linkSource).toContain("pub fn find_link_region_at(");
    expect(hitSource).not.toContain("pub(all) struct LinkRegion");
    expect(hitSource).not.toContain("pub fn find_link_at(");
  });

  it("splits browser tui hit shape predicates out of hit region collection", () => {
    const hitSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_region.mbt"), "utf8");
    const shapeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_shape.mbt"), "utf8");
    const containsSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_contains.mbt"), "utf8");

    expect(shapeSource).toContain("fn resolve_hit_radius(");
    expect(shapeSource).toContain("fn resolve_hit_clip_shape(");
    expect(containsSource).toContain("pub fn HitRegion::contains(");
    expect(hitSource).not.toContain("fn point_in_rounded_rect(");
    expect(hitSource).not.toContain("fn point_in_hit_clip_shape(");
  });

  it("splits browser tui hit containment sampling out of shape resolution", () => {
    const shapeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_shape.mbt"), "utf8");
    const containsSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_contains.mbt"), "utf8");

    expect(containsSource).toContain("fn HitRegion::contains_pixel(");
    expect(containsSource).toContain("fn HitRegion::has_cell_coverage(");
    expect(containsSource).toContain("fn HitRegion::allows_cell_coverage_sampling(");
    expect(containsSource).toContain("pub fn HitRegion::contains(");
    expect(shapeSource).not.toContain("fn HitRegion::contains_pixel(");
    expect(shapeSource).not.toContain("pub fn HitRegion::contains(");
  });

  it("splits browser tui hit point predicates out of hit shape resolution", () => {
    const shapeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_shape.mbt"), "utf8");
    const predicateSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_predicate.mbt"), "utf8");

    expect(predicateSource).toContain("fn point_in_rounded_corner(");
    expect(predicateSource).toContain("fn point_in_rounded_rect(");
    expect(predicateSource).toContain("fn point_in_hit_clip_shape(");
    expect(predicateSource).toContain("fn point_in_polygon(");
    expect(shapeSource).not.toContain("fn point_in_rounded_corner(");
    expect(shapeSource).not.toContain("fn point_in_rounded_rect(");
    expect(shapeSource).not.toContain("fn point_in_hit_clip_shape(");
    expect(shapeSource).not.toContain("fn point_in_polygon(");
  });
});
