///|
// Incremental (scoped) cascade — Phases 1–4. See
// docs/incremental-cascade-design.md. Beyond the base owner_id + ancestor-clean
// model: Phase 2 = sibling combinators via the preceding-sibling gate; Phase 3 =
// positional-from-start `:first-child` / `:nth-child` via owner_id keying;
// Phase 4 = `:empty`/`:blank` and positional-from-end / only / of-type via the
// child-structure signature. Only `:has`, `:focus-within` and pseudo-elements
// remain disqualified (see `css_allows_cascade_reuse`).
//
// A dynamic re-render rebuilds the styled node tree from the mutated document
// and re-runs the full O(n) cascade even when almost nothing changed. When the
// shell installs a prior-style map (via `cascade_reuse_begin`) for a reflow
// whose stylesheet is *reuse-safe* (`css_allows_cascade_reuse`), this lets an
// element whose own cascade inputs are unchanged reuse its prior computed style
// instead of re-running selector matching + StyleBuilder.
//
// Correctness (proved inductively):
//   - key: `owner_id`, the structural path already threaded through the build
//     (matches the anonymous-node uid scheme), so a stable position ⇒ stable key;
//   - a node is *clean* iff the stylesheet is reuse-safe, its input signature is
//     unchanged, its parent is clean (root is the base case), and — when the
//     sheet uses a sibling combinator (Phase 2) — every preceding sibling is
//     clean. The ancestor chain makes descendant/child combinators and inherited
//     context (style + css vars) safe; the preceding-sibling gate makes `+`/`~`
//     safe (a changed preceding sibling flips an `X + this` / `X ~ this` match);
//   - reuse-safe (`css_allows_cascade_reuse`) still excludes the selectors whose
//     match can flip without a change captured by the owner_id / ancestor /
//     preceding-sibling model: positional-from-end / only / of-type (a sibling
//     appended after an element flips its match without changing its key), `:has`
//     (descendant dependency), `:empty`/`:blank` (child/text presence), and
//     `:focus-within`. `css_uses_sibling_combinator` flags `+`/`~` so the
//     preceding-sibling gate turns on;
//   - the stylesheet itself must be unchanged — the shell only passes a prior
//     map when the CSS signature matches (a CSS edit resets the map).
//
// Everything degrades to a normal full cascade when a node isn't clean, so a
// miss is never wrong — only slower.

///|
priv struct CascadeReuseCtx {
  prior_styles : Map[String, @style.Style]
  prior_sigs : Map[String, String]
  new_styles : Map[String, @style.Style]
  new_sigs : Map[String, String]
  clean : Map[String, Bool]
  // Phase 2: when the stylesheet uses a sibling combinator (`+`/`~`), an
  // element's match can depend on a preceding sibling, so it may only reuse when
  // every preceding sibling (same parent) is also clean. `preceding_clean` is the
  // running AND of the direct children's cleanliness, keyed by parent owner_id;
  // children are entered left-to-right so it is complete for each next sibling.
  uses_sibling : Bool
  preceding_clean : Map[String, Bool]
  // Phase 4: when the sheet uses `:empty`/`:blank` or a positional-from-end /
  // only / of-type selector, each element's signature includes a summary of its
  // direct children (see `cascade_reuse_sig`).
  uses_child_structure : Bool
  mut reused : Int
}

///|
let cascade_reuse_ctx : Ref[CascadeReuseCtx?] = { val: None }

///|
/// Start a cascade-reuse pass. `prior_styles` / `prior_sigs` are keyed by
/// `owner_id` from the previous render (pass empty maps to record-only, i.e. no
/// reuse). The build records the new styles + signatures; retrieve them with
/// `cascade_reuse_end` to seed the next reflow. Only call around a
/// `build_render_root_node` when the stylesheet is unchanged and reuse-safe.
pub fn cascade_reuse_begin(
  prior_styles : Map[String, @style.Style],
  prior_sigs : Map[String, String],
  uses_sibling? : Bool = false,
  uses_child_structure? : Bool = false,
) -> Unit {
  cascade_reuse_ctx.val = Some({
    prior_styles,
    prior_sigs,
    new_styles: {},
    new_sigs: {},
    clean: {},
    uses_sibling,
    preceding_clean: {},
    uses_child_structure,
    reused: 0,
  })
}

