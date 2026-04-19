///|
fn collect_output_internal(
  _cmd : StringView,
  _args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  ignore((cwd, extra_env, inherit_env))
  abort("process is not supported on wasm target")
}

///|
fn collect_output_merged_internal(
  _cmd : StringView,
  _args : Array[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> (Int, &@async_io.Data) {
  ignore((cwd, extra_env, inherit_env))
  abort("process is not supported on wasm target")
}
