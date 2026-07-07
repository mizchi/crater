///|
/// Incremental cascade — functional pseudo-classes `:not()` / `:is()` /
/// `:where()`. No new machinery: they are transparent to the substring guards,
/// so their argument's features route to the right gate — `:not(.x)` keys on the
/// element signature, `:is(.a .b)` on the ancestor-clean chain, and any unsafe
/// feature nested inside (e.g. `:not(:has(.x))`) trips the same disqualifier as
/// at top level. These tests confirm equivalence to a full rebuild. Uses
/// `cascade_reuse_equiv` from cascade_reuse_wbtest.mbt.

///|
test "cascade reuse :not: a class flip under :not(...) matches full (own-input)" {
  // `.item:not(.muted)` keys on the element's own class list, which is in the
  // signature — losing `.muted` must recompute it.
  let css = ".item{color:#111111}.item:not(.muted){color:#0000ff;padding:5px}"
  let v1 = "<html><head><style>" +
    css +
    "</style></head><body><span class=\"item muted\">a</span></body></html>"
  let v2 = "<html><head><style>" +
    css +
    "</style></head><body><span class=\"item\">a</span></body></html>"
  let (equal, _) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
}

///|
test "cascade reuse :is: an ancestor class flip under :is(...) matches full" {
  // `:is(.on, .active) .item` — the descendant `.item` depends on an ancestor
  // matching `:is(...)`; the ancestor-clean chain must invalidate it.
  let css = ".item{color:#111111}:is(.on, .active) .item{color:#00aa00;padding:6px}"
  let v1 = "<html><head><style>" +
    css +
    "</style></head><body><div class=\"wrap\"><span class=\"item\">a</span></div></body></html>"
  let v2 = "<html><head><style>" +
    css +
    "</style></head><body><div class=\"wrap on\"><span class=\"item\">a</span></div></body></html>"
  let (equal, _) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
}

///|
test "cascade reuse :not(:has()): a :has inside :not is disqualified and matches full" {
  // The `:has` inside `:not` still trips the guard, so the whole sheet is
  // disqualified (`:has` is not reuse-supported — a subtree-clean pre-pass was
  // measured as a net loss; see docs/incremental-cascade-design.md). The sheet
  // therefore falls back to a full cascade and must still render correctly.
  let css = ".card{color:#111111}.card:not(:has(.badge)){color:#0000ff;padding:5px}"
  let v1 = "<html><head><style>" +
    css +
    "</style></head><body><div class=\"card\"><span class=\"badge\">b</span></div></body></html>"
  let v2 = "<html><head><style>" +
    css +
    "</style></head><body><div class=\"card\"><span class=\"label\">l</span></div></body></html>"
  let (equal, _) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
}

///|
test "cascade reuse :not: a :not(...) sheet still reuses on a text edit" {
  let css = ".item{color:#111111}.item:not(.muted){color:#0000ff;padding:5px}"
  let v1 = "<html><head><style>" +
    css +
    "</style></head><body><span class=\"item\">a</span><span class=\"other\">x</span></body></html>"
  let v2 = "<html><head><style>" +
    css +
    "</style></head><body><span class=\"item\">a</span><span class=\"other\">x changed</span></body></html>"
  let (equal, reused) = cascade_reuse_equiv(v1, v2)
  inspect(equal, content="true")
  inspect(reused > 0, content="true")
}
