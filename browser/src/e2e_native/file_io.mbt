///|
/// Native file I/O for E2E tests.
/// Uses C helper to read files as byte arrays.

///|
extern "C" fn c_read_file_size(path : Int) -> Int = "moonbit_read_file_size_ptr"

///|
extern "C" fn c_read_file_data(
  path : Int,
  buf : Int,
  buf_size : Int,
) -> Int = "moonbit_read_file_data_ptr"

// Simpler approach: use V8 to read files via JS
// Since we have V8, let's use Node.js-style file reading

///|
pub fn read_file_to_string_via_eval(path : String) -> String? {
  // For now, return None - file reading not available
  // Tests should use pre-captured HTML embedded in the test or passed via globals
  let _ = path
  None
}
