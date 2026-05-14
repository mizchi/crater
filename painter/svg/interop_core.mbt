///|
/// Extract the root SVG viewBox with the shared SVG parser.
pub fn extract_root_view_box(svg_text : String) -> ViewBox? {
  match @msvg.parse_svg_document(svg_text) {
    Some(doc) =>
      match doc.root.view_box {
        Some(view_box) =>
          Some(ViewBox::{
            min_x: view_box.min_x,
            min_y: view_box.min_y,
            width: view_box.width,
            height: view_box.height,
          })
        None => None
      }
    None => None
  }
}

///|
fn transform_from_msvg(transform : @msvg.Transform) -> Transform {
  {
    a: transform.a,
    b: transform.b,
    c: transform.c,
    d: transform.d,
    e: transform.e,
    f: transform.f,
  }
}

///|
fn view_box_from_msvg(view_box : @msvg.ViewBox) -> ViewBox {
  {
    min_x: view_box.min_x,
    min_y: view_box.min_y,
    width: view_box.width,
    height: view_box.height,
  }
}

///|
fn view_box_to_msvg(view_box : ViewBox) -> @msvg.ViewBox {
  @msvg.ViewBox::{
    min_x: view_box.min_x,
    min_y: view_box.min_y,
    width: view_box.width,
    height: view_box.height,
  }
}

///|
fn view_box_from_msvg_option(view_box : @msvg.ViewBox?) -> ViewBox? {
  match view_box {
    Some(vb) => Some(view_box_from_msvg(vb))
    None => None
  }
}

///|
fn view_box_to_msvg_option(view_box : ViewBox?) -> @msvg.ViewBox? {
  match view_box {
    Some(vb) => Some(view_box_to_msvg(vb))
    None => None
  }
}

///|
fn color_from_msvg(color : @msvg.Color) -> Color {
  { r: color.r, g: color.g, b: color.b, a: color.a }
}

///|
fn color_to_msvg(color : Color) -> @msvg.Color {
  @msvg.Color::{ r: color.r, g: color.g, b: color.b, a: color.a }
}

///|
fn pointer_event_from_msvg(event : @msvg.PointerEvent) -> PointerEvent {
  {
    x: event.x,
    y: event.y,
    button: event.button,
    target: event.target,
    propagation_stopped: event.propagation_stopped,
  }
}

///|
fn pointer_event_to_msvg(event : PointerEvent) -> @msvg.PointerEvent {
  let msvg_event = @msvg.PointerEvent::new(
    event.x,
    event.y,
    event.button,
    event.target,
  )
  if event.propagation_stopped {
    msvg_event.stop_propagation()
  }
  msvg_event
}

///|
fn copy_pointer_event_state_from_msvg(
  target : PointerEvent,
  source : @msvg.PointerEvent,
) -> Unit {
  target.propagation_stopped = source.propagation_stopped
}

///|
fn[T] object_pool_from_msvg(pool : @msvg.ObjectPool[T]) -> ObjectPool[T] {
  { available: pool.available, factory: pool.factory, reset: pool.reset }
}

///|
fn[T] object_pool_to_msvg(pool : ObjectPool[T]) -> @msvg.ObjectPool[T] {
  @msvg.ObjectPool::{
    available: pool.available,
    factory: pool.factory,
    reset: pool.reset,
  }
}
