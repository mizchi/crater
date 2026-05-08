# Component VRT Tool

`scripts/component-vrt.ts` is a framework-independent screenshot runner for fast
component VRT. Frameworks provide only a URL or an HTML fixture plus a component
root selector. Crater owns the browser backend, text asset cache, clipping, and
artifact manifest.

## Use

```bash
pnpm vrt:component -- --config component-vrt.json --output-dir screenshots/component-vrt
pnpm vrt:component -- --backend chromium --config component-vrt.json --output-dir screenshots/chromium
pnpm vrt:component -- --config component-vrt.json --asset-cache-dir .cache/component-vrt
```

## Config

```json
{
  "schemaVersion": 1,
  "backend": "crater",
  "outputDir": "screenshots/component-vrt",
  "timeoutMs": 5000,
  "assets": {
    "cacheDir": ".cache/component-vrt",
    "ttlMs": 86400000,
    "revalidate": false,
    "preload": [
      "http://127.0.0.1:3000/assets/app.css",
      "http://127.0.0.1:3000/assets/runtime.js"
    ]
  },
  "scenarios": [
    {
      "id": "button-primary",
      "url": "http://127.0.0.1:3000/iframe.html?id=button--primary",
      "selector": "#storybook-root",
      "viewport": { "width": 800, "height": 600 },
      "waitForSelector": "#storybook-root",
      "padding": 4
    },
    {
      "id": "static-card",
      "html": "<main><section data-component-root>Card</section></main>",
      "selector": "[data-component-root]",
      "viewport": { "width": 640, "height": 480 }
    }
  ]
}
```

## Cache Model

The asset cache is deliberately text-only for now:

- cached: CSS, JS, SVG, JSON, HTML, and text assets
- disk cache: each preloaded URL is saved under `cacheDir` and restored before
  the browser route layer is installed
- reuse: `revalidate: false` means restored preload URLs are not fetched again;
  missing preload URLs are still fetched and then persisted
- skipped: `Cache-Control: no-store`, non-2xx responses, oversized bodies, and
  binary content types
- replay: installed as a Playwright-compatible `page.route(/.*/, handler)` layer
  and fulfilled from cache for matching `GET` requests

This keeps the first version safe for both Crater's adapter and Chromium. Binary
asset replay should be added after route fulfillment preserves bytes end to end.

## Framework Boundary

React, Preact, Vue, Storybook, HRC, or product-specific runners should render the
component however they want, then pass a stable URL/HTML and selector to this
tool. The runner does not know about framework lifecycle APIs.
