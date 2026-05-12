import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser TUI render paint boundaries", () => {
  it("splits browser tui image rendering out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const imageSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_image.mbt"), "utf8");

    expect(imageSource).toContain("fn render_image_node(");
    expect(imageSource).toContain("fn draw_image_placeholder(");
    expect(imageSource).toContain("ctx.image_regions.push(");
    expect(renderSource).not.toContain("ctx.image_regions.push(");
    expect(renderSource).not.toContain("let img_bg =");
    expect(renderSource).not.toContain("Draw alt text");
  });

  it("splits browser tui text rendering out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const textSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_text.mbt"), "utf8");

    expect(textSource).toContain("fn render_text_node(");
    expect(textSource).toContain("fn resolve_text_style(");
    expect(textSource).toContain("ctx.link_regions.push(");
    expect(renderSource).not.toContain("ctx.link_regions.push(");
    expect(renderSource).not.toContain("write_text_wrapped(");
    expect(renderSource).not.toContain("let text_display_width =");
  });

  it("splits browser tui element scrollbar rendering out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const scrollbarSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_scrollbar.mbt"), "utf8");

    expect(scrollbarSource).toContain("fn render_element_scrollbar(");
    expect(scrollbarSource).toContain("ctx.element_scroll_positions.get(");
    expect(scrollbarSource).toContain("draw_scrollbar(");
    expect(renderSource).not.toContain("ctx.element_scroll_positions.get(");
    expect(renderSource).not.toContain("node.is_scrollable()");
  });

  it("splits browser tui child traversal out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const traversalSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_traversal.mbt"), "utf8");

    expect(traversalSource).toContain("fn render_child_nodes(");
    expect(traversalSource).toContain("for child in node.children");
    expect(traversalSource).toContain("render_paint_node(");
    expect(renderSource).not.toContain("for child in node.children");
  });
});
