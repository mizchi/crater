///|
test "webdriver-bidi facade parses api method names" {
  match parse_method("newContext") {
    Some(ApiMethod::NewContext) => ()
    _ => fail("expected newContext to parse as NewContext")
  }
  match parse_method("Page.navigate") {
    Some(ApiMethod::Goto(page_id~, url~)) => {
      inspect(page_id, content="")
      inspect(url, content="")
    }
    _ => fail("expected Page.navigate to parse as Goto")
  }
}

///|
test "webdriver-bidi facade exposes server configuration without cdp handlers" {
  let config = BidiServerConfig::{
    host: "127.0.0.1",
    port: 9222,
    auth_token: "test-token",
  }

  inspect(
    config.web_socket_url(),
    content="ws://127.0.0.1:9222/session/test-token",
  )
  let _server = BidiServer::new(config~)
}
