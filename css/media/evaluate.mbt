///|
/// CSS Media Query Evaluation
/// Evaluates media queries against viewport dimensions

///|
/// Environment for evaluating media queries
pub struct MediaEnvironment {
  viewport_width : Double
  viewport_height : Double
  device_pixel_ratio : Double
}

///|
/// Create a default media environment for screen
pub fn MediaEnvironment::new(
  viewport_width : Double,
  viewport_height : Double,
) -> MediaEnvironment {
  { viewport_width, viewport_height, device_pixel_ratio: 1.0 }
}

///|
/// Evaluate a media query list against the environment
/// Returns true if ANY query in the list matches (OR semantics)
pub fn MediaQueryList::evaluate(
  self : MediaQueryList,
  env : MediaEnvironment,
) -> Bool {
  // Empty query list matches everything
  if self.queries.is_empty() {
    return true
  }
  // Any matching query makes the whole list match
  for query in self.queries {
    if query.evaluate(env) {
      return true
    }
  }
  false
}

///|
/// Evaluate a single media query
pub fn MediaQuery::evaluate(self : MediaQuery, env : MediaEnvironment) -> Bool {
  let result = self.evaluate_without_negation(env)
  if self.negated {
    not(result)
  } else {
    result
  }
}

///|
/// Evaluate a media query without considering negation
fn MediaQuery::evaluate_without_negation(
  self : MediaQuery,
  env : MediaEnvironment,
) -> Bool {
  // Check media type
  match self.media_type {
    Some(MediaType::Print) => return false // We're rendering to screen
    Some(MediaType::Speech) => return false
    Some(MediaType::All) | Some(MediaType::Screen) | None => ()
  }
  // Check all conditions (AND semantics)
  for condition in self.conditions {
    if not(evaluate_feature(condition, env)) {
      return false
    }
  }
  true
}

///|
/// Evaluate a single media feature
fn evaluate_feature(feature : MediaFeature, env : MediaEnvironment) -> Bool {
  match feature {
    // Width features
    MediaFeature::Width(value) =>
      match value {
        Some(v) => compare_value(v, env.viewport_width, RangeOp::Eq)
        None => true // Boolean context: width exists
      }
    MediaFeature::MinWidth(value) =>
      compare_value(value, env.viewport_width, RangeOp::Ge)
    MediaFeature::MaxWidth(value) =>
      compare_value(value, env.viewport_width, RangeOp::Le)
    MediaFeature::WidthRange(op, value) =>
      compare_value_with_op(value, env.viewport_width, op)
    // Height features
    MediaFeature::Height(value) =>
      match value {
        Some(v) => compare_value(v, env.viewport_height, RangeOp::Eq)
        None => true
      }
    MediaFeature::MinHeight(value) =>
      compare_value(value, env.viewport_height, RangeOp::Ge)
    MediaFeature::MaxHeight(value) =>
      compare_value(value, env.viewport_height, RangeOp::Le)
    MediaFeature::HeightRange(op, value) =>
      compare_value_with_op(value, env.viewport_height, op)
    // Aspect ratio
    MediaFeature::AspectRatio(value) =>
      match value {
        Some(v) =>
          compare_aspect_ratio(
            v,
            env.viewport_width,
            env.viewport_height,
            RangeOp::Eq,
          )
        None => true
      }
    MediaFeature::MinAspectRatio(value) =>
      compare_aspect_ratio(
        value,
        env.viewport_width,
        env.viewport_height,
        RangeOp::Ge,
      )
    MediaFeature::MaxAspectRatio(value) =>
      compare_aspect_ratio(
        value,
        env.viewport_width,
        env.viewport_height,
        RangeOp::Le,
      )
    // Orientation
    MediaFeature::Orientation(value) =>
      match value.to_lower() {
        "portrait" => env.viewport_height >= env.viewport_width
        "landscape" => env.viewport_width > env.viewport_height
        _ => true
      }
    // Resolution
    MediaFeature::Resolution(value) =>
      match value {
        Some(v) => compare_resolution(v, env.device_pixel_ratio, RangeOp::Eq)
        None => true
      }
    MediaFeature::MinResolution(value) =>
      compare_resolution(value, env.device_pixel_ratio, RangeOp::Ge)
    MediaFeature::MaxResolution(value) =>
      compare_resolution(value, env.device_pixel_ratio, RangeOp::Le)
    // Boolean features (always true for screen)
    MediaFeature::Color => true
    MediaFeature::ColorIndex => false
    MediaFeature::ColorGamut => true
    MediaFeature::Grid => false
    MediaFeature::Hover => true // Assume hover is available
    MediaFeature::Monochrome => false
    MediaFeature::Pointer => true // Assume pointer is available
    MediaFeature::Scripting => true
    MediaFeature::Update => true
    // Discrete features
    MediaFeature::DisplayMode(_) => true // Assume browser mode
    MediaFeature::PrefersColorScheme(_) => true // Accept any color scheme
    MediaFeature::PrefersReducedMotion(_) => true // Accept any motion preference
    // Unknown features default to true
    MediaFeature::Custom(_, _) => true
  }
}

