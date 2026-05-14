///|
test "capture screenshot options normalize default origin" {
  match normalize_capture_screenshot_options({}) {
    Ok(options) => {
      inspect(options.origin, content="viewport")
      match options.clip {
        NoClip => ()
        _ => fail("expected no clip")
      }
    }
    Err(error) =>
      fail("unexpected screenshot options error: " + error.message())
  }
}

///|
test "capture screenshot options preserve element clip shared id" {
  let params : Map[String, Json] = {
    "clip": Json::object({
      "type": Json::string("element"),
      "element": Json::object({ "sharedId": Json::string("node-1") }),
    }),
  }
  match normalize_capture_screenshot_options(params) {
    Ok(options) =>
      match options.clip {
        ElementClip(shared_id) => inspect(shared_id, content="node-1")
        _ => fail("expected element clip")
      }
    Err(error) =>
      fail("unexpected screenshot options error: " + error.message())
  }
}

///|
test "capture screenshot options validate box clip dimensions" {
  let params : Map[String, Json] = {
    "clip": Json::object({
      "type": Json::string("box"),
      "x": Json::number(1.0),
      "y": Json::number(2.0),
      "width": Json::number(10.0),
      "height": Json::number(20.0),
    }),
  }
  match normalize_capture_screenshot_options(params) {
    Ok(options) =>
      match options.clip {
        BoxClip(width~, height~) => {
          inspect(width, content="10")
          inspect(height, content="20")
        }
        _ => fail("expected box clip")
      }
    Err(error) =>
      fail("unexpected screenshot options error: " + error.message())
  }
}

///|
test "capture screenshot options reject zero box dimensions as capture error" {
  let params : Map[String, Json] = {
    "clip": Json::object({
      "type": Json::string("box"),
      "x": Json::number(1.0),
      "y": Json::number(2.0),
      "width": Json::number(0.0),
      "height": Json::number(20.0),
    }),
  }
  match normalize_capture_screenshot_options(params) {
    Ok(_) => fail("expected invalid box clip")
    Err(error) => {
      inspect(error.name(), content="unable to capture screen")
      inspect(error.message(), content="Clip dimensions must be positive")
    }
  }
}

///|
test "capture screenshot options validate format type" {
  let params : Map[String, Json] = {
    "format": Json::object({ "type": Json::string("image/webp") }),
  }
  match normalize_capture_screenshot_options(params) {
    Ok(_) => fail("expected invalid format")
    Err(error) => {
      inspect(error.name(), content="invalid argument")
      inspect(
        error.message(),
        content="format.type must be 'image/png' or 'image/jpeg'",
      )
    }
  }
}