///|
/// End the pass: returns (new styles by owner_id, new signatures by owner_id,
/// reused count) and clears the active context. The maps become the next
/// reflow's prior maps.
pub fn cascade_reuse_end() -> (
  Map[String, @style.Style],
  Map[String, String],
  Int,
) {
  match cascade_reuse_ctx.val {
    Some(ctx) => {
      cascade_reuse_ctx.val = None
      (ctx.new_styles, ctx.new_sigs, ctx.reused)
    }
    None => ({}, {}, 0)
  }
}

///|
/// The cascade-input signature of an element: everything a reuse-safe cascade
/// keys on (tag, id, class list, inline style, attributes). Two renders with the
/// same signature at the same `owner_id` and a clean parent compute the same
/// style. Attributes are serialized in sorted order for stability.
fn cascade_reuse_sig(
  elem : @html.Element,
  include_child_structure : Bool,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string(elem.tag)
  buf.write_char('|')
  match elem.id {
    Some(id) => buf.write_string(id)
    None => ()
  }
  buf.write_char('|')
  for c in elem.classes {
    buf.write_string(c)
    buf.write_char(' ')
  }
  buf.write_char('|')
  match elem.style {
    Some(s) => buf.write_string(s)
    None => ()
  }
  buf.write_char('|')
  let keys = elem.attributes.keys().collect()
  keys.sort()
  for k in keys {
    buf.write_string(k)
    buf.write_char('=')
    match elem.attributes.get(k) {
      Some(v) => buf.write_string(v)
      None => ()
    }
    buf.write_char(';')
  }
  // Phase 4: when the sheet uses child-structure-dependent selectors, append a
  // summary of this element's direct children. It captures the two things those
  // selectors key on: (a) the element's own emptiness / blankness (`:empty` /
  // `:blank`), and (b) — through the *parent's* summary, which reaches children
  // via the ancestor-clean chain — the child list a positional-from-end / only /
  // of-type match reads (count, order, tags). A non-whitespace text edit that
  // keeps the same shape (`T`) leaves the summary unchanged, so text-edit reuse
  // is preserved.
  if include_child_structure {
    buf.write_char('|')
    for child in elem.children {
      match child {
        @html.Node::Element(e) => {
          buf.write_string("E:")
          buf.write_string(e.tag)
          buf.write_char(';')
        }
        @html.Node::Text(t) =>
          if t.trim().is_empty() {
            buf.write_char('W')
          } else {
            buf.write_char('T')
          }
      }
    }
  }
  buf.to_string()
}

///|
/// The `owner_id` of the parent, i.e. the path with the last `/segment` removed.
/// Returns None for a top-level key (no `/`).
fn cascade_reuse_parent_key(owner_id : String) -> String? {
  match owner_id.rev_find("/") {
    Some(idx) => Some(owner_id.substring(start=0, end=idx))
    None => None
  }
}

///|
/// If element `elem` at `owner_id` can reuse its prior computed style, return it
/// (and mark the node clean so its children may reuse too). Records the
/// signature. Returns None when there is no active reuse pass or the node isn't
/// clean — the caller then computes the style normally and must call
/// `cascade_reuse_record` with the result.
fn cascade_reuse_try(owner_id : String, elem : @html.Element) -> @style.Style? {
  match cascade_reuse_ctx.val {
    None => None
    Some(ctx) => {
      let sig = cascade_reuse_sig(elem, ctx.uses_child_structure)
      ctx.new_sigs[owner_id] = sig
      let parent = cascade_reuse_parent_key(owner_id)
      let parent_clean = match parent {
        None => true // root: no parent constraint
        Some(pk) => ctx.clean.get(pk) is Some(true)
      }
      // Own inputs unchanged and a prior style exists to reuse.
      let self_clean = match ctx.prior_sigs.get(owner_id) {
        Some(prior_sig) =>
          prior_sig == sig && ctx.prior_styles.get(owner_id) is Some(_)
        None => false
      }
      // Sibling gate (Phase 2): with `+`/`~` in the sheet, this element may only
      // reuse if every preceding sibling is clean (a changed preceding sibling
      // can flip an `X + this` / `X ~ this` match).
      let preceding_ok = if ctx.uses_sibling {
        match parent {
          None => true
          Some(pk) => not(ctx.preceding_clean.get(pk) is Some(false))
        }
      } else {
        true
      }
      let is_clean = self_clean && parent_clean && preceding_ok
      // Fold this element into its parent's running preceding-clean AND.
      match parent {
        Some(pk) => {
          let prev = match ctx.preceding_clean.get(pk) {
            Some(v) => v
            None => true
          }
          ctx.preceding_clean[pk] = prev && is_clean
        }
        None => ()
      }
      if is_clean {
        ctx.clean[owner_id] = true
        match ctx.prior_styles.get(owner_id) {
          Some(style) => {
            ctx.new_styles[owner_id] = style
            ctx.reused += 1
            return Some(style)
          }
          None => ()
        }
      }
      None
    }
  }
}

