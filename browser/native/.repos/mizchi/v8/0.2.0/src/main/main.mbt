///|
fn main {
  let source = "'Hello' + ', MoonBit runtime!'"
  match @v8.eval_string(source) {
    Ok(value) => println(value)
    Err(err) => println(err.to_string())
  }
}
