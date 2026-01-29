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
  inspect(found is None, content="false")
  let not_found = scene.find_node("nonexistent")
  inspect(not_found is None, content="true")
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

///|
test "stroke dasharray" {
  // Test dashed line directly using raster function
  let drawn_pixels : Array[(Int, Int)] = []
  let setter : PixelSetter = {
    set: fn(x, y, _color) { drawn_pixels.push((x, y)) },
  }
  // Draw a dashed line from (0,0) to (99,0)
  raster_line_dashed(0, 0, 99, 0, Color::black(), [10.0, 5.0], 0.0, setter)
  // Should have some pixels drawn
  inspect(drawn_pixels.length() > 0, content="true")
  // Inspect actual count for debugging
  inspect(drawn_pixels.length(), content="70")
}

///|
test "linear gradient color interpolation" {
  // Create a simple horizontal gradient (left=red, right=blue)
  let grad = LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 1.0,
    y2: 0.0,
    stops: [
      { offset: 0.0, color: Color::rgb(255, 0, 0) },
      { offset: 1.0, color: Color::rgb(0, 0, 255) },
    ],
    spread_method: Pad,
  }
  // Test color at start (t=0)
  let c0 = grad.color_at(0.0)
  inspect(c0.r, content="255")
  inspect(c0.b, content="0")
  // Test color at end (t=1)
  let c1 = grad.color_at(1.0)
  inspect(c1.r, content="0")
  inspect(c1.b, content="255")
  // Test color at middle (t=0.5)
  let c05 = grad.color_at(0.5)
  inspect(c05.r, content="127")
  inspect(c05.b, content="127")
}

///|
test "linear gradient rendering" {
  // Create a rect with gradient fill
  let grad = LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 1.0,
    y2: 0.0,
    stops: [
      { offset: 0.0, color: Color::rgb(255, 0, 0) },
      { offset: 1.0, color: Color::rgb(0, 0, 255) },
    ],
    spread_method: Pad,
  }
  let rect_node = rect("grad-rect", 0.0, 0.0, 100.0, 50.0)
  rect_node.fill = LinearGrad(grad)
  let scene = Scene::new(rect_node)
  let drawn_pixels : Array[(Int, Int, Color)] = []
  let setter : PixelSetter = {
    set: fn(x, y, color) { drawn_pixels.push((x, y, color)) },
  }
  let ctx = RenderContext::new(setter, 100, 50)
  scene.render(ctx)
  // Should have drawn pixels (100 * 50 = 5000)
  inspect(drawn_pixels.length(), content="5000")
  // Check left edge is red
  let left = drawn_pixels[0]
  inspect(left.2.r, content="255")
  inspect(left.2.b, content="0")
  // Check right edge is blue (last row, x=99)
  let right = drawn_pixels.iter().find_first(fn(p) { p.0 == 99 && p.1 == 0 })
  match right {
    Some((_, _, c)) => {
      inspect(c.r, content="0")
      inspect(c.b, content="255")
    }
    None => panic()
  }
}

///|
test "viewBox transform identity" {
  // viewBox matches viewport - should be identity
  let vb = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 100.0, height: 100.0 }
  let t = vb.get_transform(100.0, 100.0, PreserveAspectRatio::default())
  // Should be identity (scale=1, no translation)
  inspect(t.a, content="1")
  inspect(t.d, content="1")
  inspect(t.e, content="0")
  inspect(t.f, content="0")
}

///|
test "viewBox transform scale 2x" {
  // viewBox is half the viewport size - should scale 2x
  let vb = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 50.0, height: 50.0 }
  let t = vb.get_transform(100.0, 100.0, PreserveAspectRatio::default())
  // Should scale by 2
  inspect(t.a, content="2")
  inspect(t.d, content="2")
}

///|
test "viewBox with offset" {
  // viewBox starts at (10, 20)
  let vb = ViewBox::{ min_x: 10.0, min_y: 20.0, width: 100.0, height: 100.0 }
  let t = vb.get_transform(100.0, 100.0, PreserveAspectRatio::default())
  // Should translate by (-10, -20) scaled
  inspect(t.e, content="-10")
  inspect(t.f, content="-20")
}

///|
test "viewBox preserveAspectRatio none" {
  // Non-uniform scaling
  let vb = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 100.0, height: 50.0 }
  let par = PreserveAspectRatio::{ align: None, meet_or_slice: Meet }
  let t = vb.get_transform(200.0, 200.0, par)
  // Should stretch: x by 2, y by 4
  inspect(t.a, content="2")
  inspect(t.d, content="4")
}

///|
test "viewBox preserveAspectRatio meet" {
  // Uniform scaling, fit entirely (use smaller scale)
  let vb = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 100.0, height: 50.0 }
  let par = PreserveAspectRatio::{ align: XMidYMid, meet_or_slice: Meet }
  let t = vb.get_transform(200.0, 200.0, par)
  // x scale would be 2, y scale would be 4, use min = 2
  inspect(t.a, content="2")
  inspect(t.d, content="2")
  // Centered: extra y space = 200 - 50*2 = 100, translate by 50
  inspect(t.f, content="50")
}

///|
test "viewBox preserveAspectRatio slice" {
  // Uniform scaling, cover entirely (use larger scale)
  let vb = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 100.0, height: 50.0 }
  let par = PreserveAspectRatio::{ align: XMidYMid, meet_or_slice: Slice }
  let t = vb.get_transform(200.0, 200.0, par)
  // x scale would be 2, y scale would be 4, use max = 4
  inspect(t.a, content="4")
  inspect(t.d, content="4")
}

///|
test "viewBox render with scaling" {
  // Create a 50x50 rect in viewBox coordinates
  let rect_node = rect("scaled-rect", 0.0, 0.0, 50.0, 50.0)
  rect_node.fill = SolidColor(Color::rgb(255, 0, 0))
  let scene = Scene::new(rect_node)
  let drawn_pixels : Array[(Int, Int, Color)] = []
  let setter : PixelSetter = {
    set: fn(x, y, color) { drawn_pixels.push((x, y, color)) },
  }
  let ctx = RenderContext::new(setter, 100, 100)
  // ViewBox is 50x50, viewport is 100x100, so scale 2x
  let viewbox = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 50.0, height: 50.0 }
  scene.render_with_viewbox(ctx, viewbox, PreserveAspectRatio::default())
  // The 50x50 rect should become 100x100 in viewport
  inspect(drawn_pixels.length(), content="10000")
}

///|
test "text rendering basic" {
  // Create a text node
  let text_node = SVGNode::new(Text(x=10.0, y=20.0, text="Hi", font_size=7.0))
  text_node.fill = SolidColor(Color::rgb(0, 0, 0))
  let scene = Scene::new(text_node)
  let drawn_pixels : Array[(Int, Int, Color)] = []
  let setter : PixelSetter = {
    set: fn(x, y, color) { drawn_pixels.push((x, y, color)) },
  }
  let ctx = RenderContext::new(setter, 100, 50)
  scene.render(ctx)
  // Should have drawn some pixels for the text
  inspect(drawn_pixels.length() > 0, content="true")
}

///|
test "text helper function" {
  let text_node = text("hello", 0.0, 14.0, "Hello", 14.0)
  inspect(text_node.id, content="hello")
  match text_node.shape {
    Text(x~, y~, text~, font_size~) => {
      inspect(x, content="0")
      inspect(y, content="14")
      inspect(text, content="Hello")
      inspect(font_size, content="14")
    }
    _ => panic()
  }
}

///|
test "hit test rect" {
  let shape = Rect(x=10.0, y=20.0, width=100.0, height=50.0, rx=0.0, ry=0.0)
  // Inside
  inspect(hit_test_shape(50.0, 40.0, shape), content="true")
  inspect(hit_test_shape(10.0, 20.0, shape), content="true") // corner
  inspect(hit_test_shape(110.0, 70.0, shape), content="true") // opposite corner
  // Outside
  inspect(hit_test_shape(5.0, 40.0, shape), content="false")
  inspect(hit_test_shape(50.0, 15.0, shape), content="false")
  inspect(hit_test_shape(115.0, 40.0, shape), content="false")
}

///|
test "hit test circle" {
  let shape = Circle(cx=50.0, cy=50.0, r=25.0)
  // Inside
  inspect(hit_test_shape(50.0, 50.0, shape), content="true") // center
  inspect(hit_test_shape(50.0, 25.0, shape), content="true") // edge
  inspect(hit_test_shape(60.0, 50.0, shape), content="true")
  // Outside
  inspect(hit_test_shape(80.0, 50.0, shape), content="false")
  inspect(hit_test_shape(50.0, 80.0, shape), content="false")
}

