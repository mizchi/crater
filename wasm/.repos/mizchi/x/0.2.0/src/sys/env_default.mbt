///|
pub fn get_env_var(name : String) -> String? {
  @x_sys.get_env_var(name)
}

///|
pub fn get_env_vars() -> Map[String, String] {
  @x_sys.get_env_vars()
}

///|
pub fn get_cli_args() -> Array[String] {
  @x_sys.get_cli_args()
}

///|
pub fn set_env_var(name : String, value : String) -> Unit {
  @x_sys.set_env_var(name, value)
}

///|
pub fn unset_env_var(name : String) -> Unit {
  @x_sys.unset_env_var(name)
}

///|
pub fn exit(code : Int) -> Unit {
  @x_sys.exit(code)
}
