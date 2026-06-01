# WPT runner fonts

Fonts vendored for the WPT CSS runner (`scripts/wpt-runner.ts`) text measurement.

The runner compares Crater's computed layout against Chromium (Puppeteer). Crater
gets its text advances from `globalThis.__craterMeasureTextIntrinsic`, which the
runner installs. When no external `mizchi/text` module is available, the runner
measures glyph advances with `opentype.js` against the font(s) below instead of
the old `length * fontSize * 0.5` heuristic.

## Why Tinos

Chromium's default font for content that does not set `font-family` is **Times
New Roman** (a proportional serif). `Tinos-Regular.ttf` is metric-compatible with
Times New Roman, so its per-glyph advances match Chromium's default to within
~0.3% mean error (the heuristic was ~33% off). Matching the default font is the
single largest lever for WPT CSS text-measurement parity, because most layout
fixtures do not set `font-family`.

`monospace`-family text is handled as `length * fontSize * 0.6` (the advance of a
typical monospace face such as Noto Sans Mono, 600/1000 em) and `Ahem` as
`length * fontSize` (1em squares), so no extra font binaries are required.

## License

- `Tinos-Regular.ttf` — SIL Open Font License 1.1, see `Tinos-LICENSE.txt`.
  Source: https://github.com/googlefonts/Tinos
