# Design memo: `<template>` content parsing ("in template" insertion mode)

Status: **landed** (crater #313). The full "in template" insertion mode described
below is implemented in `dom/html` and validated. This memo is kept as the
root-cause record; the "Proposed change" section documents what shipped.

Implementation: `TreeBuilder::start_template` / `end_template`
(`dom/html/insertion_mode.mbt`), the `template_insertion_modes` stack and uniform
`</template>` intercept in `dom/html/tree_builder.mbt`
(`process_token_single` + `handle_in_template`), and the `template` case in
`reset_insertion_mode` (`insertion_mode.mbt`). Template content is parsed as a
real but inert (`display:none`) subtree — no raw-text shortcut.

Verification (2026-07-03, via `just test-no-v8` now that #312 is unblocked):
- `dom/html/tree_builder_test.mbt` regression tests
  `tree_builder/nested template does not leak siblings out of container` and
  `tree_builder/template sibling stays in container` — green; full `dom/html`
  suite 161/161.
- Real `real-world/mdn-grid/` fixture rendered through the conformance runtime:
  `aside#main-sidebar` is a child of the grid container
  (`div.layout__2-sidebars-inline`) and lands in the 256px sidebar column
  (`x=0, width=256`), not full-width 1280 and not vanished.

Original source of the issue: the MDN `CSS grid layout` fixture
(`real-world/mdn-grid/`) rendered its left sidebar (`<aside id="main-sidebar">`)
at full width because the sidebar was hoisted out of its grid container.

---

## Root cause

Crater parses `<template>` as a **raw-text element scanned until the first
`</template>`** — `dom/html/insertion_mode.mbt` (`handle_in_head` template arm,
and the in-body metadata block) call `tokenizer.enter_raw_text_mode("template")`
and switch to `InsertionMode::Text`. The tokenizer's raw-text scan
(`dom/html/tokenizer.mbt::consume_raw_text_token`) stops at the first matching
end tag with no nesting awareness.

`<template>` is **not** a raw-text element in the spec. Its content is parsed
into a separate `content` DocumentFragment using the "in template" insertion
mode and a parallel stack of template insertion modes. Critically, templates can
**nest** (declarative shadow DOM `shadowrootmode` + lit emit nested
`<template>`s). The raw-text shortcut therefore terminates at the first *inner*
`</template>`, and the outer template's tail (e.g. a `</div>`) leaks back into
the main parser. With the grid `<div>` still in scope, that stray `</div>`
over-closes it, and subsequent siblings (the `<aside>` sidebar) are hoisted out
of the grid.

### Minimal repros (verified via the conformance WPT JS runtime)

Fully balanced, no stray tags — a spec parser keeps `#sidebar` inside the grid;
Crater hoists it out:

```html
<div style="display:grid"><main>
  <x-el><template shadowrootmode="open"><div><template><span>a</span></template></div></template></x-el>
</main><aside id="sidebar">…</aside></div>
```

Single (non-nested) template is the control and already works correctly:

```html
<div style="display:grid"><main>
  <host><template><div>x</div></template></host>
</main><aside id="sidebar">…</aside></div>
```

Diagnostic signal used: render `<div class="grid">…</div>` and check whether the
trailing `<aside>` is a **child** of the grid (correct) or a **sibling**
(hoisted/bug).

---

## Proposed change (crater-side; no `mizchi/css` change needed)

Parse template content as real DOM rather than raw text. Templates are UA
`display:none` (`renderer/renderer/style_resolve.mbt:531`) and already scope
boundaries (`tree_builder.mbt::is_scope_boundary` includes `template`), so a
properly-stacked template neither renders nor leaks stray end tags.

1. **Start tag** (`<template>`): create + `insert_element` the element (so it is
   pushed onto `open_elements`), and do **not** enter raw-text / `Text` mode.
   Continue parsing content. Affected sites:
   - `handle_in_head` template arm (`insertion_mode.mbt` ~line 102)
   - in-body metadata block — split `template` out of the
     `"base" | … | "template" | "title"` arm into its own arm
     (`insertion_mode.mbt` ~line 206/213)
   - the in-table / in-column-group delegations already route through
     `handle_in_head`, so they inherit the new behavior.

2. **End tag** (`</template>`): close from **any** insertion mode. Template
   content can switch the mode (a nested `<table>` → InTable, `<select>` →
   InSelect, …); if the close tag is handled only in InBody/InHead, those modes
   swallow it and the template stays open, absorbing the rest of the document
   into a `display:none` subtree (this is the regression the prototype hit on the
   full MDN fixture — the sidebar vanished entirely instead of being hoisted).

   The robust shape is a uniform intercept at the top of
   `process_token_single` (`tree_builder.mbt`):

   ```
   if token is Token::EndTag("template") && self.has_element_in_scope("template") {
     self.flush_pending_text()
     self.generate_implied_end_tags()
     self.pop_until("template")
     self.reset_insertion_mode()
     return
   }
   ```

3. **Insertion-mode fidelity.** The prototype above fixed every isolated repro
   but still regressed the full MDN document, because a single uniform intercept
   is **not** equivalent to the spec's template-insertion-mode stack. The proper
   implementation needs:
   - an `InsertionMode::InTemplate` plus a `template_insertion_modes` stack
     (push on `<template>` start, pop on end), driving `reset_insertion_mode`'s
     `template` case (currently absent — it falls through to body/html);
   - template content inserted into the template element's content fragment, with
     foster-parenting suppressed inside templates;
   - the in-table/in-row/in-cell/in-select/in-caption/in-column-group handlers'
     `<template>` start and `</template>` end cases wired to the in-head rules,
     per spec.

   Without this, mode-switching content inside one of MDN's ~15 top-level
   (some nested) declarative-shadow templates leaves a template open and the
   `<aside>` is consumed. The uniform intercept is a good first step but is not
   sufficient on its own.

---

## Test-environment blocker (resolved)

Originally the `dom` package's own test suite could not run in the web sandbox:
the workspace pulls `mizchi/v8` (via `browser/native` and `testing`), whose
postadd / consumer prebuild `git clone`s `denoland/rusty_v8`, aborting `moon
test` at dependency resolution before any test runs.

This is now unblocked (crater #312): `just test-no-v8 -p mizchi/crater-dom/html`
(→ `scripts/moon-test-no-v8.sh`, which drops the two v8-pulling members via
`scripts/ci/drop-v8-members.sh`) runs the `dom/html` suite without touching v8.
The template fix above was validated with it.

The **conformance** module (`conformance/`, its own `moon.mod.json`, no v8) is
still the path for whole-fixture render checks:

```
cd conformance && moon build --target js --release --warn-list -27-29
# -> conformance/_build/js/release/build/wpt/wpt.js exports renderHtmlToJsonForWpt(html, w, h)
```

---

## Acceptance checks for the follow-up

- The two minimal repros above: trailing `<aside>` is a **child** of the grid.
- `real-world/mdn-grid/` : `aside#main-sidebar` exists, is a grid child, and the
  `var(--layout-2-sidebars)` grid places it in the ~240px sidebar column (not
  full-width 1280, not vanished).
- No regression in `dom/html/*_test.mbt` and the `wpt/dom/` baseline.
- A new `dom/html` test pinning nested-template containment (a `<template>`
  containing a `<template>` does not leak end tags to the outer document).
