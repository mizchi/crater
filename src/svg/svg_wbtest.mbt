///|
/// SVG Module Tests

///|
test "transform_identity" {
  let t = Transform::identity()
  inspect(t.is_identity(), content="true")
  let (x, y) = t.apply(10.0, 20.0)
  inspect(x, content="10")
  inspect(y, content="20")
}

///|
test "transform_translate" {
  let t = Transform::translate(5.0, 10.0)
  let (x, y) = t.apply(10.0, 20.0)
  inspect(x, content="15")
  inspect(y, content="30")
}

///|
test "transform_scale" {
  let t = Transform::scale(2.0, 3.0)
  let (x, y) = t.apply(10.0, 20.0)
  inspect(x, content="20")
  inspect(y, content="60")
}

///|
test "transform_multiply" {
  let t1 = Transform::translate(10.0, 0.0)
  let t2 = Transform::scale(2.0, 2.0)
  let t = t1.multiply(t2) // First scale, then translate
  let (x, y) = t.apply(5.0, 5.0)
  // Scale: (5, 5) -> (10, 10)
  // Translate: (10, 10) -> (20, 10)
  inspect(x, content="20")
  inspect(y, content="10")
}

///|
test "parse_path_simple" {
  let commands = parse_path("M 10 20 L 30 40")
  inspect(commands.length(), content="2")
}

///|
test "parse_path_relative" {
  let commands = parse_path("m 10 20 l 30 40")
  inspect(commands.length(), content="2")
}

///|
test "parse_path_horizontal_vertical" {
  let commands = parse_path("M 0 0 H 100 V 50")
  inspect(commands.length(), content="3")
}

///|
test "parse_path_curve" {
  let commands = parse_path("M 10 10 C 20 20 40 20 50 10")
  inspect(commands.length(), content="2")
}

///|
test "parse_path_close" {
  let commands = parse_path("M 10 10 L 50 10 L 30 50 Z")
  inspect(commands.length(), content="4")
}

///|
test "parse_path_arc" {
  let commands = parse_path("M 10 10 A 5 5 0 0 1 20 20")
  inspect(commands.length(), content="2")
}

///|
test "path_to_polylines_simple" {
  let commands = parse_path("M 0 0 L 100 0 L 100 100 Z")
  let polylines = path_to_polylines(commands, 1.0)
  inspect(polylines.length(), content="1")
  // 4 points: start, 2 line endpoints, close back to start
  inspect(polylines[0].length(), content="4")
}

///|
test "bounding_box" {
  let bbox = BoundingBox::from_rect(10.0, 20.0, 30.0, 40.0)
  inspect(bbox.width(), content="30")
  inspect(bbox.height(), content="40")
}

///|
test "bounding_box_union" {
  let b1 = BoundingBox::from_rect(0.0, 0.0, 10.0, 10.0)
  let b2 = BoundingBox::from_rect(5.0, 5.0, 10.0, 10.0)
  let union = b1.union(b2)
  inspect(union.min_x, content="0")
  inspect(union.min_y, content="0")
  inspect(union.max_x, content="15")
  inspect(union.max_y, content="15")
}

///|
test "svg_node_creation" {
  let node = SVGNode::new(
    Rect(x=10.0, y=20.0, width=100.0, height=50.0, rx=0.0, ry=0.0),
  )
  inspect(node.opacity, content="1")
}

///|
test "scene_creation" {
  let node = SVGNode::new(Group)
  let scene = Scene::new(node)
  inspect(scene.is_dirty(), content="true")
  scene.clear_dirty()
  inspect(scene.is_dirty(), content="false")
  scene.mark_dirty()
  inspect(scene.is_dirty(), content="true")
}

///|
test "scene_add_child" {
  let root = SVGNode::new(Group)
  root.id = "root"
  let scene = Scene::new(root)
  let child = rect("child1", 0.0, 0.0, 50.0, 50.0)
  let added = scene.add_child("root", child)
  inspect(added, content="true")
}

///|
test "scene_find_node" {
  let root = SVGNode::new(Group)
  root.id = "root"
  let scene = Scene::new(root)
  let child = rect("child1", 0.0, 0.0, 50.0, 50.0)
  let _ = scene.add_child("root", child)
  let found = scene.find_node("child1")
  inspect(found.is_empty(), content="false")
  let not_found = scene.find_node("nonexistent")
  inspect(not_found.is_empty(), content="true")
}

///|
test "parse_svg_simple_rect" {
  let svg = "<rect x=\"10\" y=\"20\" width=\"100\" height=\"50\" fill=\"red\"/>"
  match parse_svg(svg) {
    Some(node) =>
      match node.shape {
        Rect(x~, y~, width~, height~, ..) => {
          inspect(x, content="10")
          inspect(y, content="20")
          inspect(width, content="100")
          inspect(height, content="50")
        }
        _ => panic()
      }
    None => panic()
  }
}

