///|
#cfg(target="js")
extern "js" fn has_external_text_metrics_provider() -> Bool =
  #|() => typeof globalThis.__craterMeasureTextIntrinsic === "function"

///|
#cfg(target="js")
extern "js" fn call_external_text_metrics_provider(
  text : String,
  font_size : Double,
  line_height : Double,
  white_space : String,
  writing_mode : String,
  available_width : Double,
  available_height : Double,
) -> String =
  #|(text, fontSize, lineHeight, whiteSpace, writingMode, availableWidth, availableHeight) => {
  #|  const fn = globalThis.__craterMeasureTextIntrinsic;
  #|  if (typeof fn !== "function") return "";
  #|  try {
  #|    const result = fn(text, fontSize, lineHeight, whiteSpace, writingMode, availableWidth, availableHeight);
  #|    let minWidth, maxWidth, minHeight, maxHeight;
  #|    if (Array.isArray(result) && result.length >= 4) {
  #|      minWidth = Number(result[0]);
  #|      maxWidth = Number(result[1]);
  #|      minHeight = Number(result[2]);
  #|      maxHeight = Number(result[3]);
  #|    } else if (result && typeof result === "object") {
  #|      minWidth = Number(result.minWidth ?? result.min_width);
  #|      maxWidth = Number(result.maxWidth ?? result.max_width ?? minWidth);
  #|      minHeight = Number(result.minHeight ?? result.min_height);
  #|      maxHeight = Number(result.maxHeight ?? result.max_height ?? minHeight);
  #|    } else {
  #|      return "";
  #|    }
  #|    if (!Number.isFinite(minWidth) || !Number.isFinite(maxWidth) || !Number.isFinite(minHeight) || !Number.isFinite(maxHeight)) return "";
  #|    return `${minWidth},${maxWidth},${minHeight},${maxHeight}`;
  #|  } catch {
  #|    return "";
  #|  }
  #|}

///|
#cfg(target="js")
extern "js" fn has_external_image_intrinsic_provider() -> Bool =
  #|() => typeof globalThis.__craterResolveImageIntrinsicSize === "function"

///|
#cfg(target="js")
extern "js" fn call_external_image_intrinsic_provider(src : String) -> String =
  #|(src) => {
  #|  const fn = globalThis.__craterResolveImageIntrinsicSize;
  #|  if (typeof fn !== "function") return "";
  #|  try {
  #|    const result = fn(src);
  #|    let width, height;
  #|    if (Array.isArray(result) && result.length >= 2) {
  #|      width = Number(result[0]);
  #|      height = Number(result[1]);
  #|    } else if (result && typeof result === "object") {
  #|      width = Number(result.width ?? result.w);
  #|      height = Number(result.height ?? result.h);
  #|    } else {
  #|      return "";
  #|    }
  #|    if (!Number.isFinite(width) || !Number.isFinite(height)) return "";
  #|    return `${width},${height}`;
  #|  } catch {
  #|    return "";
  #|  }
  #|}

///|
#cfg(target="js")
fn parse_csv_pair(payload : String) -> (Double, Double)? {
  let parts : Array[String] = payload
    .split(",")
    .map(fn(s) { s.trim().to_string() })
    .collect()
  if parts.length() != 2 {
    return None
  }
  let first = @strconv.parse_double(parts[0]) catch { _ => return None }
  let second = @strconv.parse_double(parts[1]) catch { _ => return None }
  Some((first, second))
}

///|
#cfg(target="js")
fn parse_csv_quad(payload : String) -> (Double, Double, Double, Double)? {
  let parts : Array[String] = payload
    .split(",")
    .map(fn(s) { s.trim().to_string() })
    .collect()
  if parts.length() != 4 {
    return None
  }
  let first = @strconv.parse_double(parts[0]) catch { _ => return None }
  let second = @strconv.parse_double(parts[1]) catch { _ => return None }
  let third = @strconv.parse_double(parts[2]) catch { _ => return None }
  let fourth = @strconv.parse_double(parts[3]) catch { _ => return None }
  Some((first, second, third, fourth))
}

///|
#cfg(target="js")
fn create_external_text_metrics_provider() -> @renderer.TextMetricsProvider {
  @renderer.TextMetricsProvider::new(fn(
    text,
    font_size,
    line_height,
    white_space,
    writing_mode,
    _font_weight,
    _font_family,
  ) {
    let white_space_name = white_space.to_string()
    let writing_mode_name = writing_mode.to_string()
    {
      func: fn(available_width, available_height) {
        let payload = call_external_text_metrics_provider(
          text, font_size, line_height, white_space_name, writing_mode_name, available_width,
          available_height,
        )
        match parse_csv_quad(payload) {
          Some((min_width, max_width, min_height, max_height)) =>
            { min_width, max_width, min_height, max_height }
          None => {
            let mut cols = 0
            for _ in text.iter() {
              cols = cols + 1
            }
            let char_width = if font_size > 0.0 { font_size * 0.5 } else { 8.0 }
            let width = cols.to_double() * char_width
            let height = if line_height > 0.0 {
              line_height
            } else if font_size > 0.0 {
              font_size
            } else {
              16.0
            }
            {
              min_width: width,
              max_width: width,
              min_height: height,
              max_height: height,
            }
          }
        }
      },
    }
  })
}

///|
#cfg(target="js")
fn create_external_image_intrinsic_size_provider() -> @renderer.ImageIntrinsicSizeProvider {
  @renderer.ImageIntrinsicSizeProvider::new(fn(src : String) {
    let payload = call_external_image_intrinsic_provider(src)
    parse_csv_pair(payload)
  })
}

///|
#cfg(target="js")
fn install_wpt_external_measurement_providers() -> Unit {
  if has_external_text_metrics_provider() {
    let provider = create_external_text_metrics_provider()
    @renderer.set_text_metrics_provider(provider)
  } else {
    @renderer.clear_text_metrics_provider()
  }
  if has_external_image_intrinsic_provider() {
    let provider = create_external_image_intrinsic_size_provider()
    @renderer.set_image_intrinsic_size_provider(provider)
  } else {
    @renderer.clear_image_intrinsic_size_provider()
  }
}
