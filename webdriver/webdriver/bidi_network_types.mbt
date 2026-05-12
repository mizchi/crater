///|
extern "js" fn js_utf8_byte_length(value : String) -> Int =
  #| (value) => new TextEncoder().encode(String(value ?? "")).length

///|
extern "js" fn js_base64_byte_length(value : String) -> Int =
  #| (value) => {
  #|   try {
  #|     return Uint8Array.from(atob(String(value ?? "")), (c) => c.charCodeAt(0)).length;
  #|   } catch (_) {
  #|     return 0;
  #|   }
  #| }

///|
extern "js" fn js_decode_query_component(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     const text = value === null || value === undefined ? "" : String(value);
  #|     return decodeURIComponent(text.replace(/\+/g, " "));
  #|   } catch (_) {
  #|     return value === null || value === undefined ? "" : String(value);
  #|   }
  #| }

///|
priv struct SyntheticNetworkCookieOverride {
  enabled : Bool
  cookies : Array[Json]
}

///|
priv struct SyntheticNetworkEventInput {
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
priv struct SyntheticNetworkResponseOverrides {
  from_cache : Bool
  headers : Array[Json]
  mime_type : String
  protocol : String
  status : Int
  status_text : String
  auth_challenges : Json?
}

///|
priv struct SyntheticNetworkContinueCredentials {
  username : String
  password : String
}

///|
priv struct SyntheticNetworkSetCookieEntries {
  headers : Array[Json]
  cookies : Array[StoredCookie]
}
