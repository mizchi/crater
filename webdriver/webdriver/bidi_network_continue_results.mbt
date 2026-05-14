///|
fn BidiProtocol::apply_navigation_provide_response_body_override(
  self : BidiProtocol,
  context_id : String,
  destination : String,
  body_text : String,
) -> Unit {
  ignore(self)
  self.prepare_runtime_context_for_browsing_command(context_id)
  match destination {
    "script" =>
      ignore(evaluate_js_with_console(body_text, false, false, false, "{}"))
    "style" => {
      let body_json = Json::string(body_text).stringify()
      let expression = (
          #|(() => {
          #|  if (
          #|    !document.body &&
          #|    document.documentElement &&
          #|    typeof document.createElement === "function"
          #|  ) {
          #|    const body = document.createElement("body");
          #|    document.documentElement.appendChild(body);
          #|  }
          #|  if (
          #|    document.body &&
          #|    !document.querySelector("div") &&
          #|    typeof document.createElement === "function"
          #|  ) {
          #|    const div = document.createElement("div");
          #|    document.body.appendChild(div);
          #|  }
          #|  const style = document.createElement("style");
        ) +
        "  style.textContent = " +
        body_json +
        ";\n" +
        (
          #|  const parent = document.head || document.documentElement;
          #|  if (parent) parent.appendChild(style);
          #|  const match = /color\s*:\s*([^;}\n]+)/i.exec(style.textContent || "");
          #|  const fallbackColor =
          #|    match && match[1] ? String(match[1]).trim() : "rgb(0, 0, 0)";
          #|  const originalGetComputedStyle =
          #|    typeof globalThis.getComputedStyle === "function"
          #|      ? globalThis.getComputedStyle.bind(globalThis)
          #|      : null;
          #|  const craterGetComputedStyle = function(el) {
          #|    const base = originalGetComputedStyle
          #|      ? originalGetComputedStyle(el)
          #|      : (el && el._style) || {};
          #|    return new Proxy(base || {}, {
          #|      get(target, prop) {
          #|        if (prop === "getPropertyValue") {
          #|          return function(name) {
          #|            const raw = target && target[name] ? target[name] : "";
          #|            if (String(name) === "color" && !raw) return fallbackColor;
          #|            return raw || "";
          #|          };
          #|        }
          #|        if (prop === "color") {
          #|          const raw = target && target[prop] ? target[prop] : "";
          #|          return raw || fallbackColor;
          #|        }
          #|        return target && target[prop] ? target[prop] : "";
          #|      },
          #|    });
          #|  };
          #|  globalThis.getComputedStyle = craterGetComputedStyle;
          #|  window.getComputedStyle = craterGetComputedStyle;
          #|})()
        )
      ignore(evaluate_js_with_console(expression, false, false, false, "{}"))
    }
    _ => {
      let body_json = Json::string(body_text).stringify()
      let expression = (
          #|(() => {
          #|  if (
          #|    !document.body &&
          #|    document.documentElement &&
          #|    typeof document.createElement === "function"
          #|  ) {
          #|    const body = document.createElement("body");
          #|    document.documentElement.appendChild(body);
          #|  }
          #|  if (document.body) {
        ) +
        "    document.body.innerHTML = " +
        body_json +
        ";\n" +
        (
          #|  }
          #|})()
        )
      ignore(evaluate_js_with_console(expression, false, false, false, "{}"))
    }
  }
}

///|
fn BidiProtocol::send_continue_blocked_response_result(
  self : BidiProtocol,
  request_id : Int,
  response_started_event : Json?,
  response_completed_event : Json?,
  auth_required_event : Json?,
  load_event : Json?,
  consumed : Bool,
  status_code : Int?,
  reason_phrase : String?,
  body_text : String?,
) -> Unit {
  let _ = self
  let result : Map[String, Json] = {}
  result["responseStartedEvent"] = match response_started_event {
    Some(event) => event
    None => Json::null()
  }
  result["responseCompletedEvent"] = match response_completed_event {
    Some(event) => event
    None => Json::null()
  }
  result["authRequiredEvent"] = match auth_required_event {
    Some(event) => event
    None => Json::null()
  }
  result["browsingContextLoad"] = match load_event {
    Some(event) => event
    None => Json::null()
  }
  result["consumed"] = Json::boolean(consumed)
  match status_code {
    Some(value) => result["statusCode"] = Json::number(value.to_double())
    None => ()
  }
  match reason_phrase {
    Some(value) => result["reasonPhrase"] = Json::string(value)
    None => ()
  }
  match body_text {
    Some(text) => result["bodyText"] = Json::string(text)
    None => result["bodyText"] = Json::null()
  }
  self.send_success(request_id, Some(make_object(result)))
}

