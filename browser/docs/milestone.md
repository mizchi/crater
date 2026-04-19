# Crater Browser Milestones

## Current Snapshot

```text
Implemented
  - terminal browser CLI with text / kitty / sixel output
  - structured outputs: JSON, AOM, Arc90, ExtractMain, Grounding
  - keyboard + mouse interaction, hint mode, dark mode, selection mode
  - browser shell with DOM/CSS/layout/AOM orchestration

Substantial progress
  - Preact-oriented DOM / event / state update scenarios
  - WebDriver BiDi protocol and WPT-focused synthetic behavior

Partial
  - CDP bridge for Puppeteer smoke tests
  - full-page headless rendering
  - real-world site parity for dynamic pages
```

---

## Milestone Status

### M1: Terminal Browser And Extraction

**Status**: Implemented

```text
✓ ANSI text rendering
✓ Kitty graphics output
✓ Sixel output
✓ Interactive navigation and history
✓ Hit-a-hint
✓ Dark mode
✓ Selection mode for copy
✓ AOM / JSON / Arc90 / ExtractMain / Grounding outputs
```

This is the most stable user-facing surface in the repository today.

### M2: Browser Shell As Shared Runtime

**Status**: Implemented

```text
✓ Central browser shell in shell/browser.mbt
✓ DOM / layout / paint / accessibility orchestration
✓ Scheduler and JS runtime hooks for tests and automation
✓ Shared state for history, focus, scroll, drag, and pointer input
```

This milestone matters because both the CLI and automation stacks reuse the same browser abstraction.

### M3: Preact-Oriented Compatibility

**Status**: Substantial progress

```text
✓ render() / h() basics
✓ useState re-render flow
✓ click -> state update -> re-render
✓ useEffect and cleanup
✓ keyed list rendering
✓ controlled input
✓ conditional rendering
✓ className and style object behavior
✓ larger TODO-style CRUD scenario
```

The goal is no longer "can a trivial Preact app mount at all?".
The current question is how far the runtime can be pushed before broader web-platform gaps show up.

### M4: WebDriver BiDi Automation

**Status**: Substantial progress

```text
✓ browsingContext lifecycle and navigation flows
✓ screenshot and print paths
✓ script evaluate / callFunction / preload scripts
✓ keyboard, pointer, drag-and-drop, setFiles
✓ network interception and synthetic fetch handling
✓ storage and cookie behavior
✓ emulation overrides (user agent, locale, geolocation, network, screen)
✓ WPT-oriented synthetic modules for prompts, downloads, bluetooth, web extensions
```

This is the primary automation milestone for the project.
Most current compatibility work should be framed as "expand BiDi/WPT coverage" rather than "introduce BiDi".

### M5: CDP Bridge For Puppeteer

**Status**: Partial

```text
✓ Target / DOM / Page / Input foundations in MoonBit
✓ Node-side bridge for HTTP fetch and lifecycle events
✓ puppeteer-core smoke tests
□ richer Runtime coverage
□ stronger hit testing and element interaction fidelity
□ broader DevTools protocol parity
```

CDP remains useful, but it is no longer the lead architecture.

### M6: Real-World Browser Experience

**Status**: Ongoing

```text
□ expose a clear public story for JS-enabled browsing from the CLI
□ true full-page headless rendering
□ deeper dynamic-site compatibility
□ tighter resource / storage / security parity with real browsers
□ better automation behavior on non-synthetic pages
```

This milestone is now more about productizing the existing runtime than inventing the core pieces.

---

## Recommended Next Steps

### 1. BiDi/WPT hardening

Keep expanding the WPT-driven BiDi clusters, especially around edge-case navigation, script realms, input, and network interception.

### 2. CDP bridge stabilization

Fill the remaining fidelity gaps that block Puppeteer smoke tests from becoming less synthetic.

### 3. CLI/product parity

Decide how far the public CLI should go toward JS-enabled browsing versus remaining a safer read-oriented renderer and extractor.

---

## Dependency View

```text
Browser shell
  ├─> Terminal CLI features
  ├─> Preact-oriented compatibility work
  ├─> WebDriver BiDi behavior
  └─> CDP compatibility bridge
```

In other words:

- the shell/runtime is the base platform
- BiDi is the primary automation contract
- CDP is compatibility work on top
- better real-world browsing depends on hardening all three