///|
test "hit test polygon" {
  // Triangle
  let shape = Polygon(points=[(0.0, 0.0), (100.0, 0.0), (50.0, 100.0)])
  // Inside
  inspect(hit_test_shape(50.0, 30.0, shape), content="true")
  // Outside
  inspect(hit_test_shape(10.0, 80.0, shape), content="false")
  inspect(hit_test_shape(90.0, 80.0, shape), content="false")
}

///|
test "hit test node with transform" {
  let node = rect("test", 0.0, 0.0, 50.0, 50.0)
  node.transform = Transform::translate(100.0, 100.0)
  // After translation, rect is at (100,100) to (150,150)
  inspect(node.hit_test(125.0, 125.0), content="true")
  inspect(node.hit_test(50.0, 50.0), content="false")
}

///|
test "hit test all nodes" {
  let child1 = rect("rect1", 0.0, 0.0, 100.0, 100.0)
  let child2 = rect("rect2", 50.0, 50.0, 100.0, 100.0) // overlaps rect1
  let root = group("root", [child1, child2])
  let results = root.hit_test_all(75.0, 75.0)
  // Both should be hit at (75, 75)
  inspect(results.length(), content="2")
}

///|
test "z-index sorting" {
  let child1 = rect("rect1", 0.0, 0.0, 50.0, 50.0)
  child1.z_index = 2
  let child2 = rect("rect2", 0.0, 0.0, 50.0, 50.0)
  child2.z_index = 1
  let child3 = rect("rect3", 0.0, 0.0, 50.0, 50.0)
  child3.z_index = 3
  let sorted = sort_by_z_index([child1, child2, child3])
  // Should be sorted: rect2 (z=1), rect1 (z=2), rect3 (z=3)
  inspect(sorted[0].id, content="rect2")
  inspect(sorted[1].id, content="rect1")
  inspect(sorted[2].id, content="rect3")
}

///|
test "bring to front" {
  let child1 = rect("rect1", 0.0, 0.0, 50.0, 50.0)
  child1.z_index = 0
  let child2 = rect("rect2", 0.0, 0.0, 50.0, 50.0)
  child2.z_index = 1
  let root = group("root", [child1, child2])
  let scene = Scene::new(root)
  // Bring rect1 to front
  let success = scene.bring_to_front("rect1")
  inspect(success, content="true")
  // rect1 should now have higher z_index than rect2
  inspect(child1.z_index > child2.z_index, content="true")
}

///|
test "send to back" {
  let child1 = rect("rect1", 0.0, 0.0, 50.0, 50.0)
  child1.z_index = 1
  let child2 = rect("rect2", 0.0, 0.0, 50.0, 50.0)
  child2.z_index = 0
  let root = group("root", [child1, child2])
  let scene = Scene::new(root)
  // Send rect1 to back
  let success = scene.send_to_back("rect1")
  inspect(success, content="true")
  // rect1 should now have lower z_index than rect2
  inspect(child1.z_index < child2.z_index, content="true")
}

///|
test "easing functions" {
  // Linear
  inspect(Linear.apply(0.0), content="0")
  inspect(Linear.apply(0.5), content="0.5")
  inspect(Linear.apply(1.0), content="1")
  // EaseIn (quadratic)
  inspect(EaseIn.apply(0.0), content="0")
  inspect(EaseIn.apply(0.5), content="0.25")
  inspect(EaseIn.apply(1.0), content="1")
  // EaseOut (quadratic)
  inspect(EaseOut.apply(0.0), content="0")
  inspect(EaseOut.apply(0.5), content="0.75")
  inspect(EaseOut.apply(1.0), content="1")
}

///|
test "tween animation" {
  let node = rect("test", 0.0, 0.0, 50.0, 50.0)
  node.transform = Transform::translate(0.0, 0.0)
  let tween = Tween::new("test", Translate(100.0, 100.0), 1.0, Linear)
  // Not started yet
  inspect(tween.started, content="false")
  inspect(tween.completed, content="false")
  // Update with half the duration
  let running = tween.update(0.5, node)
  inspect(running, content="true")
  inspect(tween.started, content="true")
  // Position should be halfway
  let (tx, ty) = node.transform.get_translate()
  inspect(tx, content="50")
  inspect(ty, content="50")
  // Update to completion
  let still_running = tween.update(0.5, node)
  inspect(still_running, content="false")
  inspect(tween.completed, content="true")
  // Position should be at target
  let (final_x, final_y) = node.transform.get_translate()
  inspect(final_x, content="100")
  inspect(final_y, content="100")
}

///|
test "animation manager" {
  let node = rect("test", 0.0, 0.0, 50.0, 50.0)
  node.opacity = 1.0
  let root = group("root", [node])
  let scene = Scene::new(root)
  let anim = AnimationManager::new()
  // Add opacity animation
  anim.animate_opacity("test", 0.0, 1.0, Linear)
  inspect(anim.is_animating(), content="true")
  // Update half way
  let _ = anim.update(0.5, scene)
  inspect(node.opacity, content="0.5")
  // Update to completion
  let _ = anim.update(0.5, scene)
  inspect(node.opacity, content="0")
  // Cleanup
  anim.cleanup()
  inspect(anim.is_animating(), content="false")
}

///|
test "dirty region calculation" {
  let node1 = rect("rect1", 10.0, 10.0, 50.0, 50.0)
  node1.node_dirty = true
  let node2 = rect("rect2", 100.0, 100.0, 50.0, 50.0)
  node2.node_dirty = false // Not dirty
  let root = group("root", [node1, node2])
  let scene = Scene::new(root)
  let dirty_region = scene.get_dirty_region()
  // Only node1 should contribute to dirty region
  inspect(dirty_region.min_x, content="10")
  inspect(dirty_region.min_y, content="10")
  inspect(dirty_region.max_x, content="60")
  inspect(dirty_region.max_y, content="60")
}

///|
test "mark node dirty" {
  let node = rect("test", 0.0, 0.0, 50.0, 50.0)
  node.node_dirty = false
  let root = group("root", [node])
  let scene = Scene::new(root)
  scene.clear_all_dirty()
  inspect(node.node_dirty, content="false")
  // Mark dirty
  let success = scene.mark_node_dirty("test")
  inspect(success, content="true")
  inspect(node.node_dirty, content="true")
  inspect(scene.is_dirty(), content="true")
}

///|
test "dirty render updates bounds" {
  let node = rect("test", 10.0, 10.0, 50.0, 50.0)
  let scene = Scene::new(node)
  let drawn_pixels : Array[(Int, Int, Color)] = []
  let setter : PixelSetter = {
    set: fn(x, y, color) { drawn_pixels.push((x, y, color)) },
  }
  let ctx = RenderContext::new(setter, 200, 200)
  // First render - should have dirty region
  let dirty = scene.render_dirty(ctx)
  inspect(dirty.is_empty(), content="false")
  // After render, node should have prev_bounds set
  match node.prev_bounds {
    Some(bounds) => {
      inspect(bounds.min_x, content="10")
      inspect(bounds.min_y, content="10")
    }
    None => panic()
  }
}

///|
test "event system click" {
  let node = rect("btn", 10.0, 10.0, 100.0, 50.0)
  let scene = Scene::new(node)
  let events = EventManager::new()
  let clicked : Array[String] = []
  events.on("btn", Click, EventHandler::{
    call: fn(_e) { clicked.push("clicked") },
  })
  // Click inside the button
  events.dispatch_click(50.0, 30.0, 0, scene)
  inspect(clicked.length(), content="1")
  // Click outside the button
  events.dispatch_click(200.0, 200.0, 0, scene)
  inspect(clicked.length(), content="1") // No additional click
}

///|
test "collision circle-circle" {
  // Overlapping circles
  inspect(
    collide_circle_circle(0.0, 0.0, 10.0, 15.0, 0.0, 10.0),
    content="true",
  )
  // Non-overlapping circles
  inspect(
    collide_circle_circle(0.0, 0.0, 10.0, 30.0, 0.0, 10.0),
    content="false",
  )
  // Touching circles
  inspect(
    collide_circle_circle(0.0, 0.0, 10.0, 20.0, 0.0, 10.0),
    content="true",
  )
}

///|
test "collision rect-rect" {
  // Overlapping rects
  inspect(
    collide_rect_rect(0.0, 0.0, 20.0, 20.0, 10.0, 10.0, 20.0, 20.0),
    content="true",
  )
  // Non-overlapping rects
  inspect(
    collide_rect_rect(0.0, 0.0, 10.0, 10.0, 20.0, 20.0, 10.0, 10.0),
    content="false",
  )
}

