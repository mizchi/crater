///|

///|
fn stub_glyph_provider(
  base_advance : Double,
  kern : Double,
) -> @image.GlyphProvider {
  {
    get_glyph: fn(_codepoint, _font_size, _is_bold) { ([], base_advance) },
    get_kern: fn(_cp1, _cp2, _font_size, _is_bold) { kern },
    ascent_ratio: base_advance / 10.0,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_ascent_for_family: None,
  }
}

///|
test "merge_glyph_providers uses bold provider for bold requests" {
  let merged = merge_glyph_providers(
    stub_glyph_provider(10.0, 1.0),
    Some(stub_glyph_provider(20.0, 2.0)),
  )
  let (_, regular_advance) = (merged.get_glyph)(65, 16.0, false)
  let (_, bold_advance) = (merged.get_glyph)(65, 16.0, true)
  let regular_kern = (merged.get_kern)(65, 66, 16.0, false)
  let bold_kern = (merged.get_kern)(65, 66, 16.0, true)
  inspect(regular_advance, content="10")
  inspect(bold_advance, content="20")
  inspect(regular_kern, content="1")
  inspect(bold_kern, content="2")
}

///|
test "merge_glyph_providers falls back to regular provider without bold font" {
  let merged = merge_glyph_providers(stub_glyph_provider(10.0, 1.0), None)
  let (_, regular_advance) = (merged.get_glyph)(65, 16.0, false)
  let (_, bold_advance) = (merged.get_glyph)(65, 16.0, true)
  let regular_kern = (merged.get_kern)(65, 66, 16.0, false)
  let bold_kern = (merged.get_kern)(65, 66, 16.0, true)
  inspect(regular_advance, content="10")
  inspect(bold_advance, content="10")
  inspect(regular_kern, content="1")
  inspect(bold_kern, content="1")
}

///|
test "parse_args_list reads component artifact options" {
  let options = parse_args_list([
    "--html-file", "fixture.html", "--css-file", "baseline.css", "--css-file", "component.css",
    "--target-id", "card-root", "--artifact", "landmarks", "--viewport-width", "960",
    "--viewport-height", "720",
  ])
  inspect(options.html_file, content="fixture.html")
  inspect(options.css_files.length(), content="2")
  inspect(options.css_files[0], content="baseline.css")
  inspect(options.css_files[1], content="component.css")
  inspect(options.target_id, content="Some(\"card-root\")")
  inspect(options.target_selector, content="None")
  inspect(options.artifact, content="Landmarks")
  inspect(options.viewport_width, content="960")
  inspect(options.viewport_height, content="720")
}

///|
test "parse_args_list reads selector target option" {
  let options = parse_args_list([
    "--html-file", "fixture.html", "--target-selector", ".card.primary", "--artifact",
    "layout",
  ])
  inspect(options.target_id, content="None")
  inspect(options.target_selector, content="Some(\".card.primary\")")
  inspect(options.artifact, content="Layout")
}

///|
test "parse_args_list reads stdin and output options" {
  let options = parse_args_list([
    "--stdin-html", "--stdin-css", "--target-id", "card-root", "--output-file", "artifact.json",
  ])
  inspect(options.stdin_html, content="true")
  inspect(options.stdin_css, content="true")
  inspect(options.output_file, content="Some(\"artifact.json\")")
}

///|
test "validate_options rejects html file together with stdin html" {
  let options = parse_args_list([
    "--html-file", "fixture.html", "--stdin-html", "--target-id", "card-root",
  ])
  match validate_options(options) {
    Some(error) =>
      inspect(error, content="Choose either --html-file or --stdin-html")
    None => panic()
  }
}

///|
test "validate_options rejects target id together with target selector" {
  let options = parse_args_list([
    "--html-file", "fixture.html", "--target-id", "card-root", "--target-selector",
    ".card",
  ])
  match validate_options(options) {
    Some(error) =>
      inspect(error, content="Choose either --target-id or --target-selector")
    None => panic()
  }
}

///|
test "render_artifact returns landmark tree for target subtree" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|  <body>
    #|    <div id="noise">ignore me</div>
    #|    <section id="card-root" role="region" aria-label="Billing Card">
    #|      <nav aria-label="Card Nav">
    #|        <a href="/">Home</a>
    #|      </nav>
    #|      <footer role="contentinfo" aria-label="Card Actions">
    #|        <button>Open</button>
    #|      </footer>
    #|    </section>
    #|  </body>
    #|</html>
  let artifact = match
    render_artifact_or_error(
      {
        html,
        css: [],
        target_id: Some("card-root"),
        target_selector: None,
        viewport_width: 800,
        viewport_height: 600,
      },
      Landmarks,
    ) {
    Ok(output) => output
    Err(_error) => panic()
  }
  inspect(artifact.contains("\"schemaVersion\":1"), content="true")
  inspect(artifact.contains("\"artifact\":\"landmarks\""), content="true")
  inspect(artifact.contains("\"targetId\":\"card-root\""), content="true")
  inspect(artifact.contains("\"role\":\"region\""), content="true")
  inspect(artifact.contains("\"role\":\"navigation\""), content="true")
  inspect(artifact.contains("\"role\":\"contentinfo\""), content="true")
  inspect(artifact.contains("ignore me"), content="false")
}

