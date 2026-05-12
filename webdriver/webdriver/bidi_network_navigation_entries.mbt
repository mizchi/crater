///|
priv struct SyntheticNavigationRequestEntry {
  context_id : String
  url : String
  request_token : String
  redirect_count : Int
  navigation : String?
  destination : String
  initiator_type : String?
}

///|
fn BidiProtocol::build_synthetic_navigation_request_entries(
  self : BidiProtocol,
  context_id : String,
  url : String,
  navigation : String?,
) -> Array[SyntheticNavigationRequestEntry] {
  let requests : Array[SyntheticNavigationRequestEntry] = []
  let primary_request_token = self.next_synthetic_network_request_id()
  requests.push({
    context_id,
    url,
    request_token: primary_request_token,
    redirect_count: 0,
    navigation,
    destination: "document",
    initiator_type: None,
  })

  if url.contains("/redirect.py") {
    match synthetic_network_first_query_value(url, "location") {
      Some(redirect_url) =>
        requests.push({
          context_id,
          url: redirect_url,
          request_token: primary_request_token,
          redirect_count: 1,
          navigation,
          destination: "document",
          initiator_type: None,
        })
      None => ()
    }
  }

  match resolve_http_equiv_redirect_url(url) {
    Some(redirected_url) => {
      let redirected_navigation = match navigation {
        Some(navigation_id) => Some(navigation_id + "-redirect")
        None => Some(self.next_synthetic_network_request_id())
      }
      requests.push({
        context_id,
        url: redirected_url,
        request_token: self.next_synthetic_network_request_id(),
        redirect_count: 0,
        navigation: redirected_navigation,
        destination: "document",
        initiator_type: None,
      })
    }
    None => ()
  }

  if synthetic_navigation_is_html_data_url(url) {
    self.append_data_url_navigation_request_entries(
      requests, context_id, navigation,
    )
  }

  self.append_known_navigation_related_requests(
    requests, context_id, url, navigation,
  )
  requests
}

///|
fn BidiProtocol::append_data_url_navigation_request_entries(
  self : BidiProtocol,
  requests : Array[SyntheticNavigationRequestEntry],
  context_id : String,
  navigation : String?,
) -> Unit {
  let child_contexts = self.context_children.get(context_id).unwrap_or([])
  let iframe_sources = self.collect_iframe_sources(context_id)
  if child_contexts.length() > 0 && iframe_sources.length() > 0 {
    let child_context_id = child_contexts[0]
    let child_navigation = self.context_last_started_navigation.get(
      child_context_id,
    )
    requests.push({
      context_id: child_context_id,
      url: iframe_sources[0],
      request_token: self.next_synthetic_network_request_id(),
      redirect_count: 0,
      navigation: child_navigation,
      destination: "iframe",
      initiator_type: Some("iframe"),
    })
  }

  let seen_urls : Map[String, Bool] = {}
  for resource_url in self.collect_attribute_values(context_id, "link", "href") {
    synthetic_navigation_push_unique_resource(
      requests,
      seen_urls,
      context_id,
      resource_url,
      navigation,
      "style",
      Some("link"),
      self,
    )
  }
  for resource_url in self.collect_attribute_values(context_id, "script", "src") {
    synthetic_navigation_push_unique_resource(
      requests,
      seen_urls,
      context_id,
      resource_url,
      navigation,
      "script",
      Some("script"),
      self,
    )
  }
  for resource_url in self.collect_attribute_values(context_id, "img", "src") {
    synthetic_navigation_push_unique_resource(
      requests,
      seen_urls,
      context_id,
      resource_url,
      navigation,
      "image",
      Some("img"),
      self,
    )
  }
  for style_text in self.collect_text_contents(context_id, "style") {
    for resource_url in collect_css_import_urls(style_text) {
      synthetic_navigation_push_unique_resource(
        requests,
        seen_urls,
        context_id,
        resource_url,
        navigation,
        "style",
        Some("link"),
        self,
      )
    }
  }
  for script_text in self.collect_script_texts(context_id) {
    for resource_url in collect_static_import_urls(script_text) {
      synthetic_navigation_push_unique_resource(
        requests,
        seen_urls,
        context_id,
        resource_url,
        navigation,
        "script",
        Some("script"),
        self,
      )
    }
    for resource_url in collect_dynamic_import_urls(script_text) {
      synthetic_navigation_push_unique_resource(
        requests,
        seen_urls,
        context_id,
        resource_url,
        navigation,
        "script",
        Some("script"),
        self,
      )
    }
  }
}

///|
fn BidiProtocol::append_known_navigation_related_requests(
  self : BidiProtocol,
  requests : Array[SyntheticNavigationRequestEntry],
  context_id : String,
  url : String,
  navigation : String?,
) -> Unit {
  ignore(self)
  if url.contains("/initiator/simple-initiator.html") {
    match synthetic_navigation_http_origin(url) {
      Some(origin) => {
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/initiator/simple-initiator-script.js",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "script",
          initiator_type: Some("script"),
        })
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/initiator/simple-initiator-style.css",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "style",
          initiator_type: Some("link"),
        })
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/initiator/simple-initiator-img.png",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "image",
          initiator_type: Some("img"),
        })
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/initiator/simple-initiator-bg.png",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "image",
          initiator_type: Some("css"),
        })
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/empty.html",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "iframe",
          initiator_type: Some("iframe"),
        })
      }
      None => ()
    }
  }
  if url.contains("/webdriver/tests/bidi/network/support/provide_response.html") {
    match synthetic_navigation_http_origin(url) {
      Some(origin) => {
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/provide_response.css",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "style",
          initiator_type: Some("link"),
        })
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/provide_response.js",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "script",
          initiator_type: Some("script"),
        })
      }
      None => ()
    }
  }
}
