#!/usr/bin/env python3
"""Generate a minimal CFF2 font with .notdef + 'A' glyphs."""

from fontTools.fontBuilder import FontBuilder
from fontTools.ttLib import TTFont
from fontTools.misc.psCharStrings import T2CharString

def main():
    fb = FontBuilder(1000, isTTF=False)
    fb.setupGlyphOrder([".notdef", "A"])
    fb.setupCharacterMap({0x41: "A"})

    fb.setupHorizontalMetrics({".notdef": (500, 0), "A": (600, 0)})
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupOS2()
    fb.setupPost()
    fb.setupNameTable({
        "familyName": "TestCFF2",
        "styleName": "Regular",
    })

    # Build CFF2 charstrings
    # .notdef: empty (CFF2: no endchar needed)
    notdef_cs = T2CharString()
    notdef_cs.program = []

    # 'A': triangle shape
    # In CFF2, no width value at start of charstring
    a_cs = T2CharString()
    a_cs.program = [
        0, 0, 'rmoveto',
        300, 700, 'rlineto',
        300, -700, 'rlineto',
        'endchar',
    ]

    charstrings = {
        ".notdef": notdef_cs,
        "A": a_cs,
    }

    fb.setupCFF2(charstrings)

    fb.font.save("fixtures/minimal-cff2.otf")
    print(f"Saved fixtures/minimal-cff2.otf")

    # Verify
    font = TTFont("fixtures/minimal-cff2.otf")
    print(f"Tables: {sorted(font.keys())}")
    print(f"Has CFF2: {'CFF2' in font}")
    print(f"Glyph order: {font.getGlyphOrder()}")

    with open("fixtures/minimal-cff2.otf", "rb") as f:
        data = f.read()
    print(f"Size: {len(data)} bytes")

    # Generate MoonBit FixedArray[Byte] literal
    hex_values = ", ".join(f"0x{b:02X}" for b in data)
    print(f"\nMoonBit embedding ({len(data)} bytes):")
    # Print in chunks of 14 per line
    chunks = [f"0x{b:02X}" for b in data]
    lines = []
    for i in range(0, len(chunks), 14):
        lines.append("  " + ", ".join(chunks[i:i+14]) + ",")
    print("let minimal_cff2_otf : FixedArray[Byte] = [")
    for line in lines:
        print(line)
    print("]")


if __name__ == "__main__":
    main()
