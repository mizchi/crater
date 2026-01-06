///|
/// Tests for Browser API types
test "selector to string - css" {
  let sel : Selector = Selector::Css("#my-id")
  inspect(sel.to_string(), content="css=#my-id")
}

///|
test "selector to string - xpath" {
  let sel : Selector = Selector::XPath("//div[@class='test']")
  inspect(sel.to_string(), content="xpath=//div[@class='test']")
}

///|
test "selector to string - text" {
  let sel : Selector = Selector::Text("Click me")
  inspect(sel.to_string(), content="text=\"Click me\"")
}

///|
test "selector to string - role with name" {
  let sel : Selector = Selector::Role(role="button", name=Some("Submit"))
  inspect(sel.to_string(), content="role=button[name=\"Submit\"]")
}

///|
test "selector to string - role without name" {
  let sel : Selector = Selector::Role(role="heading", name=None)
  inspect(sel.to_string(), content="role=heading")
}

///|
test "selector to string - testid" {
  let sel : Selector = Selector::TestId("login-form")
  inspect(sel.to_string(), content="data-testid=login-form")
}

///|
test "modifiers none" {
  let mods = Modifiers::none()
  assert_false(mods.ctrl)
  assert_false(mods.shift)
  assert_false(mods.alt)
  assert_false(mods.meta)
}

///|
test "api error variants" {
  let err1 : ApiError = ApiError::ElementNotFound(selector="#missing")
  let err2 : ApiError = ApiError::Timeout(message="Waited too long")
  let err3 : ApiError = ApiError::NavigationFailed(
    url="http://bad.url",
    reason="Network error",
  )
  // Just check they can be created
  inspect(err1, content="ElementNotFound(selector=\"#missing\")")
  inspect(err2, content="Timeout(message=\"Waited too long\")")
  assert_true(err3.to_string().contains("NavigationFailed"))
}

///|
test "api result ok" {
  let result : ApiResult[String] = ApiResult::Ok("success")
  match result {
    ApiResult::Ok(v) => inspect(v, content="success")
    ApiResult::Err(_) => fail("Expected Ok")
  }
}

///|
test "api result err" {
  let result : ApiResult[String] = ApiResult::Err(
    ApiError::ElementNotFound(selector="#id"),
  )
  match result {
    ApiResult::Ok(_) => fail("Expected Err")
    ApiResult::Err(e) =>
      match e {
        ApiError::ElementNotFound(selector~) => inspect(selector, content="#id")
        _ => fail("Expected ElementNotFound")
      }
  }
}

///|
test "api method enum" {
  let m1 : ApiMethod = ApiMethod::NewContext
  let m2 : ApiMethod = ApiMethod::Goto(page_id="p1", url="http://example.com")
  let m3 : ApiMethod = ApiMethod::Click(element_id="btn")
  inspect(m1, content="NewContext")
  assert_true(m2.to_string().contains("Goto"))
  assert_true(m3.to_string().contains("Click"))
}
