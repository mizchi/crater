///|
test "AuthState::default is empty" {
  let state = AuthState::default()
  inspect(state, content=(
    #|{}
  ))
}
