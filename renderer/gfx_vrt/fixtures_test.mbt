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

///|
test "image vrt: overflow hidden clips the oversized child" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="overflow:hidden;width:8px;height:8px;background:#cccccc">
    #|<div style="width:16px;height:16px;background:#000000"></div>
    #|</div>
    #|</body></html>
  inspect(
    render_ascii(html, 16.0, 16.0),
    content=(
      #|@@@@@@@@        
      #|@@@@@@@@        
      #|@@@@@@@@        
      #|@@@@@@@@        
      #|@@@@@@@@        
      #|@@@@@@@@        
      #|@@@@@@@@        
      #|@@@@@@@@        
      #|                
      #|                
      #|                
      #|                
      #|                
      #|                
      #|                
      #|                
      #|
    ),
  )
}

///|
test "image vrt: element opacity dims to grey over white" {
  let html =
    #|<html><body style="margin:0;background:#ffffff">
    #|<div style="width:8px;height:8px;background:#ffffff"></div>
    #|<div style="position:absolute;left:0;top:0;width:8px;height:8px;background:#000000;opacity:0.5"></div>
    #|</body></html>
  inspect(
    render_ascii(html, 8.0, 8.0),
    content=(
      #|========
      #|========
      #|========
      #|========
      #|========
      #|========
      #|========
      #|========
      #|
    ),
  )
}

///|
// A first in-flow child's top margin collapses through the (margin:0) body
// and shifts the body box down in the viewport. The renderer must translate
// each node by its accumulated ancestor offset (paint coordinates are
// parent-relative), so the box paints below the blank margin band rather than
// flush to the top. Regression guard for the offset-accumulation fix.
test "image vrt: first-child top margin shifts content down" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:16px;height:4px;background:#000000;margin-top:4px"></div>
    #|</body></html>
  inspect(
    render_ascii(html, 16.0, 12.0),
    content=(
      #|                
      #|                
      #|                
      #|                
      #|@@@@@@@@@@@@@@@@
      #|@@@@@@@@@@@@@@@@
      #|@@@@@@@@@@@@@@@@
      #|@@@@@@@@@@@@@@@@
      #|                
      #|                
      #|                
      #|                
      #|
    ),
  )
}

///|
// An axis-aligned (`to bottom`) linear gradient is lowered as 1px solid
// strips perpendicular to the gradient axis, ramping black -> white down the
// box. Regression guard for gradient background lowering.
test "image vrt: vertical linear gradient ramps top to bottom" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:8px;height:8px;background:linear-gradient(to bottom,#000000,#ffffff)"></div>
    #|</body></html>
  inspect(
    render_ascii(html, 8.0, 8.0),
    content=(
      #|@@@@@@@@
      #|########
      #|********
      #|++++++++
      #|========
      #|--------
      #|::::::::
      #|........
      #|
    ),
  )
}

///|
// A 45deg rotation paints the box as its actual rotated quad (a diamond),
// filled from the node's visual polygon, rather than its axis-aligned bounding
// box. Regression guard for transform: rotate lowering.
test "image vrt: rotate 45deg paints a diamond" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:10px;height:10px;background:#000000;transform:rotate(45deg);margin:3px"></div>
    #|</body></html>
  inspect(
    render_ascii(html, 22.0, 22.0),
    content=(
      #|                      
      #|       @@             
      #|      @@@@            
      #|     @@@@@@           
      #|    @@@@@@@@          
      #|   @@@@@@@@@@         
      #|  @@@@@@@@@@@@        
      #| @@@@@@@@@@@@@@       
      #| @@@@@@@@@@@@@@       
      #|  @@@@@@@@@@@@        
      #|   @@@@@@@@@@         
      #|    @@@@@@@@          
      #|     @@@@@@           
      #|      @@@@            
      #|       @@             
      #|                      
      #|                      
      #|                      
      #|                      
      #|                      
      #|                      
      #|                      
      #|
    ),
  )
}

///|
// `border-radius: 50%` on a square box resolves the percentage against the
// box dimension (negative-encoded radius -> min_dim/2) and paints a full
// circle, not the bounding square. Regression guard for percentage radius
// resolution.
test "image vrt: border-radius 50pct paints a circle" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:12px;height:12px;background:#000000;border-radius:50%"></div>
    #|</body></html>
  inspect(
    render_ascii(html, 12.0, 12.0),
    content=(
      #|   =#%%#=   
      #| .#@@@@@@#. 
      #| #@@@@@@@@# 
      #|=@@@@@@@@@@=
      #|#@@@@@@@@@@#
      #|%@@@@@@@@@@%
      #|%@@@@@@@@@@%
      #|#@@@@@@@@@@#
      #|=@@@@@@@@@@=
      #| #@@@@@@@@# 
      #| .#@@@@@@#. 
      #|   =#%%#=   
      #|
    ),
  )
}

///|
// `border-radius: 50%` on a non-square box resolves the horizontal radius
// against the width and the vertical against the height, painting a true
// ellipse (wider than tall here) rather than a pill. Regression guard for the
// per-corner (rx, ry) uniform layout.
test "image vrt: border-radius 50pct on a wide box paints an ellipse" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:20px;height:10px;background:#000000;border-radius:50%"></div>
    #|</body></html>
  inspect(
    render_ascii(html, 20.0, 10.0),
    content=(
      #|    .=*#%@@%#*=.    
      #|  -#@@@@@@@@@@@@#-  
      #| +@@@@@@@@@@@@@@@@+ 
      #|=@@@@@@@@@@@@@@@@@@=
      #|%@@@@@@@@@@@@@@@@@@%
      #|%@@@@@@@@@@@@@@@@@@%
      #|=@@@@@@@@@@@@@@@@@@=
      #| +@@@@@@@@@@@@@@@@+ 
      #|  -#@@@@@@@@@@@@#-  
      #|    .=*#%@@%#*=.    
      #|
    ),
  )
}

///|
test "image vrt: border-radius rounds the corners" {
  let html =
    #|<html><body style="margin:0;background:#ffffff">
    #|<div style="width:12px;height:12px;background:#000000;border-radius:4px"></div>
    #|</body></html>
  inspect(
    render_ascii(html, 12.0, 12.0),
    content=(
      #| .*%@@@@%*. 
      #|.%@@@@@@@@%.
      #|*@@@@@@@@@@*
      #|%@@@@@@@@@@%
      #|@@@@@@@@@@@@
      #|@@@@@@@@@@@@
      #|@@@@@@@@@@@@
      #|@@@@@@@@@@@@
      #|%@@@@@@@@@@%
      #|*@@@@@@@@@@*
      #|.%@@@@@@@@%.
      #| .*%@@@@%*. 
      #|
    ),
  )
}
