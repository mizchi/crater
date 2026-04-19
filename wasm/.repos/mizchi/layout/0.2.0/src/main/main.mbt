///|
fn main {
  let (start, gap) = @lib.compute_justify(@types.SpaceAround, 120.0, 3)
  println("start=\{start}, gap=\{gap}")
}
