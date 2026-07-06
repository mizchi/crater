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
  // Fuse the RGBA expansion into the base64 loop instead of materializing an
  // ~n*4-int RGBA buffer first: that intermediate was pure memory-bandwidth
  // cost for a full-viewport screenshot (the BiDi captureScreenshot path).
  // RGBA is 4 bytes/pixel and base64 groups 3 bytes, and lcm(4,3)=12 bytes =
  // 3 pixels = 4 base64 quads, so whole groups of 3 pixels land exactly on a
  // base64 group boundary with no carry. Keep the plain (incrementally grown)
  // StringBuilder — eagerly presizing it to the multi-MB output measured slower
  // (worse cache/paging) than incremental growth.
  let n = pixels.length()
  let out = StringBuilder::new()
  let full = n / 3
  for g = 0; g < full; g = g + 1 {
    let i = g * 3
    let p0 = pixels[i]
    let p1 = pixels[i + 1]
    let p2 = pixels[i + 2]
    let r0 = palette_r[p0]
    let g0 = palette_g[p0]
    let b0 = palette_b[p0]
    let r1 = palette_r[p1]
    let g1 = palette_g[p1]
    let b1 = palette_b[p1]
    let r2 = palette_r[p2]
    let g2 = palette_g[p2]
    let b2 = palette_b[p2]
    // Bytes r0 g0 b0 | 255 r1 g1 | b1 255 r2 | g2 b2 255 -> four base64 quads.
    write_base64_quad(out, r0, g0, b0, 0)
    write_base64_quad(out, 255, r1, g1, 0)
    write_base64_quad(out, b1, 255, r2, 0)
    write_base64_quad(out, g2, b2, 255, 0)
  }
  // Tail: the last n % 3 pixels (0, 1 or 2) form up to 8 RGBA bytes. `full * 3`
  // pixels is `full * 12` bytes (a multiple of 3), so the stream splits cleanly
  // here; encode the remainder on its own (it carries the base64 padding).
  let rem = n - full * 3
  if rem > 0 {
    let tail : Array[Int] = []
    for k = full * 3; k < n; k = k + 1 {
      let p = pixels[k]
      tail.push(palette_r[p])
      tail.push(palette_g[p])
      tail.push(palette_b[p])
      tail.push(255)
    }
    out.write_string(encode_bytes_base64(tail))
  }
  out.to_string()
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