///|
test "collision circle-rect" {
  // Circle overlaps rect
  inspect(
    collide_circle_rect(15.0, 15.0, 10.0, 0.0, 0.0, 20.0, 20.0),
    content="true",
  )
  // Circle outside rect
  inspect(
    collide_circle_rect(50.0, 50.0, 10.0, 0.0, 0.0, 20.0, 20.0),
    content="false",
  )
}

///|
test "collision shapes" {
  let circle1 = Circle(cx=0.0, cy=0.0, r=10.0)
  let circle2 = Circle(cx=15.0, cy=0.0, r=10.0)
  let rect1 = Rect(x=0.0, y=0.0, width=20.0, height=20.0, rx=0.0, ry=0.0)
  // Circle-circle collision
  inspect(collide_shapes(circle1, circle2), content="true")
  // Circle-rect collision
  inspect(collide_shapes(circle1, rect1), content="true")
}

// ============================================================================
// Image Tests
// ============================================================================

///|
test "image creation" {
  let img = Image::new(10, 10)
  inspect(img.width, content="10")
  inspect(img.height, content="10")
  inspect(img.pixels.length(), content="100")
  // Default pixel is transparent
  let p = img.get_pixel(0, 0)
  inspect(p.a, content="0")
}

///|
test "image filled" {
  let red = Color::rgb(255, 0, 0)
  let img = Image::filled(5, 5, red)
  let p = img.get_pixel(2, 2)
  inspect(p.r, content="255")
  inspect(p.g, content="0")
  inspect(p.b, content="0")
}

///|
test "image set and get pixel" {
  let img = Image::new(10, 10)
  let blue = Color::rgb(0, 0, 255)
  img.set_pixel(5, 5, blue)
  let p = img.get_pixel(5, 5)
  inspect(p.b, content="255")
  // Out of bounds returns transparent
  let out = img.get_pixel(-1, 0)
  inspect(out.a, content="0")
}

///|
test "image fill_rect" {
  let img = Image::new(20, 20)
  let green = Color::rgb(0, 255, 0)
  img.fill_rect(5, 5, 10, 10, green)
  // Inside rect
  let inside = img.get_pixel(10, 10)
  inspect(inside.g, content="255")
  // Outside rect
  let outside = img.get_pixel(0, 0)
  inspect(outside.a, content="0")
}

///|
test "sprite creation" {
  let img = Image::filled(32, 32, Color::rgb(255, 0, 0))
  let sprite = Sprite::new(img, 8, 8, 16, 16)
  inspect(sprite.x, content="8")
  inspect(sprite.y, content="8")
  inspect(sprite.width, content="16")
  inspect(sprite.height, content="16")
  // Get pixel from sprite
  let p = sprite.get_pixel(0, 0)
  inspect(p.r, content="255")
}

///|
test "sprite sheet" {
  // Create a 64x64 image with 16x16 tiles
  let img = Image::new(64, 64)
  let sheet = SpriteSheet::new(img, 16, 16)
  inspect(sheet.columns, content="4")
  inspect(sheet.rows, content="4")
  inspect(sheet.sprite_count(), content="16")
  // Get sprite by grid position
  let sprite = sheet.get_sprite(1, 2)
  inspect(sprite.x, content="16")
  inspect(sprite.y, content="32")
  // Get sprite by index
  let sprite2 = sheet.get_sprite_by_index(5)
  inspect(sprite2.x, content="16") // 5 % 4 = 1
  inspect(sprite2.y, content="16") // 5 / 4 = 1
}

///|
test "blit images" {
  let dest = Image::new(20, 20)
  let src = Image::filled(5, 5, Color::rgb(255, 0, 0))
  blit(dest, src, 10, 10)
  // Check blitted area
  let p1 = dest.get_pixel(10, 10)
  inspect(p1.r, content="255")
  let p2 = dest.get_pixel(14, 14)
  inspect(p2.r, content="255")
  // Check outside
  let p3 = dest.get_pixel(0, 0)
  inspect(p3.a, content="0")
}

///|
test "image flip horizontal" {
  let img = Image::new(4, 2)
  img.set_pixel(0, 0, Color::rgb(255, 0, 0))
  img.set_pixel(3, 0, Color::rgb(0, 255, 0))
  let flipped = img.flip_horizontal()
  // Red should now be at right
  let p1 = flipped.get_pixel(3, 0)
  inspect(p1.r, content="255")
  // Green should now be at left
  let p2 = flipped.get_pixel(0, 0)
  inspect(p2.g, content="255")
}

///|
test "image flip vertical" {
  let img = Image::new(2, 4)
  img.set_pixel(0, 0, Color::rgb(255, 0, 0))
  img.set_pixel(0, 3, Color::rgb(0, 255, 0))
  let flipped = img.flip_vertical()
  // Red should now be at bottom
  let p1 = flipped.get_pixel(0, 3)
  inspect(p1.r, content="255")
  // Green should now be at top
  let p2 = flipped.get_pixel(0, 0)
  inspect(p2.g, content="255")
}

///|
test "image rotate 90 cw" {
  let img = Image::new(4, 2)
  img.set_pixel(0, 0, Color::rgb(255, 0, 0)) // top-left
  let rotated = img.rotate_90_cw()
  // Original dimensions swapped
  inspect(rotated.width, content="2")
  inspect(rotated.height, content="4")
  // Top-left should move to top-right
  let p = rotated.get_pixel(1, 0)
  inspect(p.r, content="255")
}

///|
test "image sub_image" {
  let img = Image::filled(10, 10, Color::rgb(100, 100, 100))
  img.set_pixel(5, 5, Color::rgb(255, 0, 0))
  let sub = img.sub_image(4, 4, 3, 3)
  inspect(sub.width, content="3")
  inspect(sub.height, content="3")
  // The red pixel should be at (1, 1) in the sub image
  let p = sub.get_pixel(1, 1)
  inspect(p.r, content="255")
}

///|
test "animated sprite" {
  let img = Image::new(64, 16)
  let sheet = SpriteSheet::new(img, 16, 16)
  let anim = AnimatedSprite::from_range(sheet, 0, 3, 0.1)
  inspect(anim.frames.length(), content="4")
  inspect(anim.current_frame, content="0")
  inspect(anim.playing, content="true")
  // Update animation
  anim.update(0.15) // Should advance 1 frame
  inspect(anim.current_frame, content="1")
  anim.update(0.25) // Should advance 2 more frames
  inspect(anim.current_frame, content="3")
  // Loop back
  anim.update(0.1)
  inspect(anim.current_frame, content="0")
}

///|
test "animated sprite no loop" {
  let img = Image::new(32, 16)
  let sheet = SpriteSheet::new(img, 16, 16)
  let anim = AnimatedSprite::from_range(sheet, 0, 1, 0.1)
  anim.set_looping(false)
  anim.update(0.15) // Frame 1
  inspect(anim.current_frame, content="1")
  anim.update(0.15) // Should stop at last frame
  inspect(anim.current_frame, content="1")
  inspect(anim.playing, content="false")
}

// ============================================================================
// Transform Parser Tests
// ============================================================================

///|
test "parse_transform translate" {
  let t = parse_transform("translate(10, 20)")
  let (x, y) = t.apply(0.0, 0.0)
  inspect(x, content="10")
  inspect(y, content="20")
}

///|
test "parse_transform scale" {
  let t = parse_transform("scale(2)")
  let (x, y) = t.apply(5.0, 3.0)
  inspect(x, content="10")
  inspect(y, content="6")
}

///|
test "parse_transform rotate" {
  let t = parse_transform("rotate(90)")
  let (x, y) = t.apply(1.0, 0.0)
  // After 90 degree rotation, (1,0) -> (0,1)
  inspect((x * 10.0).round() / 10.0, content="0")
  inspect((y * 10.0).round() / 10.0, content="1")
}

///|
test "parse_transform combined" {
  let t = parse_transform("translate(10, 0) scale(2)")
  let (x, y) = t.apply(5.0, 0.0)
  // translate(10,0) then scale(2): (5,0) -> (15,0) -> (30, 0)
  inspect(x, content="20")
  inspect(y, content="0")
}

///|
test "parse_transform matrix" {
  let t = parse_transform("matrix(1, 0, 0, 1, 100, 200)")
  let (x, y) = t.apply(0.0, 0.0)
  inspect(x, content="100")
  inspect(y, content="200")
}

// ============================================================================
// ClipPath Tests
// ============================================================================

