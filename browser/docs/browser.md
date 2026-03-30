# Crater Browser Architecture

## Overview

Crater Browser is no longer just a terminal renderer with a thin CDP layer.
The current codebase has three distinct integration surfaces:

| Surface | Entry Point | Purpose | Status |
| --- | --- | --- | --- |
| Terminal CLI | `src/main/main.mbt` | Interactive browsing and structured extraction | Primary user-facing surface |
| WebDriver BiDi | `jsbidi/bidi_main/main.mbt`, `jsbidi/webdriver/*` | Automation, WPT-oriented behavior, future Playwright/WebDriver work | Primary automation surface |
| CDP bridge | `tools/cdp-server.ts`, `src/cdp/*` | `puppeteer-core` smoke tests and legacy compatibility | Secondary and partial |

The center of gravity is now BiDi-first. CDP still exists, but mainly as a compatibility bridge.

## Core Runtime Layers

| Layer | Main Files | Responsibility |
| --- | --- | --- |
| CLI entry | `src/main/main.mbt` | Parses flags, chooses output mode, runs interactive loop or headless render |
| Browser shell | `src/shell/browser.mbt` | Owns URL/history state, DOM/AOM/render caches, scheduler, hint mode, selection mode, output generation |
| Interaction | `src/interaction/interaction.mbt`, `src/tui/*` | Maps keyboard and mouse input to browser actions |
| CDP domains | `src/cdp/*` | MoonBit-side `Target`, `DOM`, `Page`, `Input`, and related protocol handling |
| BiDi protocol | `jsbidi/webdriver/bidi_protocol.mbt` | Session state, browsing contexts, subscriptions, script/input/network/storage/emulation modules |
| BiDi transport | `jsbidi/webdriver/bidi_server.mbt` | Deno WebSocket server and JS runtime bootstrap |
| Test bridges | `tools/cdp-server.ts`, `tools/webdriver-server.ts` | Node-side harnesses used by Puppeteer/WebDriver smoke tests |

## Terminal Browser Path

The CLI path is centered on `src/shell/browser.mbt`.

It currently supports:

- `Text`, `Kitty`, and `Sixel` rendering
- lightweight navigation for `--json` and `--aom`
- full render path for `--text`, `--kitty`, `--sixel`, `--arc90`, `--grounding`, and `--extract-main`
- keyboard and mouse input, including hit-a-hint, dark mode, and selection mode

The shell keeps the following state in one place:

- current URL and history stacks
- parsed HTML, external CSS, DOM tree, accessibility tree, and render/layout caches
- focus and scroll state
- pointer/drag state
- scheduler and optional JS runtime hooks

This shell is the shared browser abstraction used by both user-facing rendering and automation-oriented tests.

## WebDriver BiDi Stack

`jsbidi/` is the primary automation implementation.

### Entry Points

- `jsbidi/bidi_main/main.mbt`: minimal server entry point
- `jsbidi/bidi_main/start-with-font.ts`: Deno launcher with font loading and text metrics setup
- `jsbidi/webdriver/bidi_server.mbt`: WebSocket transport and JS runtime bootstrap
- `jsbidi/webdriver/bidi_protocol.mbt`: main protocol state machine

### Current Coverage

The BiDi stack already contains substantial WPT-oriented coverage for:

- `session.*` and `browser.*`
- `browsingContext.*`, including context lifecycle, tree queries, viewport overrides, navigation, screenshot, print, and locate-nodes flows
- `script.*`, including evaluate/callFunction, realms, preload scripts, prompt handling, and file-dialog shims
- `input.*`, including keyboard, pointer, drag-and-drop, and `setFiles`
- `network.*`, including synthetic request lifecycle, interception, provide/continue/fail flows, and request data collection
- storage and cookie behavior
- emulation features such as user agent, locale, geolocation, network conditions, and screen settings
- WPT-oriented synthetic modules for permissions, downloads, Bluetooth, and web extensions

The BiDi implementation keeps significant protocol state in MoonBit:

- browsing contexts and parent/child trees
- per-context realms and sandbox realms
- subscriptions at global, context, and user-context scope
- local storage and synthetic cookie stores
- navigation, prompt, and download state
- emulation overrides
- input and drag session state

BiDi responses are emitted directly from this state machine, with CDP-style session objects reused only where that is convenient.

## CDP Bridge

The CDP path remains useful, but it is intentionally smaller than the BiDi path.

### MoonBit Side

`src/cdp/` currently provides:

- `Target` domain session/context plumbing
- `DOM` domain document, query, attribute, and box-model helpers
- `Page` domain navigation/history/frame helpers
- `Input` domain mouse/key/text primitives
- protocol routing for additional compatibility domains

### Node Side

`tools/cdp-server.ts` is the outer bridge used by `puppeteer-core` tests.
It does the parts that are currently simpler in Node:

- fetch the target URL
- translate responses into CDP network/lifecycle events
- load HTML into the MoonBit session
- expose `/json/*` discovery endpoints required by Puppeteer

### Practical Status

The CDP bridge is good enough for smoke tests and basic page automation flows.
It is not the authoritative architecture for the project anymore, and some areas remain partial:

- hit testing in `src/cdp/input.mbt`
- richer `Runtime.*` behavior
- broader DevTools parity across domains

## Data Flow Snapshot

### CLI / Rendering

```text
URL
  -> Browser shell
  -> HTML/CSS parse
  -> layout / paint / AOM
  -> Text | Kitty | Sixel | JSON | AOM | Arc90 | ExtractMain | Grounding
```

### Automation

```text
BiDi request
  -> BidiProtocol
  -> context / storage / emulation / input / script state
  -> browser shell and runtime helpers as needed
  -> BiDi response + events
```

```text
Puppeteer CDP request
  -> tools/cdp-server.ts
  -> src/cdp/*
  -> CDP response + compatibility events
```

## Guidance For Future Changes

- Treat WebDriver BiDi as the primary automation contract.
- Treat the terminal shell as the primary browser abstraction.
- Keep CDP working, but optimize it for compatibility value rather than full Chrome parity.
- Prefer documenting current entry points and actual ownership boundaries rather than aspirational directory layouts.
