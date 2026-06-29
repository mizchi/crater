///|
fn solid(
  id : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  color : @types.Color,
  children : Array[@paint_model.PaintNode],
) -> @paint_model.PaintNode {
  @paint_model.PaintNode::new(
    id,
    "div",
    x,
    y,
    w,
    h,
    { ..@paint_model.PaintProperties::default(), background_color: color },
    children,
  )
}

///|
test "render_paint_tree_to_image produces the expected pixels" {
  let root = solid(
    "root",
    0.0,
    0.0,
    8.0,
    8.0,
    @types.Color::rgb(255, 255, 255),
    [solid("box", 2.0, 2.0, 4.0, 4.0, @types.Color::rgb(0, 0, 0), [])],
  )
  let image = render_paint_tree_to_image(root, 8, 8)
  debug_inspect(image.pixel_at(0, 0), content="(255, 255, 255, 255)")
  debug_inspect(image.pixel_at(3, 3), content="(0, 0, 0, 255)")
  debug_inspect(image.pixel_at(7, 7), content="(255, 255, 255, 255)")
}

///|
test "to_ascii renders a snapshot-friendly image" {
  let root = solid(
    "root",
    0.0,
    0.0,
    8.0,
    8.0,
    @types.Color::rgb(255, 255, 255),
    [solid("box", 2.0, 2.0, 4.0, 4.0, @types.Color::rgb(0, 0, 0), [])],
  )
  let image = render_paint_tree_to_image(root, 8, 8)
  // white background (space) with a dark 4x4 box ('@') in the middle
  inspect(
    image.to_ascii(),
    content=(
      #|        
      #|        
      #|  @@@@  
      #|  @@@@  
      #|  @@@@  
      #|  @@@@  
      #|        
      #|        
      #|
    ),
  )
}

///|
test "render_html_to_image rasterizes a styled box through the VRT pipeline" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:8px;height:8px;background:rgb(255,0,0)"></div>
    #|</body></html>
  let image = render_html_to_image(html, @types.Size::new(8.0, 8.0))
  inspect(image.width, content="8")
  inspect(image.height, content="8")
  // the red box paints the top-left pixel
  debug_inspect(image.pixel_at(0, 0), content="(255, 0, 0, 255)")
}

///|
test "render_text_to_image draws legible bitmap text" {
  // "CRATER" at scale 1: 6 glyphs * 6 cells = 36 wide, 7 tall
  inspect(
    render_text_to_image("CRATER", 36, 7).to_ascii(),
    content=(
      #| @@@  @@@@   @@@  @@@@@ @@@@@ @@@@  
      #|@   @ @   @ @   @   @   @     @   @ 
      #|@     @   @ @   @   @   @     @   @ 
      #|@     @@@@  @@@@@   @   @@@@  @@@@  
      #|@     @ @   @   @   @   @     @ @   
      #|@   @ @  @  @   @   @   @     @  @  
      #| @@@  @   @ @   @   @   @@@@@ @   @ 
      #|
    ),
  )
}
