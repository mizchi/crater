#!/usr/bin/env python3
"""Generate a minimal glyf+gvar variable font for testing.

Same spec as gen_cff2_var.py but using TrueType outlines (glyf+gvar):
- fvar: wght axis (min=100, default=400, max=900)
- .notdef (empty) + 'A' (triangle) glyphs
- Default (wght=400): A triangle (0,0)->(300,700)->(600,0)
- Bold (wght=900): A triangle (0,0)->(300,800)->(600,0) — Y peak +100
"""
import os
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
    """Draw triangle glyph: (0,0)->(300,peak_y)->(600,0)"""
    pen = TTGlyphPen(None)
    pen.moveTo((0, 0))
    pen.lineTo((300, peak_y))
    pen.lineTo((600, 0))
    pen.closePath()
    return pen.glyph()


def build_master(family_name, style_name, upm, ascent, descent, char_map, peak_y):
    """Build a single TrueType master font."""
    fb = FontBuilder(upm, isTTF=True)
    fb.setupGlyphOrder([".notdef", "A"])
    fb.setupCharacterMap(char_map)
    fb.setupGlyf({".notdef": TTGlyph(), "A": draw_triangle(peak_y)})
    fb.setupHorizontalMetrics({".notdef": (500, 0), "A": (600, 0)})
    fb.setupHorizontalHeader(ascent=ascent, descent=descent)
    fb.setupNameTable({
        "familyName": family_name,
        "styleName": style_name,
    })
    fb.setupOS2()
    fb.setupPost()
    fb.setupHead(unitsPerEm=upm)
    return fb.font


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "..", "fixtures", "minimal-gvar.ttf")
    output_path = os.path.normpath(output_path)

    upm = 1000
    ascent = 800
    descent = -200
    char_map = {0x41: "A"}

    default_font = build_master(
        "TestGvar", "Regular", upm, ascent, descent, char_map, 700
    )
    bold_font = build_master(
        "TestGvar", "Bold", upm, ascent, descent, char_map, 800
    )

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

    vf.save(output_path)

    # Verify
    verify = TTFont(output_path)
    tables = sorted(verify.keys())
    print(f"Tables: {tables}")
    print(f"Has fvar: {'fvar' in verify}")
    print(f"Has gvar: {'gvar' in verify}")
    print(f"Has glyf: {'glyf' in verify}")

    if "fvar" in verify:
        for ax in verify["fvar"].axes:
            print(
                f"  Axis: {ax.axisTag} min={ax.minValue} "
                f"default={ax.defaultValue} max={ax.maxValue}"
            )

    if "gvar" in verify:
        gvar = verify["gvar"]
        for name in [".notdef", "A"]:
            if name in gvar.variations:
                vars_data = gvar.variations[name]
                print(f"  gvar '{name}': {len(vars_data)} variation(s)")
                for v in vars_data:
                    print(f"    axes={v.axes} coords={v.coordinates}")
            else:
                print(f"  gvar '{name}': no variations")

    file_size = os.path.getsize(output_path)
    print(f"Output: {output_path} ({file_size} bytes)")


if __name__ == "__main__":
    main()
