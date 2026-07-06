///|
/// Incremental (scoped) cascade — Phase 1 equivalence + engagement tests.
///
/// Correctness is a pure render property: with cascade reuse ON, rendering v2
/// after v1 (so unchanged subtrees reuse prior computed styles) must be
/// byte-identical to a full from-scratch render of v2. The engagement assertions
/// (`cascade_reuse_last_count`) guard against a silently-disabled fast path
/// reading as a pass. See docs/incremental-cascade-design.md.

///|
/// Render `v2` on a full-rebuild browser; render `v2` on a reuse browser that
/// first rendered `v1` (populating the prior-style maps). Returns
/// (incremental == full, reused-count-on-the-v2-render).
fn cascade_reuse_equiv(v1 : String, v2 : String) -> (Bool, Int) {
  let full = Browser::new(400, 300)
  full.set_html_content(v2)
  full.parsed_doc = Some(@html.parse_document(v2))
  let want = full.render_text_full_page()

  // Reuse: render v1 (records prior styles), then re-render v2.
  let incr = Browser::new(400, 300)
  incr.set_cascade_reuse(true)
  incr.set_html_content(v1)
  incr.parsed_doc = Some(@html.parse_document(v1))
  let _ = incr.render_text_full_page()
  incr.set_html_content(v2)
  incr.clear_render_cache()
  incr.parsed_doc = Some(@html.parse_document(v2))
  let got = incr.render_text_full_page()
  (got == want, incr.cascade_reuse_last_count())
}

///|
/// A reuse-safe stylesheet (only class / tag / descendant selectors) wrapping a
/// two-column structure. `t1` / `t2` are the two cells' text.
fn cascade_reuse_page(t1 : String, t2 : String, extra_css : String) -> String {
  "<html><head><style>" +
  ".box{color:#112233;padding:4px}.row .cell{margin:2px;color:#334455}" +
  extra_css +
  "</style></head><body>" +
  "<div class=\"row\"><div class=\"box\"><span class=\"cell\">" +
  t1 +
  "</span></div><div class=\"box\"><span class=\"cell\">" +
  t2 +
  "</span></div></div></body></html>"
}

///|
test "cascade reuse: a text-only change matches a full rebuild and engages" {
  let v1 = cascade_reuse_page("a", "b", "")
  let v2 = cascade_reuse_page("aaa changed", "b", "")
  let (equal, reused) = cascade_reuse_equiv(v1, v2)
  // Byte-identical to a full rebuild.
  inspect(equal, content="true")
  // The fast path actually engaged: unchanged subtrees reused prior styles.
  inspect(reused > 0, content="true")
}

///|
test "cascade reuse: a :empty rule disables reuse but still matches" {
  // `:empty` makes a text edit able to flip a match, so the guard must fall back
  // to a full cascade. Output still matches; reuse must not have engaged.
  let v1 = cascade_reuse_page("a", "b", ".box:empty{color:#ff0000}")
  let v2 = cascade_reuse_page("aaa changed", "b", ".box:empty{color:#ff0000}")
  let (equal, reused) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
  inspect(reused, content="0")
}

///|
test "cascade reuse: a class change re-cascades and matches a full rebuild" {
  // The mutated element's class changes (its style must be recomputed); the
  // unchanged sibling may still reuse. Output must match a full rebuild.
  let v1 = cascade_reuse_page("a", "b", ".hot{color:#00ff00;padding:20px}")
  let v2 = "<html><head><style>.box{color:#112233;padding:4px}.row .cell{margin:2px;color:#334455}.hot{color:#00ff00;padding:20px}</style></head><body>" +
    "<div class=\"row\"><div class=\"box hot\"><span class=\"cell\">a</span></div><div class=\"box\"><span class=\"cell\">b</span></div></div></body></html>"
  let (equal, _) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
}

///|
test "cascade reuse: an unchanged re-render matches and reuses everything" {
  let v = cascade_reuse_page("hello", "world", "")
  let (equal, reused) = cascade_reuse_equiv(v, v)
  inspect(equal, content="true")
  inspect(reused > 0, content="true")
}

