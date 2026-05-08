# Luna Reference VRT

This directory contains static Luna UI fixtures that Crater uses as a reference
implementation target. The dependency direction is intentionally Crater -> Luna
fixtures: `@luna_ui/*` should not depend on Crater just to run VRT.

## Usage

Run from the repository root:

```bash
# Capture all Luna reference fixtures with the Crater CLI
pnpm vrt:luna-reference -- --json

# Capture one fixture
pnpm vrt:luna-reference -- switch

# Capture a fixture with a selector target
pnpm vrt:luna-reference -- switch --target-selector "[data-vrt-root]"

# Capture with text glyph pixels hidden while preserving text layout
pnpm vrt:luna-reference -- --mask-text --json
```

The runner writes PNGs to `browser/tests/luna-vrt/output` by default.

## Structure

```
browser/tests/luna-vrt/
├── fixtures/          # Static HTML fixtures with Luna-compatible markup/CSS
│   ├── alert.html
│   ├── checkbox.html
│   └── switch.html
├── output/            # Generated Crater PNG captures
├── run-vrt.mjs        # Legacy Crater vs Chrome comparison runner
└── README.md
```

## Adding Fixtures

1. Create `fixtures/<name>.html` with theme CSS variables, component CSS, and
   component HTML inside `<div id="target">`.
2. Run `pnpm vrt:luna-reference -- <name> --json`.

## Legacy Comparison

`run-vrt.mjs` still compares Crater output with Chrome baselines. Keep it for
manual investigation, but prefer `pnpm vrt:luna-reference` for the Crater-side
reference path because it does not require adding Crater to Luna packages.
Use `node tests/luna-vrt/run-vrt.mjs --mask-text --update-baseline` from
`browser/` to compare Chrome and Crater while ignoring font rasterization noise.
