///|
pub fn get_env_var(_name : String) -> String? {
  None
}

///|
pub fn get_env_vars() -> Map[String, String] {
  {}
}

///|
pub fn get_cli_args() -> Array[String] {
  []
}

///|
pub fn set_env_var(_name : String, _value : String) -> Unit {
  abort("set_env_var is not supported on wasm-gc target")
}

///|
pub fn unset_env_var(_name : String) -> Unit {
  abort("unset_env_var is not supported on wasm-gc target")
}

///|
pub fn exit(_code : Int) -> Unit {
  abort("exit is not supported on wasm-gc target")
}
