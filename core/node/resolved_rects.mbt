///|
/// A node's `padding` / `margin` / `border`, resolved to pixels.
pub(all) struct ResolvedRects {
  padding : @types.Rect[Double]
  margin : @types.Rect[Double]
  border : @types.Rect[Double]
}

///|
/// Whether `dim` resolves to the same length whatever containing-block basis it
/// is given, i.e. whether `Dimension::resolve_or(dim, basis, 0.0)` reads `basis`.
///
/// The three forms that read it are `Percent`, `Calc` (which carries a
/// percentage ratio beside its fixed part) and `MathFn` (which mixes lengths and
/// percentages that cannot be ordered without a basis). `Calc` with a ratio of
/// zero would resolve to its fixed part alone, but `mizchi/css` keeps a
/// pure-length `calc()` as a `Length`, so that form does not arise — and reading
/// the basis even to multiply it by zero would propagate a non-finite width.
fn dimension_ignores_basis(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Length(_)
    | @types.Auto
    | @types.MinContent
    | @types.MaxContent
    | @types.FitContent(_) => true
    @types.Percent(_) | @types.Calc(_, _) | @types.MathFn(_, _) => false
  }
}

///|
fn rect_ignores_basis(rect : @types.Rect[@types.Dimension]) -> Bool {
  dimension_ignores_basis(rect.left) &&
  dimension_ignores_basis(rect.right) &&
  dimension_ignores_basis(rect.top) &&
  dimension_ignores_basis(rect.bottom)
}

///|
/// Resolve this node's `padding` / `margin` / `border` against `parent_width`,
/// keeping the answer on the node when it does not depend on that width.
///
/// Layout asks for these three rects constantly: a CPU/heap profile of a
/// 2.5k-node render had `@types.resolve_rect` as the single largest allocator of
/// the whole layout phase (~21% of sampled bytes, ~14k calls per render), each
/// call materializing a fresh `Rect[Double]`. In that document *every* one of
/// those calls resolved a rect whose sides were all plain lengths — so the
/// result did not depend on `parent_width` at all and the allocation was pure
/// waste on every visit after the first.
///
/// `Node::style` is immutable, so a memo attached to the node stays correct for
/// as long as the node lives, no matter which width a later caller passes. A
/// rect that genuinely reads the width (a percentage, a mixed `calc()`, a
/// `min()`/`max()`/`clamp()`) is resolved on every call as before, and never
/// memoized.
pub fn Node::resolved_rects(
  self : Node,
  parent_width : Double,
) -> ResolvedRects {
  match self.resolved_rects_memo {
    Some(memo) => memo
    None => {
      let style = self.style
      let resolved : ResolvedRects = {
        padding: @types.resolve_rect(style.padding, parent_width),
        margin: @types.resolve_rect(style.margin, parent_width),
        border: @types.resolve_rect(style.border, parent_width),
      }
      if rect_ignores_basis(style.padding) &&
        rect_ignores_basis(style.margin) &&
        rect_ignores_basis(style.border) {
        self.resolved_rects_memo = Some(resolved)
      }
      resolved
    }
  }
}
