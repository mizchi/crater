# Crater Browser CDP Architecture

## Overview

Crater Browser implements Chrome DevTools Protocol (CDP) for Puppeteer compatibility.
The implementation references lightpanda-browser's architecture while optimizing for Crater's DOM types.

## Current Architecture

```
crater/           Root module
└── dom/          Core DOM primitives (shared across modules)
    ├── dom.mbt   DomTree implementation
    └── types.mbt NodeId, Rect, Point, NodeType, etc.

browser/          Browser module (crater-browser)
└── src/
    ├── cdp/      CDP domain implementations
    │   ├── types.mbt   CdpNode, CdpError, CdpBoxModel
    │   ├── session.mbt CdpSession (combines all domains)
    │   ├── dom.mbt     DomDomain
    │   ├── page.mbt    PageDomain
    │   └── input.mbt   InputDomain
    │
    └── webdriver/  WebDriver protocol (uses CDP internally)
```

**Note**: `dom/` is at crater root (not browser/src/dom) because:
- Layout engine (`compute/`) writes coordinates to DOM
- Shared with other modules (aom, html, style)
- Clear dependency: dom ← cdp ← webdriver

## Design Principles

### 1. Zero-Copy DOM Access

CDP domains directly reference `@dom.DomTree` and `@dom.NodeId` without conversion overhead:

```moonbit
// Good: Direct reference
pub struct DomDomain {
  tree : @dom.DomTree
}

// Avoid: Unnecessary wrapper
pub struct DomDomain {
  tree : SomeWrapper  // Extra indirection
}
```

### 2. Lazy CdpNode Conversion

`CdpNode` is only created when serializing to JSON for protocol responses.
Internal operations use `@dom.NodeId` directly:

```moonbit
// Internal operation - uses NodeId
pub fn DomDomain::query_selector(
  self : DomDomain,
  node_id : Int,       // CDP uses Int for node IDs
  selector : String,
) -> Result[Int?, CdpError]

// Protocol response - converts to CdpNode
pub fn DomDomain::get_document(
  self : DomDomain,
  depth : Int?,
) -> Result[CdpNode, CdpError]  // Only here we create CdpNode
```

### 3. Session-Based State Management

Following lightpanda-browser's pattern:

```
CdpProtocol (message dispatch)
    │
    └─► CdpContext (= BrowserContext)
            │
            ├── session_id : String
            ├── target_id : String
            ├── tree : @dom.DomTree
            └── domains
                  ├── dom : DomDomain
                  ├── page : PageDomain
                  └── input : InputDomain
```

## CDP Protocol Format

### Request
```json
{
  "id": 1,
  "method": "DOM.querySelector",
  "params": { "nodeId": 1, "selector": "div" },
  "sessionId": "SID1"
}
```

### Response
```json
{
  "id": 1,
  "result": { "nodeId": 5 },
  "sessionId": "SID1"
}
```

### Event (no id)
```json
{
  "method": "DOM.setChildNodes",
  "params": { "parentId": 1, "nodes": [...] },
  "sessionId": "SID1"
}
```

## Domain Methods

### Target Domain (Required for Puppeteer)

| Method | Description |
|--------|-------------|
| `createBrowserContext` | Create isolated context |
| `disposeBrowserContext` | Destroy context |
| `createTarget` | Create new page/tab |
| `closeTarget` | Close page |
| `attachToTarget` | Attach to get sessionId |
| `detachFromTarget` | Detach from target |
| `setAutoAttach` | Auto-attach to new targets |
| `getTargets` | List all targets |
| `getTargetInfo` | Get target details |

### DOM Domain

| Method | Status | Notes |
|--------|--------|-------|
| `getDocument` | ✅ | Returns root node |
| `querySelector` | ✅ | CSS selector query |
| `querySelectorAll` | ✅ | Returns all matches |
| `getAttributes` | ✅ | Returns [name, value, ...] |
| `setAttributeValue` | ✅ | Sets attribute |
| `removeAttribute` | ✅ | Removes attribute |
| `getBoxModel` | ✅ | Returns box model |
| `getOuterHTML` | ✅ | Returns HTML string |
| `setNodeValue` | ✅ | Sets text content |
| `removeNode` | ✅ | Removes from tree |
| `requestChildNodes` | ✅ | Returns children |
| `describeNode` | TODO | Node description |
| `performSearch` | TODO | Search by XPath/CSS |
| `resolveNode` | TODO | objectId → nodeId |

### Page Domain

| Method | Status | Notes |
|--------|--------|-------|
| `navigate` | ✅ | Navigate to URL |
| `getFrameTree` | TODO | Frame hierarchy |
| `setLifecycleEventsEnabled` | TODO | Enable lifecycle events |
| `reload` | ✅ | Reload page |

### Input Domain

| Method | Status | Notes |
|--------|--------|-------|
| `dispatchMouseEvent` | ✅ | Mouse events |
| `dispatchKeyEvent` | ✅ | Keyboard events |
| `insertText` | ✅ | Insert text at focus |

### Runtime Domain (Stub)

| Method | Status | Notes |
|--------|--------|-------|
| `enable` | TODO | Enable domain |
| `evaluate` | TODO | Execute JS (stub) |
| `callFunctionOn` | TODO | Call function (stub) |

## Implementation Plan

### Phase 1: Testing Infrastructure

1. Create test helpers for CDP message handling
2. Port lightpanda-browser test patterns
3. Test DOM domain methods

### Phase 2: Target Domain

1. Implement `CdpContext` (browser context)
2. Add `createBrowserContext`, `disposeBrowserContext`
3. Add `createTarget`, `closeTarget`
4. Add `attachToTarget`, `detachFromTarget`

### Phase 3: Protocol Layer

1. JSON-RPC message parsing
2. Domain/method dispatch
3. Event emission

### Phase 4: Puppeteer Integration

1. WebSocket server (separate module)
2. Connection handling
3. Integration tests with Puppeteer

## Type Mappings

| CDP Type | Crater Type |
|----------|-------------|
| `NodeId` (int) | `@dom.NodeId` |
| `BackendNodeId` | `@dom.NodeId` (same) |
| `Node` | `CdpNode` (serialization only) |
| `BoxModel` | `CdpBoxModel` |
| `Quad` | `Array[Double]` (8 elements) |

## File Structure (Target)

```
src/cdp/
├── protocol.mbt      # JSON-RPC message handling
├── context.mbt       # CdpContext (browser context)
├── session.mbt       # CdpSession (existing)
├── types.mbt         # CDP types
├── testing.mbt       # Test utilities
│
├── domains/
│   ├── target.mbt    # Target domain
│   ├── dom.mbt       # DOM domain (move existing)
│   ├── page.mbt      # Page domain (move existing)
│   ├── input.mbt     # Input domain (move existing)
│   └── runtime.mbt   # Runtime domain (stub)
│
└── *_test.mbt        # Tests
```

## References

- [lightpanda-browser CDP](../lightpanda-browser/src/cdp/)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [Puppeteer CDP Usage](https://pptr.dev/)
