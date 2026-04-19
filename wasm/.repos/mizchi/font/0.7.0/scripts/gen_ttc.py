#!/usr/bin/env python3
"""Generate a minimal TTC (TrueType Collection) for testing.

Produces a TTC with 2 fonts:
- Font 0: 'A' = triangle (0,0)->(300,700)->(600,0), UPM=1000
- Font 1: 'A' = square (0,0)->(0,600)->(600,600)->(600,0), UPM=1000
Both use glyf outlines (TrueType).
"""
import os
import tempfile

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.ttCollection import TTCollection
from fontTools.ttLib.tables._g_l_y_f import Glyph as TTGlyph


def build_ttf_font(family_name, style_name, upm, ascent, descent, char_map, draw_fn):
    """Build a single TrueType font."""
    fb = FontBuilder(upm, isTTF=True)
    fb.setupGlyphOrder([".notdef", "A"])
    fb.setupCharacterMap(char_map)
    fb.setupGlyf({".notdef": TTGlyph(), "A": draw_fn()})
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


def draw_triangle():
    """Draw triangle glyph: (0,0)->(300,700)->(600,0)"""
    pen = TTGlyphPen(None)
    pen.moveTo((0, 0))
    pen.lineTo((300, 700))
    pen.lineTo((600, 0))
    pen.closePath()
    return pen.glyph()


def draw_square():
    """Draw square glyph: (0,0)->(0,600)->(600,600)->(600,0)"""
    pen = TTGlyphPen(None)
    pen.moveTo((0, 0))
    pen.lineTo((0, 600))
    pen.lineTo((600, 600))
    pen.lineTo((600, 0))
    pen.closePath()
    return pen.glyph()


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "..", "fixtures", "minimal.ttc")
    output_path = os.path.normpath(output_path)

    upm = 1000
    ascent = 800
    descent = -200
    char_map = {0x41: "A"}

    font0 = build_ttf_font("TestTTC0", "Regular", upm, ascent, descent, char_map, draw_triangle)
    font1 = build_ttf_font("TestTTC1", "Regular", upm, ascent, descent, char_map, draw_square)

    ttc = TTCollection()
    ttc.fonts = [font0, font1]
    ttc.save(output_path)

    file_size = os.path.getsize(output_path)
    print(f"Output: {output_path} ({file_size} bytes)")

    # Verify
    v0 = TTFont(output_path, fontNumber=0)
    glyf0 = v0["glyf"]
    coords0 = [(p[0], p[1]) for p in glyf0['A'].coordinates]
    print(f"Font 0 'A' points: {coords0}")

    v1 = TTFont(output_path, fontNumber=1)
    glyf1 = v1["glyf"]
    coords1 = [(p[0], p[1]) for p in glyf1['A'].coordinates]
    print(f"Font 1 'A' points: {coords1}")


if __name__ == "__main__":
    main()
