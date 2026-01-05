# Crater Browser (Experimental)

An experimental TUI browser implemented in MoonBit. Renders web pages in the terminal using Sixel graphics.

**Warning: This is an experimental implementation and is not intended for production use.**

## Features

- HTML parsing and rendering
- External CSS fetching and application
- Sixel graphics output
- Basic keyboard navigation

## Usage

```bash
cd browser
moon run src/main --target js -- <URL>
```

Example:
```bash
moon run src/main --target js -- https://example.com
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
- Images are not displayed
- CJK characters are rendered as placeholders