///|
/// Convert media value to pixels
fn to_pixels(value : MediaValue) -> Double {
  match value {
    MediaValue::Number(n) => n
    MediaValue::Dimension(n, unit) =>
      match unit.to_lower() {
        "px" => n
        "em" | "rem" => n * 16.0 // Assume 16px base font size
        "vw" | "vh" => n // Would need viewport for accurate conversion
        "pt" => n * 1.333333 // 1pt = 4/3 px
        "pc" => n * 16.0 // 1pc = 16px
        "in" => n * 96.0 // 1in = 96px
        "cm" => n * 37.8 // 1cm ≈ 37.8px
        "mm" => n * 3.78 // 1mm ≈ 3.78px
        _ => n
      }
    MediaValue::Ratio(_, _) => 0.0 // Ratios aren't pixel values
    MediaValue::Ident(_) => 0.0 // Identifiers aren't pixel values
  }
}

///|
/// Compare a media value against an actual value
/// For min-X: actual >= query (Le means query <= actual)
/// For max-X: actual <= query (Ge means query >= actual)
fn compare_value(
  query_value : MediaValue,
  actual : Double,
  op : RangeOp,
) -> Bool {
  let query_pixels = to_pixels(query_value)
  match op {
    RangeOp::Eq => (actual - query_pixels).abs() < 0.01
    RangeOp::Lt => actual < query_pixels
    RangeOp::Le => actual <= query_pixels
    RangeOp::Gt => actual > query_pixels
    RangeOp::Ge => actual >= query_pixels
  }
}

///|
/// Compare value with swapped semantics for range syntax
/// (width >= 500px) means actual >= query
fn compare_value_with_op(
  query_value : MediaValue,
  actual : Double,
  op : RangeOp,
) -> Bool {
  let query_pixels = to_pixels(query_value)
  match op {
    RangeOp::Eq => (actual - query_pixels).abs() < 0.01
    RangeOp::Lt => actual < query_pixels
    RangeOp::Le => actual <= query_pixels
    RangeOp::Gt => actual > query_pixels
    RangeOp::Ge => actual >= query_pixels
  }
}

///|
/// Compare aspect ratio
fn compare_aspect_ratio(
  query_value : MediaValue,
  width : Double,
  height : Double,
  op : RangeOp,
) -> Bool {
  if height == 0.0 {
    return false
  }
  let actual_ratio = width / height
  let query_ratio = match query_value {
    MediaValue::Ratio(w, h) =>
      if h == 0 {
        0.0
      } else {
        w.to_double() / h.to_double()
      }
    MediaValue::Number(n) => n
    _ => 1.0
  }
  match op {
    RangeOp::Eq => (actual_ratio - query_ratio).abs() < 0.01
    RangeOp::Lt => actual_ratio < query_ratio
    RangeOp::Le => actual_ratio <= query_ratio
    RangeOp::Gt => actual_ratio > query_ratio
    RangeOp::Ge => actual_ratio >= query_ratio
  }
}

///|
/// Compare resolution (device pixel ratio)
fn compare_resolution(
  query_value : MediaValue,
  actual_dpr : Double,
  op : RangeOp,
) -> Bool {
  let query_dpr = match query_value {
    MediaValue::Number(n) => n
    MediaValue::Dimension(n, unit) =>
      match unit.to_lower() {
        "dppx" | "x" => n
        "dpi" => n / 96.0
        "dpcm" => n / 37.8
        _ => n
      }
    _ => 1.0
  }
  match op {
    RangeOp::Eq => (actual_dpr - query_dpr).abs() < 0.01
    RangeOp::Lt => actual_dpr < query_dpr
    RangeOp::Le => actual_dpr <= query_dpr
    RangeOp::Gt => actual_dpr > query_dpr
    RangeOp::Ge => actual_dpr >= query_dpr
  }
}
