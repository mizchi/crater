///|
/// The non-JS `framebuffer_to_rgba_base64_js` fuses RGBA expansion into the
/// base64 loop (encoding 3 pixels / 12 bytes at a time). Prove it stays byte-
/// identical to the straightforward "expand to an RGBA array, then encode"
/// reference for every pixel-count remainder (n % 3 in {0, 1, 2}), including the
/// tail path. JS uses a separate Buffer-based extern, so guard this to non-JS.
#cfg(not(target="js"))
test "fused framebuffer base64 matches rgba-expansion reference" {
  let palette_r = [10, 20, 30, 255, 0]
  let palette_g = [40, 50, 60, 255, 0]
  let palette_b = [70, 80, 90, 255, 0]
  let palette_len = palette_r.length()
  for n = 1; n <= 12; n = n + 1 {
    let pixels : Array[Int] = []
    for i = 0; i < n; i = i + 1 {
      pixels.push(i % palette_len)
    }
    let fused = framebuffer_to_rgba_base64_js(
      pixels, palette_r, palette_g, palette_b,
    )
    let rgba : Array[Int] = []
    for idx in pixels {
      rgba.push(palette_r[idx])
      rgba.push(palette_g[idx])
      rgba.push(palette_b[idx])
      rgba.push(255)
    }
    let reference = encode_bytes_base64(rgba)
    assert_eq(fused, reference)
  }
}
