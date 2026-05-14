///|
test "network intercept phase and context options match" {
  let options = {
    "phases": Json::array([
      Json::string("beforeRequestSent"),
      Json::string("responseStarted"),
    ]),
    "contexts": Json::array([Json::string("child")]),
  }
  assert_true(network_intercept_matches_phase(options, "beforeRequestSent"))
  assert_false(network_intercept_matches_phase(options, "authRequired"))
  assert_true(network_option_contexts_match(options, ["top", "child"]))
  assert_false(network_option_contexts_match(options, ["other"]))
  assert_true(network_option_contexts_match({}, []))
}

///|
test "network string URL patterns canonicalize HTTP defaults" {
  let options = {
    "urlPatterns": Json::array([
      Json::object({
        "type": Json::string("string"),
        "pattern": Json::string("http://Example.test/path?q=1"),
      }),
    ]),
  }
  assert_true(
    network_url_patterns_match(options, "http://example.test:80/path?q=1"),
  )
  assert_false(
    network_url_patterns_match(options, "http://example.test:80/path?q=2"),
  )
  assert_true(
    network_url_patterns_match(
      {
        "urlPatterns": Json::array([
          Json::object({
            "type": Json::string("string"),
            "pattern": Json::string("data:text/plain,ok"),
          }),
        ]),
      },
      "data:text/plain,ok",
    ),
  )
}

///|
test "network object URL patterns match selected URL parts" {
  let options = {
    "urlPatterns": Json::array([
      Json::object({
        "type": Json::string("pattern"),
        "protocol": Json::string("https:"),
        "hostname": Json::string("EXAMPLE.test"),
        "port": Json::string("443"),
        "pathname": Json::string("docs/page"),
        "search": Json::string("q=1"),
      }),
    ]),
  }
  assert_true(
    network_url_patterns_match(
      options, "https://example.test/docs/page?q=1#top",
    ),
  )
  assert_false(
    network_url_patterns_match(options, "https://example.test/docs/page?q=2"),
  )
  assert_false(
    network_url_patterns_match(options, "http://example.test/docs/page?q=1"),
  )
}
