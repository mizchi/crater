#!/usr/bin/env python3
"""Generate a minimal TrueType font with a kern table for testing.

Contains:
- .notdef (empty)
- 'A' (glyph_id=1) and 'V' (glyph_id=2) with kerning pair A-V = -80
"""
import os
import struct

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import Glyph as TTGlyph


def draw_triangle(pen, peak_y):
    pen.moveTo((0, 0))
    pen.lineTo((300, peak_y))
    pen.lineTo((600, 0))
    pen.closePath()
    return pen.glyph()


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "..", "fixtures", "minimal-kern.ttf")
    output_path = os.path.normpath(output_path)

    upm = 1000
    fb = FontBuilder(upm, isTTF=True)
    fb.setupGlyphOrder([".notdef", "A", "V"])
    fb.setupCharacterMap({0x41: "A", 0x56: "V"})

    pen_a = TTGlyphPen(None)
    pen_v = TTGlyphPen(None)

    fb.setupGlyf({
        ".notdef": TTGlyph(),
        "A": draw_triangle(pen_a, 700),
        "V": draw_triangle(pen_v, 700),
    })
    fb.setupHorizontalMetrics({".notdef": (500, 0), "A": (600, 0), "V": (600, 0)})
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({"familyName": "TestKern", "styleName": "Regular"})
    fb.setupOS2()
    fb.setupPost()
    fb.setupHead(unitsPerEm=upm)

    font = fb.font

    # Manually build a kern table (format 0)
    # kern table: version(u16=0) + nTables(u16=1)
    # subtable: version(u16=0) + length(u16) + coverage(u16=0x0001, format 0 horizontal)
    # format 0: nPairs(u16=1) + searchRange(u16) + entrySelector(u16) + rangeShift(u16)
    # pair: left(u16) + right(u16) + value(i16)
    n_pairs = 1
    sub_length = 6 + 8 + n_pairs * 6  # header + format0 header + pairs
    kern_data = struct.pack(">HH", 0, 1)  # version, nTables
    kern_data += struct.pack(">HHH", 0, sub_length, 0x0001)  # subtable header
    kern_data += struct.pack(">HHHH", n_pairs, 6, 0, 0)  # format 0 header
    # A (glyph 1) - V (glyph 2) = -80
    kern_data += struct.pack(">HHh", 1, 2, -80)

    from fontTools.ttLib.tables.DefaultTable import DefaultTable
    kern_table = DefaultTable("kern")
    kern_table.data = kern_data
    font["kern"] = kern_table

    font.save(output_path)

    # Verify
    verify = TTFont(output_path)
    print(f"Has kern: {'kern' in verify}")
    print(f"kern table present")
    file_size = os.path.getsize(output_path)
    print(f"Output: {output_path} ({file_size} bytes)")


if __name__ == "__main__":
    main()
