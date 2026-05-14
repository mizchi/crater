///|
test "batch render options normalize defaults and mutations" {
  let params : Map[String, Json] = {
    "variants": Json::array([
      Json::object({
        "id": Json::string("wide"),
        "mutations": Json::array([
          Json::object({
            "selector": Json::string(".hero"),
            "property": Json::string("display"),
            "action": Json::object({ "override": Json::string("block") }),
          }),
        ]),
      }),
    ]),
  }
  match normalize_batch_render_options(params, "<html></html>") {
    Ok(options) => {
      inspect(options.base_html, content="<html></html>")
      inspect(options.viewport.width, content="1280")
      inspect(options.viewport.height, content="900")
      inspect(options.variants.length(), content="1")
      let variant = options.variants[0]
      inspect(variant.id, content="wide")
      inspect(variant.mutations.length(), content="1")
      let mutation = variant.mutations[0]
      inspect(mutation.selector, content=".hero")
      inspect(mutation.property, content="display")
      match mutation.action {
        @vrt.CssMutationAction::Override(value) =>
          inspect(value, content="block")
        _ => fail("expected override mutation")
      }
    }
    Err(error) =>
      fail("unexpected batch render options error: " + error.message())
  }
}

///|
test "batch render options preserve explicit base html and viewport" {
  let params : Map[String, Json] = {
    "baseHtml": Json::string("<main></main>"),
    "viewport": Json::object({
      "width": Json::number(375.0),
      "height": Json::number(667.0),
    }),
    "variants": Json::array([]),
  }
  match normalize_batch_render_options(params, "<fallback></fallback>") {
    Ok(options) => {
      inspect(options.base_html, content="<main></main>")
      inspect(options.viewport.width, content="375")
      inspect(options.viewport.height, content="667")
      inspect(options.variants.length(), content="0")
    }
    Err(error) =>
      fail("unexpected batch render options error: " + error.message())
  }
}

///|
test "batch render options reject non string base html" {
  let params : Map[String, Json] = {
    "baseHtml": Json::number(1.0),
    "variants": Json::array([]),
  }
  match normalize_batch_render_options(params, "<html></html>") {
    Ok(_) => fail("expected invalid baseHtml")
    Err(error) => {
      inspect(error.name(), content="invalid argument")
      inspect(error.message(), content="baseHtml must be a string")
    }
  }
}

///|
test "batch render options require variants array" {
  match normalize_batch_render_options({}, "<html></html>") {
    Ok(_) => fail("expected invalid variants")
    Err(error) => {
      inspect(error.name(), content="invalid argument")
      inspect(error.message(), content="variants must be an array")
    }
  }
}

///|
test "batch render results serialize to bidi result object" {
  let results = @vrt.render_html_batch_variants(
    "<main>hello</main>",
    @types.Size::new(120.0, 80.0),
    [{ id: "base", mutations: [] }],
  )
  match batch_render_results_to_json(results) {
    Object(output) =>
      match output.get("results") {
        Some(Array(items)) => {
          inspect(items.length(), content="1")
          match items[0] {
            Object(item) => {
              match item.get("id") {
                Some(String(id)) => inspect(id, content="base")
                _ => fail("expected id")
              }
              match item.get("paintTree") {
                Some(Object(_)) => ()
                _ => fail("expected paintTree object")
              }
            }
            _ => fail("expected result object")
          }
        }
        _ => fail("expected results array")
      }
    _ => fail("expected output object")
  }
}
