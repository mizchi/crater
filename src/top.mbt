// =============================================================================
// Layout Dispatcher
// =============================================================================

///|
/// Default dispatch for top module
fn default_dispatch() -> @node.DispatchFn {
  @node.DispatchFn(fn(node, ctx, dispatch) {
    @dispatch.compute(node, ctx, dispatch)
  })
}

///|
/// Compute layout for a node tree with given viewport
/// Dispatches to the appropriate layout algorithm based on display type
pub fn compute_layout(
  node : @node.Node,
  viewport : @types.Size[Double],
) -> @types.Layout {
  let ctx : @types.LayoutContext = {
    available_width: viewport.width,
    available_height: Some(viewport.height),
    sizing_mode: @types.MaxContent,
    viewport_width: viewport.width,
    viewport_height: viewport.height,
    stretch_width: false,
    stretch_height: false,
  }
  dispatch_compute(node, ctx)
}

///|
/// Compute layout with warnings
pub fn compute_layout_with_warnings(
  node : @node.Node,
  viewport : @types.Size[Double],
) -> @types.LayoutResult {
  let ctx : @types.LayoutContext = {
    available_width: viewport.width,
    available_height: Some(viewport.height),
    sizing_mode: @types.MaxContent,
    viewport_width: viewport.width,
    viewport_height: viewport.height,
    stretch_width: false,
    stretch_height: false,
  }
  dispatch_compute_with_warnings(node, ctx)
}

///|
/// Validate a node tree against the predictable core (TUI-oriented) subset.
pub fn validate_core_subset(node : @node.Node) -> Array[@core.CoreIssue] {
  @core.validate_tui_subset(node)
}

///|
/// Compute layout only when the node tree satisfies core subset constraints.
/// Returns issues without computing if unsupported styles are present.
pub fn compute_core_layout(
  node : @node.Node,
  viewport : @types.Size[Double],
) -> @core.CoreComputeResult {
  @core.compute_if_supported(
    node,
    viewport,
    @core.LayoutComputeFn(fn(node, ctx) { @dispatch.compute_layout(node, ctx) }),
  )
}

///|
/// Dispatch to appropriate layout algorithm based on display type
fn dispatch_compute(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  let dispatch = default_dispatch()
  match node.style.display {
    @types.Flex | @types.InlineFlex => @flex.compute(node, ctx, dispatch)
    @types.Block | @types.Inline | @types.InlineBlock | @types.FlowRoot =>
      @block.compute(node, ctx, dispatch)
    @types.Grid | @types.InlineGrid =>
      @grid.compute_grid_layout(
        node,
        ctx.available_width,
        ctx.available_height.unwrap_or(0.0),
        dispatch,
      )
    @types.Table | @types.InlineTable => @table.compute(node, ctx, dispatch)
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
        scroll_width: 0.0,
        scroll_height: 0.0,
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
    | @types.TableColumnGroup => @block.compute(node, ctx, dispatch)
  }
}

///|
/// Dispatch with warnings
fn dispatch_compute_with_warnings(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.LayoutResult {
  let dispatch = default_dispatch()
  match node.style.display {
    @types.Flex | @types.InlineFlex =>
      @flex.compute_with_warnings(node, ctx, dispatch)
    @types.Block | @types.Inline | @types.InlineBlock | @types.FlowRoot =>
      @block.compute_with_warnings(node, ctx, dispatch)
    @types.Grid | @types.InlineGrid => {
      let layout = @grid.compute_grid_layout(
        node,
        ctx.available_width,
        ctx.available_height.unwrap_or(0.0),
        dispatch,
      )
      { layout, warnings: [] }
    }
    @types.Table | @types.InlineTable => {
      let layout = @table.compute(node, ctx, dispatch)
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
          scroll_width: 0.0,
          scroll_height: 0.0,
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
    | @types.TableColumnGroup =>
      @block.compute_with_warnings(node, ctx, dispatch)
  }
}

///|
/// Compute block layout directly
pub fn compute_block_layout(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  @block.compute(node, ctx, default_dispatch())
}

///|
/// Compute flex layout directly
pub fn compute_flex_layout(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  @flex.compute(node, ctx, default_dispatch())
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
