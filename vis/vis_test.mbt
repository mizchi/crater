///|
test "to_svg basic" {
  let layout : @node.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 50.0,
    margin: { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 },
    padding: { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 },
    border: { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 },
    children: [],
    text: None,
  }
  let svg = to_svg(layout, 100.0, 50.0)
  inspect(svg.contains("<svg"), content="true")
  inspect(svg.contains("root"), content="true")
  inspect(svg.contains("</svg>"), content="true")
}

///|
test "to_svg nested" {
  let child : @node.Layout = {
    id: "child",
    x: 10.0,
    y: 10.0,
    width: 80.0,
    height: 30.0,
    margin: { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 },
    padding: { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 },
    border: { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 },
    children: [],
    text: None,
  }
  let root : @node.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 50.0,
    margin: { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 },
    padding: { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 },
    border: { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 },
    children: [child],
    text: None,
  }
  let svg = to_svg(root, 100.0, 50.0)
  inspect(svg.contains("root"), content="true")
  inspect(svg.contains("child"), content="true")
}