///|
/// Record a freshly-computed style for `owner_id` (the not-clean path). The
/// signature was already recorded by `cascade_reuse_try`.
fn cascade_reuse_record(owner_id : String, style : @style.Style) -> Unit {
  match cascade_reuse_ctx.val {
    Some(ctx) => ctx.new_styles[owner_id] = style
    None => ()
  }
}

///|
/// Whether the given raw CSS texts are safe for scoped cascade reuse: they must
/// use no selector whose match can flip without a change in an element's own
/// inputs or its ancestors' inputs. Conservative and cheap: a substring scan for
/// the disqualifying selector features. A false positive (e.g. `+` inside a
/// `calc()` value) only disables the optimization — never a correctness risk.
pub fn css_allows_cascade_reuse(texts : Array[String]) -> Bool {
  // NOT disqualifying:
  //   - sibling combinators (`+`/`~`) — handled by the preceding-sibling gate
  //     (`css_uses_sibling_combinator`);
  //   - `:first-child` / `:nth-child(...)` (from the *start*) — a sibling
  //     inserted before an element shifts its `owner_id` (child index) so it
  //     recomputes; one inserted after leaves its from-start position (and key)
  //     unchanged, so reuse is correct.
  //   - positional-from-*end* / only / of-type (`:last-child`, `:only-child`,
  //     `:nth-last-*`, `*-of-type`) and `:empty`/`:blank` — handled by the child
  //     structure summary (see `css_uses_child_structure` / `cascade_reuse_sig`).
  // Still disqualifying — dependencies not captured by any of the above: `:has`
  // (arbitrary-depth descendant dependency, needs a subtree-clean pass),
  // `:focus-within` (descendant focus state), and pseudo-elements.
  let unsafe_tokens = [":has", ":focus-within", "::"]
  for text in texts {
    for tok in unsafe_tokens {
      if text.contains(tok) {
        return false
      }
    }
  }
  true
}

///|
/// Whether any CSS text uses a selector whose match depends on child structure:
/// `:empty`/`:blank` (own child/text presence) or positional-from-end / only /
/// of-type (`:last-child`, `:only-child`, `:nth-last-*`, `*-of-type` — read the
/// parent's child list). When true, each element's reuse signature includes a
/// summary of its direct children. Conservative substring scan; a false positive
/// only tightens reuse.
pub fn css_uses_child_structure(texts : Array[String]) -> Bool {
  let tokens = [
    ":empty", ":blank", ":last-child", ":only-child", ":nth-last", "-of-type",
  ]
  for text in texts {
    for tok in tokens {
      if text.contains(tok) {
        return true
      }
    }
  }
  false
}

///|
/// Whether any CSS text uses a sibling combinator (`+` or `~`). Conservative: a
/// substring match (so `calc(a + b)` or `[attr~=v]` also counts) — a false
/// positive only tightens the preceding-sibling gate, never a correctness risk.
/// When true, cascade reuse requires every preceding sibling to be clean.
pub fn css_uses_sibling_combinator(texts : Array[String]) -> Bool {
  for text in texts {
    if text.contains("+") || text.contains("~") {
      return true
    }
  }
  false
}
