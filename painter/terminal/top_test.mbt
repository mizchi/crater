///|
test "terminal facade renders svg scene to sixel" {
  let scene = Scene::new(@svg.circle("dot", 8.0, 8.0, 4.0))
  let sixel = render_svg_to_sixel(scene, 16, 16)

  inspect(sixel.length() > 0, content="true")
}

///|
test "terminal facade exposes kitty placement commands" {
  inspect(
    encode_kitty_put_placement(7, 11, 3, 2),
    content="\u001b_Ga=p,q=2,i=7,p=11,c=3,r=2;\u001b\\",
  )
  inspect(
    encode_kitty_delete_placement(7, 11),
    content="\u001b_Ga=d,q=2,d=i,i=7,p=11;\u001b\\",
  )
}

///|
test "terminal facade renders svg text to kitty cells" {
  let kitty = render_svg_text_to_kitty_cells(
    "<svg viewBox='0 0 16 16'><circle cx='8' cy='8' r='4'/></svg>",
    16,
    16,
    2,
    1,
    image_id=3,
    placement_id=5,
  )
  inspect(kitty.has_prefix("\u001b_Ga=T"), content="true")
  inspect(kitty.contains("c=2,r=1,i=3,p=5"), content="true")
}