///|
test "render_artifact resolves selector target to a synthetic id" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|  <body>
    #|    <div class="noise"></div>
    #|    <section class="card primary" role="region" aria-label="Billing Card">
    #|      <nav aria-label="Card Nav">
    #|        <a href="/">Home</a>
    #|      </nav>
    #|    </section>
    #|  </body>
    #|</html>
  let artifact = match
    render_artifact_or_error(
      {
        html,
        css: [],
        target_id: None,
        target_selector: Some(".card.primary"),
        viewport_width: 800,
        viewport_height: 600,
      },
      Landmarks,
    ) {
    Ok(output) => output
    Err(_error) => panic()
  }
  inspect(artifact.contains("\"artifact\":\"landmarks\""), content="true")
  inspect(artifact.contains("\"targetId\":\"crater-e"), content="true")
  inspect(artifact.contains("\"role\":\"region\""), content="true")
  inspect(artifact.contains("\"role\":\"navigation\""), content="true")
}

///|
test "render_artifact returns layout metadata for target subtree" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|  <body>
    #|    <div id="noise" style="width: 400px; height: 80px;">ignore me</div>
    #|    <div id="card-root" style="width: 120px; height: 40px;"></div>
    #|  </body>
    #|</html>
  let artifact = match
    render_artifact_or_error(
      {
        html,
        css: [],
        target_id: Some("card-root"),
        target_selector: None,
        viewport_width: 800,
        viewport_height: 600,
      },
      Layout,
    ) {
    Ok(output) => output
    Err(_error) => panic()
  }
  inspect(artifact.contains("\"schemaVersion\":1"), content="true")
  inspect(artifact.contains("\"artifact\":\"layout\""), content="true")
  inspect(artifact.contains("\"targetId\":\"card-root\""), content="true")
  inspect(
    artifact.contains("\"viewport\":{\"width\":800,\"height\":600}"),
    content="true",
  )
  inspect(
    artifact.contains("\"data\":{\"id\":\"div#card-root\""),
    content="true",
  )
}

///|
test "render_artifact returns image metadata for target subtree" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|  <body>
    #|    <div id="noise" style="width: 400px; height: 80px;">ignore me</div>
    #|    <div id="card-root" style="width: 120px; height: 40px; background: #ff0000;"></div>
    #|  </body>
    #|</html>
  let artifact = match
    render_artifact_or_error(
      {
        html,
        css: [],
        target_id: Some("card-root"),
        target_selector: None,
        viewport_width: 800,
        viewport_height: 600,
      },
      Image,
    ) {
    Ok(output) => output
    Err(_error) => panic()
  }
  inspect(artifact.contains("\"schemaVersion\":1"), content="true")
  inspect(artifact.contains("\"artifact\":\"image\""), content="true")
  inspect(artifact.contains("\"targetId\":\"card-root\""), content="true")
  inspect(artifact.contains("\"encoding\":\"png-base64\""), content="true")
  inspect(artifact.contains("\"width\":120"), content="true")
  inspect(artifact.contains("\"height\":40"), content="true")
  inspect(artifact.contains("\"data\":\""), content="true")
}

///|
test "help_text explains input model artifact modes and css layering" {
  let help = help_text()
  inspect(
    help.contains("Render one component artifact from HTML + CSS inputs."),
    content="true",
  )
  inspect(
    help.contains("Applies every --css-file in the order given."),
    content="true",
  )
  inspect(
    help.contains("layout     Layout JSON for the target subtree only"),
    content="true",
  )
  inspect(
    help.contains("image      PNG base64 JSON with width/height metadata"),
    content="true",
  )
  inspect(
    help.contains(
      "landmarks  Accessibility landmark tree JSON for fast structural checks",
    ),
    content="true",
  )
  inspect(
    help.contains(
      "Every artifact is emitted as JSON schema v1 with schemaVersion/artifact/targetId fields.",
    ),
    content="true",
  )
  inspect(
    help.contains(
      "Selector targets are normalized to the resolved DOM id in targetId.",
    ),
    content="true",
  )
  inspect(help.contains("--target-selector <selector>"), content="true")
  inspect(
    help.contains(
      "--viewport-width <px>       Viewport width in px (default: 1280)",
    ),
    content="true",
  )
}
