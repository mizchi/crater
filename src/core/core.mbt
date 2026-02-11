///|
/// Shared alignment computation functions for Box/Flex/Grid layouts.
/// This package is intentionally pure and stateless so it can be reused
/// independently from full layout implementations.

///|
/// Compute justify-content positioning for distributing items along an axis.
/// Returns (start_offset, gap_between_items).
/// Note: FlexStart/FlexEnd should be resolved by caller when wrap-reverse
/// behavior needs physical flipping.
pub fn compute_justify(
  justify : @types.Alignment,
  free_space : Double,
  item_count : Int,
) -> (Double, Double) {
  if item_count == 0 {
    return (0.0, 0.0)
  }

  // CSS spec: when free_space is negative, space-* alignments fall back to start.
  if free_space < 0.0 {
    match justify {
      @types.SpaceBetween | @types.SpaceAround | @types.SpaceEvenly =>
        return (0.0, 0.0)
      _ => ()
    }
  }

  match justify {
    @types.Start | @types.FlexStart => (0.0, 0.0)
    @types.End | @types.FlexEnd => (free_space, 0.0)
    @types.Center => (free_space / 2.0, 0.0)
    @types.SpaceBetween =>
      if item_count == 1 {
        (0.0, 0.0)
      } else {
        (0.0, free_space / (item_count - 1).to_double())
      }
    @types.SpaceAround => {
      let gap = free_space / item_count.to_double()
      (gap / 2.0, gap)
    }
    @types.SpaceEvenly => {
      let gap = free_space / (item_count + 1).to_double()
      (gap, gap)
    }
    @types.Stretch => (0.0, 0.0)
    @types.Baseline => (0.0, 0.0)
  }
}

///|
/// Compute alignment offset for a single item.
/// Used for align-items, align-self, justify-self.
pub fn compute_align_offset(
  align : @types.Alignment,
  free_space : Double,
) -> Double {
  if free_space <= 0.0 {
    return 0.0
  }
  match align {
    @types.Start | @types.FlexStart => 0.0
    @types.End | @types.FlexEnd => free_space
    @types.Center => free_space / 2.0
    @types.SpaceBetween => 0.0
    @types.SpaceAround => free_space / 2.0
    @types.SpaceEvenly => free_space / 2.0
    @types.Stretch => 0.0
    @types.Baseline => 0.0
  }
}

///|
/// Compute alignment offset for align-self (child override of parent align-items).
pub fn compute_align_self_offset(
  align_self : @types.AlignSelf,
  parent_align : @types.Alignment,
  free_space : Double,
) -> Double {
  if free_space <= 0.0 {
    return 0.0
  }
  match align_self {
    @types.AlignSelf::Auto => compute_align_offset(parent_align, free_space)
    @types.AlignSelf::Start => 0.0
    @types.AlignSelf::End => free_space
    @types.AlignSelf::Center => free_space / 2.0
    @types.AlignSelf::Stretch => 0.0
    @types.AlignSelf::Baseline => 0.0
  }
}