///|
test "parse_svg_circle" {
  let svg = "<circle cx=\"50\" cy=\"60\" r=\"25\" fill=\"blue\"/>"
  match parse_svg(svg) {
    Some(node) =>
      match node.shape {
        Circle(cx~, cy~, r~) => {
          inspect(cx, content="50")
          inspect(cy, content="60")
          inspect(r, content="25")
        }
        _ => panic()
      }
    None => panic()
  }
}

///|
test "parse_svg_group" {
  let svg = "<g id=\"group1\"><rect x=\"0\" y=\"0\" width=\"10\" height=\"10\"/></g>"
  match parse_svg(svg) {
    Some(node) => {
      inspect(node.id, content="group1")
      inspect(node.children.length(), content="1")
    }
    None => panic()
  }
}

///|
test "parse_hex_color" {
  // This tests the color parsing indirectly through parse_svg
  let svg = "<rect fill=\"#ff0000\" width=\"10\" height=\"10\"/>"
  match parse_svg(svg) {
    Some(node) =>
      match node.fill {
        SolidColor(c) => {
          inspect(c.r, content="255")
          inspect(c.g, content="0")
          inspect(c.b, content="0")
        }
        _ => panic()
      }
    None => panic()
  }
}

///|
test "camera basics" {
  let camera = Camera::new(800, 600)
  inspect(camera.x, content="0")
  inspect(camera.y, content="0")
  inspect(camera.zoom, content="1")
  // Pan
  camera.pan(100.0, 50.0)
  inspect(camera.x, content="100")
  inspect(camera.y, content="50")
  // Zoom
  camera.set_zoom(2.0)
  inspect(camera.zoom, content="2")
  // Visible bounds at 2x zoom from (100, 50)
  let bounds = camera.get_visible_bounds()
  // At 2x zoom, visible area is half size: 400x300, centered at (100, 50)
  inspect(bounds.min_x, content="-100")
  inspect(bounds.min_y, content="-100")
  inspect(bounds.max_x, content="300")
  inspect(bounds.max_y, content="200")
}

///|
test "camera transform" {
  let camera = Camera::new(100, 100)
  camera.set_position(50.0, 50.0)
  camera.set_zoom(2.0)
  // World (50, 50) should map to screen center (50, 50)
  let (sx, sy) = camera.world_to_screen(50.0, 50.0)
  inspect(sx, content="50")
  inspect(sy, content="50")
  // World (0, 0) at 2x zoom from camera at (50, 50)
  // sx = (0 - 50) * 2 + 50 = -100 + 50 = -50
  let (sx2, sy2) = camera.world_to_screen(0.0, 0.0)
  inspect(sx2, content="-50")
  inspect(sy2, content="-50")
}

///|
test "clip rect" {
  let clip = ClipRect::new(10, 10, 100, 100)
  // Inside
  inspect(clip.contains(50, 50), content="true")
  inspect(clip.contains(10, 10), content="true")
  inspect(clip.contains(109, 109), content="true")
  // Outside
  inspect(clip.contains(9, 50), content="false")
  inspect(clip.contains(110, 50), content="false")
  inspect(clip.contains(50, 9), content="false")
  inspect(clip.contains(50, 110), content="false")
}

///|
test "bounding box intersects" {
  let a = BoundingBox::from_rect(0.0, 0.0, 100.0, 100.0)
  let b = BoundingBox::from_rect(50.0, 50.0, 100.0, 100.0)
  let c = BoundingBox::from_rect(200.0, 200.0, 100.0, 100.0)
  // a and b overlap
  inspect(a.intersects(b), content="true")
  inspect(b.intersects(a), content="true")
  // a and c don't overlap
  inspect(a.intersects(c), content="false")
  inspect(c.intersects(a), content="false")
}

///|
test "render with clipping culls invisible nodes" {
  // Create a scene with nodes at different positions
  let visible_rect = rect("visible", 10.0, 10.0, 20.0, 20.0)
  visible_rect.fill = SolidColor(Color::rgb(255, 0, 0))
  let invisible_rect = rect("invisible", 200.0, 200.0, 20.0, 20.0)
  invisible_rect.fill = SolidColor(Color::rgb(0, 255, 0))
  let root = group("root", [visible_rect, invisible_rect])
  let scene = Scene::new(root)
  // Track which pixels were drawn
  let drawn_pixels : Array[(Int, Int)] = []
  let setter : PixelSetter = {
    set: fn(x, y, _color) { drawn_pixels.push((x, y)) },
  }
  // Render with a small clip rect that only includes the visible rect
  let clip = ClipRect::new(0, 0, 50, 50)
  let ctx = RenderContext::with_clip(setter, 50, 50, clip)
  scene.render(ctx)
  // Check that pixels were drawn (visible rect should be rendered)
  inspect(drawn_pixels.length() > 0, content="true")
  // All drawn pixels should be within clip bounds
  for p in drawn_pixels {
    let in_bounds = p.0 >= 0 && p.0 < 50 && p.1 >= 0 && p.1 < 50
    inspect(in_bounds, content="true")
  }
}
