import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser TUI buffer core boundaries", () => {
  it("delegates reusable browser tui buffer algorithms to tui terminal buffer", () => {
    const pkg = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/moon.pkg"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer.mbt"), "utf8");
    const textSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer_text.mbt"), "utf8");

    expect(pkg).toContain('"mizchi/tui-terminal-buffer/buffer" @tui_buffer');
    expect(source).toContain("@tui_buffer.clip_rect(self.width, self.height, x, y, w, h)");
    expect(textSource).toContain("@tui_buffer.char_display_width(c)");
    expect(textSource).toContain("@tui_buffer.plan_write_text(x, y, text, max_width)");
    expect(textSource).toContain("@tui_buffer.plan_write_text_pre(x, y, text, max_width, max_height)");
    expect(textSource).toContain("@tui_buffer.plan_write_text_wrapped(");
    expect(textSource).toContain("x, y, text, max_width, max_height,");
    expect(source).not.toContain("fn is_wide_char(");
    expect(source).not.toContain("fn CharBuffer::write_styled_char(");
  });

  it("splits browser tui buffer cell types out of buffer storage", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer.mbt"), "utf8");
    const cellSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer_cell.mbt"), "utf8");

    expect(cellSource).toContain("pub(all) struct CharCell");
    expect(cellSource).toContain("pub fn CharCell::default(");
    expect(cellSource).toContain("pub(all) struct TextStyle");
    expect(cellSource).toContain("pub fn TextStyle::default(");
    expect(source).not.toContain("pub(all) struct CharCell");
    expect(source).not.toContain("pub(all) struct TextStyle");
  });

  it("splits browser tui buffer text writing out of buffer storage", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer.mbt"), "utf8");
    const textSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer_text.mbt"), "utf8");

    expect(textSource).toContain("pub fn char_display_width(");
    expect(textSource).toContain("fn CharBuffer::apply_text_write_plan(");
    expect(textSource).toContain("pub fn CharBuffer::write_text(");
    expect(textSource).toContain("pub fn CharBuffer::write_text_pre(");
    expect(textSource).toContain("pub fn CharBuffer::write_text_wrapped(");
    expect(source).not.toContain("pub fn char_display_width(");
    expect(source).not.toContain("fn CharBuffer::apply_text_write_plan(");
    expect(source).not.toContain("pub fn CharBuffer::write_text(");
  });

  it("delegates reusable browser tui widget plans to tui terminal buffer", () => {
    const pkg = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/moon.pkg"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/widget.mbt"), "utf8");
    const scrollbarSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/scrollbar_widget.mbt"), "utf8");

    expect(pkg).toContain('"mizchi/tui-terminal-buffer/buffer" @tui_buffer');
    expect(source).toContain("@tui_buffer.BoxChars::single()");
    expect(source).toContain("@tui_buffer.plan_box(x, y, w, h, box_chars(style))");
    expect(source).toContain("@tui_buffer.plan_hline(x, y, w, chars.horizontal)");
    expect(source).toContain("@tui_buffer.plan_vline(x, y, h, chars.vertical)");
    expect(scrollbarSource).toContain("@tui_buffer.plan_scrollbar(");
    expect(source).not.toContain("for col = x + 1; col < x + w - 1");
    expect(source).not.toContain("let thumb_height =");
  });
});
