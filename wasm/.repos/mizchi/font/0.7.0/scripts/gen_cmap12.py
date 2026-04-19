#!/usr/bin/env python3
"""Generate a minimal TrueType font with cmap Format 12 for testing.

Contains:
- .notdef (empty)
- 'A' (U+0041) - BMP character
- Emoji grinning face (U+1F600) - non-BMP character
"""
import os

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib.tables._g_l_y_f import Glyph as TTGlyph


def draw_triangle(pen, peak_y):
    pen.moveTo((0, 0))
    pen.lineTo((300, peak_y))
    pen.lineTo((600, 0))
    pen.closePath()
    return pen.glyph()


def draw_square(pen, size):
    pen.moveTo((0, 0))
    pen.lineTo((0, size))
    pen.lineTo((size, size))
    pen.lineTo((size, 0))
    pen.closePath()
    return pen.glyph()


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "..", "fixtures", "minimal-cmap12.ttf")
    output_path = os.path.normpath(output_path)

    upm = 1000
    fb = FontBuilder(upm, isTTF=True)
    fb.setupGlyphOrder([".notdef", "A", "emoji"])

    # Use Format 12 by including a non-BMP character
    fb.setupCharacterMap({0x41: "A", 0x1F600: "emoji"})

    pen_a = TTGlyphPen(None)
    pen_e = TTGlyphPen(None)

    fb.setupGlyf({
        ".notdef": TTGlyph(),
        "A": draw_triangle(pen_a, 700),
        "emoji": draw_square(pen_e, 500),
    })
    fb.setupHorizontalMetrics({".notdef": (500, 0), "A": (600, 0), "emoji": (500, 0)})
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({"familyName": "TestCmap12", "styleName": "Regular"})
    fb.setupOS2()
    fb.setupPost()
    fb.setupHead(unitsPerEm=upm)

    fb.font.save(output_path)

    # Verify
    from fontTools.ttLib import TTFont
    verify = TTFont(output_path)
    cmap = verify.getBestCmap()
    print(f"cmap entries: {cmap}")
    print(f"Has format 12: {any(t.format == 12 for t in verify['cmap'].tables)}")
    file_size = os.path.getsize(output_path)
    print(f"Output: {output_path} ({file_size} bytes)")


if __name__ == "__main__":
    main()
