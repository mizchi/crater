///|
/// Block layout margin collapse helpers
///
/// CSS margin collapse bookkeeping is kept separate from block layout flow.

///|
/// Collapse two margins according to CSS rules:
/// - Both positive: use the larger one
/// - Both negative: use the more negative (smaller) one
/// - Mixed: add them (positive + negative)
fn collapse_margins(m1 : Double, m2 : Double) -> Double {
  if m1 >= 0.0 && m2 >= 0.0 {
    @types.max(m1, m2)
  } else if m1 <= 0.0 && m2 <= 0.0 {
    @types.min(m1, m2)
  } else {
    m1 + m2
  }
}

///|
/// CSS margin collapse over more than two margins is not associative when
/// positive and negative margins are mixed. Keep the strongest positive and
/// strongest negative components until the collapsed value is needed.
priv struct CollapsedMargin {
  max_positive : Double
  min_negative : Double
}

///|
fn collapsed_margin_zero() -> CollapsedMargin {
  { max_positive: 0.0, min_negative: 0.0 }
}

///|
fn collapsed_margin_of(value : Double) -> CollapsedMargin {
  if value >= 0.0 {
    { max_positive: value, min_negative: 0.0 }
  } else {
    { max_positive: 0.0, min_negative: value }
  }
}

///|
fn collapsed_margin_value(margin : CollapsedMargin) -> Double {
  margin.max_positive + margin.min_negative
}

///|
fn collapsed_margin_merge(
  left : CollapsedMargin,
  right : CollapsedMargin,
) -> CollapsedMargin {
  {
    max_positive: @types.max(left.max_positive, right.max_positive),
    min_negative: @types.min(left.min_negative, right.min_negative),
  }
}

///|
fn collapsed_margin_merge_optional(
  own_margin : Double,
  escaped : CollapsedMargin?,
) -> CollapsedMargin {
  let own = collapsed_margin_of(own_margin)
  match escaped {
    Some(escaped_margin) => collapsed_margin_merge(own, escaped_margin)
    None => own
  }
}

///|
fn collapsed_margin_from_optional(value : Double?) -> CollapsedMargin? {
  match value {
    Some(v) => Some(collapsed_margin_of(v))
    None => None
  }
}