///|
test "clippath contains" {
  let clip = ClipPath::new(
    "clip1",
    Rect(x=0.0, y=0.0, width=100.0, height=100.0, rx=0.0, ry=0.0),
  )
  inspect(clip.contains(50.0, 50.0), content="true")
  inspect(clip.contains(150.0, 50.0), content="false")
}

///|
test "clippath registry" {
  let registry = ClipPathRegistry::new()
  let clip = ClipPath::new("myClip", Circle(cx=50.0, cy=50.0, r=25.0))
  registry.add(clip)
  match registry.get("myClip") {
    Some(c) => inspect(c.id, content="myClip")
    None => inspect("not found", content="should find clip")
  }
}

// ============================================================================
// Pattern Tests
// ============================================================================

///|
test "pattern creation" {
  let content = [rect("tile", 0.0, 0.0, 10.0, 10.0)]
  let pattern = Pattern::new("dots", 20.0, 20.0, content)
  inspect(pattern.width, content="20")
  inspect(pattern.height, content="20")
}

///|
test "pattern registry" {
  let registry = PatternRegistry::new()
  let pattern = Pattern::new("stripes", 10.0, 10.0, [])
  registry.add(pattern)
  match registry.get("stripes") {
    Some(p) => inspect(p.id, content="stripes")
    None => inspect("not found", content="should find pattern")
  }
}

// ============================================================================
// Text Layout Tests
// ============================================================================

///|
test "text style default" {
  let style = TextStyle::default()
  inspect(style.font_size, content="16")
  inspect(style.line_height, content="1.2")
}

///|
test "text block width" {
  let block = TextBlock::new(0.0, 0.0, "Hello")
  // 5 chars * 16 * 0.6 = 48
  let width = block.get_width()
  inspect((width * 10.0).round() / 10.0, content="48")
}

///|
test "text anchor middle" {
  let mut style = TextStyle::default()
  style = { ..style, text_anchor: Middle }
  let block = TextBlock::with_style(100.0, 50.0, "Test", style)
  let x = block.get_anchor_x()
  // 4 chars * 16 * 0.6 = 38.4, so 100 - 38.4/2 = 80.8
  inspect((x * 10.0).round() / 10.0, content="80.8")
}

///|
test "text span" {
  let span = TextSpan::with_offset("world", 5.0, 10.0)
  inspect(span.dx, content="5")
  inspect(span.dy, content="10")
}

// ============================================================================
// Use/Symbol Tests
// ============================================================================

///|
test "symbol creation" {
  let content = rect("content", 0.0, 0.0, 50.0, 50.0)
  let symbol = Symbol::new("mySymbol", content)
  inspect(symbol.id, content="mySymbol")
}

///|
test "use element get_id" {
  let use_elem = UseElement::new("#mySymbol", 10.0, 20.0)
  inspect(use_elem.get_id(), content="mySymbol")
}

///|
test "symbol registry and instantiate" {
  let registry = SymbolRegistry::new()
  let content = rect("box", 0.0, 0.0, 30.0, 30.0)
  let symbol = Symbol::new("box", content)
  registry.add(symbol)
  let use_elem = UseElement::new("#box", 100.0, 100.0)
  match use_elem.instantiate(registry) {
    Some(node) => {
      // Check transform includes translation
      let (tx, ty) = node.transform.get_translate()
      inspect(tx, content="100")
      inspect(ty, content="100")
    }
    None => inspect("failed", content="should instantiate")
  }
}

// ============================================================================
// Marker Tests
// ============================================================================

///|
test "marker arrow" {
  let marker = Marker::arrow("arrow1")
  inspect(marker.ref_x, content="10")
  inspect(marker.ref_y, content="5")
  inspect(marker.marker_width, content="10")
}

///|
test "marker dot" {
  let marker = Marker::dot("dot1", 5.0)
  inspect(marker.ref_x, content="5")
  inspect(marker.ref_y, content="5")
  inspect(marker.marker_width, content="10")
}

///|
test "marker registry" {
  let registry = MarkerRegistry::new()
  let marker = Marker::arrow("myArrow")
  registry.add(marker)
  match registry.get("myArrow") {
    Some(m) => inspect(m.id, content="myArrow")
    None => inspect("not found", content="should find marker")
  }
}

///|
test "marked line angles" {
  let line = MarkedLine::new([(0.0, 0.0), (10.0, 0.0), (10.0, 10.0)])
  // Start angle: pointing right (0 radians)
  let start_angle = line.get_angle_at(0)
  inspect((start_angle * 100.0).round() / 100.0, content="0")
  // End angle: pointing down (pi/2 radians)
  let end_angle = line.get_angle_at(2)
  inspect((end_angle * 100.0).round() / 100.0, content="1.57")
}

// ============================================================================
// Filter Tests
// ============================================================================

///|
test "filter brightness" {
  let color = Color::rgba(100, 150, 200, 255)
  // Increase brightness by 50%
  let brighter = apply_brightness(color, 1.5)
  inspect(brighter.r, content="150")
  inspect(brighter.g, content="225")
  inspect(brighter.b, content="255") // Clamped to 255
  inspect(brighter.a, content="255")
  // Decrease brightness by 50%
  let darker = apply_brightness(color, 0.5)
  inspect(darker.r, content="50")
  inspect(darker.g, content="75")
  inspect(darker.b, content="100")
}

///|
test "filter contrast" {
  let mid_gray = Color::rgba(128, 128, 128, 255)
  // Mid gray should stay the same
  let same = apply_contrast(mid_gray, 1.5)
  inspect(same.r, content="128")
  // High contrast on light color
  let light = Color::rgba(200, 200, 200, 255)
  let high_contrast = apply_contrast(light, 2.0)
  inspect(high_contrast.r > 200, content="true") // Should be brighter
}

///|
test "filter grayscale" {
  let color = Color::rgba(255, 0, 0, 255) // Pure red
  // Full grayscale
  let gray = apply_grayscale(color, 1.0)
  // Gray value = 255 * 0.299 + 0 * 0.587 + 0 * 0.114 ≈ 76
  inspect(gray.r, content="76")
  inspect(gray.g, content="76")
  inspect(gray.b, content="76")
  // Partial grayscale
  let partial = apply_grayscale(color, 0.5)
  inspect(partial.r > partial.g, content="true") // Still some red
}

///|
test "filter blur" {
  // Create a simple 3x3 image with center pixel white
  let pixels : Array[Array[Color]] = []
  for y = 0; y < 3; y = y + 1 {
    let row : Array[Color] = []
    for x = 0; x < 3; x = x + 1 {
      if x == 1 && y == 1 {
        row.push(Color::white())
      } else {
        row.push(Color::black())
      }
    }
    pixels.push(row)
  }
  let blurred = apply_blur(pixels, 1)
  // Center should be less bright after blur
  inspect(blurred[1][1].r < 255, content="true")
  // Corners should have some color now
  inspect(blurred[0][0].r > 0, content="true")
}

///|
test "image clone" {
  let img = Image::new(10, 10)
  img.set_pixel(5, 5, Color::rgb(255, 0, 0))
  let clone = img.clone()
  // Verify clone has same data
  inspect(clone.get_pixel(5, 5).r, content="255")
  // Modify original - clone should be unaffected
  img.set_pixel(5, 5, Color::rgb(0, 0, 255))
  inspect(clone.get_pixel(5, 5).r, content="255")
  inspect(img.get_pixel(5, 5).r, content="0")
}

///|
test "image apply_brightness_in_place" {
  let img = Image::new(2, 2)
  img.set_pixel(0, 0, Color::rgba(100, 100, 100, 255))
  img.set_pixel(1, 0, Color::rgba(100, 100, 100, 255))
  img.apply_brightness_in_place(2.0)
  inspect(img.get_pixel(0, 0).r, content="200")
  inspect(img.get_pixel(1, 0).g, content="200")
}

///|
test "image apply_grayscale_in_place" {
  let img = Image::new(2, 2)
  img.set_pixel(0, 0, Color::rgb(255, 0, 0))
  img.apply_grayscale_in_place(1.0)
  let px = img.get_pixel(0, 0)
  inspect(px.r == px.g && px.g == px.b, content="true")
}

///|
test "node filters" {
  let node = SVGNode::new(
    Shape::Rect(x=0.0, y=0.0, width=100.0, height=100.0, rx=0.0, ry=0.0),
  )
  inspect(node.filters.length(), content="0")
  node.add_filter(Blur(5.0))
  inspect(node.filters.length(), content="1")
  node.add_filter(Brightness(1.5))
  inspect(node.filters.length(), content="2")
  node.clear_filters()
  inspect(node.filters.length(), content="0")
}

