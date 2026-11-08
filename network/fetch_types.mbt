///|
pub(all) struct SyntheticFetchPlanEntry {
  url : String
  http_method : String
  request_token : String
  redirect_count : Int32
  request_value : Json?
}

///|
pub(all) struct SyntheticFetchStepResult {
  blocked_text : String?
  response_value : Json?
}

///|
pub(all) struct SyntheticFetchCommandResult {
  blocked_text : String?
  response_value : Json
}
