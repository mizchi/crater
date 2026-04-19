# mizchi/zlib

Pure MoonBit zlib/deflate implementation.

## Features

- zlib streams (compress stored / full inflate)
- raw deflate (stored compress / full inflate)
- gzip (stored compress / full inflate)

## Quick Commands

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
just bench     # run benchmarks
just bench-compare  # compare vs system zlib (hyperfine)
just test-update  # update snapshot tests
just info      # generate type definition files
```

## Benchmark (Rust flate2 / miniz_oxide baseline)

Measured on 2026-01-28 with `hyperfine --warmup 3` and the bundled 256KiB fixtures.
Commands are very short (<5ms), so shell overhead can skew results. wasm/wasm-gc uses
`moon run`, so the runtime/launcher overhead is included.

| Format | MoonBit native (mean) | Rust baseline (mean) | Relative | MoonBit wasm (mean) | MoonBit wasm-gc (mean) |
| --- | --- | --- | --- | --- | --- |
| zlib | 3.8 ms | 2.1 ms (flate2/miniz_oxide) | 1.8x slower | 31.8 ms | 22.9 ms |
| deflate | 3.7 ms | 2.1 ms (flate2/miniz_oxide) | 1.8x slower | 30.0 ms | 22.6 ms |
| gzip | 4.2 ms | 2.2 ms (flate2/miniz_oxide) | 1.9x slower | 30.7 ms | 27.1 ms |

## Project Structure

```
zlib/
├── moon.mod.json
├── src/
│   ├── moon.pkg
│   ├── zlib.mbt
│   ├── inflate.mbt
│   ├── huffman.mbt
│   ├── adler32.mbt
│   └── zlib_test.mbt
└── justfile
```

## License

Apache-2.0