///|
test "apply_filter function" {
  let img = Image::new(10, 10)
  img.fill_rect(0, 0, 10, 10, Color::rgba(100, 100, 100, 255))
  // Test Brightness filter
  let brighter = apply_filter(img, Brightness(2.0))
  inspect(brighter.get_pixel(5, 5).r, content="200")
  // Test Grayscale filter
  let img2 = Image::new(10, 10)
  img2.fill_rect(0, 0, 10, 10, Color::rgb(255, 0, 0))
  let gray = apply_filter(img2, Grayscale(1.0))
  let px = gray.get_pixel(5, 5)
  inspect(px.r == px.g && px.g == px.b, content="true")
}

// ============================================================================
// Radial Gradient Tests
// ============================================================================

///|
test "radial gradient new" {
  let grad = RadialGradient::new(0.5, 0.5, 0.5, [
    { offset: 0.0, color: Color::rgb(255, 255, 255) },
    { offset: 1.0, color: Color::rgb(0, 0, 0) },
  ])
  inspect(grad.cx, content="0.5")
  inspect(grad.cy, content="0.5")
  inspect(grad.r, content="0.5")
  inspect(grad.stops.length(), content="2")
}

///|
test "radial gradient color_at center" {
  let grad = RadialGradient::new(0.5, 0.5, 0.5, [
    { offset: 0.0, color: Color::rgb(255, 255, 255) },
    { offset: 1.0, color: Color::rgb(0, 0, 0) },
  ])
  // At center (0.5, 0.5), should be white
  let center_color = grad.color_at(0.5, 0.5, 1.0, 1.0)
  inspect(center_color.r, content="255")
  inspect(center_color.g, content="255")
  inspect(center_color.b, content="255")
}

///|
test "radial gradient color_at edge" {
  let grad = RadialGradient::new(0.5, 0.5, 0.5, [
    { offset: 0.0, color: Color::rgb(255, 255, 255) },
    { offset: 1.0, color: Color::rgb(0, 0, 0) },
  ])
  // At edge (1.0, 0.5), distance = 0.5, should be black
  let edge_color = grad.color_at(1.0, 0.5, 1.0, 1.0)
  inspect(edge_color.r, content="0")
  inspect(edge_color.g, content="0")
  inspect(edge_color.b, content="0")
}

///|
test "radial gradient color_at midpoint" {
  let grad = RadialGradient::new(0.5, 0.5, 0.5, [
    { offset: 0.0, color: Color::rgb(255, 255, 255) },
    { offset: 1.0, color: Color::rgb(0, 0, 0) },
  ])
  // At (0.75, 0.5), distance = 0.25, t = 0.5, should be gray
  let mid_color = grad.color_at(0.75, 0.5, 1.0, 1.0)
  // Should be approximately 127 (midpoint between 255 and 0)
  inspect(mid_color.r > 100 && mid_color.r < 160, content="true")
}

///|
test "raster rect radial gradient" {
  let mut pixel_count = 0
  let setter = PixelSetter::{
    set: fn(_x, _y, _c) { pixel_count = pixel_count + 1 },
  }
  let grad = RadialGradient::new(0.5, 0.5, 0.5, [
    { offset: 0.0, color: Color::rgb(255, 0, 0) },
    { offset: 1.0, color: Color::rgb(0, 0, 255) },
  ])
  raster_rect_radial_gradient(0, 0, 10, 10, grad, 1.0, setter)
  inspect(pixel_count, content="100") // 10x10 = 100 pixels
}

///|
test "raster circle radial gradient" {
  let mut pixel_count = 0
  let setter = PixelSetter::{
    set: fn(_x, _y, _c) { pixel_count = pixel_count + 1 },
  }
  let grad = RadialGradient::new(0.5, 0.5, 0.5, [
    { offset: 0.0, color: Color::rgb(255, 0, 0) },
    { offset: 1.0, color: Color::rgb(0, 0, 255) },
  ])
  raster_circle_radial_gradient(10, 10, 5, grad, 1.0, setter)
  // Should draw roughly pi*r^2 ≈ 78 pixels
  inspect(pixel_count > 70, content="true")
}

///|
test "paint radial grad" {
  let grad = RadialGradient::new(0.5, 0.5, 0.5, [
    { offset: 0.0, color: Color::rgb(255, 0, 0) },
    { offset: 1.0, color: Color::rgb(0, 0, 255) },
  ])
  let paint : Paint = RadialGrad(grad)
  match paint {
    RadialGrad(g) => inspect(g.cx, content="0.5")
    _ => panic()
  }
}

// ============================================================================
// Mask Tests
// ============================================================================

///|
test "mask new" {
  let content = [rect("mask-rect", 0.0, 0.0, 100.0, 100.0)]
  let mask = Mask::new("test-mask", content)
  inspect(mask.id, content="test-mask")
  inspect(mask.content.length(), content="1")
  inspect(mask.mask_type, content="Luminance")
}

///|
test "mask with bounds" {
  let content = [circle("mask-circle", 50.0, 50.0, 50.0)]
  let mask = Mask::with_bounds("bounded-mask", content, 0.0, 0.0, 1.0, 1.0)
  inspect(mask.x, content="0")
  inspect(mask.y, content="0")
  inspect(mask.width, content="1")
  inspect(mask.height, content="1")
}

///|
test "mask registry" {
  let registry = MaskRegistry::new()
  let mask = Mask::new("my-mask", [])
  registry.add(mask)
  let found = registry.get("my-mask")
  inspect(found is None, content="false")
  let not_found = registry.get("nonexistent")
  inspect(not_found is None, content="true")
}

///|
test "compute luminance white" {
  let white = Color::rgb(255, 255, 255)
  let lum = compute_luminance(white)
  // Should be close to 1.0
  inspect(lum > 0.99, content="true")
}

///|
test "compute luminance black" {
  let black = Color::rgb(0, 0, 0)
  let lum = compute_luminance(black)
  inspect(lum, content="0")
}

///|
test "compute luminance gray" {
  let gray = Color::rgb(128, 128, 128)
  let lum = compute_luminance(gray)
  // Should be around 0.5
  inspect(lum > 0.4 && lum < 0.6, content="true")
}

///|
test "compute alpha mask" {
  let semi_transparent = Color::rgba(255, 0, 0, 128)
  let alpha = compute_alpha_mask(semi_transparent)
  // Should be around 0.5
  inspect(alpha > 0.4 && alpha < 0.6, content="true")
}

///|
test "node mask operations" {
  let node = SVGNode::new(
    Shape::Rect(x=0.0, y=0.0, width=100.0, height=100.0, rx=0.0, ry=0.0),
  )
  inspect(node.mask_id is None, content="true")
  node.set_mask("my-mask")
  inspect(node.mask_id is None, content="false")
  node.clear_mask()
  inspect(node.mask_id is None, content="true")
}

///|
test "node clip path operations" {
  let node = SVGNode::new(
    Shape::Rect(x=0.0, y=0.0, width=100.0, height=100.0, rx=0.0, ry=0.0),
  )
  inspect(node.clip_path_id is None, content="true")
  node.set_clip_path("my-clip")
  inspect(node.clip_path_id is None, content="false")
  node.clear_clip_path()
  inspect(node.clip_path_id is None, content="true")
}

///|
test "apply mask to image" {
  // Create source image (red)
  let src = Image::new(10, 10)
  src.fill_rect(0, 0, 10, 10, Color::rgba(255, 0, 0, 255))
  // Create mask (gradient from white to black)
  let mask = Image::new(10, 10)
  for x = 0; x < 10; x = x + 1 {
    let gray = x * 255 / 9
    for y = 0; y < 10; y = y + 1 {
      mask.set_pixel(x, y, Color::rgb(gray, gray, gray))
    }
  }
  // Apply mask
  let result = apply_mask_to_image(src, mask, Luminance)
  // Left edge should be mostly transparent
  let left_pixel = result.get_pixel(0, 5)
  inspect(left_pixel.a < 50, content="true")
  // Right edge should be mostly opaque
  let right_pixel = result.get_pixel(9, 5)
  inspect(right_pixel.a > 200, content="true")
}

///|
test "mask get bounds object bounding box" {
  let mask = Mask::new("test", [])
  let target : BoundingBox = {
    min_x: 100.0,
    min_y: 100.0,
    max_x: 200.0,
    max_y: 200.0,
  }
  let bounds = mask.get_mask_bounds(target)
  // Default mask is -0.1 to 1.1 relative, so should extend beyond target
  inspect(bounds.min_x < 100.0, content="true")
  inspect(bounds.max_x > 200.0, content="true")
}

