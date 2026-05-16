///|
/// ViewBox specification for SVG coordinate system mapping
pub(all) struct ViewBox {
  min_x : Double
  min_y : Double
  width : Double
  height : Double
}

///|
/// preserveAspectRatio alignment values
pub(all) enum Align {
  None // No forced uniform scaling
  XMinYMin
  XMidYMin
  XMaxYMin
  XMinYMid
  XMidYMid // Default
  XMaxYMid
  XMinYMax
  XMidYMax
  XMaxYMax
} derive(Eq, Debug)

///|
/// preserveAspectRatio meet/slice
pub(all) enum MeetOrSlice {
  Meet // Scale to fit entirely (default)
  Slice // Scale to cover entirely
} derive(Eq, Debug)

///|
/// Complete preserveAspectRatio setting
pub(all) struct PreserveAspectRatio {
  align : Align
  meet_or_slice : MeetOrSlice
}

///|
pub fn PreserveAspectRatio::default() -> PreserveAspectRatio {
  { align: XMidYMid, meet_or_slice: Meet }
}

///|
pub impl Show for Align with output(self, logger) {
  let name = match self {
    None => "None"
    XMinYMin => "XMinYMin"
    XMidYMin => "XMidYMin"
    XMaxYMin => "XMaxYMin"
    XMinYMid => "XMinYMid"
    XMidYMid => "XMidYMid"
    XMaxYMid => "XMaxYMid"
    XMinYMax => "XMinYMax"
    XMidYMax => "XMidYMax"
    XMaxYMax => "XMaxYMax"
  }
  logger.write_string(name)
}

///|
pub impl Show for MeetOrSlice with output(self, logger) {
  let name = match self {
    Meet => "Meet"
    Slice => "Slice"
  }
  logger.write_string(name)
}

///|
/// Calculate the transform matrix to map viewBox coordinates to viewport
/// viewport_width/height: the actual pixel dimensions of the SVG element
pub fn ViewBox::get_transform(
  self : ViewBox,
  viewport_width : Double,
  viewport_height : Double,
  preserve_aspect_ratio : PreserveAspectRatio,
) -> Transform {
  let transform = @msvg.ViewBox::{
    min_x: self.min_x,
    min_y: self.min_y,
    width: self.width,
    height: self.height,
  }.get_transform(
    viewport_width,
    viewport_height,
    preserve_aspect_ratio.to_msvg(),
  )
  Transform::{
    a: transform.a,
    b: transform.b,
    c: transform.c,
    d: transform.d,
    e: transform.e,
    f: transform.f,
  }
}

///|
/// Extract the root SVG viewBox with the shared SVG parser.
pub fn extract_root_view_box(svg_text : String) -> ViewBox? {
  match @msvg.parse_svg_document(svg_text) {
    Some(doc) =>
      match doc.root.view_box {
        Some(view_box) => Some(ViewBox::from_msvg(view_box))
        None => None
      }
    None => None
  }
}

///|
fn ViewBox::from_msvg(v : @msvg.ViewBox) -> ViewBox {
  { min_x: v.min_x, min_y: v.min_y, width: v.width, height: v.height }
}

///|
fn ViewBox::to_msvg(self : ViewBox) -> @msvg.ViewBox {
  @msvg.ViewBox::{
    min_x: self.min_x,
    min_y: self.min_y,
    width: self.width,
    height: self.height,
  }
}

///|
fn ViewBox::from_msvg_option(v : @msvg.ViewBox?) -> ViewBox? {
  match v {
    Some(vb) => Some(ViewBox::from_msvg(vb))
    None => None
  }
}

///|
fn ViewBox::to_msvg_option(v : ViewBox?) -> @msvg.ViewBox? {
  match v {
    Some(vb) => Some(vb.to_msvg())
    None => None
  }
}

///|
fn Align::to_msvg(self : Align) -> @msvg.Align {
  match self {
    None => @msvg.Align::None
    XMinYMin => @msvg.Align::XMinYMin
    XMidYMin => @msvg.Align::XMidYMin
    XMaxYMin => @msvg.Align::XMaxYMin
    XMinYMid => @msvg.Align::XMinYMid
    XMidYMid => @msvg.Align::XMidYMid
    XMaxYMid => @msvg.Align::XMaxYMid
    XMinYMax => @msvg.Align::XMinYMax
    XMidYMax => @msvg.Align::XMidYMax
    XMaxYMax => @msvg.Align::XMaxYMax
  }
}

///|
fn MeetOrSlice::to_msvg(self : MeetOrSlice) -> @msvg.MeetOrSlice {
  match self {
    Meet => @msvg.MeetOrSlice::Meet
    Slice => @msvg.MeetOrSlice::Slice
  }
}

///|
fn PreserveAspectRatio::to_msvg(
  self : PreserveAspectRatio,
) -> @msvg.PreserveAspectRatio {
  @msvg.PreserveAspectRatio::{
    align: self.align.to_msvg(),
    meet_or_slice: self.meet_or_slice.to_msvg(),
  }
}
