# Crater Browser

Experimental browser/runtime work implemented in MoonBit.

Crater Browser currently has two main faces:

- a terminal browser CLI for text and graphics rendering
- a browser automation stack centered on WebDriver BiDi, with a smaller CDP bridge for compatibility tests

## Current Scope

- Terminal rendering in `--text` (default), `--kitty`, and `--sixel`
- Structured outputs for tooling: `--json`, `--aom`, `--extract-main`, `--arc90`, `--grounding`
- Interactive navigation with keyboard, mouse, hit-a-hint, dark mode, and selection mode
- Browser core with DOM, CSS, layout, accessibility tree, scheduler, and JS-backed test/automation paths
- WebDriver BiDi-first automation stack under `jsbidi/`
- Partial CDP bridge used for `puppeteer-core` smoke tests

The project is still experimental and should not be treated as a production browser.

## Requirements

- Node.js 24+
- pnpm
- MoonBit toolchain
- Deno, if you want to run the WebDriver BiDi server

Optional:

- a sixel-capable terminal for `--sixel`
- Kitty terminal for `--kitty`

## Install The CLI

```bash
pnpm add -g @mizchi/crater-browser
```

or without a global install:

```bash
pnpm dlx @mizchi/crater-browser https://example.com
```

## CLI Usage

```bash
crater-browser [OPTIONS] <URL>
```

Examples:

```bash
crater-browser https://example.com
crater-browser --aom https://example.com
crater-browser --headless=viewport https://example.com
crater-browser --dark --no-color https://example.com
```

### Output Modes

- `--text`: render ANSI text output (default)
- `--sixel`: render Sixel graphics
- `--kitty`: render Kitty graphics protocol output
- `--json`: output the accessibility tree as JSON
- `--aom`: output the accessibility tree as Playwright-style YAML
- `--arc90`: run Arc90 content extraction
- `--grounding`: run the visual grounding demo
- `--extract-main`: extract main content text only
- `--debug`: print the layout tree

### Headless And Display Options

- `--headless=viewport`: render once and exit
- `--headless=full`: intended for full-page rendering, currently prints the initial viewport
- `--dark`: start with `prefers-color-scheme: dark`
- `--no-color`: disable ANSI color output
- `--width=N`: override viewport width in terminal columns

## Interactive Key Bindings

- `j` / `ArrowDown`: scroll down
- `k` / `ArrowUp`: scroll up
- `Ctrl-D` / `PageDown` / `Space`: page down
- `Ctrl-U` / `PageUp` / `Shift-Space`: page up
- `Tab` / `n`: focus next link
- `Shift-Tab` / `N` / `p`: focus previous link
- `Enter`: activate the focused link
- `f`: enter hit-a-hint mode
- `g`: prompt for a URL
- `r`: reload
- `H` / `Backspace` / `Delete`: go back
- `L`: go forward
- `d`: toggle dark mode
- `v`: toggle selection mode for text copy
- `q`: quit

Mouse tracking is enabled in interactive mode for scrolling, hover, click, and text-selection flows.

## Development

Install dependencies:

```bash
pnpm install
```

Build the CLI target:

```bash
moon build --target js --release
```

Run the terminal browser from the source tree:

```bash
moon run src/main --target js -- https://example.com
moon run src/main --target js -- --aom https://example.com
moon run src/main --target js -- --headless=viewport https://example.com
```

Run the test helpers exposed through `package.json`:

```bash
pnpm test
pnpm test:cdp
pnpm test:cdp:navigate
pnpm test:webdriver
```

Run the WebDriver BiDi server:

```bash
cd jsbidi
moon build --target js --release
cd ..
deno run -A jsbidi/bidi_main/start-with-font.ts
```

## Architecture Notes

- `src/main/main.mbt`: terminal CLI entry point
- `src/shell/browser.mbt`: browser shell, rendering orchestration, output modes, history, hint mode, selection mode
- `src/interaction/interaction.mbt`: keyboard and mouse dispatch
- `src/cdp/`: partial MoonBit CDP domains
- `jsbidi/webdriver/`: WebDriver BiDi protocol, server, synthetic WPT helpers
- `tools/cdp-server.ts`: Node-side CDP bridge used by Puppeteer tests

## Limits And Known Gaps

- The browser core has JS-backed test and automation paths, but the public CLI remains read-oriented and does not expose a general JS execution switch.
- `--headless=full` is not yet a true full-page renderer.
- The CDP bridge is intentionally partial and mostly exists for compatibility smoke tests.
- WebDriver BiDi coverage is WPT-driven and still expanding.
- Real-world site compatibility is improving, but dynamic sites and edge-case browser APIs are incomplete.
