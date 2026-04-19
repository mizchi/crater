///|
/// Tests for SVG DOM API

///|
test "SVGRect::new" {
  let rect = SVGRect::new(10.0, 20.0, 100.0, 50.0)
  assert_eq(rect.x, 10.0)
  assert_eq(rect.y, 20.0)
  assert_eq(rect.width, 100.0)
  assert_eq(rect.height, 50.0)
}

///|
test "SVGRect::from_rect" {
  let rect = Rect::new(5.0, 10.0, 200.0, 100.0)
  let svg_rect = SVGRect::from_rect(rect)
  assert_eq(svg_rect.x, 5.0)
  assert_eq(svg_rect.y, 10.0)
  assert_eq(svg_rect.width, 200.0)
  assert_eq(svg_rect.height, 100.0)
}

///|
test "SVGPoint::new" {
  let point = SVGPoint::new(15.0, 25.0)
  assert_eq(point.x, 15.0)
  assert_eq(point.y, 25.0)
}

///|
test "SVGPoint::matrix_transform" {
  let point = SVGPoint::new(10.0, 0.0)
  // Translate by (5, 10)
  let matrix = SVGMatrix::translate(5.0, 10.0)
  let transformed = point.matrix_transform(matrix)
  assert_eq(transformed.x, 15.0)
  assert_eq(transformed.y, 10.0)
}

///|
test "SVGPoint::matrix_transform_scale" {
  let point = SVGPoint::new(10.0, 20.0)
  // Scale by 2x
  let matrix = SVGMatrix::scale(2.0, 2.0)
  let transformed = point.matrix_transform(matrix)
  assert_eq(transformed.x, 20.0)
  assert_eq(transformed.y, 40.0)
}

///|
test "SVGMatrix::identity" {
  let m = SVGMatrix::identity()
  assert_eq(m.a, 1.0)
  assert_eq(m.b, 0.0)
  assert_eq(m.c, 0.0)
  assert_eq(m.d, 1.0)
  assert_eq(m.e, 0.0)
  assert_eq(m.f, 0.0)
}

///|
test "SVGMatrix::multiply" {
  // Matrix multiplication: scale(2,3) * translate(10,20)
  // In matrix terms: translate is applied first, then scale
  // Point (1, 1) -> translate to (11, 21) -> scale to (22, 63)
  let scale = SVGMatrix::scale(2.0, 3.0)
  let translate = SVGMatrix::translate(10.0, 20.0)
  let combined = scale.multiply(translate)
  let point = SVGPoint::new(1.0, 1.0)
  let result = point.matrix_transform(combined)
  assert_eq(result.x, 22.0)
  assert_eq(result.y, 63.0)
}

///|
test "SVGMatrix::inverse" {
  let m = SVGMatrix::translate(10.0, 20.0)
  match m.inverse() {
    Some(inv) => {
      // m * inv should be identity
      let identity = m.multiply(inv)
      assert_true(
        (identity.a - 1.0).abs() < 0.0001 &&
        (identity.d - 1.0).abs() < 0.0001 &&
        identity.e.abs() < 0.0001 &&
        identity.f.abs() < 0.0001,
      )
    }
    None => assert_true(false)
  }
}

///|
test "SVGMatrix::inverse_singular" {
  // Singular matrix (determinant = 0)
  let m = SVGMatrix::new(1.0, 2.0, 2.0, 4.0, 0.0, 0.0)
  match m.inverse() {
    Some(_) => assert_true(false) // Should not have inverse
    None => assert_true(true)
  }
}

///|
test "factory functions" {
  let rect = create_svg_rect()
  assert_eq(rect.x, 0.0)
  assert_eq(rect.width, 0.0)
  let point = create_svg_point()
  assert_eq(point.x, 0.0)
  assert_eq(point.y, 0.0)
  let matrix = create_svg_matrix()
  assert_eq(matrix.a, 1.0)
  assert_eq(matrix.d, 1.0)
}

///|
test "SVGNumber" {
  let num = SVGNumber::new(42.5)
  assert_eq(num.value, 42.5)
  let zero = create_svg_number()
  assert_eq(zero.value, 0.0)
}

///|
test "SVGLength" {
  let len = SVGLength::new(100.0)
  assert_eq(len.value, 100.0)
  assert_eq(len.unit_type, Number)
}

///|
test "SVGAngle::to_radians" {
  let angle = SVGAngle::new(180.0)
  let rad = angle.to_radians()
  let pi = 3.14159265358979323846
  assert_true((rad - pi).abs() < 0.0001)
}

///|
test "SVGTransform::translate" {
  let t = SVGTransform::translate(10.0, 20.0)
  assert_eq(t.transform_type, Translate)
  assert_eq(t.matrix.e, 10.0)
  assert_eq(t.matrix.f, 20.0)
}

///|
test "SVGTransform::scale" {
  let t = SVGTransform::scale(2.0, 3.0)
  assert_eq(t.transform_type, Scale)
  assert_eq(t.matrix.a, 2.0)
  assert_eq(t.matrix.d, 3.0)
}

///|
test "SVGTransform::rotate" {
  let t = SVGTransform::rotate(90.0)
  assert_eq(t.transform_type, Rotate)
  assert_eq(t.angle, 90.0)
  // 90 degree rotation: cos(90) = 0, sin(90) = 1
  assert_true(t.matrix.a.abs() < 0.0001) // cos(90) ≈ 0
  assert_true((t.matrix.b - 1.0).abs() < 0.0001) // sin(90) ≈ 1
}
