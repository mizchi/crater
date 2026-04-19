///|
async fn collect_output_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  @async_process.collect_output(cmd, args, cwd?, extra_env~, inherit_env~)
}

///|
async fn run_inherit_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> Int {
  @async_process.run(cmd, args, cwd?, extra_env~, inherit_env~)
}

///|
async fn collect_output_merged_internal(
  cmd : StringView,
  args : Array[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> (Int, &@async_io.Data) {
  @async_process.collect_output_merged(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
  )
}
