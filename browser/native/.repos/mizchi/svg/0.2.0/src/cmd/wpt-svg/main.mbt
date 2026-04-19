///|
/// WPT SVG reftest runner (static subset)

///|
fn abs_int(v : Int) -> Int {
  if v < 0 {
    -v
  } else {
    v
  }
}

///|
fn color_close(a : @svg.Color, b : @svg.Color, tol : Int) -> Bool {
  abs_int(a.r - b.r) <= tol &&
  abs_int(a.g - b.g) <= tol &&
  abs_int(a.b - b.b) <= tol &&
  abs_int(a.a - b.a) <= tol
}

///|
fn diff_images(a : @svg.Image, b : @svg.Image, tol : Int) -> Int {
  if a.width != b.width || a.height != b.height {
    return -1
  }
  let mut diff = 0
  let total = a.width * a.height
  for i in 0..<total {
    let ca = a.pixels[i]
    let cb = b.pixels[i]
    if not(color_close(ca, cb, tol)) {
      diff = diff + 1
    }
  }
  diff
}

///|
fn count_non_transparent(img : @svg.Image) -> Int {
  let mut count = 0
  let total = img.width * img.height
  for i in 0..<total {
    if img.pixels[i].a > 0 {
      count = count + 1
    }
  }
  count
}

///|
fn count_color(img : @svg.Image, r : Int, g : Int, b : Int, a : Int) -> Int {
  let mut count = 0
  let total = img.width * img.height
  for i in 0..<total {
    let c = img.pixels[i]
    if c.r == r && c.g == g && c.b == b && c.a == a {
      count = count + 1
    }
  }
  count
}

///|
fn bbox_not_green(img : @svg.Image) -> (Int, Int, Int, Int)? {
  let mut min_x = img.width
  let mut min_y = img.height
  let mut max_x = -1
  let mut max_y = -1
  for y in 0..<img.height {
    for x in 0..<img.width {
      let i = y * img.width + x
      let c = img.pixels[i]
      let is_green = c.r == 0 && c.g == 128 && c.b == 0 && c.a == 255
      if not(is_green) {
        if x < min_x {
          min_x = x
        }
        if y < min_y {
          min_y = y
        }
        if x > max_x {
          max_x = x
        }
        if y > max_y {
          max_y = y
        }
      }
    }
  }
  if max_x < 0 || max_y < 0 {
    None
  } else {
    Some((min_x, min_y, max_x, max_y))
  }
}

///|
fn bbox_green(img : @svg.Image) -> (Int, Int, Int, Int)? {
  let mut min_x = img.width
  let mut min_y = img.height
  let mut max_x = -1
  let mut max_y = -1
  for y in 0..<img.height {
    for x in 0..<img.width {
      let i = y * img.width + x
      let c = img.pixels[i]
      let is_green = c.r == 0 && c.g == 128 && c.b == 0 && c.a == 255
      if is_green {
        if x < min_x {
          min_x = x
        }
        if y < min_y {
          min_y = y
        }
        if x > max_x {
          max_x = x
        }
        if y > max_y {
          max_y = y
        }
      }
    }
  }
  if max_x < 0 || max_y < 0 {
    None
  } else {
    Some((min_x, min_y, max_x, max_y))
  }
}

///|

///|
fn run_case(c : WptCase) -> (Bool, Int) {
  let channel_tol = if c.max_diff > 0 { c.max_diff } else { 2 }
  let max_diff_ratio = 0.005
  match
    (
      @svg.render_svg_to_image(c.test_svg, c.width, c.height),
      @svg.render_svg_to_image(c.ref_svg, c.width, c.height),
    ) {
    (Some(imgA), Some(imgB)) => {
      let diff = diff_images(imgA, imgB, channel_tol)
      if diff < 0 {
        (false, diff)
      } else {
        let total = imgA.width * imgA.height
        if total <= 0 {
          (diff == 0, diff)
        } else {
          let max_pixels = if c.max_pixels > 0 {
            c.max_pixels
          } else {
            (total.to_double() * max_diff_ratio).to_int()
          }
          (diff <= max_pixels, diff)
        }
      }
    }
    _ => (false, -1)
  }
}

///|
fn main {
  let cases = wpt_svg_cases()
  let mut passed = 0
  let mut failed = 0
  for c in cases {
    let (ok, diff) = run_case(c)
    if ok {
      passed = passed + 1
    } else {
      failed = failed + 1
      println("[wpt-svg] FAIL: " + c.name + " (diff=" + diff.to_string() + ")")
      match
        (
          @svg.render_svg_to_image(c.test_svg, c.width, c.height),
          @svg.render_svg_to_image(c.ref_svg, c.width, c.height),
        ) {
        (Some(imgA), Some(imgB)) => {
          println(
            "[wpt-svg] nontransparent test=" +
            count_non_transparent(imgA).to_string() +
            " ref=" +
            count_non_transparent(imgB).to_string(),
          )
          println(
            "[wpt-svg] green test=" +
            count_color(imgA, 0, 128, 0, 255).to_string() +
            " ref=" +
            count_color(imgB, 0, 128, 0, 255).to_string(),
          )
          if bbox_not_green(imgA) is Some((x0, y0, x1, y1)) {
            println(
              "[wpt-svg] not-green-bbox: (" +
              x0.to_string() +
              "," +
              y0.to_string() +
              ")-(" +
              x1.to_string() +
              "," +
              y1.to_string() +
              ")",
            )
          }
          match bbox_green(imgA) {
            Some((x0, y0, x1, y1)) =>
              println(
                "[wpt-svg] green-bbox: (" +
                x0.to_string() +
                "," +
                y0.to_string() +
                ")-(" +
                x1.to_string() +
                "," +
                y1.to_string() +
                ")",
              )
            None => ()
          }
        }
        _ => ()
      }
    }
  }
  println(
    "[wpt-svg] Summary: passed=" +
    passed.to_string() +
    ", failed=" +
    failed.to_string(),
  )
  if failed > 0 {
    abort("wpt svg failed")
  }
}
