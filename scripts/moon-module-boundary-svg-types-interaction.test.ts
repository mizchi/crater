import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, readSvgInteropSources } from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade interaction boundaries", () => {
  it("delegates SVG pointer event state to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/event.mbt"), "utf8");
    const interopSource = readSvgInteropSources();

    expect(source.includes("@msvg.PointerEvent::new(")).toBe(true);
    expect(source.includes("pointer_event_from_msvg(")).toBe(true);
    expect(source.includes("pointer_event_to_msvg(self)")).toBe(true);
    expect(source.includes("event.stop_propagation()")).toBe(true);
    expect(interopSource.includes("fn pointer_event_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn pointer_event_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_pointer_event_state_from_msvg(")).toBe(true);
    expect(source.includes("self.propagation_stopped = true")).toBe(false);
  });

  it("keeps SVG event system in a dedicated module", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const eventSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/event.mbt"), "utf8");

    expect(eventSource.includes("pub(all) struct PointerEvent")).toBe(true);
    expect(eventSource.includes("pub(all) struct EventManager")).toBe(true);
    expect(eventSource.includes("pub fn EventManager::dispatch_click(")).toBe(true);
    expect(eventSource.includes("fn EventManager::dispatch_to_node(")).toBe(true);
    expect(typesSource.includes("pub(all) struct EventManager")).toBe(false);
    expect(typesSource.includes("fn EventManager::dispatch_to_node(")).toBe(false);
  });
});
