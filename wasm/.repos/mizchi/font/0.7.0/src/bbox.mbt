///|
/// Mutable bounding box accumulator
priv struct BBoxAccum {
  mut x_min : Double
  mut y_min : Double
  mut x_max : Double
  mut y_max : Double
  mut has_points : Bool
}

///|
fn BBoxAccum::new() -> BBoxAccum {
  {
    x_min: 1.0e18,
    y_min: 1.0e18,
    x_max: -1.0e18,
    y_max: -1.0e18,
    has_points: false,
  }
}

///|
fn BBoxAccum::add(self : BBoxAccum, x : Double, y : Double) -> Unit {
  self.has_points = true
  if x < self.x_min {
    self.x_min = x
  }
  if y < self.y_min {
    self.y_min = y
  }
  if x > self.x_max {
    self.x_max = x
  }
  if y > self.y_max {
    self.y_max = y
  }
}

///|
fn BBoxAccum::to_bbox(self : BBoxAccum) -> GlyphBBox {
  if not(self.has_points) {
    return { x_min: 0, y_min: 0, x_max: 0, y_max: 0 }
  }
  {
    x_min: self.x_min.to_int(),
    y_min: self.y_min.to_int(),
    x_max: (self.x_max + 0.999).to_int(),
    y_max: (self.y_max + 0.999).to_int(),
  }
}

///|
/// Compute bounding box from path commands.
/// Calculates exact bounds including cubic/quadratic bezier curve extrema.
pub fn compute_path_bbox(cmds : Array[@svg.PathCommand]) -> GlyphBBox {
  let acc = BBoxAccum::new()
  let mut cx = 0.0
  let mut cy = 0.0
  for cmd in cmds {
    match cmd {
      @svg.MoveTo(x, y) => {
        acc.add(x, y)
        cx = x
        cy = y
      }
      @svg.LineTo(x, y) => {
        acc.add(x, y)
        cx = x
        cy = y
      }
      @svg.QuadraticCurveTo(cpx, cpy, x, y) => {
        add_quad_extrema(acc, cx, cy, cpx, cpy, x, y)
        acc.add(x, y)
        cx = x
        cy = y
      }
      @svg.CurveTo(cp1x, cp1y, cp2x, cp2y, x, y) => {
        add_cubic_extrema(acc, cx, cy, cp1x, cp1y, cp2x, cp2y, x, y)
        acc.add(x, y)
        cx = x
        cy = y
      }
      @svg.ClosePath => ()
      _ => ()
    }
  }
  acc.to_bbox()
}

///|
/// Add quadratic bezier extrema to accumulator.
/// Extrema at t = (P0 - CP) / (P0 - 2*CP + P1), 0 < t < 1
fn add_quad_extrema(
  acc : BBoxAccum,
  x0 : Double,
  y0 : Double,
  cpx : Double,
  cpy : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  // x extremum
  let dx = x0 - 2.0 * cpx + x1
  if dx.abs() > 1.0e-10 {
    let t = (x0 - cpx) / dx
    if t > 0.0 && t < 1.0 {
      let mt = 1.0 - t
      acc.add(
        mt * mt * x0 + 2.0 * mt * t * cpx + t * t * x1,
        mt * mt * y0 + 2.0 * mt * t * cpy + t * t * y1,
      )
    }
  }
  // y extremum
  let dy = y0 - 2.0 * cpy + y1
  if dy.abs() > 1.0e-10 {
    let t = (y0 - cpy) / dy
    if t > 0.0 && t < 1.0 {
      let mt = 1.0 - t
      acc.add(
        mt * mt * x0 + 2.0 * mt * t * cpx + t * t * x1,
        mt * mt * y0 + 2.0 * mt * t * cpy + t * t * y1,
      )
    }
  }
}

///|
/// Add cubic bezier extrema to accumulator.
/// Derivative = 0 gives at^2 + bt + c = 0 per axis
fn add_cubic_extrema(
  acc : BBoxAccum,
  x0 : Double,
  y0 : Double,
  cp1x : Double,
  cp1y : Double,
  cp2x : Double,
  cp2y : Double,
  x3 : Double,
  y3 : Double,
) -> Unit {
  // x extrema
  solve_cubic_axis(acc, x0, y0, cp1x, cp1y, cp2x, cp2y, x3, y3, true)
  // y extrema
  solve_cubic_axis(acc, x0, y0, cp1x, cp1y, cp2x, cp2y, x3, y3, false)
}

///|
fn solve_cubic_axis(
  acc : BBoxAccum,
  x0 : Double,
  y0 : Double,
  cp1x : Double,
  cp1y : Double,
  cp2x : Double,
  cp2y : Double,
  x3 : Double,
  y3 : Double,
  is_x : Bool,
) -> Unit {
  let (p0, p1, p2, p3) = if is_x {
    (x0, cp1x, cp2x, x3)
  } else {
    (y0, cp1y, cp2y, y3)
  }
  let a = -3.0 * p0 + 9.0 * p1 - 9.0 * p2 + 3.0 * p3
  let b = 6.0 * p0 - 12.0 * p1 + 6.0 * p2
  let c = -3.0 * p0 + 3.0 * p1
  if a.abs() < 1.0e-10 {
    // Linear
    if b.abs() > 1.0e-10 {
      let t = -c / b
      if t > 0.0 && t < 1.0 {
        let (ex, ey) = eval_cubic(x0, y0, cp1x, cp1y, cp2x, cp2y, x3, y3, t)
        acc.add(ex, ey)
      }
    }
    return
  }
  let disc = b * b - 4.0 * a * c
  if disc < 0.0 {
    return
  }
  let sq = disc.sqrt()
  let t1 = (-b + sq) / (2.0 * a)
  let t2 = (-b - sq) / (2.0 * a)
  if t1 > 0.0 && t1 < 1.0 {
    let (ex, ey) = eval_cubic(x0, y0, cp1x, cp1y, cp2x, cp2y, x3, y3, t1)
    acc.add(ex, ey)
  }
  if t2 > 0.0 && t2 < 1.0 {
    let (ex, ey) = eval_cubic(x0, y0, cp1x, cp1y, cp2x, cp2y, x3, y3, t2)
    acc.add(ex, ey)
  }
}

///|
fn eval_cubic(
  x0 : Double,
  y0 : Double,
  cp1x : Double,
  cp1y : Double,
  cp2x : Double,
  cp2y : Double,
  x3 : Double,
  y3 : Double,
  t : Double,
) -> (Double, Double) {
  let mt = 1.0 - t
  let mt2 = mt * mt
  let mt3 = mt2 * mt
  let t2 = t * t
  let t3 = t2 * t
  (
    mt3 * x0 + 3.0 * mt2 * t * cp1x + 3.0 * mt * t2 * cp2x + t3 * x3,
    mt3 * y0 + 3.0 * mt2 * t * cp1y + 3.0 * mt * t2 * cp2y + t3 * y3,
  )
}
