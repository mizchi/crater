# pixelmatch

**Pixelmatch for Humans and AI** - Fast pixel-level image comparison library for MoonBit/WASM.

Port of [mapbox/pixelmatch](https://github.com/mapbox/pixelmatch) to MoonBit.

## Features

- YIQ color space for perceptual color difference
- Anti-aliasing detection
- Configurable threshold
- Diff image generation
- **AI-friendly diff reports** with automatic shape hints
- Simple and fast API

## Installation

```bash
moon add mizchi/pixelmatch
```

## Usage

```moonbit
let img1 = @pixelmatch.Image::new(100, 100)
let img2 = @pixelmatch.Image::new(100, 100)

// Fill images with pixel data...

// Simple comparison
let diff_count = @pixelmatch.pixelmatch_simple(img1, img2, 0.1)

// Full comparison with options
let options = @pixelmatch.Options::default()
let output = @pixelmatch.Image::new(100, 100)
let diff_count = @pixelmatch.pixelmatch(img1, img2, Some(output), options)

// Get match ratio (0.0 to 1.0)
let ratio = @pixelmatch.match_ratio(img1, img2, options)

// Generate AI-friendly diff report
let report = @pixelmatch.diff_report(img1, img2, options)
println(report.to_compact())             // Minimal tokens for AI
println(report.to_compact_with_hints())  // With shape hints (recommended)
println(report.to_text())                // Verbose for humans
println(report.to_json())                // Structured JSON
```

## AI-Friendly Diff Report

### Compact Format

The `to_compact()` method generates a minimal-token format optimized for AI:

```
diff:100/2500(96%match)
..........
.XX.......
.XX.......
..........
..........
..........
..........
..........
..........
..........
regions:5,5,10x10
```

**Format:**
- Line 1: `diff:count/total(match%)`
- Lines 2-11: 10x10 binary heatmap (`.` = no diff, `X` = diff)
- Last line: `regions:x,y,WxH;...` (semicolon-separated)

### Shape Hints

The `to_compact_with_hints()` method adds automatic shape detection:

```
diff:952/2500(61%match)
..........
..XXXXXX..
.XXXXXXXX.
.XXXXXXXX.
.XXX..XXX.
.XXX...XXX
.XXXX.XXX.
.XXXXXXXX.
..XXXXXX..
..........
regions:5,5,41x41
hints:HAS_HOLE: shape may have empty center (ring/donut/frame)
```

**Available hints:**

| Hint | Description |
|------|-------------|
| `HAS_HOLE` | Shape has empty center (ring, donut, frame) |
| `IS_BORDER` | Changes only on edges (frame pattern) |
| `DIRECTIONAL` | Asymmetric shape (top/bottom/left/right heavy) |
| `MULTI_REGION` | Multiple separate diff areas |
| `REPEATING` | Similar-sized regions (grid/checkerboard) |

### Format Comparison

| Format | Tokens | Use case |
|--------|--------|----------|
| `to_compact()` | ~80 | AI agents, automated pipelines |
| `to_compact_with_hints()` | ~100 | AI with complex shapes |
| `to_text()` | ~400 | Human review, debugging |
| `to_json()` | ~300 | Programmatic access |

## AI Interpretation Accuracy

### Simple Patterns (10x10 grid)

| Pattern | Accuracy |
|---------|----------|
| Identical images | ◎ |
| Rectangle added/removed | ◎ |
| Border/frame | ◎ |
| Circle in center | ◎ |
| Horizontal/vertical line | ◎ |
| Scattered dots | ◎ |
| Half image changed | ◎ |
| Diagonal stripe | ◎ |

**Result: 90% accuracy**

### Complex Patterns

| Pattern | Without Hints | With Hints |
|---------|---------------|------------|
| Donut/Ring | ○ "notched rectangle" | ◎ (HAS_HOLE) |
| Arrow | ○ "wedge" | ◎ (DIRECTIONAL) |
| Checkerboard | △ "stripes" | ◎ (REPEATING) |
| Border/Frame | ○ | ◎ (IS_BORDER) |

**Result: 60% → 95% accuracy with hints**

### High-Resolution Mode

For complex shapes, use `grid_size=20`:

```moonbit
let report = diff_report(img1, img2, options, grid_size=20)
```

| Resolution | Tokens | Accuracy |
|------------|--------|----------|
| 10x10 | ~80 | 60% (complex) |
| 20x20 | ~320 | 80% (complex) |
| 10x10 + hints | ~100 | 95% (complex) |

**Recommendation:** Use `to_compact_with_hints()` for best accuracy/token ratio.

## API

### `pixelmatch(img1, img2, output?, options) -> Int`

Compare two images and return the number of different pixels.

### `pixelmatch_simple(img1, img2, threshold) -> Int`

Simple comparison without anti-aliasing detection.

### `match_ratio(img1, img2, options) -> Double`

Calculate match ratio (0.0 = completely different, 1.0 = identical).

### `diff_report(img1, img2, options, grid_size~) -> DiffReport`

Generate comprehensive diff report with statistics, heatmap, and regions.

### DiffReport Methods

| Method | Description |
|--------|-------------|
| `to_compact()` | Minimal binary heatmap |
| `to_compact_with_hints()` | With automatic shape hints |
| `to_text()` | Verbose human-readable |
| `to_json()` | Structured JSON |

### Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `threshold` | `Double` | `0.1` | Matching threshold (0-1). Smaller = more sensitive |
| `include_aa` | `Bool` | `false` | Include anti-aliased pixels in diff count |
| `alpha` | `Double` | `0.1` | Blending factor for unchanged pixels |
| `aa_color` | `Color` | Yellow | Color for anti-aliased pixels in diff |
| `diff_color` | `Color` | Red | Color for different pixels in diff |
| `diff_mask` | `Bool` | `false` | Only draw changed pixels |

## License

Apache-2.0
