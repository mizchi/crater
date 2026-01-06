# Crater Browser (Experimental)

An highly experimental TUI browser implemented in MoonBit from scratch.

**Warning: This is an experimental implementation and is not intended for production use.**

## Features

- HTML parsing and rendering
- External CSS fetching and application
- [ ] Sixel graphics output (with `--sixel` flag)
- TUI text mode rendering (with `--text` flag)
  - Image placeholders with alt text display
  - Gray background with borders for image areas
- Basic keyboard navigation
- [ ] Link navigation with Tab/Shift+Tab

## Installation

```bash
npm install -g @mizchi/crater-browser
```

## Usage

```bash
npx @mizchi/crater-browser <URL> [--sixel] [--debug]
```

### Usage Example

```bash
npx @mizchi/crater-browser https://www.cnn.co.jp/fringe/35129835.html
```

### Options

- `--text`: TUI text mode (default)
- `--sixel`: Sixel graphics mode (requires sixel-capable terminal)
- `--debug`: Print layout tree for debugging

### Development

```bash
cd browser
moon run src/main --target js -- https://example.com
moon run src/main --target js -- --sixel https://example.com
moon run src/main --target js -- --debug https://example.com
```

## Key Bindings

### Navigation

- `j` / `Down`: Scroll down
- `k` / `Up`: Scroll up
- `Ctrl-D` / `PageDown`: Page down (scroll by one screen)
- `PageUp`: Page up (scroll by one screen)
- `H` / `Backspace` / `Delete`: Go back to previous page
- `L`: Go forward to next page

### Links
- `Tab` / `n`: Next link
- `Shift+Tab` / `N` / `p`: Previous link
- `Enter`: Activate focused link
- `f`: Hit-a-hint mode (shows labels on links, type to navigate)

### General
- `g`: Go to URL (opens prompt)
- `r`: Reload current page
- `q`: Quit
- `Escape`: Exit hint mode

### Hit-a-Hint Mode

Press `f` to enter hint mode. All visible links will be labeled with characters (a-z). Type the label to navigate to that link. Press `Escape` to cancel.

For pages with more than 26 links, two-character labels (aa, ab, etc.) are used.

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
- [x] Hit-a-hint (implemented)
- [ ] Mouse click link navigation (WIP - hit testing not working correctly)
