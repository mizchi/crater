///|
// Incremental (scoped) cascade — Phase 1. See docs/incremental-cascade-design.md.
//
// A dynamic re-render rebuilds the styled node tree from the mutated document
// and re-runs the full O(n) cascade even when almost nothing changed. When the
// shell installs a prior-style map (via `cascade_reuse_begin`) for a reflow
// whose stylesheet is *reuse-safe* (no sibling/positional/:has/:empty selectors
// — `css_allows_cascade_reuse`), this lets an element whose own cascade inputs
// are unchanged **and** whose whole ancestor chain is unchanged reuse its prior
// computed style instead of re-running selector matching + StyleBuilder.
//
// Correctness (proved inductively):
//   - key: `owner_id`, the structural path already threaded through the build
//     (matches the anonymous-node uid scheme), so a stable position ⇒ stable key;
//   - a node is *clean* iff the stylesheet is reuse-safe, its input signature is
//     unchanged, and its parent is clean (root is the base case). The clean
//     chain means every ancestor's inputs are unchanged, so descendant/child
//     combinators and inherited context (style + css vars) are all unchanged;
//   - reuse-safe excludes exactly the selectors whose match can flip without a
//     change in the element's own inputs or its ancestors' inputs: sibling
//     (`+`/`~`), positional (`:nth`/`:first`/`:last`/`:only`), `:has`,
//     `:empty`/`:blank`, `:focus-within`.
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
) -> Unit {
  cascade_reuse_ctx.val = Some({
    prior_styles,
    prior_sigs,
    new_styles: {},
    new_sigs: {},
    clean: {},
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
fn cascade_reuse_sig(elem : @html.Element) -> String {
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
      let sig = cascade_reuse_sig(elem)
      ctx.new_sigs[owner_id] = sig
      let parent_clean = match cascade_reuse_parent_key(owner_id) {
        None => true // root: no parent constraint
        Some(pk) => ctx.clean.get(pk) is Some(true)
      }
      if parent_clean && ctx.prior_sigs.get(owner_id) is Some(prior_sig) {
        if prior_sig == sig {
          match ctx.prior_styles.get(owner_id) {
            Some(style) => {
              ctx.clean[owner_id] = true
              ctx.new_styles[owner_id] = style
              ctx.reused += 1
              return Some(style)
            }
            None => ()
          }
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
  let unsafe_tokens = [
    "+", "~", ":nth", ":has", ":empty", ":blank", ":first-child", ":last-child",
    ":only-child", "-of-type", ":focus-within", "::",
  ]
  for text in texts {
    for tok in unsafe_tokens {
      if text.contains(tok) {
        return false
      }
    }
  }
  true
}
