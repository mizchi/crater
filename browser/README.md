# Crater Browser (Experimental)

An experimental TUI browser implemented in MoonBit. Renders web pages in the terminal using Sixel graphics.

**Warning: This is an experimental implementation and is not intended for production use.**

## Features

- HTML parsing and rendering
- External CSS fetching and application
- Sixel graphics output (with `--sixel` flag)
- TUI text mode rendering (with `--text` flag)
  - Image placeholders with alt text display
  - Gray background with borders for image areas
- Basic keyboard navigation
- Link navigation with Tab/Shift+Tab

## Usage

```bash
cd browser
moon run src/main --target js -- [OPTIONS] <URL>
```

### Options

- `--text`: TUI text mode (default terminal rendering)
- `--sixel`: Sixel graphics mode (requires sixel-capable terminal)
- `--debug`: Print layout tree for debugging

### Examples

```bash
# TUI text mode
moon run src/main --target js -- --text https://example.com

# Sixel graphics mode
moon run src/main --target js -- --sixel https://example.com

# Debug layout
moon run src/main --target js -- --debug https://example.com
```

## Key Bindings

- `j` / `Down`: Scroll down
- `k` / `Up`: Scroll up
- `Tab`: Next link
- `Shift+Tab`: Previous link
- `Enter`: Activate link
- `g`: Go to URL
- `r`: Reload
- `q`: Quit

## Limitations

- JavaScript is not executed
- Only a subset of CSS properties are supported
- Images shown as placeholders (not actual image rendering in TUI mode)
- Some CSS layout features (grid, advanced flexbox) are partial

## TODO

- [ ] Static asset cache
- [ ] Show visited/unvisited link colors
- [ ] Tab text focus and preview
- [ ] Fix j/k scroll layout
- [ ] Access and scroll to content by AOM (Accessibility Object Model)
- [ ] Text search (Ctrl+F)
- [ ] hit a hint

## WIP (Work in Progress)

- [ ] Mouse click link navigation
  - Infrastructure implemented: LinkRegion, MouseClick action, mouse tracking ANSI codes
  - Issue: Hit testing not working correctly (coordinate mismatch?)
  - TODO: Add href field to PaintNode for proper link resolution instead of text matching
