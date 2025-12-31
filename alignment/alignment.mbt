///|
/// Shared alignment computation functions for Flex and Grid layouts

///|
/// Compute justify-content positioning for distributing items along an axis
/// Returns (start_offset, gap_between_items)
pub fn compute_justify(
  justify : @style.Alignment,
  free_space : Double,
  item_count : Int
) -> (Double, Double) {
  if item_count == 0 {
    return (0.0, 0.0)
  }
  // CSS spec: when free_space is negative, SpaceBetween/SpaceAround/SpaceEvenly
  // behave like Start (items packed at start, no gap distribution)
  if free_space < 0.0 {
    match justify {
      @style.SpaceBetween | @style.SpaceAround | @style.SpaceEvenly =>
        return (0.0, 0.0)
      _ => ()
    }
  }
  match justify {
    @style.Start => (0.0, 0.0)
    @style.End => (free_space, 0.0)
    @style.Center => (free_space / 2.0, 0.0)
    @style.SpaceBetween =>
      if item_count == 1 {
        (0.0, 0.0)
      } else {
        (0.0, free_space / (item_count - 1).to_double())
      }
    @style.SpaceAround => {
      let gap = free_space / item_count.to_double()
      (gap / 2.0, gap)
    }
    @style.SpaceEvenly => {
      let gap = free_space / (item_count + 1).to_double()
      (gap, gap)
    }
    @style.Stretch => (0.0, 0.0) // Stretch doesn't apply to main axis
    @style.Baseline => (0.0, 0.0) // Baseline doesn't apply to justify-content
  }
}

///|
/// Compute alignment offset for a single item
/// Used for align-items, align-self, justify-self
pub fn compute_align_offset(
  align : @style.Alignment,
  free_space : Double
) -> Double {
  if free_space <= 0.0 {
    return 0.0
  }
  match align {
    @style.Start => 0.0
    @style.End => free_space
    @style.Center => free_space / 2.0
    @style.SpaceBetween => 0.0 // Treat as start for single item
    @style.SpaceAround => free_space / 2.0 // Center for single item
    @style.SpaceEvenly => free_space / 2.0 // Center for single item
    @style.Stretch => 0.0 // Stretch handled elsewhere
    @style.Baseline => 0.0 // Baseline handled elsewhere
  }
}

///|
/// Compute alignment offset for align-self (child's override of parent's align-items)
pub fn compute_align_self_offset(
  align_self : @style.AlignSelf,
  parent_align : @style.Alignment,
  free_space : Double
) -> Double {
  if free_space <= 0.0 {
    return 0.0
  }
  match align_self {
    @style.AlignSelf::Auto => compute_align_offset(parent_align, free_space)
    @style.AlignSelf::Start => 0.0
    @style.AlignSelf::End => free_space
    @style.AlignSelf::Center => free_space / 2.0
    @style.AlignSelf::Stretch => 0.0 // Stretch handled elsewhere
  }
}
