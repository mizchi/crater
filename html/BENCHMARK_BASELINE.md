# HTML Parser Benchmark Baseline

Date: 2026-01-05 (Updated)
MoonBit Version: Latest
Platform: Darwin (macOS)

## Summary (After Optimization)

| Category | Benchmark | Time | vs Original |
|----------|-----------|------|-------------|
| Simple Parse | 100 elements | 27-33 µs | baseline |
| Large Doc | 100x20 sections | 5.15 ms | **-73%** |
| Large Doc | 50x10 sections | 1.19 ms | **-75%** |
| Large Doc | 10x5 sections | 133 µs | **-71%** |
| Resources | 50 style/scripts | 80.6 µs | **-63%** |
| Page Layout | large | 150-210 µs | **-22%** |
| Tokenize (attrs) | 100 elements | 88.7 µs | **-33%** |
| TreeBuilder | 100 elements | 32.3 µs | **-31%** |

## Optimization History

### v1: Tokenizer Optimizations (2026-01-05)
- Added `peek_fast()` without Option wrapping
- Added `advance()` for position increment
- Use `substring` instead of `StringBuilder` for names/values
- Added `consume_name_lower()` to avoid double allocation

Results: 10-31% improvement in tokenization

### v2: TreeBuilder Text Buffering (2026-01-05)
- Added `pending_text` StringBuilder for character accumulation
- Flush text buffer before element insertion
- Eliminates O(n²) string concatenation

Results: 70-75% improvement in large documents

### v3: Additional Tokenizer Optimizations (2026-01-05)
- Optimized `matches_ci` with direct byte arithmetic
- Optimized `skip_comment` using substring
- Optimized `skip_doctype` using fast primitives

Results: Additional 5-10% improvement

## Detailed Results (Current)

### Basic Parse Performance

```
parse_simple_10       3.15 µs ±   0.15 µs
parse_simple_100     27-33 µs (variance)
parse_simple_500    145-165 µs
parse_simple_1000   305-355 µs
```

### Nested Structure

```
parse_nested_10       6.61 µs ±   0.20 µs
parse_nested_50      31.16 µs ±   0.42 µs
parse_nested_100     62.04 µs ±   2.79 µs
```

### Attribute-Heavy (6 attributes per element)

```
parse_attrs_50       90.47 µs ±   0.52 µs
parse_attrs_200     386.90 µs ±   9.93 µs
parse_attrs_500       1.01-1.44 ms
```

### Table Parsing

```
parse_table_10x5     27.54 µs ±   0.12 µs
parse_table_50x10   230.76 µs ±   0.88 µs
parse_table_100x20  991.91 µs ±  12.51 µs
```

### Page Layout

```
parse_page_small     30.88 µs ±   0.22 µs
parse_page_medium    79.79 µs ±   0.95 µs
parse_page_large    150-210 µs (variance)
```

### Resource Extraction (style/script tags)

```
parse_resources_10   18.54 µs ±   3.35 µs
parse_resources_50   80.60 µs ±   8.98 µs
```

### Fragment Parsing

```
parse_frag_simple     1.34 µs ±   0.31 µs
parse_frag_list      11.03 µs ±   0.11 µs
```

### Card Grid (realistic UI)

```
parse_card_12        49-58 µs
parse_card_48       198.17 µs ±   0.58 µs
parse_card_100      418.11 µs ±   1.25 µs
```

### Tokenizer Only

```
tokenize_100         10.51 µs ±   0.06 µs
tokenize_attrs_100   88.73 µs ±   1.02 µs
tokenize_styled_100 123.74 µs ±   0.93 µs
```

### Large Documents

```
parse_large_10x5    133.08 µs ±   8.24 µs
parse_large_50x10     1.19 ms ±   7.07 µs
parse_large_100x20    5.15 ms ±  49.68 µs
```

### TreeBuilder Direct

```
treebuilder_100      32.27 µs ±   0.13 µs
treebuilder_nested_50  53.38 µs ±   0.13 µs
treebuilder_malformed  61.54 µs ±   0.10 µs
```

## Key Optimizations Applied

1. **Text Buffering (Major Impact)**
   - Characters accumulated in StringBuilder instead of per-char string concat
   - O(n) instead of O(n²) for text content
   - 70-75% improvement for large documents

2. **Tokenizer Fast Paths**
   - `peek_fast()` returns Char directly, no Option wrapping
   - `advance()` increments position without return value
   - Direct byte comparison in `matches_ci`

3. **Substring over StringBuilder**
   - Use `input.substring(start, end)` instead of character-by-character building
   - Applies to: names, attribute values, comments

## Running Benchmarks

```bash
moon bench -p html
```

## Future Optimization Opportunities

1. **Intern common tag names** - Avoid string allocation for "div", "span", etc.
2. **Reuse StringBuilder** - Pool StringBuilders instead of creating new ones
3. **SIMD for whitespace skip** - Use vectorized search for large texts
4. **Lazy attribute parsing** - Parse attributes on-demand
