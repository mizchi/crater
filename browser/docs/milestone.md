# Crater Browser Milestones

## Current Implementation Status

```
✅ DOM API (createElement, querySelector, classList, etc.)
✅ CSS parsing & Flexbox layout (taffy)
✅ JS execution via QuickJS
✅ Promise / setTimeout / queueMicrotask
✅ fetch API (mock only)
✅ Paint tree & TUI rendering
```

---

## Milestones

### M1: Static HTML Rendering (Mostly Complete)

```
✅ HTML parsing → DOM tree
✅ CSS parsing → Style computation
✅ Layout calculation
✅ Painting
```

### M2: Real fetch Implementation

```
□ HTTP requests using Node.js native fetch
□ Response streaming
□ CORS header handling
□ Cookie management
```

**Goal**: `fetch('https://example.com')` sends actual HTTP requests

### M3: Dynamic Content Display

```
□ MutationObserver (DOM change detection)
□ requestAnimationFrame
□ CSS recalculation & re-layout
□ Incremental repaint
```

**Goal**: JS modifies DOM → changes reflect on screen

### M4: Preact Compatibility

```
□ Event delegation (bubbling/capturing)
□ input/change/submit events
□ Focus management
□ Full className / style manipulation
□ dangerouslySetInnerHTML
```

**Goal**: Simple Preact applications run correctly

### M5: Form Input

```
□ input[type=text] value management
□ checkbox / radio state
□ select / option
□ Keyboard events
□ IME support (CJK input)
```

**Goal**: Login forms work correctly

### M6: Real Website Rendering

```
□ External CSS loading
□ External JS loading & execution
□ Image loading (size detection)
□ Web fonts (or fallback)
□ localStorage / sessionStorage
□ History API (pushState, popstate)
```

**Goal**: Display zenn.dev article pages

### M7: Playwright Integration

```
□ WebDriver BiDi protocol
□ page.goto / page.click / page.fill
□ Screenshots
□ Network interception
```

**Goal**: Playwright tests can run on Crater

---

## Recommended Next Steps

**M2 (Real fetch)** provides the highest value:

1. Call Node.js fetch via FFI
2. Proper async/await support (currently using synchronous Promise polyfill)
3. Fetch external JSON APIs and render

This enables the SPA pattern: fetching data from APIs and displaying it dynamically.

---

## Dependencies Between Milestones

```
M1 ──→ M2 ──→ M3 ──→ M6
              ↓
              M4 ──→ M5
                     ↓
                     M7
```

- M2 (fetch) is a prerequisite for loading external resources
- M3 (dynamic content) is required for any interactive application
- M4 (Preact) requires M3 for reactivity
- M5 (forms) requires M4 for event handling
- M6 (real sites) requires M2, M3, and partial M4
- M7 (Playwright) requires M5 for form automation
