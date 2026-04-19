#!/usr/bin/env bash
set -euo pipefail

if ! command -v hyperfine >/dev/null 2>&1; then
  echo "hyperfine not found. Install it first (e.g. brew install hyperfine)." >&2
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found." >&2
  exit 1
fi

NEW_MOON_PKG=1 moon build --target native src/cmd/bench
NEW_MOON_PKG=1 moon build --target wasm src/cmd/bench
NEW_MOON_PKG=1 moon build --target wasm-gc src/cmd/bench

bin="_build/native/release/build/cmd/bench/bench.exe"
fixtures_dir="fixtures"
rust_bin="tools/rust_bench/target/release/rust_bench"

(cd tools/rust_bench && cargo build --release)

hyperfine --warmup 3 \
  "${bin} decompress zlib ${fixtures_dir}/zlib_dynamic_256k.bin >/dev/null" \
  "${rust_bin} decompress zlib ${fixtures_dir}/zlib_dynamic_256k.bin >/dev/null"

hyperfine --warmup 3 \
  "${bin} decompress deflate ${fixtures_dir}/deflate_dynamic_256k.bin >/dev/null" \
  "${rust_bin} decompress deflate ${fixtures_dir}/deflate_dynamic_256k.bin >/dev/null"

hyperfine --warmup 3 \
  "${bin} decompress gzip ${fixtures_dir}/gzip_dynamic_256k.bin >/dev/null" \
  "${rust_bin} decompress gzip ${fixtures_dir}/gzip_dynamic_256k.bin >/dev/null"

echo ""
echo "MoonBit wasm (moon run)"
hyperfine --warmup 3 \
  "moon run --target wasm --release src/cmd/bench -- decompress zlib ${fixtures_dir}/zlib_dynamic_256k.bin >/dev/null"

hyperfine --warmup 3 \
  "moon run --target wasm --release src/cmd/bench -- decompress deflate ${fixtures_dir}/deflate_dynamic_256k.bin >/dev/null"

hyperfine --warmup 3 \
  "moon run --target wasm --release src/cmd/bench -- decompress gzip ${fixtures_dir}/gzip_dynamic_256k.bin >/dev/null"

echo ""
echo "MoonBit wasm-gc (moon run)"
hyperfine --warmup 3 \
  "moon run --target wasm-gc --release src/cmd/bench -- decompress zlib ${fixtures_dir}/zlib_dynamic_256k.bin >/dev/null"

hyperfine --warmup 3 \
  "moon run --target wasm-gc --release src/cmd/bench -- decompress deflate ${fixtures_dir}/deflate_dynamic_256k.bin >/dev/null"

hyperfine --warmup 3 \
  "moon run --target wasm-gc --release src/cmd/bench -- decompress gzip ${fixtures_dir}/gzip_dynamic_256k.bin >/dev/null"
