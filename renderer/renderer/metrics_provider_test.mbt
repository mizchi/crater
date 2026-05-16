///|
// Renderer metrics provider regression tests split from renderer_test.mbt.

///|
#cfg(target="js")
extern "js" fn set_builtin_text_advance_ratio_override_for_test(
  ratio : Double,
) -> Unit =
  #|(ratio) => {
  #|  globalThis.__craterBuiltinTextAdvanceRatio = ratio;
  #|}

///|
#cfg(not(target="js"))
fn set_builtin_text_advance_ratio_override_for_test(ratio : Double) -> Unit {
  @renderer.set_builtin_text_advance_ratio_override_for_test(ratio)
}

///|
#cfg(target="js")
extern "js" fn clear_builtin_text_advance_ratio_override_for_test() -> Unit =
  #|() => {
  #|  delete globalThis.__craterBuiltinTextAdvanceRatio;
  #|}

///|
#cfg(not(target="js"))
fn clear_builtin_text_advance_ratio_override_for_test() -> Unit {
  @renderer.clear_builtin_text_advance_ratio_override_for_test()
}

///|
test "custom text metrics provider overrides text measurement" {
  @renderer.clear_text_metrics_provider()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="test">abc</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let default_node = @renderer.render_to_node(html, ctx)
  let default_text = default_node.children[0].children[0]
  inspect(default_text.id, content="#text")
  let default_intrinsic = match default_text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @layout_types.IntrinsicSize::default()
  }
  inspect(
    default_intrinsic.max_width == 24.0,
    content=(
      #|true
    ),
  )

  let provider = @renderer.TextMetricsProvider::new(fn(
    _text : String,
    _font_size : Double,
    _line_height : Double,
    _white_space : @style.WhiteSpace,
    _writing_mode : @style.WritingMode,
    _font_weight : Double,
    _font_family : String,
  ) -> @layout_types.MeasureFunc {
    {
      func: fn(
        _available_width : Double,
        _available_height : Double,
      ) -> @layout_types.IntrinsicSize {
        {
          min_width: 123.0,
          max_width: 123.0,
          min_height: 45.0,
          max_height: 45.0,
        }
      },
    }
  })
  @renderer.set_text_metrics_provider(provider)

  let overridden_node = @renderer.render_to_node(html, ctx)
  let overridden_text = overridden_node.children[0].children[0]
  let overridden_intrinsic = match overridden_text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @layout_types.IntrinsicSize::default()
  }
  inspect(overridden_intrinsic.max_width, content="123")
  inspect(overridden_intrinsic.max_height, content="45")
  @renderer.clear_text_metrics_provider()
}

///|
test "clear text metrics provider restores default text measurement" {
  @renderer.clear_text_metrics_provider()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="test">abc</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()

  let provider = @renderer.TextMetricsProvider::new(fn(
    _text : String,
    _font_size : Double,
    _line_height : Double,
    _white_space : @style.WhiteSpace,
    _writing_mode : @style.WritingMode,
    _font_weight : Double,
    _font_family : String,
  ) -> @layout_types.MeasureFunc {
    {
      func: fn(
        _available_width : Double,
        _available_height : Double,
      ) -> @layout_types.IntrinsicSize {
        {
          min_width: 321.0,
          max_width: 321.0,
          min_height: 65.0,
          max_height: 65.0,
        }
      },
    }
  })
  @renderer.set_text_metrics_provider(provider)
  @renderer.clear_text_metrics_provider()

  let restored_node = @renderer.render_to_node(html, ctx)
  let restored_text = restored_node.children[0].children[0]
  let restored_intrinsic = match restored_text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @layout_types.IntrinsicSize::default()
  }
  inspect(
    restored_intrinsic.max_width == 24.0,
    content=(
      #|true
    ),
  )
}

///|
test "text metrics provider affects default text input intrinsic width" {
  @renderer.clear_text_metrics_provider()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<input id="target" type="text">
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let default_node = @renderer.render_to_node(html, ctx)
  let default_input = default_node.children[0]
  inspect(default_input.id, content="input#target")
  let default_intrinsic = match default_input.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @layout_types.IntrinsicSize::default()
  }
  inspect(
    default_intrinsic.max_width,
    content=(
      #|143
    ),
  )

  let provider = @renderer.TextMetricsProvider::new(fn(
    _text : String,
    _font_size : Double,
    _line_height : Double,
    _white_space : @style.WhiteSpace,
    _writing_mode : @style.WritingMode,
    _font_weight : Double,
    _font_family : String,
  ) -> @layout_types.MeasureFunc {
    {
      func: fn(
        _available_width : Double,
        _available_height : Double,
      ) -> @layout_types.IntrinsicSize {
        { min_width: 6.0, max_width: 6.0, min_height: 16.0, max_height: 16.0 }
      },
    }
  })
  @renderer.set_text_metrics_provider(provider)

  let overridden_node = @renderer.render_to_node(html, ctx)
  let overridden_input = overridden_node.children[0]
  let overridden_intrinsic = match overridden_input.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @layout_types.IntrinsicSize::default()
  }
  inspect(overridden_intrinsic.max_width, content="133")
  @renderer.clear_text_metrics_provider()
}

