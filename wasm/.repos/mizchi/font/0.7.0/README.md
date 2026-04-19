# mizchi/font

TrueType/OTF(CFF)/WOFF/WOFF2 font parser written in [MoonBit](https://www.moonbitlang.com/).

Parses font binary data and converts glyph outlines to `@svg.PathCommand` (from [mizchi/svg](https://github.com/mizchi/svg)).

## Usage

```moonbit
let data : Bytes = ... // TTF, OTF, WOFF, WOFF2, or TTC file bytes
let font = @font.parse_font(data).unwrap()

// Get glyph outline as SVG path commands
let cmds = font.scaled_outline('A'.to_int(), 48.0)

// Get glyph metrics
let gid = font.glyph_index('A'.to_int())
let metrics = font.glyph_metrics(gid)

// Text layout with kerning
let positions = font.layout_text("Hello", 48.0)
let width = font.measure_text("Hello", 48.0)

// Variable font with axis values
let cmds = font.char_outline_at('A'.to_int(), { "wght": 700.0 })

// Vertical text layout
let vpositions = font.layout_text_vertical("縦書き", 48.0)
let vheight = font.measure_text_vertical("縦書き", 48.0)

// Font subsetting (glyf-based TrueType only)
let subset = @font.subset_font(data, [0x41, 0x42, 0x43]) // A, B, C
```

## Supported Specifications

This library covers the core OpenType tables needed for **glyph rendering, metrics, variable fonts, and text layout** (horizontal and vertical). Latin, CJK, and other scripts that don't require complex shaping work well out of the box.

### Font Formats

| Format | | Notes |
|--------|:-:|-------|
| TTF (TrueType) | ✅ | sfnt flavor `0x00010000` and `0x74727565` |
| OTF (OpenType/CFF) | ✅ | sfnt flavor `OTTO` |
| WOFF1 | ✅ | zlib decompression |
| WOFF2 | ✅ | Brotli decompression with glyf/loca/hmtx transforms |
| TTC/OTC (Font Collections) | ✅ | Index-based or first-font access |

### OpenType Tables

#### ✅ Parsed

| Table | Description |
|-------|-------------|
| `head` | units_per_em, indexToLocFormat |
| `maxp` | numGlyphs |
| `hhea` | ascent, descent, lineGap, numOfLongHorMetrics |
| `hmtx` | advanceWidth, leftSideBearing per glyph |
| `cmap` | Format 0, 4 (BMP), 6, and 12 (full Unicode) |
| `loca` | Short and long formats |
| `glyf` | Simple and compound glyphs |
| `CFF ` | Type 2 charstrings with subroutines |
| `CFF2` | Variable font support with blend/vsindex |
| `fvar` | Axis definitions (wght, wdth, opsz, etc.) |
| `avar` | Piecewise linear axis value mapping |
| `gvar` | TrueType delta interpolation with IUP |
| `kern` | Format 0 horizontal pairs |
| `name` | Windows Unicode, Unicode platform, Mac Roman |
| `OS/2` | Weight/width class, PANOSE, x-height, cap-height |
| `post` | Italic angle, fixed pitch, glyph names (v2.0) |
| `vhea`/`vmtx` | Vertical metrics — advance heights and top side bearings |
| `gasp` | Grid-fitting and scan-conversion ranges |
| `VORG` | Vertical origin Y coordinates for CFF glyphs |

#### ❌ Not Parsed

The tables below are **not** parsed. Most of them are only needed for advanced use cases.

**🔤 Complex Text Shaping** — Required for scripts with context-dependent glyph forms: Arabic, Hebrew, Devanagari, Thai, etc. Also needed for OpenType features like ligatures (`fi` → `fi`), stylistic alternates, and advanced kerning. Latin and CJK text renders correctly without these.

| Table | Description |
|-------|-------------|
| `GSUB` | Glyph substitution — ligatures, contextual alternates, localized forms |
| `GPOS` | Glyph positioning — pair adjustment, mark-to-base, mark-to-mark |
| `GDEF` | Glyph definition — glyph classes, ligature caret positions, mark sets |
| `BASE` | Baseline offsets for mixing scripts (e.g. Latin + CJK in one line) |
| `JSTF` | Justification alternatives for full-justified text |

**🎨 Color & Emoji** — Required for rendering color emoji and multi-color glyphs. Not needed for monochrome text rendering.

| Table | Description |
|-------|-------------|
| `COLR`/`CPAL` | Color layers with palettes (COLRv0/v1 color fonts) |
| `SVG ` | SVG glyph documents (SVG-in-OpenType color fonts) |
| `CBDT`/`CBLC` | Color bitmap glyphs (Google/Android emoji) |
| `sbix` | Apple bitmap glyphs (Apple emoji) |
| `EBDT`/`EBLC` | Monochrome/grayscale embedded bitmaps (legacy low-res screens) |

**📐 Specialized Rendering** — Needed only for specific rendering scenarios.

| Table | Description |
|-------|-------------|
| `MATH` | Math layout constants and glyph assembly — only for TeX-like math typesetting engines |
| `cvt`/`fpgm`/`prep` | TrueType hinting programs — grid-fitting instructions for low-DPI rasterization. Irrelevant for SVG/vector output |
| `hdmx` | Pre-computed device widths for specific PPEMs — legacy optimization for bitmap rendering |

**🍎 Apple AAT** — Apple-proprietary layout system. Most modern fonts use OpenType (GSUB/GPOS) instead. Only found in macOS system fonts and some legacy fonts.

| Table | Description |
|-------|-------------|
| `morx`/`mort` | Apple Advanced Typography — state-machine-based shaping |

**🔒 Other** — Rarely needed for rendering or layout.

| Table | Description |
|-------|-------------|
| `DSIG` | Digital signature — font authenticity verification, does not affect rendering |
| `cvar` | CVT variations — hinting value adjustments in variable fonts, only relevant if hinting is executed |

### CFF / CFF2 Charstring Operators

All standard operators for outline extraction are supported:

| Category | | Operators |
|----------|:-:|-----------|
| Move | ✅ | `rmoveto`, `hmoveto`, `vmoveto` |
| Line | ✅ | `rlineto`, `hlineto`, `vlineto` |
| Curve | ✅ | `rrcurveto`, `hhcurveto`, `vvcurveto`, `hvcurveto`, `vhcurveto` |
| Mixed | ✅ | `rcurveline`, `rlinecurve` |
| Flex | ✅ | `flex`, `hflex`, `vflex`, `hflex1`, `flex1` |
| Hint | ✅ | `hstem`, `vstem`, `hstemhm`, `vstemhm`, `hintmask`, `cntrmask` |
| Subroutine | ✅ | `callsubr`, `callgsubr`, `return` |
| Arithmetic | ✅ | `add`, `sub`, `mul`, `div`, `neg`, `abs`, `sqrt`, `eq` |
| Logic | ✅ | `and`, `or`, `not`, `ifelse` |
| Stack | ✅ | `dup`, `exch`, `drop`, `index`, `roll`, `put`, `get` |
| CFF2 Variation | ✅ | `blend`, `vsindex` |
| Control | ✅ | `endchar` |
| Deprecated | ➖ | `seac`, `dotsection` — removed from modern specs |

### Glyph Outlines

| Feature | | Notes |
|---------|:-:|-------|
| Simple glyphs (TrueType) | ✅ | |
| Compound glyphs (TrueType) | ✅ | Scale, 2x2 matrix, XY offset transforms |
| CFF1 charstrings | ✅ | Local/global subroutines |
| CFF2 charstrings | ✅ | Blend interpolation |
| TrueType variations (gvar) | ✅ | Shared tuples, IUP, delta unpacking |
| CFF2 variations (ItemVariationStore) | ✅ | Region scalars, blend deltas |
| Hinting / instruction execution | ❌ | Not needed for vector/SVG output |

### cmap Formats

Formats 0, 4, 6, and 12 cover virtually all modern fonts. The unsupported formats are legacy or niche:

| Format | | Coverage |
|--------|:-:|----------|
| Format 0 | ✅ | Mac Roman 256-char |
| Format 4 | ✅ | BMP (U+0000–U+FFFF) |
| Format 6 | ✅ | Trimmed table |
| Format 12 | ✅ | Full Unicode (preferred when available) |
| Format 2 | ❌ | CJK mixed 8/16-bit — obsolete encoding, replaced by Format 12 |
| Format 14 | ❌ | Unicode Variation Sequences — needed for CJK glyph variants (e.g. JP vs CN forms) |

### Kerning

The `kern` table Format 0 covers most Latin fonts. GPOS-based kerning requires the OpenType layout engine (GSUB/GPOS), which is a significantly larger scope:

| Feature | | Notes |
|---------|:-:|-------|
| `kern` table Format 0 (flat pairs) | ✅ | Covers most Latin fonts |
| `kern` table Format 1 (Apple state machine) | ❌ | Apple-only, rare in cross-platform fonts |
| `GPOS` pair adjustment (PairPos) | ❌ | More precise than `kern`, used by modern fonts |
| `GPOS` contextual kerning | ❌ | Context-dependent spacing adjustments |

### Font Subsetting

Subsetting extracts only the glyphs you need, reducing file size for web delivery:

| Feature | | Notes |
|---------|:-:|-------|
| Glyf-based TrueType subsetting | ✅ | |
| Compound glyph dependency resolution | ✅ | |
| Glyph ID remapping | ✅ | |
| cmap Format 12 rebuild | ✅ | |
| Table copy (head, hhea, hmtx, maxp, name, OS/2, post) | ✅ | |
| CFF/CFF2 subsetting | ❌ | CFF charstring rewriting is complex |
| WOFF/WOFF2 output | ❌ | Outputs raw sfnt — wrap with external compressor |
| Layout table subsetting (GSUB/GPOS) | ❌ | Requires lookup/coverage rewriting |

### Text Layout

Horizontal LTR text with kerning and vertical top-to-bottom text are fully supported. The unsupported features represent a full text shaping engine (like HarfBuzz), which is a separate domain:

| Feature | | Notes |
|---------|:-:|-------|
| Horizontal advance widths | ✅ | |
| Pair kerning (`kern` table) | ✅ | |
| UTF-16 surrogate pair handling | ✅ | |
| Text width measurement | ✅ | |
| OpenType shaping (GSUB/GPOS) | ❌ | Full shaping engine — needed for Arabic, Devanagari, ligatures |
| Bidirectional text | ❌ | Unicode BiDi algorithm — needed for mixed LTR/RTL text |
| Vertical layout | ✅ | Top-to-bottom CJK typesetting (vhea/vmtx/VORG) |
| Line breaking | ❌ | Text wrapping — typically handled by the application layer |

### JS Bindings (Wasm)

13 exported functions:

| Function | Returns | Description |
|----------|---------|-------------|
| `loadFont(data)` | JSON string | Parse font, return metrics |
| `getFontInfo()` | JSON string | Get cached font info |
| `glyphToSvgPath(codepoint, fontSize)` | SVG path string | Scaled glyph outline |
| `glyphAdvance(codepoint, fontSize)` | Double | Scaled advance width |
| `fontName(nameId)` | String | Name table lookup |
| `kernAdvance(cp1, cp2, fontSize)` | Double | Scaled kerning value |
| `layoutText(text, fontSize)` | JSON string | Glyph positions with kerning |
| `measureText(text, fontSize)` | Double | Total text width |
| `fontWeightClass()` | Int | OS/2 weight class |
| `isFixedPitch()` | Int (0/1) | Post table fixed-pitch flag |
| `codepointCoverage()` | JSON string | All supported codepoints |
| `glyphIds()` | JSON string | All glyph IDs (0 to numGlyphs-1) |
| `tableSizes()` | JSON string | Table tag to byte size |

## Development

```bash
# Download test fixtures and run tests
just test

# Or manually
bash scripts/download-fixtures.sh
moon test

# Type check
just check

# Format code
just fmt
```

NotoSans font files are not committed to the repository. They are downloaded from [GitHub Releases](https://github.com/mizchi/font/releases/tag/fixtures-v1) on first run.

## Dependencies

- [mizchi/svg](https://github.com/mizchi/svg) — `PathCommand` type for glyph outlines
- [mizchi/zlib](https://github.com/mizchi/zlib) — WOFF1 decompression
- [mizchi/brotli](https://github.com/mizchi/brotli) — WOFF2 decompression

## Test Fonts

`fixtures/NotoSansMono-Regular.ttf` is licensed under the [SIL Open Font License](https://scripts.sil.org/OFL).

## License

Apache-2.0
