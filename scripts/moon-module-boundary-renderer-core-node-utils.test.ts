import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core node utility boundaries", () => {
  it("keeps renderer node id helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/node_id.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = ["fn node_id_is_tag", "fn make_node_id"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer details element pruning out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/details_element.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn clone_node_with_children",
      "fn find_first_summary_path_in_node",
      "fn find_first_summary_path_in_children",
      "fn prune_node_to_summary_path",
      "fn prune_closed_details_children",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer selector element conversion out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/selector_element.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn html_to_selector_element(",
      "fn html_to_selector_element_minimal",
      "fn html_to_selector_element_with_parent",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer shared string helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/string_utils.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = ["fn remove_suffix"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer element skip policy out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/skip_element.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = ["fn should_skip_element"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