// ============================================================================
// SVG 2.0 Text Tests
// ============================================================================

///|
test "writing mode enum" {
  let mode : WritingMode = HorizontalTB
  inspect(mode, content="HorizontalTB")
  let vertical : WritingMode = VerticalRL
  inspect(vertical, content="VerticalRL")
}

///|
test "text orientation enum" {
  let orient : TextOrientation = Mixed
  inspect(orient, content="Mixed")
  let upright : TextOrientation = Upright
  inspect(upright, content="Upright")
}

///|
test "white space enum" {
  let ws : WhiteSpace = Normal
  inspect(ws, content="Normal")
  let pre : WhiteSpace = PreWrap
  inspect(pre, content="PreWrap")
}

///|
test "text overflow enum" {
  let overflow : TextOverflow = Clip
  inspect(overflow, content="Clip")
  let ellipsis : TextOverflow = Ellipsis
  inspect(ellipsis, content="Ellipsis")
}

///|
test "text style svg2 defaults" {
  let style = TextStyle::default()
  inspect(style.writing_mode, content="HorizontalTB")
  inspect(style.text_orientation, content="Mixed")
  inspect(style.white_space, content="Normal")
  inspect(style.paint_order, content="Normal")
}

///|
test "text block with wrap" {
  let block = TextBlock::with_wrap(0.0, 0.0, "Hello World", 100.0)
  inspect(block.inline_size is None, content="false")
  inspect(block.text_overflow, content="Clip")
}

///|
test "text block wrap text short" {
  let block = TextBlock::with_wrap(0.0, 0.0, "Hello", 200.0)
  let lines = block.wrap_text()
  inspect(lines.length(), content="1")
}

///|
test "text block wrap text long" {
  // With default font_size=16, char_width≈9.6, "Hello World" needs ≈105.6px
  let block = TextBlock::with_wrap(0.0, 0.0, "Hello World Test", 50.0)
  let lines = block.wrap_text()
  // Should wrap to multiple lines
  inspect(lines.length() > 1, content="true")
}

///|
test "text block is vertical" {
  let horizontal = TextBlock::new(0.0, 0.0, "Test")
  inspect(horizontal.is_vertical(), content="false")
  // Create a vertical style
  let vertical_style : TextStyle = {
    ..TextStyle::default(),
    writing_mode: VerticalRL,
  }
  let vertical = TextBlock::with_style(0.0, 0.0, "Test", vertical_style)
  inspect(vertical.is_vertical(), content="true")
}

///|
test "split words" {
  let words = split_words("Hello World Test")
  inspect(words.length(), content="3")
  inspect(words[0], content="Hello")
  inspect(words[1], content="World")
  inspect(words[2], content="Test")
}

///|
test "split words with multiple spaces" {
  let words = split_words("Hello   World")
  inspect(words.length(), content="2")
}

///|
test "process white space normal" {
  let result = process_white_space("Hello   World\n\nTest", Normal)
  // Multiple spaces and newlines collapsed to single space
  inspect(result, content="Hello World Test")
}

///|
test "process white space pre" {
  let result = process_white_space("Hello   World", Pre)
  // Preserved as-is
  inspect(result, content="Hello   World")
}

///|
test "process white space pre line" {
  let result = process_white_space("Hello   World\nTest", PreLine)
  // Spaces collapsed, newlines preserved
  inspect(result, content="Hello World\nTest")
}

///|
test "apply text overflow clip" {
  let result = apply_text_overflow("Hello World", 50.0, 10.0, Clip)
  // 50/10 = 5 chars max
  inspect(result, content="Hello")
}

///|
test "apply text overflow ellipsis" {
  let result = apply_text_overflow("Hello World", 80.0, 10.0, Ellipsis)
  // 80/10 = 8 chars max, 8-3=5 chars + "..."
  inspect(result, content="Hello...")
}

///|
test "apply text overflow custom" {
  let result = apply_text_overflow("Hello World", 80.0, 10.0, Custom(">>"))
  // 80/10 = 8 chars max, 8-2=6 chars + ">>"
  inspect(result, content="Hello >>")
}

///|
test "apply text overflow no overflow" {
  let result = apply_text_overflow("Hi", 100.0, 10.0, Ellipsis)
  // No overflow needed
  inspect(result, content="Hi")
}

///|
test "text decoration full default" {
  let deco = TextDecorationFull::default()
  inspect(deco.line, content="NoDecoration")
  inspect(deco.style, content="Solid")
  inspect(deco.color is None, content="true")
}

///|
test "paint order enum" {
  let normal : PaintOrder = Normal
  inspect(normal, content="Normal")
  let stroke_first : PaintOrder = StrokeFirst
  inspect(stroke_first, content="StrokeFirst")
}

///|
test "text block get line count" {
  let block = TextBlock::with_wrap(0.0, 0.0, "A B C D E F G", 30.0)
  let count = block.get_line_count()
  inspect(count > 1, content="true")
}

///|
test "text block get total height" {
  let block = TextBlock::new(0.0, 0.0, "Single line")
  let height = block.get_total_height()
  // font_size=16, line_height=1.2, 1 line = 19.2
  inspect(height > 19.0 && height < 20.0, content="true")
}

// ============================================================================
// Parser Extension Tests
// ============================================================================

///|
test "parse svg with stroke-linecap" {
  let svg = "<rect stroke-linecap=\"round\"/>"
  match parse_svg(svg) {
    Some(node) => inspect(node.stroke.linecap, content="Round")
    None => panic()
  }
}

///|
test "parse svg with stroke-linejoin" {
  let svg = "<rect stroke-linejoin=\"bevel\"/>"
  match parse_svg(svg) {
    Some(node) => inspect(node.stroke.linejoin, content="Bevel")
    None => panic()
  }
}

///|
test "parse svg with stroke-dasharray" {
  let svg = "<rect stroke-dasharray=\"5,3,2\"/>"
  match parse_svg(svg) {
    Some(node) =>
      match node.stroke.dasharray {
        Some(arr) => {
          inspect(arr.length(), content="3")
          inspect(arr[0], content="5")
          inspect(arr[1], content="3")
          inspect(arr[2], content="2")
        }
        None => panic()
      }
    None => panic()
  }
}

///|
test "parse svg with stroke-dasharray none" {
  let svg = "<rect stroke-dasharray=\"none\"/>"
  match parse_svg(svg) {
    Some(node) => inspect(node.stroke.dasharray is None, content="true")
    None => panic()
  }
}

///|
test "parse svg with fill-rule" {
  let svg = "<path fill-rule=\"evenodd\"/>"
  match parse_svg(svg) {
    Some(node) => inspect(node.fill_rule, content="EvenOdd")
    None => panic()
  }
}

///|
test "parse svg with stroke-miterlimit" {
  let svg = "<rect stroke-miterlimit=\"10\"/>"
  match parse_svg(svg) {
    Some(node) => inspect(node.stroke.miterlimit, content="10")
    None => panic()
  }
}