///|
test "builtin text advance ratio override affects boundary whitespace text width" {
  @renderer.clear_text_metrics_provider()
  clear_builtin_text_advance_ratio_override_for_test()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<table><tr><td>
    #|  <div style="height: 10px;"></div>
    #|  Can you see this text?
    #|</td></tr></table>
    #|</body></html>
  fn find_text_measure_with_phrase(
    node : @node.Node,
    phrase : String,
  ) -> @layout_types.MeasureFunc? {
    match node.text {
      Some(text) => if text.contains(phrase) { return node.measure }
      None => ()
    }
    for child in node.children {
      match find_text_measure_with_phrase(child, phrase) {
        Some(measure) => return Some(measure)
        None => ()
      }
    }
    None
  }
  let ctx = @renderer.RenderContext::default()
  let default_node = @renderer.render_to_node(html, ctx)
  let default_measure = match
    find_text_measure_with_phrase(default_node, "Can you see this text?") {
    Some(measure) => measure
    None => abort("expected text measure")
  }
  let default_intrinsic = (default_measure.func)(9999.0, 9999.0)
  inspect(
    default_intrinsic.max_width,
    content=(
      #|176
    ),
  )

  set_builtin_text_advance_ratio_override_for_test(0.4)
  let overridden_node = @renderer.render_to_node(html, ctx)
  let overridden_measure = match
    find_text_measure_with_phrase(overridden_node, "Can you see this text?") {
    Some(measure) => measure
    None => abort("expected overridden text measure")
  }
  let overridden_intrinsic = (overridden_measure.func)(9999.0, 9999.0)
  inspect(overridden_intrinsic.max_width, content="140.8")
  clear_builtin_text_advance_ratio_override_for_test()
}

///|
test "custom image intrinsic size provider overrides unresolved src size" {
  @renderer.clear_image_intrinsic_size_provider()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<img id="target" src="https://example.com/a.png">
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let default_node = @renderer.render_to_node(html, ctx)
  let default_img = default_node.children[0]
  inspect(default_img.id, content="img#target")
  let default_intrinsic = match default_img.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @layout_types.IntrinsicSize::default()
  }
  inspect(default_intrinsic.max_width == 0.0, content="true")
  inspect(default_intrinsic.max_height == 0.0, content="true")

  let provider = @renderer.ImageIntrinsicSizeProvider::new(fn(
    src : String,
  ) -> (Double, Double)? {
    if src.contains("example.com") {
      Some((77.0, 33.0))
    } else {
      None
    }
  })
  @renderer.set_image_intrinsic_size_provider(provider)

  let overridden_node = @renderer.render_to_node(html, ctx)
  let overridden_img = overridden_node.children[0]
  let overridden_intrinsic = match overridden_img.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @layout_types.IntrinsicSize::default()
  }
  inspect(overridden_intrinsic.max_width, content="77")
  inspect(overridden_intrinsic.max_height, content="33")
  @renderer.clear_image_intrinsic_size_provider()
}

///|
test "clear image intrinsic size provider restores default unresolved src size" {
  @renderer.clear_image_intrinsic_size_provider()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<img id="target" src="https://example.com/a.png">
    #|</body></html>
  let ctx = @renderer.RenderContext::default()

  let provider = @renderer.ImageIntrinsicSizeProvider::new(fn(
    _src : String,
  ) -> (Double, Double)? {
    Some((91.0, 52.0))
  })
  @renderer.set_image_intrinsic_size_provider(provider)
  @renderer.clear_image_intrinsic_size_provider()

  let restored_node = @renderer.render_to_node(html, ctx)
  let restored_img = restored_node.children[0]
  let restored_intrinsic = match restored_img.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @layout_types.IntrinsicSize::default()
  }
  inspect(restored_intrinsic.max_width == 0.0, content="true")
  inspect(restored_intrinsic.max_height == 0.0, content="true")
}
