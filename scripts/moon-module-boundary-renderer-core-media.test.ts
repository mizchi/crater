import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core media boundaries", () => {
  it("keeps renderer replaced-element helpers out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/replaced_element.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn is_replaced_element",
      "fn create_image_measure",
      "fn broken_img_alt_uses_non_replaced_overflow_box",
      "fn create_input_measure",
      "fn is_text_like_input_type",
      "fn resolve_input_paint_text",
      "fn input_uses_placeholder_text",
      "fn should_preserve_auto_replaced_width",
      "fn should_preserve_auto_replaced_height",
      "fn should_apply_intrinsic_replaced_aspect_ratio",
      "fn create_br_measure",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer special element node finalization out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/special_element_node.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      'tag_lower == "input" && children.is_empty()',
      'tag_lower == "button" &&',
      'tag_lower == "textarea"',
      'tag_lower == "select"',
      'tag_lower == "svg" && children.is_empty()',
      'tag_lower == "img" && children.is_empty()',
      'tag_lower == "canvas" && children.is_empty()',
      'tag_lower == "iframe" || tag_lower == "object" || tag_lower == "embed"',
      'tag_lower == "video" || tag_lower == "audio"',
      'tag_lower == "br"',
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer intrinsic-media parsers out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/intrinsic_media.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn parse_html_dimension",
      "fn url_decode",
      "fn find_string_index",
      "fn extract_svg_attribute",
      "fn parse_viewbox",
      "fn parse_svg_data_uri",
      "fn base64_char_value",
      "fn decode_base64_prefix",
      "fn parse_gif_data_uri",
      "fn parse_png_data_uri",
      "fn get_image_intrinsic_size_default",
      "fn get_image_intrinsic_size",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
