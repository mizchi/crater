///|
fn main {
  let size = @lib.Size::new(100.0, 200.0)
  println("Size: width=\{size.width}, height=\{size.height}")
  let rect = @lib.BoundingRect::new(10.0, 20.0, 100.0, 50.0)
  println(
    "BoundingRect: x=\{rect.x}, y=\{rect.y}, width=\{rect.width}, height=\{rect.height}",
  )
}
