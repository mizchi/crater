///|
/// SVG Rendering Benchmarks

// Simple rectangle
test "bench: render simple rect 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><rect width=\"100\" height=\"100\" fill=\"blue\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// Multiple rectangles

///|
test "bench: render 10 rects 200x200" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 200 200\">" +
    "<rect x=\"0\" y=\"0\" width=\"20\" height=\"20\" fill=\"red\"/>" +
    "<rect x=\"20\" y=\"0\" width=\"20\" height=\"20\" fill=\"green\"/>" +
    "<rect x=\"40\" y=\"0\" width=\"20\" height=\"20\" fill=\"blue\"/>" +
    "<rect x=\"60\" y=\"0\" width=\"20\" height=\"20\" fill=\"yellow\"/>" +
    "<rect x=\"80\" y=\"0\" width=\"20\" height=\"20\" fill=\"cyan\"/>" +
    "<rect x=\"100\" y=\"0\" width=\"20\" height=\"20\" fill=\"magenta\"/>" +
    "<rect x=\"120\" y=\"0\" width=\"20\" height=\"20\" fill=\"orange\"/>" +
    "<rect x=\"140\" y=\"0\" width=\"20\" height=\"20\" fill=\"purple\"/>" +
    "<rect x=\"160\" y=\"0\" width=\"20\" height=\"20\" fill=\"pink\"/>" +
    "<rect x=\"180\" y=\"0\" width=\"20\" height=\"20\" fill=\"brown\"/>" +
    "</svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 200, 200)) })
}

// Circle

///|
test "bench: render circle 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"red\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// Path with curves

///|
test "bench: render path bezier 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><path d=\"M10 80 Q 50 10 90 80 T 170 80\" fill=\"none\" stroke=\"blue\" stroke-width=\"2\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// Complex path (star)

///|
test "bench: render path star 200x200" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 200 200\"><path d=\"M100 10 L120 75 L190 75 L135 115 L155 180 L100 145 L45 180 L65 115 L10 75 L80 75 Z\" fill=\"gold\" stroke=\"orange\" stroke-width=\"3\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 200, 200)) })
}

// Linear gradient

///|
test "bench: render linear gradient 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><defs><linearGradient id=\"g1\"><stop offset=\"0%\" stop-color=\"red\"/><stop offset=\"100%\" stop-color=\"blue\"/></linearGradient></defs><rect width=\"100\" height=\"100\" fill=\"url(#g1)\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// Radial gradient

///|
test "bench: render radial gradient 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><defs><radialGradient id=\"g2\"><stop offset=\"0%\" stop-color=\"white\"/><stop offset=\"100%\" stop-color=\"black\"/></radialGradient></defs><circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"url(#g2)\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// ClipPath

///|
test "bench: render clipPath 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><defs><clipPath id=\"cp\"><circle cx=\"50\" cy=\"50\" r=\"40\"/></clipPath></defs><rect width=\"100\" height=\"100\" fill=\"blue\" clip-path=\"url(#cp)\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// Mask

///|
test "bench: render mask 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><defs><mask id=\"m\"><rect width=\"100\" height=\"100\" fill=\"white\"/><circle cx=\"50\" cy=\"50\" r=\"30\" fill=\"black\"/></mask></defs><rect width=\"100\" height=\"100\" fill=\"red\" mask=\"url(#m)\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// Transform

///|
test "bench: render transform rotate 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><rect x=\"25\" y=\"25\" width=\"50\" height=\"50\" fill=\"green\" transform=\"rotate(45 50 50)\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// Nested groups

///|
test "bench: render nested groups 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><g transform=\"translate(10,10)\"><g transform=\"scale(0.8)\"><g transform=\"rotate(15)\"><rect width=\"50\" height=\"50\" fill=\"purple\"/></g></g></g></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// Use element

///|
test "bench: render use element 200x200" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 200 200\"><defs><rect id=\"r\" width=\"30\" height=\"30\" fill=\"teal\"/></defs><use href=\"#r\" x=\"10\" y=\"10\"/><use href=\"#r\" x=\"50\" y=\"50\"/><use href=\"#r\" x=\"90\" y=\"90\"/><use href=\"#r\" x=\"130\" y=\"130\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 200, 200)) })
}

// Large canvas

///|
test "bench: render rect 500x500" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 500 500\"><rect width=\"500\" height=\"500\" fill=\"navy\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 500, 500)) })
}

// Stroked path

///|
test "bench: render thick stroke 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><path d=\"M10 10 L90 90 M90 10 L10 90\" stroke=\"black\" stroke-width=\"10\" stroke-linecap=\"round\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// Polygon

///|
test "bench: render polygon 100x100" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 100 100\"><polygon points=\"50,10 90,90 10,90\" fill=\"lime\" stroke=\"darkgreen\" stroke-width=\"2\"/></svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 100, 100)) })
}

// Parse only (no render)

///|
test "bench: parse only complex svg" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 200 200\"><defs><linearGradient id=\"lg\"><stop offset=\"0%\" stop-color=\"red\"/><stop offset=\"100%\" stop-color=\"blue\"/></linearGradient></defs><g transform=\"translate(10,10)\"><rect width=\"50\" height=\"50\" fill=\"url(#lg)\"/><circle cx=\"100\" cy=\"50\" r=\"30\" fill=\"green\"/></g></svg>"
  b.bench(fn() { b.keep(parse_svg_document(svg)) })
}

// Parse + render full pipeline

///|
test "bench: full pipeline 200x200" (b : @bench.T) {
  let svg = "<svg viewBox=\"0 0 200 200\">" +
    "<defs>" +
    "<linearGradient id=\"lg\"><stop offset=\"0%\" stop-color=\"red\"/><stop offset=\"100%\" stop-color=\"blue\"/></linearGradient>" +
    "<clipPath id=\"cp\"><circle cx=\"100\" cy=\"100\" r=\"80\"/></clipPath>" +
    "</defs>" +
    "<rect width=\"200\" height=\"200\" fill=\"url(#lg)\" clip-path=\"url(#cp)\"/>" +
    "<circle cx=\"100\" cy=\"100\" r=\"50\" fill=\"white\" opacity=\"0.5\"/>" +
    "</svg>"
  b.bench(fn() { b.keep(render_svg_to_image(svg, 200, 200)) })
}
