///|
/// Framebuffer output encoding helpers.

///|
#cfg(target="js")
extern "js" fn framebuffer_to_rgba_base64_js(
  pixels : Array[Int],
  palette_r : Array[Int],
  palette_g : Array[Int],
  palette_b : Array[Int],
) -> String =
  #|(pixels, pr, pg, pb) => {
  #|  const n = pixels.length;
  #|  const buf = new Uint8Array(n * 4);
  #|  for (let i = 0; i < n; i++) {
  #|    const idx = pixels[i];
  #|    const o = i * 4;
  #|    buf[o] = pr[idx] | 0;
  #|    buf[o + 1] = pg[idx] | 0;
  #|    buf[o + 2] = pb[idx] | 0;
  #|    buf[o + 3] = 255;
  #|  }
  #|  if (typeof Buffer === "function") {
  #|    return Buffer.from(buf.buffer, buf.byteOffset, buf.byteLength).toString("base64");
  #|  }
  #|  let s = '';
  #|  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  #|  const len = buf.length;
  #|  let i = 0;
  #|  for (; i + 2 < len; i += 3) {
  #|    const b0 = buf[i], b1 = buf[i+1], b2 = buf[i+2];
  #|    s += chars[b0 >> 2] + chars[((b0 & 3) << 4) | (b1 >> 4)] + chars[((b1 & 15) << 2) | (b2 >> 6)] + chars[b2 & 63];
  #|  }
  #|  if (i + 1 === len) {
  #|    const b0 = buf[i];
  #|    s += chars[b0 >> 2] + chars[(b0 & 3) << 4] + '==';
  #|  } else if (i + 2 === len) {
  #|    const b0 = buf[i], b1 = buf[i+1];
  #|    s += chars[b0 >> 2] + chars[((b0 & 3) << 4) | (b1 >> 4)] + chars[(b1 & 15) << 2] + '=';
  #|  }
  #|  return s;
  #|}

///|
#cfg(not(target="js"))
fn framebuffer_to_rgba_base64_js(
  pixels : Array[Int],
  palette_r : Array[Int],
  palette_g : Array[Int],
  palette_b : Array[Int],
) -> String {
  let rgba : Array[Int] = []
  for idx in pixels {
    rgba.push(palette_r[idx])
    rgba.push(palette_g[idx])
    rgba.push(palette_b[idx])
    rgba.push(255)
  }
  encode_bytes_base64(rgba)
}

///|
pub fn framebuffer_to_rgba_base64(
  fb : Framebuffer,
  palette : DynamicPalette,
) -> String {
  let palette_r : Array[Int] = []
  let palette_g : Array[Int] = []
  let palette_b : Array[Int] = []
  for color in palette.colors {
    palette_r.push(color.r)
    palette_g.push(color.g)
    palette_b.push(color.b)
  }
  framebuffer_to_rgba_base64_js(fb.pixels, palette_r, palette_g, palette_b)
}
