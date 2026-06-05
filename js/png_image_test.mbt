///|
test "renderHtmlToImagePngBase64 produces a valid PNG" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:8px;height:8px;background:rgb(255,0,0)"></div>
    #|</body></html>
  let b64 = renderHtmlToImagePngBase64(html, 8, 8)
  // Non-empty, and a PNG: the 8-byte signature 89 50 4E 47 0D 0A 1A 0A
  // base64-encodes to a stream beginning with "iVBORw0KGgo".
  assert_true(b64.length() > 0)
  assert_true(b64.has_prefix("iVBORw0KGgo"))
}

///|
test "renderHtmlToImageRgba returns the framebuffer pixels" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:4px;height:4px;background:rgb(255,0,0)"></div>
    #|</body></html>
  let pixels = renderHtmlToImageRgba(html, 4, 4)
  // 4x4 RGBA = 64 ints
  assert_eq(pixels.length(), 64)
  // top-left pixel is the red box
  assert_eq(pixels[0], 255)
  assert_eq(pixels[1], 0)
  assert_eq(pixels[2], 0)
  assert_eq(pixels[3], 255)
}
