# Architecture

Internal architecture documentation for Crater modules.

## Scheduler Module

Browser Event Loop / Task Scheduler equivalent. Manages HTML/CSS/Layout evaluation tasks with dependency resolution.

### File Structure

```
scheduler/
├── task.mbt               # Task type definitions
├── queue.mbt              # TaskQueue management
├── scheduler.mbt          # Scheduler core
├── html_integration.mbt   # HTML Parser integration
├── css_integration.mbt    # CSS Cascade integration
├── layout_integration.mbt # LayoutTree integration
└── task_wbtest.mbt        # Tests
```

### Components

| Component | Description |
|-----------|-------------|
| `Scheduler` | Task queue management, dependency resolution, polling |
| `DocumentParser` | HTML parsing and resource discovery |
| `StyleManager` | Stylesheet management, cascade computation |
| `LayoutManager` | LayoutTree management, layout scheduling |
| `DocumentRenderCoordinator` | HTML/CSS/Layout integration pipeline |

### Design Principles

1. **External delegation**: Network, async runtime, script execution delegated externally
2. **Internal execution**: Style and layout computation can run synchronously
3. **Dependency graph**: Explicit task dependency management
4. **Parallelism**: Each task has a parallelizable flag

### Pipeline

```
HTML Parser → CSS Parser → Style Cascade → Layout Tree
     ↓            ↓              ↓              ↓
  Task gen     Task gen      Style calc    Layout calc
     ↓            ↓              ↓              ↓
  Scheduler manages all tasks, resolves dependencies, determines execution order
```

## Web Vitals Module

Core Web Vitals measurement. Implements LCP (Largest Contentful Paint) and CLS (Cumulative Layout Shift).

### File Structure

```
webvitals/
├── lcp.mbt       # LCP detection and tracking
├── lcp_test.mbt  # LCP tests
├── cls.mbt       # CLS calculation
└── cls_test.mbt  # CLS tests
```

### LCP (Largest Contentful Paint)

Detects when the largest content element is rendered. Used to determine "interaction ready" timing.

```moonbit
let tracker = LCPTracker::new(viewport_width, viewport_height)
tracker.add_candidate(candidate)
tracker.on_resource_loaded(element_id, load_time)
tracker.on_element_rendered(element_id, render_time)
tracker.finalize()  // On user input

if tracker.is_lcp_ready() {
  // Ready for interaction
}
```

### CLS (Cumulative Layout Shift)

Calculates layout shift scores.

```moonbit
let shift = compute_element_shift(before, after, viewport)
// shift.score = impact_fraction × distance_fraction

let cls = compute_total(before_rects, after_rects, viewport)
```

## AOM (Accessibility Object Model) Module

Builds accessibility tree from HTML. Based on WAI-ARIA 1.2 and HTML-AAM 1.0 specs.

### File Structure

```
aom/
├── types.mbt          # Role, State, Bounds, AccessibilityNode, AccessibilityTree
├── role.mbt           # HTML→Role inference
├── name.mbt           # Accessible Name computation (accname spec)
├── tree.mbt           # Tree construction + Layout integration
├── snapshot.mbt       # YAML/JSON output (Playwright compatible)
└── *_test.mbt         # Tests
```

### Features

| Feature | Description |
|---------|-------------|
| `build_accessibility_tree()` | HTML Document → AccessibilityTree |
| `build_accessibility_tree_with_layout()` | HTML + LayoutTree → AccessibilityTree with bounds |
| `compute_role()` | Implicit/explicit role inference |
| `compute_accessible_name()` | Name computation from aria-label, alt, title |
| `to_aria_snapshot()` | Playwright-compatible YAML output |
| `find_interactive()` | Find interactive elements |
| `find_landmarks()` | Find landmark elements |

### Layout Integration

```moonbit
let layout_tree = @tree.LayoutTree::from_html_document(doc, 800.0, 600.0)
let _ = layout_tree.calculate_layout(800.0, 600.0)
let a11y_tree = build_accessibility_tree_with_layout(doc, layout_tree)

// Each node has bounds
match a11y_tree.find_by_source_id("login-btn") {
  Some(node) => {
    // node.role = Button
    // node.name = Some("Login")
    // node.bounds = Some(Bounds { x: 300, y: 100, width: 100, height: 40 })
  }
  None => ()
}
```

## Image Resource Lifecycle

Resource state management and paint layer integration.

### States

```
┌─────────────┐     headers     ┌─────────────┐     complete     ┌──────────┐
│  Pending    │ ───────────────>│  Sizing     │ ────────────────>│ Complete │
│ (placeholder)│                 │ (confirmed) │                  │ (render) │
└─────────────┘                 └─────────────┘                  └──────────┘
       │                              │                                │
       │          error               │           error                │
       └──────────────────────────────┴────────────────────────────────┘
                                      │
                                      v
                               ┌──────────┐
                               │  Error   │
                               │ (24x24)  │
                               └──────────┘
```

### State Definitions

```moonbit
pub(all) enum ImageResourceState {
  /// Initial: Using HTML default placeholder (300x150) or width/height attributes
  Pending(placeholder_width~ : Double, placeholder_height~ : Double)

  /// Headers received: Actual dimensions known
  Sizing(width~ : Double, height~ : Double)

  /// Partial download: Progressive data available
  Streaming(width~ : Double, height~ : Double, progress~ : Double)

  /// Complete: Full image data available
  Complete(width~ : Double, height~ : Double)

  /// Error: Load failed, use error placeholder (24x24)
  Error
}
```

### Paint Layer Flow

```
External System          LayoutTree              Paint Layer
      │                       │                       │
      │  register_resource()  │                       │
      │──────────────────────>│                       │
      │  ResourceId           │                       │
      │<──────────────────────│                       │
      │                       │                       │
      │  update_resource_state│                       │
      │  (Sizing)             │                       │
      │──────────────────────>│ on_resource_state_change
      │                       │──────────────────────>│
      │                       │                       │
      │  compute_incremental()│                       │
      │──────────────────────>│                       │
      │  Layout (with shift)  │                       │
      │<──────────────────────│ on_layout_shift       │
      │                       │──────────────────────>│
      │                       │                       │
      │  update_resource_state│                       │
      │  (Complete)           │                       │
      │──────────────────────>│ on_resource_state_change
      │                       │──────────────────────>│
```

## Unsupported Features

### Float

`float` is intentionally deferred:
- Requires BFC (Block Formatting Context) handling
- Complex interaction with `clear`, `overflow`, inline elements
- Modern layouts should use Flex/Grid instead

Current behavior: Emit warning and treat as normal block flow.
