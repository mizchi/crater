///|
test "Size::new and zero" {
  let size = Size::new(100.0, 200.0)
  inspect(size.width, content="100")
  inspect(size.height, content="200")
  let zero = Size::zero()
  inspect(zero.width, content="0")
  inspect(zero.height, content="0")
}

///|
test "Point::new and zero" {
  let point = Point::new(10.0, 20.0)
  inspect(point.x, content="10")
  inspect(point.y, content="20")
  let zero = Point::zero()
  inspect(zero.x, content="0")
  inspect(zero.y, content="0")
}

///|
test "Rect::new and sums" {
  let rect : Rect[Double] = Rect::new(10.0, 20.0, 5.0, 15.0)
  inspect(rect.horizontal_sum(), content="30")
  inspect(rect.vertical_sum(), content="20")
}

///|
test "Dimension::resolve" {
  let length : Dimension = Length(50.0)
  let percent : Dimension = Percent(0.5)
  let auto : Dimension = Auto
  inspect(length.resolve(100.0), content="Some(50)")
  inspect(percent.resolve(100.0), content="Some(50)")
  inspect(auto.resolve(100.0), content="None")
  inspect(auto.resolve_or(100.0, 25.0), content="25")
}

///|
test "BoundingRect operations" {
  let rect = BoundingRect::new(10.0, 20.0, 100.0, 50.0)
  inspect(rect.right(), content="110")
  inspect(rect.bottom(), content="70")
  inspect(rect.area(), content="5000")
}

///|
test "BoundingRect::union" {
  let a = BoundingRect::new(0.0, 0.0, 50.0, 50.0)
  let b = BoundingRect::new(25.0, 25.0, 50.0, 50.0)
  let u = a.union(b)
  inspect(u.x, content="0")
  inspect(u.y, content="0")
  inspect(u.width, content="75")
  inspect(u.height, content="75")
}
