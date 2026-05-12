///|
/// Native process argument implementation.

///|
pub fn get_args() -> Array[String] {
  let all_args = @sys.get_cli_args()
  let result : Array[String] = []
  for i = 1; i < all_args.length(); i = i + 1 {
    result.push(all_args[i])
  }
  result
}
