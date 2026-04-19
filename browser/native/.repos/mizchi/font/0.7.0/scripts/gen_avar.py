#!/usr/bin/env python3
"""Generate a minimal glyf+gvar variable font WITH avar table for testing.

Same as gen_gvar.py but adds an avar table with non-linear wght mapping:
- Normalized -1.0 -> -1.0 (identity at min)
- Normalized  0.0 ->  0.0 (identity at default)
- Normalized  0.5 ->  0.75 (non-linear: half-way maps to 75%)
- Normalized  1.0 ->  1.0 (identity at max)
"""
import os
import struct
import tempfile

from fontTools.designspaceLib import (
    AxisDescriptor,
    DesignSpaceDocument,
    SourceDescriptor,
)
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import Glyph as TTGlyph
from fontTools.varLib import build as varLib_build


def draw_triangle(peak_y):
    pen = TTGlyphPen(None)
    pen.moveTo((0, 0))
    pen.lineTo((300, peak_y))
    pen.lineTo((600, 0))
    pen.closePath()
    return pen.glyph()


def build_master(family_name, style_name, upm, ascent, descent, char_map, peak_y):
    fb = FontBuilder(upm, isTTF=True)
    fb.setupGlyphOrder([".notdef", "A"])
    fb.setupCharacterMap(char_map)
    fb.setupGlyf({".notdef": TTGlyph(), "A": draw_triangle(peak_y)})
    fb.setupHorizontalMetrics({".notdef": (500, 0), "A": (600, 0)})
    fb.setupHorizontalHeader(ascent=ascent, descent=descent)
    fb.setupNameTable({"familyName": family_name, "styleName": style_name})
    fb.setupOS2()
    fb.setupPost()
    fb.setupHead(unitsPerEm=upm)
    return fb.font


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "..", "fixtures", "minimal-avar.ttf")
    output_path = os.path.normpath(output_path)

    upm = 1000
    ascent = 800
    descent = -200
    char_map = {0x41: "A"}

    default_font = build_master("TestAvar", "Regular", upm, ascent, descent, char_map, 700)
    bold_font = build_master("TestAvar", "Bold", upm, ascent, descent, char_map, 800)

    ds = DesignSpaceDocument()
    axis = AxisDescriptor()
    axis.name = "Weight"
    axis.tag = "wght"
    axis.minimum = 100
    axis.default = 400
    axis.maximum = 900
    ds.addAxis(axis)

    with tempfile.TemporaryDirectory() as tmpdir:
        default_path = os.path.join(tmpdir, "default.ttf")
        bold_path = os.path.join(tmpdir, "bold.ttf")
        default_font.save(default_path)
        bold_font.save(bold_path)

        src_default = SourceDescriptor()
        src_default.filename = default_path
        src_default.location = {"Weight": 400}
        src_default.font = default_font
        ds.addSource(src_default)

        src_bold = SourceDescriptor()
        src_bold.filename = bold_path
        src_bold.location = {"Weight": 900}
        src_bold.font = bold_font
        ds.addSource(src_bold)

        ds.findDefault()
        vf, _, _ = varLib_build(ds)

    # Build avar table manually with F2Dot14 values
    # avar: majorVersion(u16=1) + minorVersion(u16=0) + reserved(u16=0) + axisCount(u16=1)
    # per-axis: positionMapCount(u16=4)
    # pairs: fromCoord(F2Dot14) + toCoord(F2Dot14)
    def f2dot14(val):
        """Convert float to F2Dot14 (signed 2.14 fixed point)"""
        v = int(round(val * 16384))
        if v < 0:
            v += 65536
        return v & 0xFFFF

    avar_data = struct.pack(">HHHH", 1, 0, 0, 1)  # header
    avar_data += struct.pack(">H", 4)  # 4 pairs for axis 0
    pairs = [(-1.0, -1.0), (0.0, 0.0), (0.5, 0.75), (1.0, 1.0)]
    for from_c, to_c in pairs:
        avar_data += struct.pack(">HH", f2dot14(from_c), f2dot14(to_c))

    from fontTools.ttLib.tables.DefaultTable import DefaultTable
    avar_table = DefaultTable("avar")
    avar_table.data = avar_data
    vf["avar"] = avar_table

    vf.save(output_path)

    # Verify
    verify = TTFont(output_path)
    print(f"Has avar: {'avar' in verify}")
    print(f"Has fvar: {'fvar' in verify}")
    print(f"Has gvar: {'gvar' in verify}")
    if "fvar" in verify:
        for ax in verify["fvar"].axes:
            print(f"  Axis: {ax.axisTag} min={ax.minValue} default={ax.defaultValue} max={ax.maxValue}")
    file_size = os.path.getsize(output_path)
    print(f"Output: {output_path} ({file_size} bytes)")


if __name__ == "__main__":
    main()
