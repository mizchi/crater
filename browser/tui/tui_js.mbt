///|
/// JavaScript/Node.js process argument implementation.

///|
/// Get command line arguments (after --)
extern "js" fn js_get_args() -> Array[String] =
  #| () => {
  #|   if (typeof process === 'undefined') return [];
  #|   const args = process.argv.slice(2);
  #|   const dashIndex = args.indexOf('--');
  #|   if (dashIndex >= 0) {
  #|     return args.slice(dashIndex + 1);
  #|   }
  #|   return args;
  #| }

///|
/// Get command line arguments
pub fn get_args() -> Array[String] {
  js_get_args()
}
