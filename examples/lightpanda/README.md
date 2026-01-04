# Lightpanda + Crater Integration

This example demonstrates using [Lightpanda](https://github.com/lightpanda-io/browser) as a headless browser frontend with Crater as the layout engine.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Lightpanda                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │
│  │HTML Parser│ │CSS Parser│ │DOM APIs  │ │JS Runtime │  │
│  │(NetSurf) │ │          │ │          │ │   (V8)    │  │
│  └──────────┘ └──────────┘ └──────────┘ └───────────┘  │
└─────────────────────────────────────────────────────────┘
                        ↓
              HTML with inline styles
                        ↓
┌─────────────────────────────────────────────────────────┐
│                    Crater (MoonBit)                     │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐             │
│  │HTML/CSS   │ │ Layout    │ │  Render   │             │
│  │Parser     │ │Engine     │ │  (Sixel)  │             │
│  └───────────┘ └───────────┘ └───────────┘             │
└─────────────────────────────────────────────────────────┘
```

## Why This Combination?

- **Lightpanda**: Fast headless browser for JS execution, DOM manipulation, and CSS computation
  - 11x faster than Chrome, 9x less memory
  - Designed for automation, no graphical rendering

- **Crater**: Pure layout computation engine
  - Flexbox, Grid, Block layout support
  - Lightweight (37KB gzipped wasm)
  - Terminal rendering via Sixel

Together they provide a lightweight alternative to full browsers for layout-focused tasks.

## Setup

```bash
cd examples/lightpanda
npm install
```

## Usage

### 1. Start Lightpanda

```bash
# Install Lightpanda: https://github.com/lightpanda-io/browser
lightpanda --remote-debugging-port=9222
```

Or use Lightpanda Cloud:
```bash
export LIGHTPANDA_ENDPOINT="wss://cloud.lightpanda.io/..."
```

### 2. Run the Script

```bash
# Render a URL
node index.mjs https://example.com

# With custom viewport
node index.mjs https://example.com 800 600

# JSON output (layout tree)
node index.mjs https://example.com 800 600 json
```

## How It Works

1. **Connect to Lightpanda** via Puppeteer-compatible WebSocket API
2. **Navigate to URL** and wait for JavaScript execution
3. **Extract styled HTML**: Walk the DOM tree and capture computed styles as inline styles
4. **Pass to Crater**: Run the MoonBit layout engine on the styled HTML
5. **Output**: Sixel graphics for terminal or JSON layout tree

## Alternative: Using Chrome

If Lightpanda is not available, you can use Chrome/Chromium with Puppeteer:

```bash
npm install puppeteer
```

Then modify `index.mjs`:
```javascript
import puppeteer from 'puppeteer';

const browser = await puppeteer.launch();
// ... rest of the code works the same
```

## Output Formats

- **Sixel** (default): Graphical output for terminals that support Sixel
- **JSON**: Layout tree with positions and dimensions for each element