///|
test "parse svg with color names" {
  let svg = "<rect fill=\"red\"/>"
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
test "parse svg with rgb color" {
  let svg = "<rect fill=\"rgb(100, 150, 200)\"/>"
  match parse_svg(svg) {
    Some(node) =>
      match node.fill {
        SolidColor(c) => {
          inspect(c.r, content="100")
          inspect(c.g, content="150")
          inspect(c.b, content="200")
        }
        _ => panic()
      }
    None => panic()
  }
}

///|
test "parse svg with hex color short" {
  let svg = "<rect fill=\"#f00\"/>"
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
test "parse svg with multiple stroke attrs" {
  let svg = "<line stroke=\"blue\" stroke-width=\"3\" stroke-linecap=\"square\" stroke-dasharray=\"10,5\"/>"
  match parse_svg(svg) {
    Some(node) => {
      match node.stroke.paint {
        SolidColor(c) => inspect(c.b, content="255")
        _ => panic()
      }
      inspect(node.stroke.width, content="3")
      inspect(node.stroke.linecap, content="Square")
      match node.stroke.dasharray {
        Some(arr) => inspect(arr.length(), content="2")
        None => panic()
      }
    }
    None => panic()
  }
}

// ============================================================================
// Additional Filter Tests (sepia, hue-rotate, invert, saturate)
// ============================================================================

///|
test "apply sepia filter" {
  let color = Color::rgb(255, 128, 64)
  let sepia = apply_sepia(color, 1.0)
  // Sepia should shift colors toward brown/yellow tones
  inspect(sepia.a, content="255")
  // Red channel should be highest in sepia
  assert_true(sepia.r >= sepia.g)
  assert_true(sepia.g >= sepia.b)
}

///|
test "apply sepia filter zero amount" {
  let color = Color::rgb(100, 150, 200)
  let result = apply_sepia(color, 0.0)
  // Zero amount should return original color
  inspect(result.r, content="100")
  inspect(result.g, content="150")
  inspect(result.b, content="200")
}

///|
test "apply invert filter" {
  let color = Color::rgb(100, 150, 200)
  let inverted = apply_invert(color, 1.0)
  // Full invert should flip colors
  inspect(inverted.r, content="155")
  inspect(inverted.g, content="105")
  inspect(inverted.b, content="55")
}

///|
test "apply invert filter partial" {
  let color = Color::rgb(0, 0, 0)
  let result = apply_invert(color, 0.5)
  // Half invert of black should be gray
  inspect(result.r, content="127")
  inspect(result.g, content="127")
  inspect(result.b, content="127")
}

///|
test "apply saturate filter zero" {
  let color = Color::rgb(255, 0, 0)
  let result = apply_saturate(color, 0.0)
  // Zero saturation should be grayscale
  // Red's luminance contribution: 0.2126 * 255 ≈ 54
  assert_true(result.r == result.g && result.g == result.b)
}

///|
test "apply saturate filter double" {
  let color = Color::rgb(128, 64, 64)
  let result = apply_saturate(color, 2.0)
  // Double saturation should increase color difference
  assert_true(result.r > color.r || result.r == 255)
}

///|
test "apply hue rotate 180" {
  let color = Color::rgb(255, 0, 0)
  let rotated = apply_hue_rotate(color, 180.0)
  // 180 degree rotation of red should be cyan-ish
  assert_true(rotated.g > rotated.r || rotated.b > rotated.r)
}

///|
test "apply hue rotate 360" {
  let color = Color::rgb(200, 100, 50)
  let rotated = apply_hue_rotate(color, 360.0)
  // 360 degree rotation should be close to original
  // (allowing for some numerical precision loss in trig approximations)
  inspect(rotated.r, content="200")
  inspect(rotated.g, content="99")
  inspect(rotated.b, content="50")
}

///|
test "filter enum sepia variant" {
  let filter = Sepia(0.5)
  match filter {
    Sepia(amount) => inspect(amount, content="0.5")
    _ => panic()
  }
}

///|
test "filter enum hue rotate variant" {
  let filter = HueRotate(90.0)
  match filter {
    HueRotate(angle) => inspect(angle, content="90")
    _ => panic()
  }
}

///|
test "filter enum invert variant" {
  let filter = Invert(1.0)
  match filter {
    Invert(amount) => inspect(amount, content="1")
    _ => panic()
  }
}

///|
test "filter enum saturate variant" {
  let filter = Saturate(2.0)
  match filter {
    Saturate(factor) => inspect(factor, content="2")
    _ => panic()
  }
}

///|
test "image apply sepia in place" {
  let img = Image::new(2, 2)
  img.set_pixel(0, 0, Color::rgb(255, 0, 0))
  img.apply_sepia_in_place(1.0)
  let pixel = img.get_pixel(0, 0)
  // Sepia red should have R >= G >= B
  assert_true(pixel.r >= pixel.g)
  assert_true(pixel.g >= pixel.b)
}

///|
test "image apply invert in place" {
  let img = Image::new(2, 2)
  img.set_pixel(0, 0, Color::rgb(100, 100, 100))
  img.apply_invert_in_place(1.0)
  let pixel = img.get_pixel(0, 0)
  inspect(pixel.r, content="155")
  inspect(pixel.g, content="155")
  inspect(pixel.b, content="155")
}

///|
test "apply filter sepia variant" {
  let img = Image::new(2, 2)
  img.set_pixel(0, 0, Color::rgb(128, 128, 128))
  let result = apply_filter(img, Sepia(1.0))
  inspect(result.width, content="2")
  inspect(result.height, content="2")
}

///|
test "apply filter saturate variant" {
  let img = Image::new(2, 2)
  img.set_pixel(0, 0, Color::rgb(255, 128, 0))
  let result = apply_filter(img, Saturate(0.0))
  let pixel = result.get_pixel(0, 0)
  // Desaturated should be grayscale
  assert_true(pixel.r == pixel.g && pixel.g == pixel.b)
}

// ============================================================================
// Blend Mode Tests
// ============================================================================

///|
test "blend mode normal" {
  let backdrop = Color::rgb(100, 100, 100)
  let source = Color::rgba(200, 50, 50, 255)
  let result = blend_with_mode(backdrop, source, Normal)
  // Normal blend with full opacity should be source color
  inspect(result.r, content="200")
  inspect(result.g, content="50")
  inspect(result.b, content="50")
}

///|
test "blend mode multiply" {
  let backdrop = Color::rgb(255, 255, 255)
  let source = Color::rgba(128, 128, 128, 255)
  let result = blend_with_mode(backdrop, source, Multiply)
  // Multiply white with gray should be gray
  inspect(result.r, content="128")
  inspect(result.g, content="128")
  inspect(result.b, content="128")
}

///|
test "blend mode multiply black" {
  let backdrop = Color::rgb(200, 150, 100)
  let source = Color::rgba(0, 0, 0, 255)
  let result = blend_with_mode(backdrop, source, Multiply)
  // Multiply with black should be black
  inspect(result.r, content="0")
  inspect(result.g, content="0")
  inspect(result.b, content="0")
}

///|
test "blend mode screen" {
  let backdrop = Color::rgb(0, 0, 0)
  let source = Color::rgba(128, 128, 128, 255)
  let result = blend_with_mode(backdrop, source, Screen)
  // Screen black with gray should be gray
  inspect(result.r, content="128")
}

///|
test "blend mode screen white" {
  let backdrop = Color::rgb(128, 128, 128)
  let source = Color::rgba(255, 255, 255, 255)
  let result = blend_with_mode(backdrop, source, Screen)
  // Screen with white should be white
  inspect(result.r, content="255")
  inspect(result.g, content="255")
  inspect(result.b, content="255")
}

///|
test "blend mode darken" {
  let backdrop = Color::rgb(100, 200, 150)
  let source = Color::rgba(150, 100, 200, 255)
  let result = blend_with_mode(backdrop, source, Darken)
  // Darken takes minimum of each channel
  inspect(result.r, content="100")
  inspect(result.g, content="100")
  inspect(result.b, content="150")
}

///|
test "blend mode lighten" {
  let backdrop = Color::rgb(100, 200, 150)
  let source = Color::rgba(150, 100, 200, 255)
  let result = blend_with_mode(backdrop, source, Lighten)
  // Lighten takes maximum of each channel
  inspect(result.r, content="150")
  inspect(result.g, content="200")
  inspect(result.b, content="200")
}

///|
test "blend mode difference" {
  let backdrop = Color::rgb(200, 100, 50)
  let source = Color::rgba(100, 150, 100, 255)
  let result = blend_with_mode(backdrop, source, Difference)
  // Difference is absolute difference
  inspect(result.r, content="100")
  inspect(result.g, content="50")
  inspect(result.b, content="50")
}

///|
test "blend mode exclusion" {
  let backdrop = Color::rgb(128, 128, 128)
  let source = Color::rgba(128, 128, 128, 255)
  let result = blend_with_mode(backdrop, source, Exclusion)
  // Exclusion of same color should be around 128
  // Formula: a + b - 2*a*b = 0.5 + 0.5 - 2*0.5*0.5 = 0.5
  let diff = (result.r - 128).abs()
  assert_true(diff < 5)
}

///|
test "blend mode overlay dark backdrop" {
  let backdrop = Color::rgb(64, 64, 64) // Dark backdrop
  let source = Color::rgba(128, 128, 128, 255)
  let result = blend_with_mode(backdrop, source, Overlay)
  // Overlay with dark backdrop uses multiply-like formula
  assert_true(result.r < 128)
}

///|
test "blend mode overlay light backdrop" {
  let backdrop = Color::rgb(192, 192, 192) // Light backdrop
  let source = Color::rgba(128, 128, 128, 255)
  let result = blend_with_mode(backdrop, source, Overlay)
  // Overlay with light backdrop uses screen-like formula
  assert_true(result.r > 128)
}

///|
test "blend mode enum equality" {
  inspect(BlendMode::Normal == BlendMode::Normal, content="true")
  inspect(BlendMode::Multiply == BlendMode::Multiply, content="true")
  inspect(BlendMode::Normal == BlendMode::Multiply, content="false")
}

///|
test "isolation enum" {
  let auto_iso : Isolation = Isolation::Auto
  let isolate : Isolation = Isolation::Isolate
  inspect(auto_iso == Isolation::Auto, content="true")
  inspect(isolate == Isolation::Isolate, content="true")
  inspect(auto_iso == isolate, content="false")
}

///|
test "blend images" {
  let backdrop = Image::new(2, 2)
  backdrop.set_pixel(0, 0, Color::rgb(255, 255, 255))
  backdrop.set_pixel(1, 0, Color::rgb(128, 128, 128))
  let source = Image::new(2, 2)
  source.set_pixel(0, 0, Color::rgba(128, 128, 128, 255))
  source.set_pixel(1, 0, Color::rgba(64, 64, 64, 255))
  let result = blend_images(backdrop, source, Multiply)
  // White * gray = gray
  let p0 = result.get_pixel(0, 0)
  inspect(p0.r, content="128")
  // Gray * dark gray
  let p1 = result.get_pixel(1, 0)
  assert_true(p1.r < 128)
}

///|
test "blend with alpha" {
  let backdrop = Color::rgb(100, 100, 100)
  let source = Color::rgba(200, 200, 200, 128) // 50% opacity
  let result = blend_with_mode(backdrop, source, Normal)
  // Semi-transparent blend should be between colors
  assert_true(result.r > 100 && result.r < 200)
}

// ============================================================================
// Color Matrix Tests (feColorMatrix)
// ============================================================================

///|
test "identity matrix" {
  let matrix = identity_matrix()
  inspect(matrix.length(), content="20")
  // Check diagonal is 1
  inspect(matrix[0], content="1")
  inspect(matrix[6], content="1")
  inspect(matrix[12], content="1")
  inspect(matrix[18], content="1")
  // Check off-diagonal is 0
  inspect(matrix[1], content="0")
  inspect(matrix[5], content="0")
}

///|
test "apply identity color matrix" {
  let color = Color::rgb(100, 150, 200)
  let matrix = identity_matrix()
  let result = apply_color_matrix(color, matrix)
  // Identity should preserve color
  inspect(result.r, content="100")
  inspect(result.g, content="150")
  inspect(result.b, content="200")
}

///|
test "color matrix brightness" {
  let color = Color::rgb(100, 100, 100)
  // Brightness matrix: multiply diagonal by factor
  let matrix : FixedArray[Double] = [
    2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
  ]
  let result = apply_color_matrix(color, matrix)
  inspect(result.r, content="200")
  inspect(result.g, content="200")
  inspect(result.b, content="200")
}

///|
test "color matrix offset" {
  let color = Color::rgb(0, 0, 0)
  // Add offset to channels
  let matrix : FixedArray[Double] = [
    1.0, 0.0, 0.0, 0.0, 0.5, 0.0, 1.0, 0.0, 0.0, 0.25, 0.0, 0.0, 1.0, 0.0, 0.125,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ]
  let result = apply_color_matrix(color, matrix)
  inspect(result.r, content="127")
  inspect(result.g, content="63")
  inspect(result.b, content="31")
}

///|
test "saturate matrix zero" {
  let matrix = saturate_matrix(0.0)
  let color = Color::rgb(255, 0, 0)
  let result = apply_color_matrix(color, matrix)
  // Zero saturation should convert to grayscale
  assert_true(result.r == result.g && result.g == result.b)
}

///|
test "saturate matrix one" {
  let matrix = saturate_matrix(1.0)
  let color = Color::rgb(100, 150, 200)
  let result = apply_color_matrix(color, matrix)
  // Saturation 1.0 should preserve color (within rounding)
  let diff_r = (result.r - 100).abs()
  let diff_g = (result.g - 150).abs()
  let diff_b = (result.b - 200).abs()
  assert_true(diff_r < 2 && diff_g < 2 && diff_b < 2)
}

///|
test "hue rotate matrix" {
  let matrix = hue_rotate_matrix(180.0)
  inspect(matrix.length(), content="20")
  // Alpha row should be identity
  inspect(matrix[18], content="1")
  inspect(matrix[19], content="0")
}

///|
test "luminance to alpha matrix" {
  let matrix = luminance_to_alpha_matrix()
  let color = Color::rgb(255, 255, 255)
  let result = apply_color_matrix(color, matrix)
  // White should give full alpha
  inspect(result.r, content="0")
  inspect(result.g, content="0")
  inspect(result.b, content="0")
  // Alpha = 0.2126 + 0.7152 + 0.0722 = 1.0
  inspect(result.a, content="255")
}

///|
test "luminance to alpha matrix black" {
  let matrix = luminance_to_alpha_matrix()
  let color = Color::rgb(0, 0, 0)
  let result = apply_color_matrix(color, matrix)
  // Black should give zero alpha
  inspect(result.a, content="0")
}

///|
test "color matrix invalid length" {
  let color = Color::rgb(100, 100, 100)
  let invalid_matrix : FixedArray[Double] = [1.0, 0.0, 0.0] // Too short
  let result = apply_color_matrix(color, invalid_matrix)
  // Should return original color unchanged
  inspect(result.r, content="100")
  inspect(result.g, content="100")
  inspect(result.b, content="100")
}

///|
test "filter enum color matrix variant" {
  let matrix = identity_matrix()
  let filter = ColorMatrix(matrix)
  match filter {
    ColorMatrix(m) => inspect(m.length(), content="20")
    _ => panic()
  }
}

///|
test "apply filter color matrix" {
  let img = Image::new(2, 2)
  img.set_pixel(0, 0, Color::rgb(100, 100, 100))
  let matrix = saturate_matrix(0.0)
  let result = apply_filter(img, ColorMatrix(matrix))
  let pixel = result.get_pixel(0, 0)
  // Desaturated should be grayscale
  assert_true(pixel.r == pixel.g && pixel.g == pixel.b)
}

///|
test "image apply color matrix in place" {
  let img = Image::new(2, 2)
  img.set_pixel(0, 0, Color::rgb(128, 64, 32))
  let matrix = identity_matrix()
  img.apply_color_matrix_in_place(matrix)
  let pixel = img.get_pixel(0, 0)
  // Identity should preserve
  inspect(pixel.r, content="128")
  inspect(pixel.g, content="64")
  inspect(pixel.b, content="32")
}

///|
test "blend mode hard light" {
  let backdrop = Color::rgb(128, 128, 128)
  let source = Color::rgba(64, 64, 64, 255) // Dark source
  let result = blend_with_mode(backdrop, source, HardLight)
  // Hard light with dark source uses multiply-like
  assert_true(result.r < 128)
}

///|
test "blend mode soft light" {
  let backdrop = Color::rgb(128, 128, 128)
  let source = Color::rgba(200, 200, 200, 255)
  let result = blend_with_mode(backdrop, source, SoftLight)
  // Soft light should brighten with light source
  assert_true(result.r > 128)
}

///|
test "blend mode color dodge" {
  let backdrop = Color::rgb(128, 128, 128)
  let source = Color::rgba(64, 64, 64, 255)
  let result = blend_with_mode(backdrop, source, ColorDodge)
  // Color dodge should brighten
  assert_true(result.r > 128)
}

///|
test "blend mode color burn" {
  let backdrop = Color::rgb(128, 128, 128)
  let source = Color::rgba(200, 200, 200, 255)
  let result = blend_with_mode(backdrop, source, ColorBurn)
  // Color burn with light source should darken less
  assert_true(result.r > 0)
}

///|
test "blend mode hue" {
  let backdrop = Color::rgb(100, 100, 100) // Gray
  let source = Color::rgba(255, 0, 0, 255) // Red
  let result = blend_with_mode(backdrop, source, Hue)
  // Hue blend takes hue from source, but gray has no saturation
  // Result should still be grayish
  inspect(result.a, content="255")
}

///|
test "blend mode saturation" {
  let backdrop = Color::rgb(200, 100, 50)
  let source = Color::rgba(128, 128, 128, 255) // Gray (0 saturation)
  let result = blend_with_mode(backdrop, source, Saturation)
  // Saturation from gray should desaturate
  inspect(result.a, content="255")
}

///|
test "blend mode luminosity" {
  let backdrop = Color::rgb(128, 128, 128)
  let source = Color::rgba(255, 255, 255, 255) // Bright
  let result = blend_with_mode(backdrop, source, Luminosity)
  // Luminosity from white should brighten
  assert_true(result.r > 128)
}

///|
test "blend mode color mode" {
  let backdrop = Color::rgb(128, 128, 128)
  let source = Color::rgba(255, 0, 0, 255) // Red
  let result = blend_with_mode(backdrop, source, ColorMode)
  // Color mode takes hue and saturation from source
  inspect(result.a, content="255")
}
