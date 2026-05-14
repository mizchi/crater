///|
test "print page range validation accepts bidi range forms" {
  assert_true(is_valid_print_page_range("1"))
  assert_true(is_valid_print_page_range("1-3"))
  assert_true(is_valid_print_page_range("2-"))
  assert_true(is_valid_print_page_range("-4"))
}

///|
test "print page range validation rejects empty invalid and reversed ranges" {
  assert_false(is_valid_print_page_range(""))
  assert_false(is_valid_print_page_range("0"))
  assert_false(is_valid_print_page_range("3-1"))
  assert_false(is_valid_print_page_range("1-2-3"))
  assert_false(is_valid_print_page_range("abc"))
}

///|
test "print options normalize default values" {
  match normalize_print_options({}) {
    Ok(options) => {
      inspect(options.orientation, content="portrait")
      inspect(options.background, content="false")
      inspect(options.printable_width_cm, content="21.59")
      inspect(options.printable_height_cm, content="27.94")
    }
    Err(error) => fail("unexpected print options error: " + error.message())
  }
}

///|
test "print options swap page size for landscape orientation" {
  let params : Map[String, Json] = {
    "orientation": Json::string("landscape"),
    "page": Json::object({
      "width": Json::number(10.0),
      "height": Json::number(20.0),
    }),
  }
  match normalize_print_options(params) {
    Ok(options) => {
      inspect(options.orientation, content="landscape")
      inspect(options.printable_width_cm, content="20")
      inspect(options.printable_height_cm, content="10")
    }
    Err(error) => fail("unexpected print options error: " + error.message())
  }
}

///|
test "print options clamp one-sided margin to minimum printable area" {
  let params : Map[String, Json] = {
    "margin": Json::object({ "top": Json::number(26.94) }),
  }
  match normalize_print_options(params) {
    Ok(options) => {
      inspect(options.printable_width_cm, content="21.59")
      assert_true(options.printable_height_cm < 27.94)
      assert_true(options.printable_height_cm > 27.9)
    }
    Err(error) => fail("unexpected print options error: " + error.message())
  }
}

///|
test "print options report shrink to fit validation errors" {
  let params : Map[String, Json] = { "shrink_to_fit": Json::object({}) }
  match normalize_print_options(params) {
    Ok(_) => fail("expected invalid shrinkToFit")
    Err(error) => {
      inspect(error.name(), content="invalid argument")
      inspect(error.message(), content="shrinkToFit must be a boolean")
    }
  }
}
