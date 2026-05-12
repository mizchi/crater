import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser shell input interaction boundaries", () => {
  it("keeps browser shell drag and drop helpers in their own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/drag_drop.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::is_draggable_source_id",
      "fn Browser::dispatch_drag_event_status_to_source_id",
      "fn Browser::dispatch_drag_event_to_source_id",
      "fn Browser::is_current_drop_allowed",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell form submit bridge in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/form_bridge.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn parse_navigation_request",
      "fn Browser::drain_pending_form_submission_navigation",
      "fn browser_form_submit_bridge_source",
      "fn browser_pending_form_submission_source",
      "fn browser_peek_pending_form_submission_source",
      "fn Browser::peek_pending_form_submission_navigation",
      "fn Browser::shift_pending_form_submission_navigation",
      "fn Browser::dispatch_submit_to_source_id",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell input bridge in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/input_bridge.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::dispatch_focused_key_to_source_id",
      "fn Browser::set_text_control_selection_from_cells",
      "fn Browser::set_text_control_caret_from_cell",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell DOM event bridge in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/dom_event_bridge.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::dispatch_focus_transition",
      "fn Browser::dispatch_activation_default_to_source_id",
      "fn Browser::dispatch_click_to_source_id",
      "fn Browser::dispatch_pointer_mouse_event_to_source_id",
      "fn Browser::dispatch_click_only_to_source_id",
      "fn Browser::dispatch_hover_transition",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell interaction controller in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/interaction_controller.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn cell_to_client_x",
      "fn Browser::get_client_coords_for_source_id",
      "fn Browser::get_hit_region_for_source_id",
      "fn Browser::handle_focused_key",
      "fn Browser::activate_focused_link",
      "fn Browser::hover_at",
      "fn Browser::pointer_down_at",
      "fn Browser::pointer_move_at",
      "fn Browser::pointer_up_at",
      "fn Browser::activate_at",
      "fn Browser::activate_link_at",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
