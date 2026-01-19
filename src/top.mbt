// =============================================================================
// Layout Dispatcher
// =============================================================================

///|
/// Compute layout for a node tree with given viewport
/// Dispatches to the appropriate layout algorithm based on display type
pub fn compute_layout(
  node : @node.Node,
  viewport : @types.Size[Double],
) -> @node.Layout {
  let ctx : @node.LayoutContext = {
    available_width: viewport.width,
    available_height: Some(viewport.height),
    sizing_mode: @node.MaxContent,
    viewport_width: viewport.width,
    viewport_height: viewport.height,
  }
  dispatch_compute(node, ctx)
}

///|
/// Compute layout with warnings
pub fn compute_layout_with_warnings(
  node : @node.Node,
  viewport : @types.Size[Double],
) -> @node.LayoutResult {
  let ctx : @node.LayoutContext = {
    available_width: viewport.width,
    available_height: Some(viewport.height),
    sizing_mode: @node.MaxContent,
    viewport_width: viewport.width,
    viewport_height: viewport.height,
  }
  dispatch_compute_with_warnings(node, ctx)
}

///|
/// Dispatch to appropriate layout algorithm based on display type
fn dispatch_compute(
  node : @node.Node,
  ctx : @node.LayoutContext,
) -> @node.Layout {
  match node.style.display {
    @types.Flex | @types.InlineFlex => @flex.compute(node, ctx)
    @types.Block | @types.Inline | @types.InlineBlock | @types.FlowRoot =>
      @block.compute(node, ctx)
    @types.Grid | @types.InlineGrid =>
      @grid.compute_grid_layout(
        node,
        ctx.available_width,
        ctx.available_height.unwrap_or(0.0),
      )
    @types.Table | @types.InlineTable => @table.compute(node, ctx)
    @types.Display::None | @types.Contents =>
      {
        // display: none/contents - return zero-sized layout
        id: node.id,
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
        margin: @types.Rect::zero(),
        padding: @types.Rect::zero(),
        border: @types.Rect::zero(),
        overflow_x: @types.Visible,
        overflow_y: @types.Visible,
        children: [],
        text: node.text,
      }
    // Table sub-elements - handled as blocks when encountered outside table context
    @types.TableRow
    | @types.TableCell
    | @types.TableCaption
    | @types.TableRowGroup
    | @types.TableHeaderGroup
    | @types.TableFooterGroup
    | @types.TableColumn
    | @types.TableColumnGroup => @block.compute(node, ctx)
  }
}

///|
/// Dispatch with warnings
fn dispatch_compute_with_warnings(
  node : @node.Node,
  ctx : @node.LayoutContext,
) -> @node.LayoutResult {
  match node.style.display {
    @types.Flex | @types.InlineFlex => @flex.compute_with_warnings(node, ctx)
    @types.Block | @types.Inline | @types.InlineBlock | @types.FlowRoot =>
      @block.compute_with_warnings(node, ctx)
    @types.Grid | @types.InlineGrid => {
      let layout = @grid.compute_grid_layout(
        node,
        ctx.available_width,
        ctx.available_height.unwrap_or(0.0),
      )
      { layout, warnings: [] }
    }
    @types.Table | @types.InlineTable => {
      let layout = @table.compute(node, ctx)
      { layout, warnings: [] }
    }
    @types.Display::None | @types.Contents =>
      {
        layout: {
          id: node.id,
          x: 0.0,
          y: 0.0,
          width: 0.0,
          height: 0.0,
          margin: @types.Rect::zero(),
          padding: @types.Rect::zero(),
          border: @types.Rect::zero(),
          overflow_x: @types.Visible,
          overflow_y: @types.Visible,
          children: [],
          text: node.text,
        },
        warnings: [],
      }
    // Table sub-elements - handled as blocks when encountered outside table context
    @types.TableRow
    | @types.TableCell
    | @types.TableCaption
    | @types.TableRowGroup
    | @types.TableHeaderGroup
    | @types.TableFooterGroup
    | @types.TableColumn
    | @types.TableColumnGroup => @block.compute_with_warnings(node, ctx)
  }
}

///|
/// Compute block layout directly
pub fn compute_block_layout(
  node : @node.Node,
  ctx : @node.LayoutContext,
) -> @node.Layout {
  @block.compute(node, ctx)
}

///|
/// Compute flex layout directly
pub fn compute_flex_layout(
  node : @node.Node,
  ctx : @node.LayoutContext,
) -> @node.Layout {
  @flex.compute(node, ctx)
}

///|
/// Compute element shift (CLS)
pub fn compute_element_shift(
  before : @types.BoundingRect,
  after : @types.BoundingRect,
  viewport : @types.Size[Double],
) -> @webvitals.LayoutShift {
  @webvitals.compute_element_shift(before, after, viewport)
}

///|
/// Compute total CLS score
pub fn compute_total_cls(
  before : Array[@types.BoundingRect],
  after : Array[@types.BoundingRect],
  viewport : @types.Size[Double],
) -> Double {
  @webvitals.compute_total(before, after, viewport)
}
