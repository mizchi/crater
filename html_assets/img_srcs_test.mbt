///|
test "extract_img_srcs accepts html attribute whitespace and case variants" {
  let html =
    #|<main>
    #|  <IMG
    #|    alt="Hero"
    #|    SRC = "hero.png">
    #|  <img data-src="lazy.png" srcset="ignored.png 1x" src='icon.svg'>
    #|  <image src="not-img.svg"></image>
    #|</main>
  let srcs = extract_img_srcs(html)
  inspect(srcs.length(), content="2")
  inspect(srcs[0], content="hero.png")
  inspect(srcs[1], content="icon.svg")
}
