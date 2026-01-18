///|
/// SplitPane - Split layout component for dividing screen into two sections

///|
/// Split direction
pub(all) enum SplitDirection {
  Horizontal // Top and bottom
  Vertical   // Left and right
}

///|
/// Split size specification
pub(all) enum SplitSize {
  Fixed(Double)      // Fixed size in characters/rows
  Percent(Double)    // Percentage of total (0.0 to 1.0)
  Flex(Double)       // Flex grow factor
}

///|
/// Calculate actual sizes for split pane
/// Returns (first_size, second_size)
pub fn calc_split_sizes(
  total : Int,
  first : SplitSize,
  second : SplitSize,
  divider_size~ : Int = 1
) -> (Int, Int) {
  let available = total - divider_size
  if available <= 0 {
    return (0, 0)
  }
  let avail = available.to_double()
  match (first, second) {
    // Both fixed
    (SplitSize::Fixed(f1), SplitSize::Fixed(f2)) => {
      let s1 = f1.to_int()
      let s2 = f2.to_int()
      // Clamp to available space
      if s1 + s2 <= available {
        (s1, s2)
      } else {
        // Proportionally reduce
        let ratio = avail / (f1 + f2)
        ((f1 * ratio).to_int(), (f2 * ratio).to_int())
      }
    }
    // First fixed, second fills remaining
    (SplitSize::Fixed(f1), SplitSize::Flex(_)) => {
      let s1 = f1.to_int().min(available)
      (s1, available - s1)
    }
    (SplitSize::Fixed(f1), SplitSize::Percent(p2)) => {
      let s1 = f1.to_int().min(available)
      let s2 = (avail * p2).to_int().min(available - s1)
      (s1, s2)
    }
    // Second fixed, first fills remaining
    (SplitSize::Flex(_), SplitSize::Fixed(f2)) => {
      let s2 = f2.to_int().min(available)
      (available - s2, s2)
    }
    (SplitSize::Percent(p1), SplitSize::Fixed(f2)) => {
      let s2 = f2.to_int().min(available)
      let s1 = (avail * p1).to_int().min(available - s2)
      (s1, s2)
    }
    // Both percent
    (SplitSize::Percent(p1), SplitSize::Percent(p2)) => {
      let total_pct = p1 + p2
      if total_pct > 0.0 {
        let s1 = (avail * p1 / total_pct).to_int()
        (s1, available - s1)
      } else {
        (available / 2, available - available / 2)
      }
    }
    // Both flex
    (SplitSize::Flex(g1), SplitSize::Flex(g2)) => {
      let total_grow = g1 + g2
      if total_grow > 0.0 {
        let s1 = (avail * g1 / total_grow).to_int()
        (s1, available - s1)
      } else {
        (available / 2, available - available / 2)
      }
    }
    // Percent and flex (treat flex as remaining)
    (SplitSize::Percent(p1), SplitSize::Flex(_)) => {
      let s1 = (avail * p1).to_int().min(available)
      (s1, available - s1)
    }
    (SplitSize::Flex(_), SplitSize::Percent(p2)) => {
      let s2 = (avail * p2).to_int().min(available)
      (available - s2, s2)
    }
  }
}

///|
/// Horizontal split pane (top and bottom)
pub fn hsplit(
  top : Array[@tui.Component],
  bottom : Array[@tui.Component],
  total_height : Int,
  top_size : SplitSize,
  bottom_size : SplitSize,
  divider? : Option[@tui.Component] = None,
  divider_size? : Int = 1
) -> @tui.Component {
  let (top_h, bottom_h) = calc_split_sizes(
    total_height,
    top_size,
    bottom_size,
    divider_size~,
  )
  let divider_component = match divider {
    Some(d) => d
    None => hdivider()
  }
  @tui.box(
    [
      @tui.box(top, height=@types.Dimension::Length(top_h.to_double())),
      divider_component,
      @tui.box(bottom, height=@types.Dimension::Length(bottom_h.to_double())),
    ],
    flex_direction=@style.FlexDirection::Column,
    height=@types.Dimension::Length(total_height.to_double()),
  )
}

///|
/// Vertical split pane (left and right)
pub fn vsplit(
  left : Array[@tui.Component],
  right : Array[@tui.Component],
  total_width : Int,
  left_size : SplitSize,
  right_size : SplitSize,
  divider? : Option[@tui.Component] = None,
  divider_size? : Int = 1
) -> @tui.Component {
  let (left_w, right_w) = calc_split_sizes(
    total_width,
    left_size,
    right_size,
    divider_size~,
  )
  let divider_component = match divider {
    Some(d) => d
    None => vdivider()
  }
  @tui.box(
    [
      @tui.box(left, width=@types.Dimension::Length(left_w.to_double())),
      divider_component,
      @tui.box(right, width=@types.Dimension::Length(right_w.to_double())),
    ],
    flex_direction=@style.FlexDirection::Row,
    width=@types.Dimension::Length(total_width.to_double()),
  )
}

///|
/// Simple horizontal split with fixed bottom height
pub fn hsplit_fixed_bottom(
  top : Array[@tui.Component],
  bottom : Array[@tui.Component],
  total_height : Int,
  bottom_height : Int,
  divider? : Option[@tui.Component] = None
) -> @tui.Component {
  hsplit(
    top,
    bottom,
    total_height,
    SplitSize::Flex(1.0),
    SplitSize::Fixed(bottom_height.to_double()),
    divider~,
  )
}

///|
/// Simple horizontal split with fixed top height
pub fn hsplit_fixed_top(
  top : Array[@tui.Component],
  bottom : Array[@tui.Component],
  total_height : Int,
  top_height : Int,
  divider? : Option[@tui.Component] = None
) -> @tui.Component {
  hsplit(
    top,
    bottom,
    total_height,
    SplitSize::Fixed(top_height.to_double()),
    SplitSize::Flex(1.0),
    divider~,
  )
}

///|
/// Simple vertical split with fixed left width
pub fn vsplit_fixed_left(
  left : Array[@tui.Component],
  right : Array[@tui.Component],
  total_width : Int,
  left_width : Int,
  divider? : Option[@tui.Component] = None
) -> @tui.Component {
  vsplit(
    left,
    right,
    total_width,
    SplitSize::Fixed(left_width.to_double()),
    SplitSize::Flex(1.0),
    divider~,
  )
}

///|
/// Simple vertical split with fixed right width
pub fn vsplit_fixed_right(
  left : Array[@tui.Component],
  right : Array[@tui.Component],
  total_width : Int,
  right_width : Int,
  divider? : Option[@tui.Component] = None
) -> @tui.Component {
  vsplit(
    left,
    right,
    total_width,
    SplitSize::Flex(1.0),
    SplitSize::Fixed(right_width.to_double()),
    divider~,
  )
}
