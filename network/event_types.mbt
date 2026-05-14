///|
pub(all) struct SyntheticNetworkCookieOverride {
  enabled : Bool
  cookies : Array[Json]
}

///|
pub(all) struct SyntheticNetworkEventInput {
  context_id : String
  url : String
  http_method : String
  request_token : String
  request_headers : Array[Json]
  request_value : Json?
  request_cookies : Array[Json]
  request_cookies_override : Bool
  intercepts : Array[String]
  redirect_count : Int
  navigation : String?
  destination : String
  initiator_type : String?
}

///|
pub(all) struct SyntheticNetworkResponseOverrides {
  from_cache : Bool
  headers : Array[Json]
  mime_type : String
  protocol : String
  status : Int
  status_text : String
  auth_challenges : Json?
}

///|
pub(all) struct SyntheticNetworkContinueCredentials {
  username : String
  password : String
}