///|
/// A page with an adjacent-sibling rule `.a + .b`. `c1`/`c2` are the two
/// siblings' classes, `t` the second sibling's text.
fn cascade_reuse_sibling_page(c1 : String, c2 : String, t : String) -> String {
  "<html><head><style>.b{color:#111111}.a + .b{color:#ff0000;padding:7px}</style></head><body>" +
  "<div class=\"row\"><span class=\"" +
  c1 +
  "\">x</span><span class=\"" +
  c2 +
  "\">" +
  t +
  "</span></div></body></html>"
}

///|
test "cascade reuse: a preceding-sibling change invalidates an adjacent match" {
  // `.a + .b` — changing the FIRST sibling's class must recompute `.b` even
  // though `.b`'s own inputs are unchanged. The preceding-sibling gate must catch
  // it; reusing `.b`'s style would be a stale-style bug. Output must match full.
  let v1 = cascade_reuse_sibling_page("a", "b", "y")
  let v2 = cascade_reuse_sibling_page("z", "b", "y") // .a -> .z: .b no longer adjacent to .a
  let (equal, _) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
}

///|
test "cascade reuse: a sibling-combinator sheet still reuses on a text edit" {
  // With `+` in the sheet the preceding-sibling gate is active, but a text-only
  // edit keeps every sibling clean, so reuse still engages and matches full.
  let v1 = cascade_reuse_sibling_page("a", "b", "y")
  let v2 = cascade_reuse_sibling_page("a", "b", "yyy changed")
  let (equal, reused) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
  inspect(reused > 0, content="true")
}

///|
test "cascade reuse: a calc() plus is not mistaken for an unsafe selector" {
  // `calc(... + ...)` in a value must not disable reuse (Phase 1 wrongly did):
  // it only trips the conservative sibling gate. A text edit still reuses.
  let v1 = cascade_reuse_page("a", "b", ".box{width:calc(100px + 2px)}")
  let v2 = cascade_reuse_page(
    "aaa changed", "b", ".box{width:calc(100px + 2px)}",
  )
  let (equal, reused) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
  inspect(reused > 0, content="true")
}

///|
/// A page with a `.list .item:first-child` rule. `prepend` inserts an extra
/// leading item; `t` is appended to the first original item's text.
fn cascade_reuse_first_child_page(prepend : Bool, t : String) -> String {
  let extra = if prepend { "<div class=\"item\">new</div>" } else { "" }
  "<html><head><style>.item{color:#111111}.list .item:first-child{color:#ff0000;padding:8px}</style></head><body>" +
  "<div class=\"list\">" +
  extra +
  "<div class=\"item\">a" +
  t +
  "</div><div class=\"item\">b</div></div></body></html>"
}

///|
test "cascade reuse: :first-child survives a prepend (positional-from-start)" {
  // Prepending a sibling makes the old first child no longer `:first-child`. Its
  // owner_id (child index) shifts, so it recomputes; reusing its red style would
  // be a stale-style bug. Output must match a full rebuild.
  let v1 = cascade_reuse_first_child_page(false, "")
  let v2 = cascade_reuse_first_child_page(true, "")
  let (equal, _) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
}

///|
test "cascade reuse: a :first-child sheet still reuses on a text edit" {
  // `:first-child` is now reuse-safe; a text edit keeps positions and inputs
  // stable, so reuse engages and matches full.
  let v1 = cascade_reuse_first_child_page(false, "")
  let v2 = cascade_reuse_first_child_page(false, "xxx")
  let (equal, reused) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
  inspect(reused > 0, content="true")
}

///|
test "cascade reuse: an ancestor class change invalidates descendants (combinator)" {
  // `.active .cell` is a descendant dependency: adding `active` to the ancestor
  // must recompute the .cell descendants' style, even though the .cell elements'
  // own inputs are unchanged. The ancestor-clean chain must catch this — reusing
  // the .cell styles here would be a stale-style bug. Output must match a full
  // rebuild.
  let css = ".active .cell{color:#ff0000;padding:9px}"
  let v1 = "<html><head><style>.box{color:#112233;padding:4px}.row .cell{margin:2px}" +
    css +
    "</style></head><body><div class=\"row\"><div class=\"box\"><span class=\"cell\">a</span></div></div></body></html>"
  let v2 = "<html><head><style>.box{color:#112233;padding:4px}.row .cell{margin:2px}" +
    css +
    "</style></head><body><div class=\"row active\"><div class=\"box\"><span class=\"cell\">a</span></div></div></body></html>"
  let (equal, _) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
}