///|
fn BidiProtocol::emit_synthetic_network_event_if_subscribed(
  self : BidiProtocol,
  event_name : String,
  event : Json?,
) -> Unit {
  match event {
    Some(Object(event_map)) =>
      match event_map.get("context") {
        Some(String(context_id)) =>
          if self.is_subscribed_for_context(event_name, context_id) {
            self.outbox.push(
              Event({ event_method: event_name, params: make_object(event_map) }),
            )
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn BidiProtocol::emit_synthetic_network_result_events(
  self : BidiProtocol,
  response_started_event : Json?,
  response_completed_event : Json?,
  auth_required_event : Json?,
  load_event : Json?,
) -> Unit {
  self.emit_synthetic_network_event_if_subscribed(
    "network.responseStarted", response_started_event,
  )
  self.emit_synthetic_network_event_if_subscribed(
    "network.responseCompleted", response_completed_event,
  )
  self.emit_synthetic_network_event_if_subscribed(
    "network.authRequired", auth_required_event,
  )
  match load_event {
    Some(Object(load_map)) =>
      self.outbox.push(
        Event({
          event_method: "browsingContext.load",
          params: make_object(load_map),
        }),
      )
    _ => ()
  }
}

///|
fn BidiProtocol::maybe_emit_followup_preflight_blocked_request(
  self : BidiProtocol,
  blocked_request : Map[String, Json],
) -> Unit {
  let http_method = match blocked_request.get("method") {
    Some(String(name)) => name.to_upper()
    _ => "GET"
  }
  let is_navigation = match
    get_map_field_with_alias(blocked_request, "isNavigation", "is_navigation") {
    Some(True) => true
    _ => false
  }
  if http_method != "OPTIONS" || is_navigation {
    return
  }
  let context_id = match
    get_map_field_with_alias(blocked_request, "contextId", "context_id") {
    Some(String(context_id)) => context_id
    _ => return
  }
  let url = match blocked_request.get("url") {
    Some(String(url)) => url
    _ => return
  }
  let event_name = "network.beforeRequestSent"
  if !self.is_subscribed_for_context(event_name, context_id) {
    return
  }
  let intercepts = self.resolve_matching_network_intercepts_internal(
    context_id, "beforeRequestSent", url,
  )
  if intercepts.length() == 0 {
    return
  }
  let request_token = self.next_synthetic_network_request_id()
  let request_headers = match blocked_request.get("request_headers") {
    Some(Object(request_headers)) =>
      synthetic_network_header_entries_from_object(request_headers)
    _ => []
  }
  let resolved_request_headers = self.resolve_network_extra_header_entries(
    context_id, request_headers,
  )
  let redirect_count = match blocked_request.get("redirect_count") {
    Some(redirect_count) =>
      storage_json_non_negative_int(redirect_count).unwrap_or(0)
    None => 0
  }
  let navigation : String? = match blocked_request.get("navigation") {
    Some(String(navigation)) => Some(navigation)
    _ => None
  }
  let destination = match blocked_request.get("destination") {
    Some(String(destination)) => destination
    _ => ""
  }
  let initiator_type : String? = match
    get_map_field_with_alias(blocked_request, "initiatorType", "initiator_type") {
    Some(String(initiator_type)) => Some(initiator_type)
    _ => Some("fetch")
  }
  let input : @crater_network.SyntheticNetworkEventInput = {
    context_id,
    url,
    http_method: "GET",
    request_token,
    request_headers: resolved_request_headers,
    request_value: None,
    request_cookies: [],
    request_cookies_override: false,
    intercepts,
    redirect_count,
    navigation,
    destination,
    initiator_type,
  }
  let event = match
    self.build_synthetic_before_request_sent_event_json(0, input) {
    Some(event) => event
    None => return
  }
  self.outbox.push(Event({ event_method: event_name, params: event }))
  let followup_blocked_request : Map[String, Json] = {}
  followup_blocked_request["phase"] = Json::string("beforeRequestSent")
  followup_blocked_request["context_id"] = Json::string(context_id)
  followup_blocked_request["url"] = Json::string(url)
  followup_blocked_request["method"] = Json::string("GET")
  followup_blocked_request["request_headers"] = match
    blocked_request.get("request_headers") {
    Some(Object(request_headers)) => make_object(request_headers)
    _ => make_object({})
  }
  followup_blocked_request["redirect_count"] = Json::number(
    redirect_count.to_double(),
  )
  followup_blocked_request["navigation"] = match navigation {
    Some(navigation) => Json::string(navigation)
    None => Json::null()
  }
  followup_blocked_request["destination"] = Json::string(destination)
  followup_blocked_request["initiator_type"] = match initiator_type {
    Some(initiator_type) => Json::string(initiator_type)
    None => Json::null()
  }
  followup_blocked_request["is_navigation"] = Json::boolean(false)
  self.remember_network_blocked_request(request_token, followup_blocked_request)
}

///|
fn BidiProtocol::build_synthetic_auth_required_event_json(
  self : BidiProtocol,
  request_id : Int,
  input : @crater_network.SyntheticNetworkEventInput,
  blocked_request : Map[String, Json],
) -> Json? {
  let resolved_overrides = self.resolve_synthetic_response_overrides_internal(
    input.context_id,
    input.url,
    input.http_method,
    input.request_headers,
    false,
  )
  let realm = synthetic_network_first_query_value(input.url, "realm").unwrap_or(
    "testrealm",
  )
  let status = synthetic_network_blocked_response_status(blocked_request)
  let response_overrides : @crater_network.SyntheticNetworkResponseOverrides = {
    from_cache: resolved_overrides.from_cache,
    headers: if synthetic_network_blocked_response_headers(blocked_request).length() >
      0 {
      synthetic_network_blocked_response_headers(blocked_request)
    } else {
      resolved_overrides.headers
    },
    mime_type: resolved_overrides.mime_type,
    protocol: resolved_overrides.protocol,
    status,
    status_text: synthetic_network_blocked_response_status_text(
      blocked_request, status,
    ),
    auth_challenges: Some(
      Json::array([
        make_object({
          "scheme": Json::string("Basic"),
          "realm": Json::string(realm),
        }),
      ]),
    ),
  }
  self.build_synthetic_response_event_json(
    request_id, input, response_overrides,
  )
}

///|
fn BidiProtocol::synthetic_network_request_lookup_id(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let _ = self
  match params {
    Some(Object(map)) =>
      match map.get("request") {
        Some(String(request_lookup_id)) => Some(request_lookup_id)
        _ => {
          self.send_error(
            request_id, "invalid argument", "request must be a string",
          )
          None
        }
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      None
    }
  }
}
