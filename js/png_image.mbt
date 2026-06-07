///|
/// Encode a direct RGBA framebuffer (four 0..255 channels per pixel,
/// row-major) into a base64 PNG. Unlike the terminal framebuffer encoder
/// (which takes palette indices), this consumes the gfx software backend's
/// true-color output, so HTML can be rendered straight to a PNG for image
/// VRT tooling.
#borrow(rgba)
extern "js" fn rgba_to_png_base64_js(
  width : Int,
  height : Int,
  rgba : Array[Int],
) -> String =
  #|(width, height, rgba) => {
  #|  const zlib = typeof require === "function" ? require("node:zlib") : null;
  #|  let crcTable = globalThis.__craterPngCrcTable;
  #|  if (!crcTable) {
  #|    crcTable = new Uint32Array(256);
  #|    for (let n = 0; n < 256; n++) {
  #|      let c = n;
  #|      for (let k = 0; k < 8; k++) {
  #|        c = (c & 1) !== 0 ? (0xedb88320 ^ (c >>> 1)) >>> 0 : (c >>> 1) >>> 0;
  #|      }
  #|      crcTable[n] = c >>> 0;
  #|    }
  #|    globalThis.__craterPngCrcTable = crcTable;
  #|  }
  #|  function crc32(typeBuf, dataBuf) {
  #|    let crc = 0xffffffff;
  #|    for (let i = 0; i < typeBuf.length; i++) {
  #|      crc = (crcTable[(crc ^ typeBuf[i]) & 0xff] ^ (crc >>> 8)) >>> 0;
  #|    }
  #|    for (let i = 0; i < dataBuf.length; i++) {
  #|      crc = (crcTable[(crc ^ dataBuf[i]) & 0xff] ^ (crc >>> 8)) >>> 0;
  #|    }
  #|    return (crc ^ 0xffffffff) >>> 0;
  #|  }
  #|  function adler32(buf) {
  #|    let a = 1;
  #|    let b = 0;
  #|    for (let i = 0; i < buf.length; i++) {
  #|      a = (a + (buf[i] & 0xff)) % 65521;
  #|      b = (b + a) % 65521;
  #|    }
  #|    return ((b << 16) | a) >>> 0;
  #|  }
  #|  function deflateStore(raw) {
  #|    const parts = [Buffer.from([0x78, 0x01])];
  #|    for (let offset = 0; offset < raw.length;) {
  #|      const len = Math.min(65535, raw.length - offset);
  #|      const final = offset + len >= raw.length ? 1 : 0;
  #|      const block = Buffer.allocUnsafe(5 + len);
  #|      block[0] = final;
  #|      block.writeUInt16LE(len, 1);
  #|      block.writeUInt16LE((~len) & 0xffff, 3);
  #|      raw.copy(block, 5, offset, offset + len);
  #|      parts.push(block);
  #|      offset += len;
  #|    }
  #|    const checksum = Buffer.allocUnsafe(4);
  #|    checksum.writeUInt32BE(adler32(raw), 0);
  #|    parts.push(checksum);
  #|    return Buffer.concat(parts);
  #|  }
  #|  function deflatePngData(raw) {
  #|    if (zlib && typeof zlib.deflateSync === "function") {
  #|      return zlib.deflateSync(raw, { level: 1 });
  #|    }
  #|    return deflateStore(raw);
  #|  }
  #|  function chunk(type, data) {
  #|    const typeBuf = Buffer.from(type, "ascii");
  #|    const out = Buffer.allocUnsafe(8 + data.length + 4);
  #|    out.writeUInt32BE(data.length, 0);
  #|    typeBuf.copy(out, 4);
  #|    data.copy(out, 8);
  #|    out.writeUInt32BE(crc32(typeBuf, data), 8 + data.length);
  #|    return out;
  #|  }
  #|  const raw = Buffer.allocUnsafe(height * (width * 4 + 1));
  #|  let src = 0;
  #|  let dst = 0;
  #|  for (let y = 0; y < height; y++) {
  #|    raw[dst++] = 0;
  #|    for (let x = 0; x < width; x++) {
  #|      raw[dst++] = rgba[src++] & 0xff;
  #|      raw[dst++] = rgba[src++] & 0xff;
  #|      raw[dst++] = rgba[src++] & 0xff;
  #|      raw[dst++] = rgba[src++] & 0xff;
  #|    }
  #|  }
  #|  const compressed = deflatePngData(raw);
  #|  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  #|  const ihdr = Buffer.allocUnsafe(13);
  #|  ihdr.writeUInt32BE(width >>> 0, 0);
  #|  ihdr.writeUInt32BE(height >>> 0, 4);
  #|  ihdr[8] = 8;
  #|  ihdr[9] = 6;
  #|  ihdr[10] = 0;
  #|  ihdr[11] = 0;
  #|  ihdr[12] = 0;
  #|  const chunks = [
  #|    signature,
  #|    chunk("IHDR", ihdr),
  #|    chunk("IDAT", compressed),
  #|    chunk("IEND", Buffer.alloc(0)),
  #|  ];
  #|  const png = Buffer.concat(chunks);
  #|  return png.toString("base64");
  #|}

