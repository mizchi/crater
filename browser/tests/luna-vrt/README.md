# Luna Component VRT

Visual regression testing for Luna styled components rendered with crater CLI vs Chrome.

## Usage

```bash
# Run all fixtures (uses existing Chrome baselines)
node tests/luna-vrt/run-vrt.mjs

# Update Chrome baselines
node tests/luna-vrt/run-vrt.mjs --update-baseline

# Run specific fixture
node tests/luna-vrt/run-vrt.mjs alert
```

## Structure

```
tests/luna-vrt/
├── fixtures/          # HTML fixtures (theme CSS + component CSS + sample HTML)
│   ├── alert.html
│   ├── checkbox.html
│   └── switch.html
├── output/            # Generated PNG comparisons
│   └── <name>/
│       ├── crater.png
│       └── chrome.png
├── run-vrt.mjs        # VRT runner script
└── README.md
```

## Adding Fixtures

1. Create `fixtures/<name>.html` with:
   - Theme CSS variables in `:root`
   - Component CSS
   - Component HTML inside `<div id="target">`
2. Run `node tests/luna-vrt/run-vrt.mjs --update-baseline <name>`

## Known Differences

- **alert**: Close match. Minor height/font differences.
- **checkbox**: inline-flex layout issues with small elements (1.25rem boxes)
- **switch**: inline-flex + border-radius:9999px rendering gaps
