# Changelog

All notable changes to this project will be documented in this file.

## [0.3.0] - 2026-01-29

### Added
- Deflate compression (fixed Huffman + LZ77).
- Dynamic Huffman encoding with code-length RLE.
- `deflate_compress`/`zlib_compress` now produce compressed output and select the smaller of fixed/dynamic blocks.

## [0.2.0] - 2026-01-28

### Added
- Bench CLI (`src/cmd/bench`) for native/wasm/wasm-gc runs.
- Rust baseline benchmark tool (`tools/rust_bench`) using flate2/miniz_oxide.
- `scripts/bench_compare.sh` and `just bench-compare` for side-by-side comparisons.
- wasm/wasm-gc results to the benchmark table in the README.

### Changed
- BitReader now uses a 64-bit buffer with batched reads for faster bit extraction.
- Huffman decode uses a 2-level table for fewer branches in the hot path.
- Benchmark table updated with the latest measurements.

## [0.1.0] - 2026-01-28

- Initial release.
