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

describe("MoonBit browser TUI adapter boundaries", () => {
  it("splits browser tui native UTF-8 codec out of the native adapter", () => {
    const nativeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native.mbt"), "utf8");
    const codecSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native_utf8.mbt"), "utf8");

    expect(codecSource).toContain("fn bytes_to_string(");
    expect(codecSource).toContain("fn encode_utf8(");
    expect(nativeSource).not.toContain("fn bytes_to_string(");
    expect(nativeSource).not.toContain("fn encode_utf8(");
  });

  it("splits browser tui native input parsing out of the native adapter", () => {
    const nativeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native.mbt"), "utf8");
    const inputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native_input.mbt"), "utf8");

    expect(inputSource).toContain("fn read_raw_key_from_prefix(");
    expect(inputSource).toContain("fn parse_mouse_event(");
    expect(inputSource).toContain("fn normalize_native_key(");
    expect(nativeSource).not.toContain("fn read_raw_key_from_prefix(");
    expect(nativeSource).not.toContain("fn parse_mouse_event(");
    expect(nativeSource).not.toContain("fn normalize_native_key(");
  });

  it("splits browser tui native FFI bindings out of the native adapter", () => {
    const nativeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native.mbt"), "utf8");
    const ffiSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native_ffi.mbt"), "utf8");
    const pkgSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/moon.pkg"), "utf8");

    expect(ffiSource).toContain('extern "C" fn tui_enable_raw_mode()');
    expect(ffiSource).toContain('extern "C" fn tui_read_byte()');
    expect(ffiSource).toContain('extern "C" fn tui_write_bytes_ffi(');
    expect(pkgSource).toContain('"tui_native_ffi.mbt": [ "native" ]');
    expect(nativeSource).not.toContain('extern "C" fn');
    expect(nativeSource).not.toContain("tui_write_bytes_ffi");
  });

  it("splits browser tui native terminal operations out of the native adapter", () => {
    const nativeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native.mbt"), "utf8");
    const terminalSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native_terminal.mbt"), "utf8");
    const inputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native_input.mbt"), "utf8");
    const pkgSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/moon.pkg"), "utf8");

    expect(terminalSource).toContain("pub fn print_raw(");
    expect(terminalSource).toContain("pub fn cleanup_stdin(");
    expect(terminalSource).toContain("pub fn get_terminal_size(");
    expect(terminalSource).toContain("pub fn enable_raw_mode(");
    expect(inputSource).toContain("pub fn read_key_with_timeout(");
    expect(inputSource).toContain("pub async fn read_line(");
    expect(pkgSource).toContain('"tui_native_terminal.mbt": [ "native" ]');
    expect(nativeSource).not.toContain("pub fn print_raw(");
    expect(nativeSource).not.toContain("pub fn read_key_with_timeout(");
    expect(nativeSource).not.toContain("pub async fn read_line(");
  });

  it("splits browser tui js input out of the js adapter", () => {
    const jsSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_js.mbt"), "utf8");
    const inputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_js_input.mbt"), "utf8");
    const pkgSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/moon.pkg"), "utf8");

    expect(inputSource).toContain('extern "js" fn js_read_key_with_timeout(');
    expect(inputSource).toContain('extern "js" fn js_read_line(');
    expect(inputSource).toContain("pub async fn read_key(");
    expect(inputSource).toContain("pub async fn wait_for_enter(");
    expect(pkgSource).toContain('"tui_js_input.mbt": [ "js" ]');
    expect(jsSource).not.toContain("js_read_key_with_timeout");
    expect(jsSource).not.toContain("pub async fn read_key(");
    expect(jsSource).not.toContain("pub async fn wait_for_enter(");
  });

  it("splits browser tui js terminal io out of the js adapter", () => {
    const jsSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_js.mbt"), "utf8");
    const terminalSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_js_terminal.mbt"), "utf8");
    const pkgSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/moon.pkg"), "utf8");

    expect(terminalSource).toContain('extern "js" fn js_print(');
    expect(terminalSource).toContain('extern "js" fn js_get_terminal_columns(');
    expect(terminalSource).toContain("pub fn print_raw(");
    expect(terminalSource).toContain("pub fn get_terminal_size(");
    expect(pkgSource).toContain('"tui_js_terminal.mbt": [ "js" ]');
    expect(jsSource).not.toContain("js_print");
    expect(jsSource).not.toContain("js_get_terminal_columns");
    expect(jsSource).not.toContain("pub fn print_raw(");
    expect(jsSource).not.toContain("pub fn get_terminal_size(");
  });

  it("splits browser tui mouse action parsing out of key mapping", () => {
    const tuiSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui.mbt"), "utf8");
    const mouseSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_mouse_action.mbt"), "utf8");

    expect(mouseSource).toContain("fn parse_mouse_action(");
    expect(mouseSource).toContain("enum MouseActionKind");
    expect(mouseSource).toContain("MouseScrollDownKind");
    expect(tuiSource).toContain("pub fn key_to_action(");
    expect(tuiSource).not.toContain("fn parse_mouse_action(");
    expect(tuiSource).not.toContain("enum MouseActionKind");
  });

  it("splits browser tui terminal control sequences out of action mapping", () => {
    const tuiSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui.mbt"), "utf8");
    const controlSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_terminal_control.mbt"), "utf8");

    expect(controlSource).toContain("pub fn clear_screen(");
    expect(controlSource).toContain("pub fn enter_alt_screen(");
    expect(controlSource).toContain("pub fn format_status_bar(");
    expect(tuiSource).not.toContain("pub fn clear_screen(");
    expect(tuiSource).not.toContain("pub fn format_status_bar(");
  });
});
