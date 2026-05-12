///|
priv struct SyntheticFetchPlanEntry {
  url : String
  http_method : String
  request_token : String
  redirect_count : Int
  request_value : Json?
}

///|
priv struct SyntheticFetchStepResult {
  blocked_text : String?
  response_value : Json?
}

///|
priv struct SyntheticFetchCommandResult {
  blocked_text : String?
  response_value : Json
}