///|
/// Render an HTML document to a base64-encoded PNG via the gfx software
/// backend (image VRT). Companion to `renderHtmlToPaintTree` (geometry);
/// this returns true-color pixels.
pub fn renderHtmlToImagePngBase64(
  html : String,
  width : Int,
  height : Int,
) -> String {
  let image = @gfx_vrt.render_html_to_image(
    html,
    @types.Size::new(width.to_double(), height.to_double()),
  )
  rgba_to_png_base64_js(image.width, image.height, image.pixels)
}

///|
/// Render an HTML document to a flat RGBA pixel buffer (row-major, four
/// 0..255 channels per pixel) via the gfx software backend.
pub fn renderHtmlToImageRgba(
  html : String,
  width : Int,
  height : Int,
) -> Array[Int] {
  @gfx_vrt.render_html_to_image(
    html,
    @types.Size::new(width.to_double(), height.to_double()),
  ).pixels
}

///|
/// Render text to a base64-encoded PNG using the built-in 5x7 bitmap font
/// (black on white) via the gfx software backend. `scale` is the pixel size
/// of each font cell.
pub fn renderTextToImagePngBase64(
  text : String,
  width : Int,
  height : Int,
  scale : Int,
) -> String {
  let image = @gfx_vrt.render_text_to_image(text, width, height, scale~)
  rgba_to_png_base64_js(image.width, image.height, image.pixels)
}

///|
/// Install a TrueType/OpenType font (raw bytes as 0..255 ints) as the
/// global glyph provider, so HTML text renders real glyph shapes through
/// the gfx pipeline. Returns false if the font could not be parsed.
pub fn setFontProviderFromBytes(data : Array[Int]) -> Bool {
  let bytes = Bytes::from_array(data.map(fn(i) { (i & 0xff).to_byte() }))
  match @glyph.glyph_provider_from_bytes(bytes) {
    Some(provider) => {
      @glyph.set_glyph_provider(provider)
      true
    }
    None => false
  }
}

///|
/// Render HTML to a flat RGBA pixel buffer by driving crater's assembler
/// onto the gfx **web** backend (WebGPU/WebGL stub driver + the JS runtime
/// at globalThis.__craterGfxWeb). This is the same path a real WebGPU
/// device uses; the JS runtime rasterizes (CPU today, GPU when available).
pub fn renderHtmlViaWebBackendRgba(
  html : String,
  width : Int,
  height : Int,
) -> Array[Int] {
  @gfx_web.install_js_web_backend()
  let driver = @gfx_web.webgpu_driver(width, height)
  let root = @renderer_vrt.render_html_to_paint_tree(
    html,
    @types.Size::new(width.to_double(), height.to_double()),
  )
  @gfx_bridge.render_paint_tree(driver, root, width~, height~) catch {
    _ => ()
  }
  @gfx_web.web_backend_read_pixels()
}

///|
/// Render HTML to a base64 PNG via the gfx web backend (see
/// `renderHtmlViaWebBackendRgba`).
pub fn renderHtmlViaWebBackendPngBase64(
  html : String,
  width : Int,
  height : Int,
) -> String {
  let pixels = renderHtmlViaWebBackendRgba(html, width, height)
  rgba_to_png_base64_js(width, height, pixels)
}
