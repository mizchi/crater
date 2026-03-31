# Changelog

## [0.14.0] - 2026-03-31

### CI
- Upgrade all GitHub Actions to Node 24 compatible versions (checkout v6, setup-node v6, upload-artifact v6, download-artifact v8, github-script v8, pnpm/action-setup v5)
- Enable `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` for full Node 24 runtime

### VRT Sharding
- Split monolithic VRT job (~20min) into 6 parallel shards (~8min)
- Add `WPT_VRT_SHARD`, `WPT_VRT_OFFSET`, `WPT_VRT_LIMIT` env vars for flexible test sharding
- CI time reduced from ~50min to ~13min (73% improvement)

### Bug Fixes
- Fix `knownFailures` pattern matching to use basename-only test names

## [0.13.0] - 2026-03-31

### Rendering & Paint
- CSS canvas background propagation (CSS 2.1 §14.2)
- `text-decoration: underline` in sixel/framebuffer rendering
- List markers, `letter-spacing`, `word-spacing` support
- HTML table attributes: `valign`, `cellpadding`, `cellspacing`
- `<hr>` element support
- Kitty graphics: image display, border rendering, font anti-aliasing

### Performance
- Glyph bitmap cache: 4-5x faster text rendering
- Pre-rasterized ASCII glyph warm cache at server startup
- Optimized glyph rendering (outline commands, JS base64, persistent cache)
- Skip off-screen nodes in framebuffer paint

### WPT & Testing
- Ahem-backed WPT visual regression testing
- Batch WPT VRT execution with baseline management
- Text advance ratio override for precise font metric control
- WPT known failures list (`knownFailures` in `wpt.json`)
- Playwright VRT CI integration

### Browser / BiDi
- Crater CLI with benchmark baselines and test infrastructure
- Fix BiDi server hang on 2nd+ WebSocket session
- Inline abspos WPT fixes and VRT fixture tracking
- WASM FFI pointer param annotations

[0.14.0]: https://github.com/mizchi/crater/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/mizchi/crater/compare/v0.12.0...v0.13.0
