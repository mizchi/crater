///|
/// Test cases for AI interpretation evaluation

///|
/// Case 1: Identical images
pub fn case_identical() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 1: Identical images (verbose)
pub fn case_identical_verbose() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 2: Red square added in top-left
pub fn case_red_square_topleft() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  // Add red square to img2
  for y in 5..<15 {
    for x in 5..<15 {
      img2.set_pixel(x, y, Color::rgba(255, 0, 0, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 3: Blue rectangle in bottom-right removed
pub fn case_bottomright_removed() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
      img2.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
    }
  }
  // img1 has blue rectangle that img2 doesn't have
  for y in 35..<48 {
    for x in 30..<48 {
      img1.set_pixel(x, y, Color::rgba(0, 0, 255, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 4: Overall brightness increased
pub fn case_brighter() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(50, 50, 50, 255))
      img2.set_pixel(x, y, Color::rgba(150, 150, 150, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 5: Border/frame added
pub fn case_border_added() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  // Add black border to img2
  for y in 0..<50 {
    for x in 0..<50 {
      if x < 3 || x >= 47 || y < 3 || y >= 47 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 6: Circle drawn in center
pub fn case_center_circle() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(240, 240, 240, 255))
      img2.set_pixel(x, y, Color::rgba(240, 240, 240, 255))
    }
  }
  // Draw circle in img2
  let cx = 25
  let cy = 25
  let r = 15
  for y in 0..<50 {
    for x in 0..<50 {
      let dx = x - cx
      let dy = y - cy
      if dx * dx + dy * dy <= r * r {
        img2.set_pixel(x, y, Color::rgba(0, 128, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 7: Horizontal line across middle
pub fn case_horizontal_line() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  // Add horizontal line to img2
  for x in 0..<50 {
    for y in 23..<27 {
      img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 8: Multiple small changes (scattered dots)
pub fn case_scattered_dots() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
      img2.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
    }
  }
  // Add scattered dots to img2
  let positions = [
    (5, 5),
    (15, 10),
    (40, 8),
    (10, 25),
    (35, 30),
    (20, 40),
    (45, 45),
    (8, 42),
  ]
  for pos in positions {
    let (px, py) = pos
    for dy in 0..<3 {
      for dx in 0..<3 {
        img2.set_pixel(px + dx, py + dy, Color::rgba(255, 0, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 9: Large single change (half image different)
pub fn case_half_changed() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      if x < 25 {
        img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      } else {
        img2.set_pixel(x, y, Color::rgba(255, 200, 100, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 10: Diagonal stripe
pub fn case_diagonal_stripe() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  // Add diagonal stripe to img2
  for y in 0..<50 {
    for x in 0..<50 {
      let diff = (x - y).abs()
      if diff < 5 {
        img2.set_pixel(x, y, Color::rgba(128, 0, 128, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 11: L-shaped region
pub fn case_l_shape() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
      img2.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
    }
  }
  // L-shape: vertical bar + horizontal bar at bottom
  for y in 5..<40 {
    for x in 5..<15 {
      img2.set_pixel(x, y, Color::rgba(255, 0, 0, 255))
    }
  }
  for y in 30..<40 {
    for x in 15..<35 {
      img2.set_pixel(x, y, Color::rgba(255, 0, 0, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 12: Concentric rings (donut)
pub fn case_donut() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  let cx = 25
  let cy = 25
  for y in 0..<50 {
    for x in 0..<50 {
      let dx = x - cx
      let dy = y - cy
      let dist_sq = dx * dx + dy * dy
      // Ring between radius 10 and 20
      if dist_sq >= 100 && dist_sq <= 400 {
        img2.set_pixel(x, y, Color::rgba(0, 100, 200, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 13: Checkerboard pattern
pub fn case_checkerboard() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  // 5x5 checkerboard pattern
  for y in 0..<50 {
    for x in 0..<50 {
      let cx = x / 10
      let cy = y / 10
      if (cx + cy) % 2 == 0 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 14: Two separate rectangles (top-left and bottom-right)
pub fn case_two_corners() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(128, 128, 128, 255))
      img2.set_pixel(x, y, Color::rgba(128, 128, 128, 255))
    }
  }
  // Top-left rectangle
  for y in 5..<15 {
    for x in 5..<20 {
      img2.set_pixel(x, y, Color::rgba(255, 0, 0, 255))
    }
  }
  // Bottom-right rectangle
  for y in 35..<45 {
    for x in 30..<45 {
      img2.set_pixel(x, y, Color::rgba(0, 0, 255, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 15: Cross/plus shape in center
pub fn case_cross() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(240, 240, 240, 255))
      img2.set_pixel(x, y, Color::rgba(240, 240, 240, 255))
    }
  }
  // Vertical bar of cross
  for y in 10..<40 {
    for x in 20..<30 {
      img2.set_pixel(x, y, Color::rgba(200, 50, 50, 255))
    }
  }
  // Horizontal bar of cross
  for y in 20..<30 {
    for x in 10..<40 {
      img2.set_pixel(x, y, Color::rgba(200, 50, 50, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 16: Triangle pointing right
pub fn case_triangle() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  // Triangle: starts narrow at left, expands to right
  for y in 0..<50 {
    for x in 0..<50 {
      let half_height = (x - 10) / 2
      let center_y = 25
      if x >= 10 &&
        x <= 40 &&
        y >= center_y - half_height &&
        y <= center_y + half_height {
        img2.set_pixel(x, y, Color::rgba(0, 150, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 17: Vertical stripes
pub fn case_vertical_stripes() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  // 5 vertical stripes
  for y in 0..<50 {
    for x in 0..<50 {
      if x / 10 % 2 == 0 {
        img2.set_pixel(x, y, Color::rgba(100, 100, 100, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 18: Nested squares (frame within frame)
pub fn case_nested_squares() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  // Outer frame
  for y in 0..<50 {
    for x in 0..<50 {
      if x < 5 || x >= 45 || y < 5 || y >= 45 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
    }
  }
  // Inner frame
  for y in 0..<50 {
    for x in 0..<50 {
      if ((x >= 15 && x < 20) || (x >= 30 && x < 35)) && y >= 15 && y < 35 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
      if ((y >= 15 && y < 20) || (y >= 30 && y < 35)) && x >= 15 && x < 35 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 19: Arrow pointing up
pub fn case_arrow_up() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
      img2.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
    }
  }
  // Arrow head (triangle at top)
  for y in 5..<25 {
    let half_width = (25 - y) / 2
    let start_x = 25 - half_width
    let end_x = 25 + half_width + 1
    for x in start_x..<end_x {
      if x >= 0 && x < 50 {
        img2.set_pixel(x, y, Color::rgba(50, 50, 200, 255))
      }
    }
  }
  // Arrow shaft
  for y in 25..<45 {
    for x in 20..<30 {
      img2.set_pixel(x, y, Color::rgba(50, 50, 200, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// Case 20: Random-looking noise pattern (actually deterministic)
pub fn case_noise() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(128, 128, 128, 255))
      img2.set_pixel(x, y, Color::rgba(128, 128, 128, 255))
    }
  }
  // Pseudo-random noise using simple hash
  for y in 0..<50 {
    for x in 0..<50 {
      let hash = (x * 7 + y * 13 + x * y) % 17
      if hash < 3 {
        img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact()
}

///|
/// High-resolution versions (20x20 grid)
pub fn case_donut_hires() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  let cx = 25
  let cy = 25
  for y in 0..<50 {
    for x in 0..<50 {
      let dx = x - cx
      let dy = y - cy
      let dist_sq = dx * dx + dy * dy
      if dist_sq >= 100 && dist_sq <= 400 {
        img2.set_pixel(x, y, Color::rgba(0, 100, 200, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default(), grid_size=20).to_compact()
}

///|
pub fn case_triangle_hires() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  for y in 0..<50 {
    for x in 0..<50 {
      let half_height = (x - 10) / 2
      let center_y = 25
      if x >= 10 &&
        x <= 40 &&
        y >= center_y - half_height &&
        y <= center_y + half_height {
        img2.set_pixel(x, y, Color::rgba(0, 150, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default(), grid_size=20).to_compact()
}

///|
pub fn case_arrow_hires() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
      img2.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
    }
  }
  for y in 5..<25 {
    let half_width = (25 - y) / 2
    let start_x = 25 - half_width
    let end_x = 25 + half_width + 1
    for x in start_x..<end_x {
      if x >= 0 && x < 50 {
        img2.set_pixel(x, y, Color::rgba(50, 50, 200, 255))
      }
    }
  }
  for y in 25..<45 {
    for x in 20..<30 {
      img2.set_pixel(x, y, Color::rgba(50, 50, 200, 255))
    }
  }
  diff_report(img1, img2, Options::default(), grid_size=20).to_compact()
}

///|
pub fn case_checkerboard_hires() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  for y in 0..<50 {
    for x in 0..<50 {
      let cx = x / 10
      let cy = y / 10
      if (cx + cy) % 2 == 0 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default(), grid_size=20).to_compact()
}

///|
pub fn case_nested_hires() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  // Outer frame
  for y in 0..<50 {
    for x in 0..<50 {
      if x < 5 || x >= 45 || y < 5 || y >= 45 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
    }
  }
  // Inner frame
  for y in 0..<50 {
    for x in 0..<50 {
      if ((x >= 15 && x < 20) || (x >= 30 && x < 35)) && y >= 15 && y < 35 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
      if ((y >= 15 && y < 20) || (y >= 30 && y < 35)) && x >= 15 && x < 35 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default(), grid_size=20).to_compact()
}

///|
/// Test hint generation
pub fn case_donut_hints() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  let cx = 25
  let cy = 25
  for y in 0..<50 {
    for x in 0..<50 {
      let dx = x - cx
      let dy = y - cy
      let dist_sq = dx * dx + dy * dy
      if dist_sq >= 100 && dist_sq <= 400 {
        img2.set_pixel(x, y, Color::rgba(0, 100, 200, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact_with_hints()
}

///|
pub fn case_arrow_hints() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
      img2.set_pixel(x, y, Color::rgba(200, 200, 200, 255))
    }
  }
  for y in 5..<25 {
    let half_width = (25 - y) / 2
    let start_x = 25 - half_width
    let end_x = 25 + half_width + 1
    for x in start_x..<end_x {
      if x >= 0 && x < 50 {
        img2.set_pixel(x, y, Color::rgba(50, 50, 200, 255))
      }
    }
  }
  for y in 25..<45 {
    for x in 20..<30 {
      img2.set_pixel(x, y, Color::rgba(50, 50, 200, 255))
    }
  }
  diff_report(img1, img2, Options::default()).to_compact_with_hints()
}

///|
pub fn case_checkerboard_hints() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  for y in 0..<50 {
    for x in 0..<50 {
      let cx = x / 10
      let cy = y / 10
      if (cx + cy) % 2 == 0 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact_with_hints()
}

///|
pub fn case_border_hints() -> String {
  let img1 = Image::new(50, 50)
  let img2 = Image::new(50, 50)
  for y in 0..<50 {
    for x in 0..<50 {
      img1.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
      img2.set_pixel(x, y, Color::rgba(255, 255, 255, 255))
    }
  }
  for y in 0..<50 {
    for x in 0..<50 {
      if x < 3 || x >= 47 || y < 3 || y >= 47 {
        img2.set_pixel(x, y, Color::rgba(0, 0, 0, 255))
      }
    }
  }
  diff_report(img1, img2, Options::default()).to_compact_with_hints()
}

///|
test "generate hint cases" {
  println("=== Donut with hints ===")
  println(case_donut_hints())
  println("\n=== Arrow with hints ===")
  println(case_arrow_hints())
  println("\n=== Checkerboard with hints ===")
  println(case_checkerboard_hints())
  println("\n=== Border with hints ===")
  println(case_border_hints())
}

///|
test "generate hires cases" {
  println("=== HIRES: Donut ===")
  println(case_donut_hires())
  println("\n=== HIRES: Triangle ===")
  println(case_triangle_hires())
  println("\n=== HIRES: Arrow ===")
  println(case_arrow_hires())
  println("\n=== HIRES: Checkerboard ===")
  println(case_checkerboard_hires())
  println("\n=== HIRES: Nested ===")
  println(case_nested_hires())
}

///|
test "generate all cases" {
  println("=== CASE 11: L-Shape ===")
  println(case_l_shape())
  println("\n=== CASE 12: Donut ===")
  println(case_donut())
  println("\n=== CASE 13: Checkerboard ===")
  println(case_checkerboard())
  println("\n=== CASE 14: Two Corners ===")
  println(case_two_corners())
  println("\n=== CASE 15: Cross ===")
  println(case_cross())
  println("\n=== CASE 16: Triangle ===")
  println(case_triangle())
  println("\n=== CASE 17: Vertical Stripes ===")
  println(case_vertical_stripes())
  println("\n=== CASE 18: Nested Squares ===")
  println(case_nested_squares())
  println("\n=== CASE 19: Arrow Up ===")
  println(case_arrow_up())
  println("\n=== CASE 20: Noise ===")
  println(case_noise())
}
