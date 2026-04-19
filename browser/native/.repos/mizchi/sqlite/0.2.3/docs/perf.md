# SQLite Performance Benchmarks

This document compares SQLite performance benchmarks between MoonBit and Deno (node:sqlite), including execution methods and results.

## How to Run Benchmarks

### Deno Benchmark

```bash
deno bench --allow-read --allow-write --allow-ffi sqlite_bench.ts
```

### MoonBit Benchmark

```bash
moon bench --target native
```

Note: MoonBit benchmarks are written in `sqlite_bench.mbt`.

## Benchmark Results

Test Environment:
- CPU: Apple M3
- Runtime: Deno 2.5.6 (aarch64-apple-darwin)
- MoonBit: 0.1.0 (native target)

### Comparison Table

| Benchmark | Deno (node:sqlite) | MoonBit | Performance Ratio |
|-----------|-------------------|---------|-------------------|
| **Database Open/Close** | 13.6 µs | 5.65 µs | **MoonBit 2.4x faster** ⚡ |
| **Create Table** | 38.1 µs | 26.54 µs | **MoonBit 1.4x faster** ⚡ |
| **Insert Single Row** | 40.6 µs | 30.34 µs | **MoonBit 1.3x faster** ⚡ |
| **Insert 100 Rows** | 175.4 µs | 149.43 µs | **MoonBit 1.2x faster** ⚡ |
| **Insert with Transaction (100 rows)** | 103.3 µs | 127.25 µs | Deno 1.2x faster |
| **Select All Rows** | 223.5 µs | 156.87 µs | **MoonBit 1.4x faster** ⚡ |
| **Select with WHERE clause** | 212.0 µs | 159.77 µs | **MoonBit 1.3x faster** ⚡ |
| **Update Rows** | 186.0 µs | 162.33 µs | **MoonBit 1.1x faster** ⚡ |
| **Delete Rows** | 185.8 µs | 158.66 µs | **MoonBit 1.2x faster** ⚡ |
| **Prepared Statement Reuse** | 107.9 µs | 98.94 µs | **MoonBit 1.1x faster** ⚡ |

### Deno Detailed Results

```
| Benchmark Name                               | Avg Time/Iter   | Iterations/s  |
| -------------------------------------------- | --------------- | ------------- |
| Database Open/Close                          |        13.6 µs  |        73,520 |
| Create Table                                 |        38.1 µs  |        26,260 |
| Insert Single Row                            |        40.6 µs  |        24,610 |
| Insert 100 Rows                              |       175.4 µs  |         5,703 |
| Insert with Transaction (100 rows)           |       103.3 µs  |         9,678 |
| Select All Rows                              |       223.5 µs  |         4,474 |
| Select with WHERE clause                     |       212.0 µs  |         4,717 |
| Update Rows                                  |       186.0 µs  |         5,378 |
| Delete Rows                                  |       185.8 µs  |         5,382 |
| Prepared Statement Reuse                     |       107.9 µs  |         9,268 |
```

### MoonBit Detailed Results

```
[mizchi/sqlite] bench sqlite_bench.mbt:16 ("bench: Database Open/Close") ok
time (mean ± σ)         range (min … max)
   5.65 µs ±   0.04 µs     5.59 µs …   5.72 µs  in 10 ×  17794 runs

[mizchi/sqlite] bench sqlite_bench.mbt:25 ("bench: Create Table") ok
time (mean ± σ)         range (min … max)
  26.54 µs ±   0.95 µs    25.77 µs …  28.86 µs  in 10 ×   3896 runs

[mizchi/sqlite] bench sqlite_bench.mbt:38 ("bench: Insert Single Row") ok
time (mean ± σ)         range (min … max)
  30.34 µs ±   0.13 µs    30.17 µs …  30.51 µs  in 10 ×   3322 runs

[mizchi/sqlite] bench sqlite_bench.mbt:54 ("bench: Insert 100 Rows") ok
time (mean ± σ)         range (min … max)
 149.43 µs ±   1.28 µs   147.30 µs … 150.57 µs  in 10 ×    666 runs

[mizchi/sqlite] bench sqlite_bench.mbt:73 ("bench: Insert with Transaction (100 rows)") ok
time (mean ± σ)         range (min … max)
 127.25 µs ±  14.25 µs   120.02 µs … 164.03 µs  in 10 ×    828 runs

[mizchi/sqlite] bench sqlite_bench.mbt:94 ("bench: Select All Rows") ok
time (mean ± σ)         range (min … max)
 156.87 µs ±   0.58 µs   155.89 µs … 157.96 µs  in 10 ×    631 runs

[mizchi/sqlite] bench sqlite_bench.mbt:122 ("bench: Select with WHERE clause") ok
time (mean ± σ)         range (min … max)
 159.77 µs ±   3.38 µs   157.43 µs … 166.32 µs  in 10 ×    633 runs

[mizchi/sqlite] bench sqlite_bench.mbt:151 ("bench: Update Rows") ok
time (mean ± σ)         range (min … max)
 162.33 µs ±   3.60 µs   159.66 µs … 171.34 µs  in 10 ×    623 runs

[mizchi/sqlite] bench sqlite_bench.mbt:179 ("bench: Delete Rows") ok
time (mean ± σ)         range (min … max)
 158.66 µs ±   0.86 µs   157.23 µs … 160.01 µs  in 10 ×    626 runs

[mizchi/sqlite] bench sqlite_bench.mbt:204 ("bench: Prepared Statement Reuse") ok
time (mean ± σ)         range (min … max)
  98.94 µs ±  11.78 µs    90.35 µs … 129.66 µs  in 10 ×   1113 runs
```

## Analysis

### Overall Evaluation

**MoonBit is faster than Deno in 9 out of 10 benchmarks.**

### MoonBit Strengths

1. **Database Connection Operations**: Most significant difference (2.4x faster)
   - Efficiency of low-level FFI through native compilation
   - Reduced memory management overhead

2. **SELECT Operations**: 1.3-1.4x performance improvement
   - Optimized data retrieval processing
   - Direct memory access via C FFI

3. **Basic CRUD Operations**: Generally 1.1-1.3x faster
   - Performance advantage as native binary

### Deno Advantages

**Insert with Transaction (100 rows)**: Deno is approximately 1.2x faster

Possible reasons:
- V8 engine JIT compilation optimization
- Internal transaction optimization in node:sqlite module
- Or potential room for improvement in MoonBit's transaction implementation

### Performance Characteristics Summary

| Characteristic | MoonBit | Deno |
|----------------|---------|------|
| **Architecture** | Native compilation (C FFI) | V8 JavaScript engine + node:sqlite |
| **Startup Speed** | Very fast | Somewhat slow (requires V8 initialization) |
| **Low-level Operations** | Excellent (direct C API calls) | Good (via FFI) |
| **Optimization** | AOT (Ahead-of-Time compilation) | JIT (Just-in-Time compilation) |
| **Memory Management** | Efficient | GC overhead exists |

## Conclusion

**MoonBit's SQLite bindings demonstrate superior performance in general database operations.**

- Ideal for small to medium-scale transaction processing
- Recommended for applications requiring low latency
- Maximizes the benefits of native compilation

However, for large-scale transaction processing, Deno may have a slight advantage, so choosing based on workload is important.
