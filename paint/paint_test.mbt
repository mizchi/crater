///|
test "PaintNode clips_content with overflow hidden" {
  let node = PaintNode::new(
    "test",
    "div",
    0.0,
    0.0,
    100.0,
    100.0,
    PaintProperties::default(),
    [],
    overflow_x=@style.Hidden,
    overflow_y=@style.Hidden,
  )
  inspect(node.clips_content(), content="true")
}

///|
test "PaintNode clips_content with overflow visible" {
  let node = PaintNode::new(
    "test",
    "div",
    0.0,
    0.0,
    100.0,
    100.0,
    PaintProperties::default(),
    [],
    overflow_x=@style.Visible,
    overflow_y=@style.Visible,
  )
  inspect(node.clips_content(), content="false")
}

///|
test "PaintNode get_clip_rect returns rect when clipping" {
  let node = PaintNode::new(
    "test",
    "div",
    10.0,
    20.0,
    100.0,
    50.0,
    PaintProperties::default(),
    [],
    overflow_x=@style.Hidden,
    overflow_y=@style.Visible,
  )
  inspect(node.get_clip_rect(), content="Some((10, 20, 100, 50))")
}

///|
test "PaintNode get_clip_rect returns None when not clipping" {
  let node = PaintNode::new(
    "test",
    "div",
    10.0,
    20.0,
    100.0,
    50.0,
    PaintProperties::default(),
    [],
  )
  inspect(node.get_clip_rect(), content="None")
}

///|
test "PaintNode Show includes clips marker" {
  let node = PaintNode::new(
    "clipped",
    "div",
    0.0,
    0.0,
    1.0,
    1.0,
    PaintProperties::default(),
    [],
    overflow_x=@style.Hidden,
    overflow_y=@style.Hidden,
  )
  let s = node.to_string()
  inspect(s.contains("[clips]"), content="true")
}

///|
test "PaintNode with legacy clip rect" {
  let node = PaintNode::new(
    "test",
    "div",
    10.0,
    20.0,
    100.0,
    50.0,
    PaintProperties::default(),
    [],
    clip=@types.ClipRect::Rect(top=1.0, right=1.0, bottom=1.0, left=1.0),
  )
  inspect(node.clips_content(), content="true")
  inspect(node.has_legacy_clip(), content="true")
  // clip rect: x=10+1=11, y=20+1=21, w=1-1=0, h=1-1=0
  inspect(node.get_clip_rect(), content="Some((11, 21, 0, 0))")
}

///|
test "PaintNode legacy clip values" {
  let node = PaintNode::new(
    "test",
    "div",
    0.0,
    0.0,
    100.0,
    100.0,
    PaintProperties::default(),
    [],
    clip=@types.ClipRect::Rect(top=10.0, right=90.0, bottom=90.0, left=10.0),
  )
  // get_legacy_clip returns raw values
  inspect(node.get_legacy_clip(), content="Some((10, 90, 90, 10))")
  // get_clip_rect computes absolute coords: x=0+10=10, y=0+10=10, w=90-10=80, h=90-10=80
  inspect(node.get_clip_rect(), content="Some((10, 10, 80, 80))")
}
