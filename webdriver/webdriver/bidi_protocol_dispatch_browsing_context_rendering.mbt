///|
/// Dispatch browsingContext rendering and VRT-oriented commands.
fn BidiProtocol::dispatch_browsing_context_rendering(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Bool {
  match action {
    "captureScreenshot" => {
      self.handle_capture_screenshot(request)
      true
    }
    "captureScreenshotData" => {
      self.handle_capture_screenshot_data(request.id, request.params)
      true
    }
    "capturePaintData" => {
      self.handle_capture_paint_data(request.id, request.params)
      true
    }
    "capturePaintTree" => {
      self.handle_capture_paint_tree(request.id, request.params)
      true
    }
    "getResponsiveBreakpoints" => {
      self.handle_get_responsive_breakpoints(request.id, request.params)
      true
    }
    "getCssRuleViewportMap" => {
      self.handle_get_css_rule_viewport_map(request.id, request.params)
      true
    }
    "getCssRuleUsage" => {
      self.handle_get_css_rule_usage(request.id, request.params)
      true
    }
    "getRequiredTestViewports" => {
      self.handle_get_required_test_viewports(request.id, request.params)
      true
    }
    "batchRender" => {
      self.handle_batch_render(request.id, request.params)
      true
    }
    "getComputedStyles" => {
      self.handle_get_computed_styles(request.id, request.params)
      true
    }
    "getAllComputedStyles" => {
      self.handle_get_all_computed_styles(request.id, request.params)
      true
    }
    "getComputedStylesWithState" => {
      self.handle_get_computed_styles_with_state(request.id, request.params)
      true
    }
    "print" => {
      self.handle_print(request)
      true
    }
    "printData" => {
      self.handle_print_data(request.id, request.params)
      true
    }
    "locateNodes" => {
      self.handle_locate_nodes(request)
      true
    }
    "setViewport" => {
      self.handle_set_viewport(request)
      true
    }
    "traverseHistory" => {
      self.handle_traverse_history(request)
      true
    }
    _ => false
  }
}
