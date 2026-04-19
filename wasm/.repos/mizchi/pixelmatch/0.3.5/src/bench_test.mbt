///|
/// Benchmark suite for pixelmatch

///|
/// Small identical images (baseline)
test "bench: identical 50x50" (b : @bench.T) {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
    }
  }
  b.bench(() => b.keep(pixelmatch_simple(img1, img2, 0.1)))
}

///|
/// Medium identical images
test "bench: identical 200x200" (b : @bench.T) {
  let img1 = Image::new(200, 200)
  let img2 = Image::new(200, 200)
  for y in 0..<200 {
    for x in 0..<200 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
    }
  }
  b.bench(() => b.keep(pixelmatch_simple(img1, img2, 0.1)))
}

///|
/// Large identical images (stress test)
test "bench: identical 500x500" (b : @bench.T) {
  let img1 = Image::new(500, 500)
  let img2 = Image::new(500, 500)
  for y in 0..<500 {
    for x in 0..<500 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
    }
  }
  b.bench(() => b.keep(pixelmatch_simple(img1, img2, 0.1)))
}

///|
/// Completely different images (worst case for delta calc)
test "bench: different 200x200" (b : @bench.T) {
  let img1 = Image::new(200, 200)
  let img2 = Image::new(200, 200)
  for y in 0..<200 {
    for x in 0..<200 {
      img1.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  b.bench(() => b.keep(pixelmatch_simple(img1, img2, 0.1)))
}

///|
/// With alpha blending (triggers blend_with_white)
test "bench: alpha blend 200x200" (b : @bench.T) {
  let img1 = Image::new(200, 200)
  let img2 = Image::new(200, 200)
  for y in 0..<200 {
    for x in 0..<200 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 128))
      img2.set_pixel(x, y, Color::rgba(150, 150, 150, 128))
    }
  }
  b.bench(() => b.keep(pixelmatch_simple(img1, img2, 0.1)))
}

///|
/// Full pixelmatch with anti-aliasing detection
test "bench: full AA detection 100x100" (b : @bench.T) {
  let img1 = Image::new(100, 100)
  let img2 = Image::new(100, 100)
  // Create pattern with edges that might trigger AA detection
  for y in 0..<100 {
    for x in 0..<100 {
      let c1 = if (x + y) % 2 == 0 { 50 } else { 200 }
      let c2 = if (x + y) % 2 == 0 { 60 } else { 190 }
      img1.set_pixel(x, y, Color::rgba(c1, c1, c1, 255))
      img2.set_pixel(x, y, Color::rgba(c2, c2, c2, 255))
    }
  }
  let options = Options::default()
  b.bench(() => b.keep(pixelmatch(img1, img2, None, options)))
}

///|
/// Pixelmatch with output image generation
test "bench: with output 100x100" (b : @bench.T) {
  let img1 = Image::new(100, 100)
  let img2 = Image::new(100, 100)
  let output = Image::new(100, 100)
  for y in 0..<100 {
    for x in 0..<100 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      if x < 50 {
        img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      } else {
        img2.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
      }
    }
  }
  let options = Options::default()
  b.bench(() => b.keep(pixelmatch(img1, img2, Some(output), options)))
}

///|
/// diff_report full pipeline
test "bench: diff_report 100x100" (b : @bench.T) {
  let img1 = Image::new(100, 100)
  let img2 = Image::new(100, 100)
  for y in 0..<100 {
    for x in 0..<100 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
    }
  }
  // Add some diff regions
  for y in 10..<30 {
    for x in 10..<30 {
      img2.set_pixel(x, y, Color::rgba(255, 0, 0, 255))
    }
  }
  for y in 60..<80 {
    for x in 60..<80 {
      img2.set_pixel(x, y, Color::rgba(0, 255, 0, 255))
    }
  }
  let options = Options::default()
  b.bench(() => b.keep(diff_report(img1, img2, options)))
}

///|
/// diff_report with many small regions (stress test flood fill)
test "bench: diff_report scattered 100x100" (b : @bench.T) {
  let img1 = Image::new(100, 100)
  let img2 = Image::new(100, 100)
  for y in 0..<100 {
    for x in 0..<100 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
    }
  }
  // Add many small scattered dots
  for i in 0..<20 {
    let px = i * 5 % 95
    let py = i * 7 % 95
    for dy in 0..<3 {
      for dx in 0..<3 {
        img2.set_pixel(px + dx, py + dy, Color::rgba(255, 0, 0, 255))
      }
    }
  }
  let options = Options::default()
  b.bench(() => b.keep(diff_report(img1, img2, options)))
}

///|
/// to_text generation
test "bench: to_text 100x100" (b : @bench.T) {
  let img1 = Image::new(100, 100)
  let img2 = Image::new(100, 100)
  for y in 0..<100 {
    for x in 0..<100 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
    }
  }
  for y in 20..<40 {
    for x in 20..<40 {
      img2.set_pixel(x, y, Color::rgba(255, 0, 0, 255))
    }
  }
  let options = Options::default()
  let report = diff_report(img1, img2, options)
  b.bench(() => b.keep(report.to_text()))
}
