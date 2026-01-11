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
    @style.Flex | @style.InlineFlex => @flex.compute(node, ctx)
    @style.Block | @style.Inline | @style.InlineBlock =>
      @block.compute(node, ctx)
    @style.Grid | @style.InlineGrid =>
      @grid.compute_grid_layout(
        node,
        ctx.available_width,
        ctx.available_height.unwrap_or(0.0),
      )
    @style.Table | @style.InlineTable => @table.compute(node, ctx)
    @style.None | @style.Contents =>
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
        overflow_x: @style.Visible,
        overflow_y: @style.Visible,
        children: [],
        text: node.text,
      }
    // Table sub-elements - handled as blocks when encountered outside table context
    @style.TableRow
    | @style.TableCell
    | @style.TableCaption
    | @style.TableRowGroup
    | @style.TableHeaderGroup
    | @style.TableFooterGroup
    | @style.TableColumn
    | @style.TableColumnGroup => @block.compute(node, ctx)
  }
}

///|
/// Dispatch with warnings
fn dispatch_compute_with_warnings(
  node : @node.Node,
  ctx : @node.LayoutContext,
) -> @node.LayoutResult {
  match node.style.display {
    @style.Flex | @style.InlineFlex => @flex.compute_with_warnings(node, ctx)
    @style.Block | @style.Inline | @style.InlineBlock =>
      @block.compute_with_warnings(node, ctx)
    @style.Grid | @style.InlineGrid => {
      let layout = @grid.compute_grid_layout(
        node,
        ctx.available_width,
        ctx.available_height.unwrap_or(0.0),
      )
      { layout, warnings: [] }
    }
    @style.Table | @style.InlineTable => {
      let layout = @table.compute(node, ctx)
      { layout, warnings: [] }
    }
    @style.None | @style.Contents =>
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
          overflow_x: @style.Visible,
          overflow_y: @style.Visible,
          children: [],
          text: node.text,
        },
        warnings: [],
      }
    // Table sub-elements - handled as blocks when encountered outside table context
    @style.TableRow
    | @style.TableCell
    | @style.TableCaption
    | @style.TableRowGroup
    | @style.TableHeaderGroup
    | @style.TableFooterGroup
    | @style.TableColumn
    | @style.TableColumnGroup => @block.compute_with_warnings(node, ctx)
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
