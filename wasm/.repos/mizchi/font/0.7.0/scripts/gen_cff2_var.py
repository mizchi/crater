#!/usr/bin/env python3
"""Generate a minimal CFF2 variable font for testing.

Produces a font with:
- fvar: wght axis (min=100, default=400, max=900)
- .notdef (empty) + 'A' (triangle) glyphs
- Default (wght=400): A triangle (0,0)->(300,700)->(600,0)
- Bold (wght=900): A triangle (0,0)->(300,800)->(600,0) — Y peak +100
- CFF2 outlines with ItemVariationStore for blend deltas
"""
import os
import tempfile

from fontTools.designspaceLib import (
    AxisDescriptor,
    DesignSpaceDocument,
    SourceDescriptor,
)
from fontTools.fontBuilder import FontBuilder
from fontTools.misc.psCharStrings import T2CharString
from fontTools.ttLib import TTFont
from fontTools.varLib import build as varLib_build


def make_charstring(program):
    """Create a T2CharString from a program list."""
    cs = T2CharString()
    cs.program = program
    return cs


def build_master(family_name, style_name, upm, ascent, descent, char_map, outlines):
    """Build a single CFF OTF master font."""
    fb = FontBuilder(upm, isTTF=False)
    fb.setupGlyphOrder([".notdef", "A"])
    fb.setupCharacterMap(char_map)
    fb.setupHorizontalMetrics({".notdef": (500, 0), "A": (600, 0)})
    fb.setupHorizontalHeader(ascent=ascent, descent=descent)
    fb.setupNameTable({
        "familyName": family_name,
        "styleName": style_name,
    })
    fb.setupOS2()
    fb.setupPost()
    fb.setupHead(unitsPerEm=upm)
    fb.setupCFF(
        psName=f"{family_name}-{style_name}",
        fontInfo={"FullName": f"{family_name} {style_name}"},
        charStringsDict=outlines,
        privateDict={},
    )
    return fb.font


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "..", "fixtures", "minimal-cff2-var.otf")
    output_path = os.path.normpath(output_path)

    upm = 1000
    ascent = 800
    descent = -200
    char_map = {0x41: "A"}

    # Default master (wght=400): triangle peak at y=700
    # CFF charstring: moveto, lineto x3 (close back to origin), endchar
    default_outlines = {
        ".notdef": make_charstring(["endchar"]),
        "A": make_charstring([
            0, 0, "rmoveto",
            300, 700, "rlineto",
            300, -700, "rlineto",
            -600, 0, "rlineto",
            "endchar",
        ]),
    }

    # Bold master (wght=900): triangle peak at y=800 (delta +100)
    bold_outlines = {
        ".notdef": make_charstring(["endchar"]),
        "A": make_charstring([
            0, 0, "rmoveto",
            300, 800, "rlineto",
            300, -800, "rlineto",
            -600, 0, "rlineto",
            "endchar",
        ]),
    }

    default_font = build_master(
        "TestCFF2Var", "Regular", upm, ascent, descent, char_map, default_outlines
    )
    bold_font = build_master(
        "TestCFF2Var", "Bold", upm, ascent, descent, char_map, bold_outlines
    )

    # Set up design space
    ds = DesignSpaceDocument()

    axis = AxisDescriptor()
    axis.name = "Weight"
    axis.tag = "wght"
    axis.minimum = 100
    axis.default = 400
    axis.maximum = 900
    ds.addAxis(axis)

    with tempfile.TemporaryDirectory() as tmpdir:
        default_path = os.path.join(tmpdir, "default.otf")
        bold_path = os.path.join(tmpdir, "bold.otf")
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

        # varLib.build merges CFF masters and converts to CFF2 automatically
        vf, _, _ = varLib_build(ds)

    vf.save(output_path)

    # Verify the result
    verify = TTFont(output_path)
    tables = sorted(verify.keys())
    print(f"Tables: {tables}")
    print(f"Has fvar: {'fvar' in verify}")
    print(f"Has CFF2: {'CFF2' in verify}")
    print(f"Has CFF : {'CFF ' in verify}")

    if "fvar" in verify:
        for ax in verify["fvar"].axes:
            print(
                f"  Axis: {ax.axisTag} min={ax.minValue} "
                f"default={ax.defaultValue} max={ax.maxValue}"
            )

    # Dump CFF2 charstrings for verification
    if "CFF2" in verify:
        cff2 = verify["CFF2"]
        top_dict = cff2.cff.topDictIndex[0]
        charstrings = top_dict.CharStrings
        for name in [".notdef", "A"]:
            cs = charstrings[name]
            cs.decompile()
            print(f"  CFF2 '{name}' program: {cs.program}")

    file_size = os.path.getsize(output_path)
    print(f"Output: {output_path} ({file_size} bytes)")


if __name__ == "__main__":
    main()
