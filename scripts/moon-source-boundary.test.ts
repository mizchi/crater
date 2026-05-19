import fs from "fs";
import path from "path";
import { describe, expect, it } from "vitest";

function read(relativePath: string): string {
  return fs.readFileSync(path.join(process.cwd(), relativePath), "utf-8");
}

function lineCount(source: string): number {
  return source.split("\n").length;
}

describe("MoonBit source responsibility boundaries", () => {
  it("keeps QuickJS runtime glue separate from JS FFI and DOM op parsing", () => {
    const runtimeGlue = read("runtime/js_runtime_quickjs.mbt");
    const ffi = read("runtime/js_runtime_quickjs_ffi.mbt");
    const domOps = read("runtime/js_runtime_quickjs_dom_ops.mbt");

    expect(lineCount(runtimeGlue)).toBeLessThanOrEqual(900);
    expect(runtimeGlue).not.toContain("extern \"js\" fn quickjs_execute_with_mock_dom");
    expect(runtimeGlue).not.toContain("priv struct DomOp");
    expect(ffi).toContain("extern \"js\" fn quickjs_execute_with_mock_dom");
    expect(domOps).toContain("priv struct DomOp");
  });

  it("keeps large layout packages split by helper responsibility", () => {
    const flex = read("layout/flex/flex.mbt");
    const flexCache = read("layout/flex/flex_cache.mbt");
    const block = read("layout/block/block.mbt");
    const blockMargins = read("layout/block/block_margins.mbt");
    const grid = read("layout/grid/grid.mbt");
    const gridAlignment = read("layout/grid/grid_alignment.mbt");
    const table = read("layout/table/table.mbt");
    const tableBorders = read("layout/table/table_borders.mbt");

    expect(lineCount(flex)).toBeLessThanOrEqual(9200);
    expect(flex).not.toContain("global_intrinsic_cache");
    expect(flexCache).toContain("global_intrinsic_cache");
    expect(lineCount(block)).toBeLessThanOrEqual(7500);
    expect(block).not.toContain("fn collapsed_margin_zero");
    expect(blockMargins).toContain("priv struct CollapsedMargin");
    expect(lineCount(grid)).toBeLessThanOrEqual(6650);
    expect(grid).not.toContain("AlignmentContentBounds");
    expect(gridAlignment).toContain("AlignmentContentBounds");
    expect(lineCount(table)).toBeLessThanOrEqual(3850);
    expect(table).not.toContain("resolve_border_conflict");
    expect(tableBorders).toContain("resolve_border_conflict");
  });
});
