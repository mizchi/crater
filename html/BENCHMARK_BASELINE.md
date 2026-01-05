# HTML Parser Benchmark Baseline

Date: 2026-01-05
MoonBit Version: Latest
Platform: Darwin (macOS)

## Summary

| Category | Benchmark | Time |
|----------|-----------|------|
| Simple Parse | 100 elements | 28.63 µs |
| Simple Parse | 1000 elements | 289.96 µs |
| Nested | 100 deep | 70.18 µs |
| Attributes | 200 elements | 390.87 µs |
| Large Doc | 50x10 sections | 4.75 ms |
| Tokenize | 100 elements | 11.90 µs |

## Detailed Results

### Basic Parse Performance

```
parse_simple_10       3.05 µs ±   0.04 µs
parse_simple_100     28.63 µs ±   1.89 µs
parse_simple_500    144.65 µs ±   4.81 µs
parse_simple_1000   289.96 µs ±   1.37 µs
```

### Nested Structure

```
parse_nested_10       5.79 µs ±   0.03 µs
parse_nested_50      30.56 µs ±   2.28 µs
parse_nested_100     70.18 µs ±  12.16 µs
```

### Attribute-Heavy (6 attributes per element)

```
parse_attrs_50      100.38 µs ±  11.31 µs
parse_attrs_200     390.87 µs ±  11.05 µs
parse_attrs_500       1.13 ms ± 182.12 µs
```

### Table Parsing

```
parse_table_10x5     28.77 µs ±   0.85 µs
parse_table_50x10   237.03 µs ±   6.68 µs
parse_table_100x20    1.11 ms ± 106.68 µs
```

### Page Layout

```
parse_page_small     49.49 µs ±   8.10 µs
parse_page_medium   117.86 µs ±   6.14 µs
parse_page_large    254.41 µs ±  40.56 µs
```

### Styled HTML (inline CSS)

```
parse_styled_50     136.96 µs ±  11.51 µs
parse_styled_200    569.35 µs ±  64.39 µs
```

### Resource Extraction (style/script tags)

```
parse_resources_10   40.90 µs ±   1.07 µs
parse_resources_50  219.52 µs ±  38.33 µs
```

### Form Parsing

```
parse_form_10        25.92 µs ±   0.75 µs
parse_form_50       123.55 µs ±   3.13 µs
```

### Error Recovery (malformed HTML)

```
parse_malformed_50   20.70 µs ±   3.04 µs
parse_malformed_200  87.94 µs ±  18.41 µs
```

### Fragment Parsing

```
parse_frag_simple     1.89 µs ±   0.03 µs
parse_frag_list      14.26 µs ±   0.29 µs
```

### Card Grid (realistic UI)

```
parse_card_12        53.71 µs ±   1.27 µs
parse_card_48       206.67 µs ±   4.57 µs
parse_card_100      417.58 µs ±   1.78 µs
```

### Tokenizer Only

```
tokenize_100         11.90 µs ±   0.30 µs
tokenize_attrs_100  131.53 µs ±   1.96 µs
tokenize_styled_100 166.92 µs ±   3.92 µs
```

### Large Documents

```
parse_large_10x5    459.00 µs ±   2.31 µs
parse_large_50x10     4.75 ms ±  31.49 µs
parse_large_100x20   18.94 ms ± 251.06 µs
```

### TreeBuilder Direct

```
treebuilder_100      46.86 µs ±   0.74 µs
treebuilder_nested_50  63.40 µs ±   7.50 µs
treebuilder_malformed 100.07 µs ±  13.99 µs
```

## Analysis

### Performance Characteristics

1. **Linear Scaling**: Simple parse scales linearly with element count
   - 10 → 100 elements: ~9.4x time (expected 10x)
   - 100 → 1000 elements: ~10.1x time

2. **Attribute Parsing Bottleneck**:
   - 6 attributes per element adds significant overhead
   - tokenize_attrs_100 (131µs) vs tokenize_100 (12µs) = 11x slower

3. **TreeBuilder Overhead**:
   - Tokenize 100: 11.90 µs
   - Full parse 100: 28.63 µs
   - TreeBuilder adds ~140% overhead

4. **Inline Styles Cost**:
   - tokenize_styled_100: 166.92 µs (most expensive tokenization)

### Optimization Targets

1. **High Priority**: Attribute parsing
   - Current: ~2µs per element with 6 attributes
   - Target: <1µs per element

2. **Medium Priority**: TreeBuilder efficiency
   - Current: 140% overhead over tokenization
   - Target: <50% overhead

3. **Low Priority**: Large document handling
   - Current: 19ms for 100x20 document
   - Acceptable for most use cases

## Running Benchmarks

```bash
moon bench -p html
```
