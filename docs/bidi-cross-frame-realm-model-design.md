# Design doc: live cross-frame DOM access / realm model (issue #200)

Status: **design / decision-required**. Issue #200 explicitly asks for a design
decision on Crater's realm model before implementation. This doc grounds the
three approaches from the issue in the current architecture, lays out the
trade-offs and implementation shape of each, and recommends a path. The choice
is the maintainer's to make.

Related, already-shipped: #197 (generalized synthetic iframe handler), #199
(read-only nested property/index mirror), #198 (cross-evaluate child
registration). #200 is the remaining, structurally harder "live" case.

---

## 1. Current state

Cross-frame access today is a **one-shot textual snapshot**, not a live link:

- `try_handle_synthetic_iframe_creation` (`webdriver/webdriver/bidi_protocol.mbt`)
  is a **text-pattern matcher** over the `script.evaluate` expression. It
  detects `createElement('iframe')` + a DOM-insertion verb, extracts `src`,
  and registers a child context (`assign_new_realm`).
- `bidi_iframe_content_window_mirror.mbt` extracts `<lhs> = <var>.contentWindow.<chain>`
  and, at evaluate time, reads `window.<chain>` once and writes the value into
  the parent's LHS. After that, the two sides are disconnected.
- Realms: Crater assigns a distinct **realm id** per browsing context, but JS
  executes in a **shared runtime / single `globalThis`** (the headless default).
  The "child realm" read is an eval against that shared global.

What this misses (from #200):

1. **Parent observes child mutations** — `iframe.contentWindow.addEventListener('foo', cb)`.
2. **Parent reads child state lazily** — `iframe.contentWindow.getState()` each render.
3. **Child writes parent state** — `window.parent.appCallback = ...`.

All three need a *standing* relationship between realms, which the snapshot
model cannot express.

---

## 2. Options

### Option A — Proxy-based live `contentWindow`

`iframe.contentWindow` returns a JS `Proxy` whose `get`/`set`/`apply` traps
route each access through the target realm at access time.

- **Pros**: shape-conformant; handles all three patterns (lazy reads, method
  calls, child→parent writes) including ones the text matcher can never parse
  (computed property names, calls, compound RHS).
- **Cons**: every cross-frame access pays a realm-switch + eval round-trip;
  requires a real per-realm global object to proxy *to* (see §3); trap
  semantics (prototype chain, `this` binding for methods, structured-clone vs
  live-reference of returned objects) are subtle and easy to get subtly wrong.
- **Shape**: replace the text matcher's snapshot with a runtime `contentWindow`
  accessor that returns the proxy; implement traps in the JS runtime bridge
  (`bidi_runtime_context.mbt` region) keyed by child realm id.

### Option B — Shared-realm alias (test/headless mode)

Since the default runtime is a single `globalThis`, treat
`iframe.contentWindow` as an **alias for the same global** when parent and child
are pinned to one realm.

- **Pros**: cheap; no round-trips; immediately makes lazy reads, method calls,
  and child→parent writes "work" because they are literally the same object.
- **Cons**: **semantically wrong** for isolation — parent and child share one
  global, so name collisions leak, `window.parent === window`, and any test that
  asserts realm isolation (separate `globalThis`, separate `document`) breaks.
  It is a convenience that models "one realm pretending to be two".
- **Shape**: when `assign_new_realm` would pin the child to the shared global,
  make `contentWindow` resolve to that global directly; gate behind an explicit
  "single-realm test mode" flag so it never masks real isolation expectations.

### Option C — Document the limitation, steer to `postMessage`

Keep the snapshot mirror for the simple `lhs = contentWindow.chain` case; for
everything else, document that live cross-frame member access is unsupported and
that apps should use `window.postMessage` (which has a real channel).

- **Pros**: zero new surface; honest; `postMessage` is the portable pattern.
- **Cons**: real apps and WPT use direct `contentWindow` member access; this
  closes #200 as "won't fix the general case".
- **Shape**: a docs note + ensure `postMessage` parent↔child delivery works in
  the shared runtime (verify/strengthen if needed).

---

## 3. The underlying decision: does Crater have real per-frame realms?

Options A and B diverge on the realm model:

- **A** presupposes (or forces) **distinct global objects per browsing context**
  so the proxy has a real target and isolation holds. That is the
  browser-faithful model but a larger runtime change (per-context global, realm
  switch on the JS side, lifetime/GC of child realms).
- **B** leans into the **single shared global** that exists today.

So #200 is really: *do we invest in true per-frame realms (A), accept a
shared-realm convenience (B), or decline the general case (C)?* Everything else
follows from that.

---

## 4. Recommendation

Phase the work rather than commit to full realm isolation up front:

1. **Now — Option C baseline**: document the snapshot limitation and confirm
   `postMessage` parent↔child works, so apps have one correct path today. Low
   risk, immediately honest.
2. **Next — Option B behind a flag** for the headless/test single-realm path:
   make `contentWindow` a live alias to the shared global *only* under an
   explicit single-realm mode, so lazy reads / method calls / child→parent
   writes work for the common test scenarios **without** claiming isolation.
   Add wbtests for the three #200 patterns and a test asserting the flag is off
   by default (isolation preserved).
3. **Later — Option A** if/when true multi-realm isolation is required (real
   per-context globals + proxy `contentWindow`). Track as its own scenario; it
   is the only option that is both live *and* isolation-correct, but it is the
   largest runtime change.

Acceptance for closing #200 should be tied to whichever phase is chosen (e.g. a
`protocol.bidi-cross-frame-*` scenario + wbtests for the three patterns), not to
all three at once.

---

## 5. Wiring points (for whoever implements)

- `webdriver/webdriver/bidi_protocol.mbt` — `try_handle_synthetic_iframe_creation`,
  `assign_new_realm` (realm/child-context creation).
- `webdriver/webdriver/bidi_iframe_content_window_mirror.mbt` — the snapshot
  extractor that A/B would supersede for the live cases.
- The JS runtime bridge (`bidi_runtime_context.mbt` region) — where a proxy
  (A) or a shared-global alias (B) for `contentWindow` would live, and where
  `postMessage` delivery (C) is exercised.
- `specs/crater.pkl` — add a `protocol.bidi-cross-frame-*` scenario for the
  chosen phase; link a wbtest in `specs/tasks.Test.pkl`.
