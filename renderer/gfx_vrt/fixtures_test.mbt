// Image-VRT baselines: representative HTML fixtures rendered to pixels via
// the gfx software backend and snapshotted as ASCII. These run under
// `moon test` (no browser / font needed) and complement the geometry-level
// paint-tree VRT. Re-baseline with `moon test --update` when the rendered
// pixels intentionally change.

///|
fn render_ascii(html : String, w : Double, h : Double) -> String {
  render_html_to_image(html, @types.Size::new(w, h)).to_ascii()
}

///|
test "image vrt: stacked background blocks" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:16px;height:4px;background:#000000"></div>
    #|<div style="width:16px;height:4px;background:#ffffff"></div>
    #|<div style="width:16px;height:4px;background:#808080"></div>
    #|</body></html>
  inspect(
    render_ascii(html, 16.0, 12.0),
    content=(
      #|@@@@@@@@@@@@@@@@
      #|@@@@@@@@@@@@@@@@
      #|@@@@@@@@@@@@@@@@
      #|@@@@@@@@@@@@@@@@
      #|                
      #|                
      #|                
      #|                
      #|================
      #|================
      #|================
      #|================
      #|
    ),
  )
}

///|
test "image vrt: bordered box" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:16px;height:12px;border:2px solid #000000;box-sizing:border-box;background:#ffffff"></div>
    #|</body></html>
  inspect(
    render_ascii(html, 16.0, 12.0),
    content=(
      #|@@@@@@@@@@@@@@@@
      #|@@@@@@@@@@@@@@@@
      #|@@            @@
      #|@@            @@
      #|@@            @@
      #|@@            @@
      #|@@            @@
      #|@@            @@
      #|@@            @@
      #|@@            @@
      #|@@@@@@@@@@@@@@@@
      #|@@@@@@@@@@@@@@@@
      #|
    ),
  )
}

///|
test "image vrt: side-by-side flex boxes" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="display:flex;width:16px;height:8px">
    #|<div style="width:8px;height:8px;background:#000000"></div>
    #|<div style="width:8px;height:8px;background:#808080"></div>
    #|</div>
    #|</body></html>
  inspect(
    render_ascii(html, 16.0, 8.0),
    content=(
      #|@@@@@@@@========
      #|@@@@@@@@========
      #|@@@@@@@@========
      #|@@@@@@@@========
      #|@@@@@@@@========
      #|@@@@@@@@========
      #|@@@@@@@@========
      #|@@@@@@@@========
      #|
    ),
  )
}

///|
test "image vrt: grid 2x2" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="display:grid;grid-template-columns:8px 8px;grid-template-rows:6px 6px;width:16px;height:12px">
    #|<div style="background:#000000"></div>
    #|<div style="background:#555555"></div>
    #|<div style="background:#aaaaaa"></div>
    #|<div style="background:#ffffff"></div>
    #|</div>
    #|</body></html>
  inspect(
    render_ascii(html, 16.0, 12.0),
    content=(
      #|@@@@@@@@********
      #|@@@@@@@@********
      #|@@@@@@@@********
      #|@@@@@@@@********
      #|@@@@@@@@********
      #|@@@@@@@@********
      #|--------        
      #|--------        
      #|--------        
      #|--------        
      #|--------        
      #|--------        
      #|
    ),
  )
}

///|
test "image vrt: absolute positioned overlap paints later on top" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="position:relative;width:16px;height:12px;background:#eeeeee">
    #|<div style="position:absolute;left:2px;top:2px;width:8px;height:6px;background:#000000"></div>
    #|<div style="position:absolute;left:6px;top:4px;width:8px;height:6px;background:#888888"></div>
    #|</div>
    #|</body></html>
  inspect(
    render_ascii(html, 16.0, 12.0),
    content=(
      #|                
      #|                
      #|  @@@@@@@@      
      #|  @@@@@@@@      
      #|  @@@@========  
      #|  @@@@========  
      #|  @@@@========  
      #|  @@@@========  
      #|      ========  
      #|      ========  
      #|                
      #|                
      #|
    ),
  )
}

///|
test "image vrt: translucent box alpha-blends over white" {
  let html =
    #|<html><body style="margin:0;background:#ffffff">
    #|<div style="width:16px;height:8px;background:#ffffff"></div>
    #|<div style="position:absolute;left:0;top:0;width:16px;height:8px;background:rgba(0,0,0,0.5)"></div>
    #|</body></html>
  inspect(
    render_ascii(html, 16.0, 8.0),
    content=(
      #|================
      #|================
      #|================
      #|================
      #|================
      #|================
      #|================
      #|================
      #|
    ),
  )
}
