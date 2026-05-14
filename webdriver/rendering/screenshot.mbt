///|
pub(all) enum CaptureScreenshotClip {
  NoClip
  ElementClip(String)
  BoxClip(width~ : Double, height~ : Double)
}

///|
pub(all) struct CaptureScreenshotOptions {
  origin : String
  clip : CaptureScreenshotClip
}

///|
pub fn normalize_capture_screenshot_options(
  params : Map[String, Json],
) -> Result[CaptureScreenshotOptions, RenderingValidationError] {
  let origin = match params.get("origin") {
    Some(String("viewport")) | None => "viewport"
    Some(String("document")) => "document"
    Some(String(_)) =>
      return Err(InvalidArgument("origin must be 'viewport' or 'document'"))
    Some(_) =>
      return Err(InvalidArgument("origin must be 'viewport' or 'document'"))
  }
  let clip = match normalize_capture_screenshot_clip(params.get("clip")) {
    Ok(clip) => clip
    Err(error) => return Err(error)
  }
  match validate_capture_screenshot_format(params.get("format")) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  Ok({ origin, clip })
}

///|
fn normalize_capture_screenshot_clip(
  raw_clip : Json?,
) -> Result[CaptureScreenshotClip, RenderingValidationError] {
  match raw_clip {
    None => Ok(NoClip)
    Some(Object(clip_map)) => {
      let clip_type = match clip_map.get("type") {
        Some(String(kind)) => kind
        _ => return Err(InvalidArgument("clip.type must be a string"))
      }
      if clip_type == "element" {
        normalize_capture_screenshot_element_clip(clip_map)
      } else if clip_type == "box" {
        normalize_capture_screenshot_box_clip(clip_map)
      } else {
        Err(InvalidArgument("clip.type is invalid"))
      }
    }
    Some(_) => Err(InvalidArgument("clip must be an object"))
  }
}

///|
fn normalize_capture_screenshot_element_clip(
  clip_map : Map[String, Json],
) -> Result[CaptureScreenshotClip, RenderingValidationError] {
  match clip_map.get("element") {
    Some(Object(element)) =>
      match element.get("sharedId") {
        Some(String(shared_id)) => Ok(ElementClip(shared_id))
        _ => Err(InvalidArgument("clip.element.sharedId must be a string"))
      }
    _ => Err(InvalidArgument("clip.element must be a node reference"))
  }
}

///|
fn normalize_capture_screenshot_box_clip(
  clip_map : Map[String, Json],
) -> Result[CaptureScreenshotClip, RenderingValidationError] {
  let _clip_box_x = match read_capture_screenshot_box_number(clip_map, "x") {
    Some(value) => value
    None =>
      return Err(InvalidArgument("clip.box x/y/width/height must be numbers"))
  }
  let _clip_box_y = match read_capture_screenshot_box_number(clip_map, "y") {
    Some(value) => value
    None =>
      return Err(InvalidArgument("clip.box x/y/width/height must be numbers"))
  }
  let width = match read_capture_screenshot_box_size(clip_map, "width") {
    Some(value) => value
    None =>
      return Err(InvalidArgument("clip.box x/y/width/height must be numbers"))
  }
  let height = match read_capture_screenshot_box_size(clip_map, "height") {
    Some(value) => value
    None =>
      return Err(InvalidArgument("clip.box x/y/width/height must be numbers"))
  }
  if width <= 0.0 || height <= 0.0 {
    return Err(UnableToCaptureScreen("Clip dimensions must be positive"))
  }
  Ok(BoxClip(width~, height~))
}

///|
fn read_capture_screenshot_box_number(
  clip_map : Map[String, Json],
  key : String,
) -> Double? {
  match clip_map.get(key) {
    Some(value) =>
      @protocol.json_as_safe_number(
        value, -9007199254740991.0, 9007199254740991.0,
      )
    None => None
  }
}

///|
fn read_capture_screenshot_box_size(
  clip_map : Map[String, Json],
  key : String,
) -> Double? {
  match clip_map.get(key) {
    Some(value) => @protocol.json_as_safe_number(value, 0.0, 9007199254740991.0)
    None => None
  }
}

///|
fn validate_capture_screenshot_format(
  raw_format : Json?,
) -> Result[Unit, RenderingValidationError] {
  match raw_format {
    None => Ok(())
    Some(Object(format)) => {
      match format.get("type") {
        Some(String("image/png")) | Some(String("image/jpeg")) => ()
        Some(String(_)) =>
          return Err(
            InvalidArgument("format.type must be 'image/png' or 'image/jpeg'"),
          )
        _ =>
          return Err(
            InvalidArgument("format.type must be 'image/png' or 'image/jpeg'"),
          )
      }
      match format.get("quality") {
        Some(value) =>
          match @protocol.json_as_safe_number(value, 0.0, 1.0) {
            Some(_) => ()
            None =>
              return Err(
                InvalidArgument("format.quality must be a number in [0,1]"),
              )
          }
        None => ()
      }
      Ok(())
    }
    Some(_) => Err(InvalidArgument("format must be an object"))
  }
}
